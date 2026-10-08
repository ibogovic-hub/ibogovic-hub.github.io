---
title: "Auditing and tightening systemd service sandboxing"
tags: Linux
---

A small internal exporter running as root got a path-traversal bug in its HTTP handler. Nothing dramatic happened, but during the review the uncomfortable question was obvious: if someone had found it first, what could the process actually touch? The answer was "everything root can touch", because the unit file was four lines long and nobody had looked at it since it was written.

Most fleets have dozens of services like this. Packaged daemons from distributions are increasingly hardened upstream, but in-house units, vendor agents and quick wrappers around scripts usually run with the full default privilege set. systemd has shipped the tools to fix this for years. The useful part is that you can measure the exposure, tighten it incrementally and verify the result without rewriting the application.

## Measure first

`systemd-analyze security` scores every loaded service by which sandboxing options are missing. Run it without arguments for a fleet-wide overview, or with a unit name for the detail:

```bash
systemd-analyze security --no-pager | sort -k2 -n -r | head -20
systemd-analyze security node-exporter-custom.service
```

The score is a heuristic, not a security guarantee, but it is a good triage list. Anything marked "UNSAFE" that listens on a network socket or parses untrusted input goes to the top. Units with no listener and no external input go to the bottom.

## Tighten with a drop-in, not an edit

Never edit vendor unit files in place; package upgrades will overwrite them. Use a drop-in so the hardening survives and stays visible in review:

```bash
sudo systemctl edit node-exporter-custom.service
```

A reasonable starting baseline for a network-facing daemon that only reads system state and writes to its own directory:

```ini
[Service]
DynamicUser=yes
StateDirectory=node-exporter-custom
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes
PrivateDevices=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectKernelLogs=yes
ProtectControlGroups=yes
ProtectClock=yes
ProtectHostname=yes
RestrictNamespaces=yes
RestrictRealtime=yes
RestrictSUIDSGID=yes
LockPersonality=yes
MemoryDenyWriteExecute=yes
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX
CapabilityBoundingSet=
AmbientCapabilities=
SystemCallArchitectures=native
SystemCallFilter=@system-service
SystemCallFilter=~@privileged @resources
UMask=0077
```

Then reload and restart:

```bash
sudo systemctl daemon-reload
sudo systemctl restart node-exporter-custom.service
systemd-analyze security node-exporter-custom.service | tail -1
```

## What breaks, and how to tell

Hardening is not free. The options that cause the most incidents in practice:

- `ProtectSystem=strict` makes the entire filesystem read-only. If the service writes logs or caches outside `StateDirectory`, `CacheDirectory` or `LogsDirectory`, add an explicit `ReadWritePaths=` rather than relaxing to `full`.
- `MemoryDenyWriteExecute=yes` breaks anything with a JIT: Java, Node.js, some Python extensions, LuaJIT. Drop it for those runtimes.
- `DynamicUser=yes` allocates a transient UID. Files owned by a fixed service account elsewhere will become unreadable. If the service needs stable ownership across hosts, use a normal `User=` instead.
- `SystemCallFilter` failures kill the process with SIGSYS. The journal shows it, and the audit log shows the syscall number:

```bash
journalctl -u node-exporter-custom.service -b --no-pager | tail -30
ausearch -m SECCOMP -ts recent
```

Translate the number with `ausyscall <nr>` (from the audit package) and decide whether to allow that syscall group or fix the application.

`CapabilityBoundingSet=` with an empty value removes every capability. A service binding to a port below 1024 needs `CAP_NET_BIND_SERVICE` in both the bounding and ambient sets, which is still far smaller than full root.

## Roll it out without surprises

Treat this like any other config change. Write the drop-in into configuration management (an Ansible `template` to `/etc/systemd/system/<unit>.d/hardening.conf` with a `daemon-reload` handler works fine), push it to a canary host first, and let it run through at least one full cycle of whatever the service does — log rotation, scheduled jobs, certificate renewal. Many failures only appear on the path that runs once a day.

It also helps to record the score in your monitoring. A small script that runs `systemd-analyze security --json=short` and exports the exposure per unit makes regressions visible when someone ships a new unit without a drop-in.

## Why this matters

In real incidents the first bug is rarely the whole story; the damage comes from what the compromised process can reach next. Most of the services I have reviewed in internal environments ran as root not because they needed it but because nobody had a reason to change the default. A drop-in of twenty lines, tested on one canary host, removes most of that reach: no writes outside a single directory, no new privileges, no kernel interfaces, no raw sockets. It costs an afternoon per service class, needs no application changes, and turns "what could the attacker touch?" from a guess into something you can read in the unit file.
