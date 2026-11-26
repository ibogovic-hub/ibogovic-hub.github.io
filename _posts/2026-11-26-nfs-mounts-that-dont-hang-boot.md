---
title: "NFS mounts that do not hang your boot or your shell"
tags: Linux
---

The storage team reboots a filer during a maintenance window. Twenty minutes later half your application servers are stuck: `df` hangs, `ls /` hangs when tab completion touches the mount point, and one host that rebooted at the same time sits in emergency mode because `/srv/shared` never came up. Nothing on those servers was broken. The way the NFS share was mounted was.

Most fstab NFS lines I find in the wild look like this:

```text
filer01:/export/shared  /srv/shared  nfs  defaults  0 0
```

That line carries three problems. It is a hard dependency for boot, so systemd waits on it before reaching `local-fs.target` or `remote-fs.target` and fails the boot if it cannot mount. It is mounted at boot whether anything needs it or not. And with default hard semantics plus no timeout tuning, any process that touches it while the server is gone blocks in uninterruptible sleep until the server returns.

## Let systemd mount it on demand

systemd reads fstab and generates `.mount` units from it. A few `x-systemd` options change the behaviour completely:

```text
filer01:/export/shared  /srv/shared  nfs  _netdev,nofail,noauto,x-systemd.automount,x-systemd.idle-timeout=10min,x-systemd.mount-timeout=30s,vers=4.2,hard,timeo=600,retrans=2  0 0
```

What each one does:

- `x-systemd.automount` creates an autofs trigger at `/srv/shared`. The real mount happens on first access, not at boot.
- `noauto` together with automount means boot never waits for the filer.
- `nofail` keeps a missing mount from pulling the box into emergency mode.
- `_netdev` marks it as network storage so ordering is after the network is up.
- `x-systemd.idle-timeout=10min` unmounts after inactivity. That shrinks the window in which a dead server can wedge anything.
- `x-systemd.mount-timeout=30s` caps how long a mount attempt may block.

Apply it without a reboot:

```bash
sudo umount /srv/shared 2>/dev/null || true
sudo systemctl daemon-reload
sudo systemctl restart remote-fs.target
systemctl list-units --type=automount
ls /srv/shared >/dev/null && findmnt /srv/shared
```

`findmnt` should now show two entries: an `autofs` layer and, after access, the `nfs4` mount underneath.

## Hard versus soft is not the fix you think

The usual reaction to a hang is to switch to `soft`. Be careful. A soft mount returns `EIO` to the application after the retries expire, and many applications do not handle a failed write well. You can end up with truncated files and no error in the logs that anyone reads. For anything that writes data, keep `hard`. It is the correct default because it guarantees a write either completes or waits.

What you control instead is blast radius: automount plus idle timeout means fewer processes are holding the mount when the server disappears, and boot does not depend on it. For read-only shares like software repositories or reference data, `soft` with sensible `timeo` and `retrans` values is acceptable, because the worst case is a failed read that can be retried.

## Keep monitoring and tooling off the mount

A detail that bites in practice: your monitoring agent's filesystem check calls `statfs` on every mount, including the NFS one, and hangs with it. Then you lose metrics for the whole host exactly when you need them. Exclude network filesystems from generic disk checks and monitor them separately with a timeout. For node_exporter that is the `--collector.filesystem.fs-types-exclude` flag; for ad hoc scripts, wrap the call:

```bash
#!/usr/bin/env bash
# check-nfs.sh - report whether a mount responds within 5 seconds
mp="${1:-/srv/shared}"
if timeout 5 stat -f "$mp" >/dev/null 2>&1; then
  echo "OK $mp"
else
  echo "STALE_OR_SLOW $mp"
  exit 2
fi
```

Note that `timeout` cannot always kill a process in `D` state, so run the check from a separate process per mount and do not let your agent wait on it serially.

Also check `updatedb`. On many distributions `mlocate` or `plocate` is configured to skip `nfs` and `nfs4` in `PRUNEFS`, but I have seen custom configs that dropped that line and had the nightly indexer walk a multi-terabyte share.

## Verifying the behaviour before the filer does it for you

Test it on purpose. On a non-production host, block the filer with a temporary firewall rule, then confirm the box still reboots cleanly and that only processes actually touching `/srv/shared` stall:

```bash
sudo nft add table inet nfstest
sudo nft add chain inet nfstest out '{ type filter hook output priority 0; }'
sudo nft add rule inet nfstest out ip daddr 192.0.2.10 tcp dport 2049 drop
# reboot, log in, check: systemctl is-system-running; df -h -x nfs4
sudo nft delete table inet nfstest
```

`systemctl is-system-running` should report `running` or `degraded`, not leave you at an emergency shell.

## Why this matters

Every NFS incident I have been pulled into followed the same pattern: the storage outage was short and planned, and the outage it caused on the compute side was long and unplanned. Hosts sat in emergency mode waiting for someone with console access, monitoring went dark because the agent hung on `statfs`, and recovery meant rebooting machines that were never actually broken. Moving the mounts to systemd automount with `nofail` and timeouts is a one-line change per share. Doing it before the next filer maintenance window is cheaper than explaining afterwards why a storage reboot took out the application tier.
