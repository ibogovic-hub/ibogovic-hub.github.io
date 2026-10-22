---
title: "Sandboxing your own systemd units before they bite you"
tags: Linux
---

Most infrastructure teams carefully harden the services they install from packages and then run their own glue as root with no restrictions at all. Examples include a Python exporter that scrapes a vendor API, a backup script triggered by a timer, or a small webhook receiver. Each one starts as a quick unit file with `ExecStart=` and `User=root`, and it usually stays that way for years. If any of them gets compromised through a dependency, a parsing bug, or a bad input, the attacker gets the whole host.

systemd already includes most of what you would otherwise build with containers or AppArmor profiles. You can harden a unit with a drop-in file, without changing the code, and measure the result in a few minutes.

## Start by measuring

`systemd-analyze security` scores every loaded service according to which sandboxing options are enabled. It runs locally and shows you exactly which options are missing:

```bash
systemd-analyze security --no-pager | sort -k2 -n -r | head -20
systemd-analyze security my-exporter.service
```

The per-unit view lists each check with a short explanation. Use the score to find gaps. It does not measure actual security. A unit can score well and still write secrets to a world-readable log. What the score does well is show you which units nobody has looked at.

## A practical baseline drop-in

Don't edit the vendor or original unit. Add a drop-in instead, so the hardening is visible and easy to revert:

```bash
sudo systemctl edit my-exporter.service
```

```ini
[Service]
# Identity: no fixed UID needed, no root
DynamicUser=yes
# State/cache/logs dirs created and owned automatically
StateDirectory=my-exporter
CacheDirectory=my-exporter

# Filesystem
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes
PrivateDevices=yes
ReadWritePaths=

# Kernel and process surface
NoNewPrivileges=yes
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
CapabilityBoundingSet=
AmbientCapabilities=

# Syscalls and network families
SystemCallArchitectures=native
SystemCallFilter=@system-service
SystemCallFilter=~@privileged @resources
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX

# Optional: only talk to what it needs
IPAddressDeny=any
IPAddressAllow=127.0.0.1 10.20.0.0/16
```

Then reload, restart, and measure again:

```bash
sudo systemctl daemon-reload
sudo systemctl restart my-exporter.service
systemctl status my-exporter.service
systemd-analyze security my-exporter.service | tail -1
```

## Where it breaks, and how to tell

A few options account for most of the breakage.

- **`MemoryDenyWriteExecute=yes`** breaks anything that uses a JIT. That includes Node.js, the JVM, some Python extensions, and PCRE JIT in certain builds. If the service dies at startup with `SIGSYS` or an mmap error, remove this option first.
- **`SystemCallFilter`** kills the process when it makes a disallowed syscall. To debug, temporarily add `SystemCallLog=~@system-service` (systemd 247 or newer), or set `SystemCallErrorNumber=EPERM` so the call fails without killing the process. Then check `journalctl -k` for audit lines that show the syscall number.
- **`ProtectSystem=strict`** makes the entire filesystem read-only. If the script writes to `/var/lib/something` or `/opt/app/logs`, either add that path to `ReadWritePaths=` or move the data to `StateDirectory=`/`LogsDirectory=`. Moving it is cleaner.
- **`DynamicUser=yes`** allocates a fresh UID, so files the service created earlier as root become unreadable to it. Migrate the data into the state directory once, or use a fixed system user if other tools need to share the files.
- **`RestrictAddressFamilies`** without `AF_NETLINK` breaks tools that enumerate interfaces. This is common in monitoring exporters.

Apply the options in groups, not all at once. Start with filesystem, identity, and `NoNewPrivileges`, since they almost never break anything. Add the kernel protections next, and syscall filtering last. After each group, restart the service and run its real workload, not just a status check. The timer-driven backup has to actually complete a backup before you move on.

## Keep it from regressing

Drop-ins live under `/etc/systemd/system/<unit>.d/override.conf`, so ship them through your configuration management like any other file. You can also add a check that fails if a unit's exposure score rises above a threshold:

```bash
#!/usr/bin/env bash
# fail if any listed unit's exposure score exceeds the limit
limit=4.0
rc=0
for u in my-exporter.service webhook.service backup.service; do
  score=$(systemd-analyze security "$u" 2>/dev/null | awk '/Overall exposure level/ {print $5}')
  if awk -v s="$score" -v l="$limit" 'BEGIN{exit !(s>l)}'; then
    echo "FAIL $u exposure=$score (limit $limit)"; rc=1
  else
    echo "OK   $u exposure=$score"
  fi
done
exit $rc
```

Run it from CI against a test VM or from your monitoring as a daily check. The specific limit is less important than having one, because a later change that quietly removes the drop-in will then get noticed.

## Why this matters

On real hosts, the services that cause incidents are rarely nginx or sshd. They are the in-house helpers that someone wrote during an outage and never revisited, often running as root, holding API tokens, and parsing input from systems you don't control. Wrapping them in a systemd sandbox takes a 20-line drop-in and an afternoon of testing, and it turns "the attacker owns the box" into "the attacker owns one empty directory and a loopback socket". It also documents in one file what each service is supposed to touch, which helps the next engineer who has to debug it at 3 a.m.
