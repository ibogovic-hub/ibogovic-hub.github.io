---
title: "Stop letting the kernel OOM killer pick your victims: memory limits with systemd"
tags: Linux
---

A familiar incident: a monitoring host goes unresponsive for ten minutes, SSH times out, and when it finally recovers the kernel log shows the OOM killer took out `sshd` or the metrics agent instead of the runaway log-processing job that caused the problem. By the time the kernel OOM killer acts, the box has usually been thrashing for a while, reclaiming page cache and swapping, and everything on it is degraded. The kernel picks a victim by its own heuristics, not by what you consider expendable.

On any modern distribution running systemd with cgroup v2, you can take that decision back. The tools are already installed: per-unit memory controls, slices, and `systemd-oomd`. This post walks through a setup I use on infrastructure hosts where a few batch workloads share a machine with services that must stay reachable.

## Check that you are on cgroup v2

Everything below assumes the unified hierarchy. Verify it first:

```bash
stat -fc %T /sys/fs/cgroup
# cgroup2fs  -> unified hierarchy, good
# tmpfs      -> legacy/hybrid, the memory.* knobs below behave differently
```

Most current releases of Debian, Ubuntu, RHEL and Fedora default to cgroup v2. If you see `tmpfs`, fix that before going further.

## MemoryHigh versus MemoryMax

systemd exposes two limits that map to cgroup v2 files:

- `MemoryHigh=` is a throttling threshold. When a cgroup exceeds it, the kernel aggressively reclaims memory from that cgroup and slows its allocations. The processes keep running, just slower.
- `MemoryMax=` is a hard cap. Exceeding it triggers the OOM killer, but scoped to that cgroup only.

The practical pattern is to set `MemoryHigh` somewhat below `MemoryMax`. The workload gets pushed back on before it hits the wall, and if it still blows through, only that unit dies. The rest of the host never sees global memory pressure.

There is also `MemoryLow=` and `MemoryMin=`, which protect a cgroup from reclaim. That is the other half of the story: protect the things you need, constrain the things you can lose.

## Put batch work in its own slice

Rather than tuning every unit individually, group expendable workloads into a slice and limit the slice. A drop-in for a slice file:

```ini
# /etc/systemd/system/batch.slice
[Unit]
Description=Expendable batch workloads

[Slice]
MemoryHigh=6G
MemoryMax=7G
CPUWeight=50
```

Then assign services to it:

```ini
# /etc/systemd/system/logcrunch.service.d/10-slice.conf
[Service]
Slice=batch.slice
```

For ad-hoc jobs, you do not need a unit file at all:

```bash
systemd-run --slice=batch.slice --unit=reindex-$(date +%s) \
  -p MemoryHigh=2G -p MemoryMax=3G \
  /usr/local/bin/reindex --full
```

That runs the command as a transient service inside the slice, with its own limits nested under the slice limits. Output goes to the journal under the generated unit name, which is also handy for later auditing.

## Protect what must survive

On the other side, give the access path and monitoring agent guaranteed memory:

```ini
# /etc/systemd/system/ssh.service.d/10-protect.conf
[Service]
MemoryMin=64M
OOMScoreAdjust=-900
```

`MemoryMin` keeps reclaim away from that memory; `OOMScoreAdjust` makes the global OOM killer far less likely to choose it if things do go global. Apply the same to your node exporter or whatever agent tells you the host is in trouble. A monitoring agent that dies first during a memory incident is worse than useless, because the graphs show a gap exactly where you needed data.

## Add systemd-oomd for pressure-based kills

Hard limits cover known workloads. `systemd-oomd` covers the case where pressure builds slowly across several units. It watches Pressure Stall Information (PSI) and kills the cgroup with the most reclaim activity when pressure stays above a threshold for a sustained period, before the kernel gets into thrashing territory.

Enable it and opt in the slice:

```ini
# /etc/systemd/system/batch.slice.d/20-oomd.conf
[Slice]
ManagedOOMMemoryPressure=kill
ManagedOOMMemoryPressureLimit=60%
```

```bash
systemctl enable --now systemd-oomd
systemctl daemon-reload
oomctl          # shows monitored cgroups and current pressure
```

Read the PSI numbers directly when tuning:

```bash
cat /sys/fs/cgroup/batch.slice/memory.pressure
# some avg10=0.00 avg60=0.00 avg300=0.00 total=...
# full avg10=0.00 avg60=0.00 avg300=0.00 total=...
```

`full` means all non-idle tasks in the cgroup were stalled on memory. Sustained non-zero `full` values are your signal that the limits are too tight or the workload has grown. These are also good metrics to scrape: alert on pressure, not just on used memory, because used memory on Linux is mostly page cache and tells you very little.

## Verify before you trust it

Do not ship this without testing a kill. On a non-production host:

```bash
systemd-run --slice=batch.slice -p MemoryMax=200M --wait \
  stress-ng --vm 1 --vm-bytes 500M --timeout 30s
journalctl -k --since "-2min" | grep -i "memory cgroup out of memory"
```

You should see a cgroup-scoped OOM kill referencing the transient unit, and nothing else on the host affected. `systemctl status batch.slice` and `systemd-cgtop` show live usage per slice.

## Why this matters

Every memory incident I have worked on had the same shape: one workload grew, the whole host degraded, and the recovery cost more time than the original problem. The global OOM killer is a last resort that fires late and picks victims you would never choose. Moving those decisions into unit files makes them explicit, reviewable in config management, and testable. The batch job still fails, but it fails alone, the host stays reachable, and the monitoring agent is still there to tell you why.
