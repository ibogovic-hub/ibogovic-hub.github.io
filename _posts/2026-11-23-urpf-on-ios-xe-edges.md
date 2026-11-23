---
title: "Dropping spoofed traffic at the edge with uRPF on IOS XE"
tags: Cisco
---

During a flood, the source addresses in the capture look random. Some of them come from your own public prefix, and some come from RFC 1918 space arriving on an internet-facing interface. None of that traffic should ever have reached the router's forwarding path. An ingress ACL that lists bogons helps, but it goes stale and it says nothing about your customer-facing interfaces. Unicast Reverse Path Forwarding (uRPF) solves the general case using the routing table you already maintain.

## What uRPF actually checks

For each packet arriving on an interface with uRPF enabled, the router looks up the packet's source address in the FIB. The mode decides what counts as a pass:

- **Strict mode** (`rx`): the best route back to the source must point out the interface the packet came in on. Use it where routing is symmetric: customer access ports, single-homed sites and server VLANs.
- **Loose mode** (`any`): any route to the source in the FIB is enough, as long as that route is not a null route. Use it on multi-homed internet edges, where return traffic often leaves through a different link than the one it arrived on.

Loose mode looks weak, but it does two useful things. It drops traffic sourced from unrouted space. It also turns your RTBH setup into a source-based blackhole, because a source that resolves to Null0 fails the check.

## Configuration

Customer-facing or single-homed interface, strict mode:

```text
interface GigabitEthernet0/0/2
 description CUST-ACME access
 ip address 198.51.100.1 255.255.255.252
 ip verify unicast source reachable-via rx
 ipv6 verify unicast source reachable-via rx
```

Internet transit interface on a dual-homed edge, loose mode:

```text
interface TenGigabitEthernet0/1/0
 description TRANSIT-A
 ip verify unicast source reachable-via any
 ipv6 verify unicast source reachable-via any
```

If you carry a default route from transit, loose mode passes everything, because every source matches 0.0.0.0/0. On IOS XE, the `allow-default` keyword controls this. Without it, a default route is not considered valid for the check, which is the behaviour you want. Leave it off unless you have a specific reason to add it.

Use a numbered ACL to log what you drop without letting the log hide what's going on:

```text
access-list 199 deny   ip any any log-input
!
interface GigabitEthernet0/0/2
 ip verify unicast source reachable-via rx 199
```

When a packet fails uRPF, the router evaluates it against ACL 199. A `deny` keeps the drop and logs it. A `permit` would let the failing packet through, and that is your escape hatch during rollout. Rate-limit the logging (`logging rate-limit`) or you will flood your own syslog during an attack.

## Verifying it does something

```text
show ip interface GigabitEthernet0/0/2 | include verify|drops
show ip traffic | include RPF
show cef interface GigabitEthernet0/0/2 | include RPF
```

`show ip interface` shows the per-interface verification drops. Take a baseline right after enabling uRPF, then compare after a day. If drops climb on a port where you expected zero, either a customer is leaking addresses or your routing is less symmetric than you thought. Check which one before you blame the customer.

To track it over time, poll the counters. A small check over SSH with Netmiko is enough for a daily report:

```python
from netmiko import ConnectHandler
import re

dev = {"device_type": "cisco_xe", "host": "edge1.example.net",
       "username": "netops", "use_keys": True}

with ConnectHandler(**dev) as conn:
    out = conn.send_command("show ip interface")

current = None
for line in out.splitlines():
    if line and not line.startswith(" "):
        current = line.split()[0]
    m = re.search(r"(\d+) verification drops", line)
    if m and int(m.group(1)) > 0:
        print(f"{current}: {m.group(1)} uRPF drops")
```

## Where it bites

- **Asymmetric routing under strict mode.** This is the usual outage. A site that's dual-homed through two of your PEs, or a customer announcing a more-specific route through a backup link, gets its legitimate return traffic dropped. Before you enable strict mode, check `show ip cef <customer-prefix>` and confirm the best path points at that interface.
- **ECMP.** Strict mode accepts a packet if the incoming interface is one of the equal-cost paths. That's fine until an unequal-cost or backup path starts carrying traffic.
- **Platform support.** Hardware platforms differ in whether uRPF runs in the forwarding ASIC and whether enabling it costs TCAM or reduces throughput. Read the datasheet and release notes for your exact platform and release rather than assuming software-router behaviour.
- **VRFs.** The lookup runs in the interface's VRF. Leaked routes and shared services in another VRF can fail the check in ways that are not obvious from the global table.

## Rollout order that has worked for me

1. Enable loose mode on transit interfaces first. It carries the least risk and filters bogon sources immediately.
2. Enable strict mode with a permit-and-log ACL on single-homed customer ports. Leave it for a week and review the log.
3. Swap the ACL to deny on any port with clean logs.
4. Document every port where strict mode cannot run, with the reason. That list is your asymmetric-routing inventory, and it is useful on its own.

## Why this matters

Most spoofed traffic I have dealt with did not come from clever attackers. It came from misconfigured customer CPE, a NAT box leaking private addresses, or a compromised host on a network that never filtered its egress. uRPF is BCP 38 applied with a single interface command, and loose mode fixes a whole class of problem on edges where nobody wants to maintain a bogon ACL by hand. The real cost is learning where your routing is asymmetric, and you need to know that before an incident forces you to find out.
