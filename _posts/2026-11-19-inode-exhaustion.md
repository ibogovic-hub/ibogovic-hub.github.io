---
title: "When df says there is space but writes still fail: inode exhaustion"
tags: Linux
---

The page arrives at 03:00: a service cannot write its PID file, the package manager aborts with "No space left on device", and the on-call engineer runs `df -h`. The root filesystem is at 41%. Plenty of room. Twenty minutes go into checking quotas, the read-only remount theory and SELinux before someone runs `df -i` and sees 100% in the IUse% column.

Inode exhaustion is not exotic. On ext4 the inode count is fixed when the filesystem is created, based on a bytes-per-inode ratio. A filesystem formatted for typical workloads has a lot of space and a finite number of file slots. Fill those slots with millions of tiny files and the disk is "full" while most of the blocks are still unused.

## Where the small files come from

In my experience the culprits are almost always the same few:

- PHP or application session directories that nobody cleans up.
- Mail queues (Postfix `maildrop` or `deferred`) after a relay breaks and cron keeps sending mail into the queue.
- Build caches and package manager caches on CI runners.
- Monitoring agents or scripts writing one small file per check per host.
- Old kernels' module trees and headers on systems that never run `autoremove`.

None of these are large in bytes, so they never appear in the usual "what's using the disk" checks with `du -sh`.

## Finding the directory responsible

`du` can count inodes instead of bytes. Stay on one filesystem so you don't wander into `/proc` or network mounts:

```bash
# Which top-level directories hold the most inodes on /
sudo du --inodes -x -d 1 / 2>/dev/null | sort -n | tail -15

# Drill down into the worst one
sudo du --inodes -x -d 1 /var 2>/dev/null | sort -n | tail -15
```

Repeat the drill down until you find a directory with hundreds of thousands of entries. On older coreutils without `--inodes`, this works too:

```bash
sudo find /var -xdev -type d -print0 \
  | xargs -0 -I{} sh -c 'echo "$(find "{}" -maxdepth 1 | wc -l) {}"' \
  | sort -n | tail -15
```

It is slow on a big tree, but it does not need anything installed.

## Cleaning up without making it worse

`rm -rf /var/lib/php/sessions/*` fails with "Argument list too long" once the glob expands past the kernel's argument limit. Let `find` do the deletion itself:

```bash
# Delete session files older than two days, one filesystem only
sudo find /var/lib/php/sessions -xdev -type f -mtime +2 -delete
```

For a mail queue, use the MTA's own tooling (`postsuper -d ALL deferred`) rather than deleting files under its feet. And fix the cause before you clean up, or the slots will be gone again by morning.

## Making it stay fixed

Cleanup in the middle of an incident is not a fix. Two things make it one.

First, put the cleanup under systemd-tmpfiles so it runs on a schedule you already trust:

```ini
# /etc/tmpfiles.d/app-sessions.conf
# type path                         mode user     group    age
d      /var/lib/app/sessions        0770 www-data www-data 2d
```

`systemd-tmpfiles-clean.timer` runs daily on most distributions and will age out files older than two days. Check it with `systemctl list-timers systemd-tmpfiles-clean.timer`.

Second, monitor inodes the same way you monitor bytes. If you run node_exporter, the metrics are already there; most teams just never wrote the alert:

```text
(
  node_filesystem_files_free{fstype=~"ext4|xfs"}
  / node_filesystem_files{fstype=~"ext4|xfs"}
) < 0.10
and node_filesystem_readonly == 0
```

Alert at 10% free, give it a `for: 15m`, and attach the `du --inodes` one-liner to the runbook.

## Planning for it at mkfs time

If you know a volume will hold huge numbers of small files (a mail spool, a cache, an artifact store), size the inode table when you create it:

```bash
# One inode per 4 KiB instead of the default ratio
sudo mkfs.ext4 -i 4096 /dev/vg0/spool

# Check what an existing filesystem got
sudo tune2fs -l /dev/vg0/spool | grep -Ei 'inode count|inodes per group'
```

You cannot add inodes to an existing ext4 filesystem in place, except by growing it. XFS allocates inodes dynamically up to a percentage limit (`imaxpct`), so it runs out far less often, though it can still happen on a nearly full filesystem. Btrfs has no fixed inode table at all. That is a reasonable argument for XFS on volumes where you can't predict file counts.

## Why this matters

Every team I have worked with has lost an hour to this exactly once, because the first instinct is `df -h` and the number looks fine. The fix is cheap: one alert expression, one tmpfiles entry per known small-file producer, and `df -i` added to the disk-full runbook next to `df -h`. The incident it prevents is the confusing kind, where the obvious tool tells you everything is healthy while services fail around you. Those are the ones that run long at night.
