---
title: Stop letting the kernel OOM killer pick your victims
tags: Linux
---

A build agent VM starts swapping, load climbs, and twenty minutes later SSH finally answers. `dmesg` shows the kernel OOM killer fired — and it killed sshd's child, or the node_exporter, or postgres. Anything but the runaway Java process that actually ate the box. That outcome is not a bug. The kernel OOM killer is a last-resort memory reclaimer, not a policy engine. It picks by `oom_score`, which is dominated by resident set size adjusted by `oom_score_adj`, and it only runs once allocation has already failed. By then the machine has spent minutes thrashing, and every latency SLO you had is gone.

The fix is to stop treating memory as a global pool and start treating it as a per-service budget, enforced by cgroup v2 before the kernel is ever cornered.

## The three knobs that matter

Under cgroup v2 (default on any current distro with systemd), each unit gets `memory.min`, `memory.low`, `memory.high`, and `memory.max`. systemd exposes them as `MemoryMin=`, `MemoryLow=`, `MemoryHigh=`, `MemoryMax=`.

The important distinction is between `MemoryHigh` and `MemoryMax`:

- `MemoryHigh` is a throttle. Cross it and the kernel puts the cgroup under aggressive reclaim pressure and stalls its allocations. The process keeps running, just slowly. Nothing dies.
- `MemoryMax` is a wall. Cross it and the cgroup gets OOM-killed — but only processes inside that cgroup, which is exactly the scoping the global killer refuses to give you.

`MemoryMin` is a reclaim guarantee: memory up to that amount is protected from reclaim even under system-wide pressure. That is what you use to keep sshd and your monitoring agent alive.

## A concrete drop-in

Do not edit vendor unit files. Use drop-ins so package upgrades do not clobber you.

```ini
# /etc/systemd/system/buildagent.service.d/10-memory.conf
[Service]
# Throttle at 6G: reclaim hard, stall allocations, stay alive.
MemoryHigh=6G
# Hard ceiling: kill inside this cgroup only, never the rest of the host.
MemoryMax=8G
MemorySwapMax=0
# Restart cleanly instead of leaving a half-dead process tree.
Restart=on-failure
RestartSec=5s
```

And the protection side, which people forget:

```ini
# /etc/systemd/system/sshd.service.d/10-memory.conf
[Service]
MemoryMin=64M
ManagedOOMPreference=avoid
```

Apply and verify against the real cgroup files, not against what you think systemd parsed:

```bash
systemctl daemon-reload
systemctl restart buildagent.service

systemctl show buildagent.service -p MemoryHigh -p MemoryMax -p MemoryCurrent

CG=$(systemctl show -p ControlGroup --value buildagent.service)
cat /sys/fs/cgroup${CG}/memory.high
cat /sys/fs/cgroup${CG}/memory.max
cat /sys/fs/cgroup${CG}/memory.events
```

`memory.events` is the file to watch. It counts `low`, `high`, `max`, and `oom` / `oom_kill` events for that cgroup. If `high` is incrementing steadily and `oom_kill` stays at zero, your throttle is doing its job and the limit is roughly right. If `high` is climbing constantly and the service is missing deadlines, the budget is too small — that is a capacity decision, not a tuning trick.

## Pressure, not utilisation

The second half of this is PSI. `/proc/pressure/memory` and the per-cgroup `memory.pressure` report how much wall time tasks actually lost stalled on memory. Utilisation percentages tell you nothing about whether anyone is suffering; PSI tells you exactly that.

```bash
# Host-wide
cat /proc/pressure/memory
# Per service
cat /sys/fs/cgroup${CG}/memory.pressure
```

The `some avg60` field is the one to alert on. Sustained double-digit values there mean tasks are spending a meaningful fraction of their time waiting on memory, and you will see it as latency long before you see it as a crash. node_exporter exposes these as `node_pressure_memory_waiting_seconds_total`; a `rate()` over that is a far better alerting signal than free-memory thresholds, which fire constantly on healthy machines because Linux uses free memory for page cache by design.

If you want the automated version, `systemd-oomd` will act on PSI thresholds and kill the worst cgroup before the kernel gets involved. It is worth enabling on shared build and CI hosts, with `ManagedOOMSwap=` and `ManagedOOMMemoryPressure=` set per slice. Be deliberate about it — an oomd that is too eager is its own outage.

## Why this matters

Every memory incident I have worked has the same shape: the failure was not the memory exhaustion, it was the blast radius. One misbehaving workload took down the observability agent and the management path, so the first thirty minutes of the incident went to regaining access rather than fixing anything. Setting `MemoryMax` on the workloads that can misbehave and `MemoryMin` on the two or three things you need to debug the box turns a host outage into a single service restart that your monitoring actually reports. It costs one drop-in file per unit and no runtime overhead, and it is the difference between reading a graph during the incident and reading `dmesg` after it.
