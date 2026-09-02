---
title: Hardening the services you forgot you were running
tags: Security
---

A vendor-supplied exporter runs on 400 hosts. It ships as a systemd unit, runs as root because the install script never bothered to create a user, and it reads a config file that contains an API token for your monitoring backend. Nobody has looked at it since the day it was deployed. That is the shape of most real compromises I have cleaned up: not a heroic zero-day, but a long-lived daemon with far more authority than its job requires.

The useful question is not "is this daemon vulnerable" — you cannot know that. The useful question is "if this daemon is fully controlled by an attacker tomorrow, what can it reach?" On any modern Linux host that question has a concrete, testable answer, and you can change the answer without touching the vendor's code.

## Start by measuring, not guessing

`systemd-analyze security` scores every unit on the host against the sandboxing options systemd exposes. It is a blunt instrument — the score is not a risk rating — but as a triage list it is excellent, because it sorts your fleet's daemons by how much of the kernel and filesystem they can still touch.

```bash
# Rank all running units by exposure, worst first
systemd-analyze security --no-pager | sort -k2 -rn | head -20

# Then drill into one
systemd-analyze security node_exporter.service
```

The per-unit output tells you exactly which knob is unset and what it would buy you. Work top-down; the first five directives usually remove most of the reachable surface.

## A baseline drop-in that rarely breaks anything

Do not edit vendor unit files. Use a drop-in so package upgrades do not silently revert your hardening:

```bash
sudo systemctl edit node_exporter.service
```

```ini
# /etc/systemd/system/node_exporter.service.d/hardening.conf
[Service]
# Identity: no root, no way to regain privilege
User=node_exporter
Group=node_exporter
NoNewPrivileges=yes
CapabilityBoundingSet=
AmbientCapabilities=

# Filesystem: read-only OS, private /tmp, nothing under /home or /root
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes
StateDirectory=node_exporter

# Kernel and device surface
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectKernelLogs=yes
ProtectControlGroups=yes
PrivateDevices=yes
RestrictSUIDSGID=yes
LockPersonality=yes
MemoryDenyWriteExecute=yes

# Syscalls and address families
SystemCallFilter=@system-service
SystemCallFilter=~@privileged @resources
SystemCallArchitectures=native
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX
RestrictNamespaces=yes
```

Reload and verify:

```bash
sudo systemctl daemon-reload
sudo systemctl restart node_exporter
systemd-analyze security node_exporter.service | tail -5
journalctl -u node_exporter -n 50 --no-pager
```

## The parts that actually bite

Three failure modes account for nearly every rollback I have seen.

`ProtectSystem=strict` makes the entire filesystem hierarchy read-only, including `/etc` and `/var`. Any daemon that writes a pidfile, a cache, or a local database will die on start. The fix is not to loosen the directive; it is to declare the write target explicitly with `StateDirectory=`, `CacheDirectory=`, `LogsDirectory=`, or as a last resort `ReadWritePaths=`. Those create the directory with the right ownership and keep the rest of the tree immutable.

`SystemCallFilter=@system-service` kills processes with SIGSYS when they hit a denied call, and the log line is not always obvious. If a service starts dying after you apply the filter, switch temporarily to `SystemCallErrorNumber=EPERM` so calls return an error instead of killing the process, and watch what the application complains about. Go and Rust binaries are usually fine; anything that shells out, loads plugins, or manages its own namespaces frequently is not.

`PrivateDevices=yes` removes access to physical devices. Agents that read SMART data, talk to a TPM, or open a raw socket for ICMP will break. That is a signal worth acting on — a daemon that genuinely needs raw device access should get a narrow `DeviceAllow=` line and a single capability such as `CAP_NET_RAW`, not an empty bounding set reversed back to root.

Roll this out the way you would any config change: one canary host, a full restart cycle, then a functional check that the service still does its job — not just that systemd reports it active. `systemctl is-active` will happily report success for a daemon that started, failed its first scrape, and is silently returning nothing.

## Why this matters

Most of the hardening work that survives contact with production is boring and structural: shrink what a process can reach, then leave it alone. Patching is reactive and always lags disclosure. Sandboxing is proactive and holds regardless of which CVE lands next quarter, because it constrains the blast radius rather than the specific bug. In an environment where you inherit dozens of third-party agents you did not write and cannot audit, that distinction is the whole game. The drop-in above takes ten minutes per service type and is the cheapest reduction in exposure available on a Linux fleet — and unlike a firewall rule, it keeps working when the traffic is already inside.
