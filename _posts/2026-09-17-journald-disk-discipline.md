---
title: Stop letting journald eat your root filesystem
tags: Linux
---

The page came in at 03:12: root filesystem at 96% on a monitoring VM that had been quiet for months. No application had grown, no core dumps, no runaway log rotation in `/var/log/*.log`. The space was in `/var/log/journal` — 3.4 GB of binary journal files accumulated since the machine was built, because someone had enabled persistent logging and never told journald what "persistent" was supposed to cost.

This is one of the most common slow-motion outages I see on Linux fleets, and it is entirely preventable with three settings and one unit file.

## Why the default surprises people

When `/var/log/journal` exists, systemd-journald switches from volatile (tmpfs, capped at a fraction of RAM) to persistent mode. In persistent mode the default cap is 10% of the filesystem's size, with 15% kept free. On a 20 GB root volume that is 2 GB of logs before journald even thinks about vacuuming — and it computes that against the *filesystem*, not against a dedicated partition. If `/var` is not split out, journald is quietly authorised to consume a tenth of your root disk, and it will, given a chatty service.

The second surprise is the rate limiter. `RateLimitIntervalSec=30s` and `RateLimitBurst=10000` mean a single misbehaving unit can write ten thousand messages every thirty seconds and journald will happily accept them. That is how 3.4 GB appears without anyone noticing.

## The fix

Do not edit `/etc/systemd/journald.conf` directly — it gets replaced on package upgrade and it makes config management messy. Use a drop-in:

```ini
# /etc/systemd/journald.conf.d/10-limits.conf
[Journal]
Storage=persistent
Compress=yes
SystemMaxUse=512M
SystemKeepFree=1G
SystemMaxFileSize=64M
MaxRetentionSec=2week
MaxFileSec=1day
RateLimitIntervalSec=30s
RateLimitBurst=2000
ForwardToSyslog=no
```

Apply and verify:

```bash
sudo systemctl restart systemd-journald
journalctl --disk-usage
sudo journalctl --vacuum-size=512M
```

A few of these deserve comment.

`SystemMaxFileSize=64M` matters more than the total cap. Journald deletes whole archived files, never partial ones. With the default file size (1/8 of `SystemMaxUse`) you delete in large, lumpy steps and your usable retention swings wildly. Smaller files mean the vacuum is granular and retention is predictable.

`MaxFileSec=1day` forces a rotation boundary every day even on an idle host. Without it, a low-volume machine can keep the same active journal file open for months, which is miserable when you need to ship or prune by date.

`ForwardToSyslog=no` is the one people forget. If you are running rsyslog alongside journald — which most distro images still do — every message is written twice, once to `/var/log/journal` and once to `/var/log/syslog`. You pay double the disk and double the I/O for the same data. Pick one. If you are shipping to a central collector via rsyslog, then you want journald small and syslog authoritative; if you are shipping with a journal-native agent, turn rsyslog off entirely.

## Catching it before the page

The cap protects the disk, but it does not tell you *who* was noisy. Journald can answer that directly:

```bash
# top writers in the current boot, by message count
journalctl -b -o json --output-fields=_SYSTEMD_UNIT \
  | jq -r '._SYSTEMD_UNIT // "kernel"' \
  | sort | uniq -c | sort -rn | head -20

# who got rate-limited
journalctl -b | grep -i "Suppressed .* messages from"
```

That second command is the one worth wiring into a check. When journald suppresses messages it logs the fact, including the offending unit's cgroup path. A host that is regularly hitting the rate limit is a host with a bug — usually a service in a crash loop, a filesystem error repeating every few seconds, or a Python app logging a stack trace per request.

For fleet-wide visibility, `journalctl --disk-usage` is parseable enough for a textfile collector:

```bash
# /usr/local/bin/journal-usage-metrics.sh
set -eu
BYTES=$(journalctl --disk-usage | grep -oP '\d+(\.\d+)?[KMG]' | head -1 | numfmt --from=iec)
printf 'node_journal_disk_bytes %s\n' "$BYTES" \
  > /var/lib/node_exporter/textfile/journal.prom.$$
mv /var/lib/node_exporter/textfile/journal.prom.$$ \
   /var/lib/node_exporter/textfile/journal.prom
```

Run it from a systemd timer every five minutes. The atomic rename matters — node_exporter will read a half-written file otherwise.

## Why this matters

Disk-full incidents are rarely interesting and always expensive. They take out unrelated services on the same host, they corrupt databases that were mid-write, and they generate the kind of 3 a.m. page where the fix is trivial but the cleanup is not. Every fleet I have inherited has had at least one class of unbounded growth sitting in the base image, and journald is the most common one because the default *looks* bounded — there is a percentage in the docs, so people assume someone thought about it.

Put the drop-in in your base image or your config management role, not in a runbook. A limit that has to be applied by hand is a limit that exists on the hosts you remembered and nowhere else.
