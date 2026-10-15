---
title: "Systemd timers that tell you when they fail"
tags: Linux
---

A backup job ran from cron every night for months. At some point a package update changed a library path, the script started exiting with status 1 after two seconds, and nobody noticed. Cron sent its output to a local mailbox that nobody had read since the host was built. The failure only came to light when someone needed a restore.

This is the usual way cron fails. It runs the job, but it does not track whether the job worked, it does not stop two copies running at once, and it logs very little. Systemd timers fix most of this, and once the first unit is written they are no harder to manage.

## The pieces

A timer is two units. The `.service` says what to run. The `.timer` says when to run it. Because the job runs as an ordinary service, you get everything systemd already does for services: logs go to journald, the exit status is recorded, resource limits apply, and you can hook up a failure handler.

Here is the backup job written as units:

```ini
# /etc/systemd/system/backup-etc.service
[Unit]
Description=Nightly /etc backup
OnFailure=notify-failure@%n.service
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/backup-etc.sh
User=backup
Nice=10
IOSchedulingClass=idle
TimeoutStartSec=30min
ProtectSystem=strict
ReadWritePaths=/var/backups/etc
PrivateTmp=yes
```

```ini
# /etc/systemd/system/backup-etc.timer
[Unit]
Description=Run /etc backup nightly

[Timer]
OnCalendar=*-*-* 02:15:00
RandomizedDelaySec=15min
Persistent=true

[Install]
WantedBy=timers.target
```

Some of these settings matter more than they look:

- `Type=oneshot` means the unit counts as active only while the script runs. If the timer fires while the last run is still going, systemd does not start a second copy. With cron you need `flock` to get the same guarantee.
- `Persistent=true` stores the last run time on disk. If the host was powered off at 02:15, the job runs soon after boot instead of being skipped silently.
- `RandomizedDelaySec` spreads the start times out. Without it, fifty VMs built from the same template all hit the backup target in the same second.
- `TimeoutStartSec` kills a run that hangs. A backup stuck on an NFS mount should fail loudly rather than block every later run.

## The failure hook

`OnFailure=` is what fixes the original problem. If the service ends in a failed state, systemd starts the unit named there. A template unit lets one handler cover every job:

```ini
# /etc/systemd/system/notify-failure@.service
[Unit]
Description=Failure notification for %i

[Service]
Type=oneshot
ExecStart=/usr/local/bin/notify-failure.sh %i
```

```bash
#!/usr/bin/env bash
# /usr/local/bin/notify-failure.sh
set -euo pipefail
unit="$1"
host="$(hostname -f)"
log="$(journalctl -u "$unit" -n 30 --no-pager -o cat)"

curl -fsS -m 10 -X POST "${ALERT_WEBHOOK:?}" \
  -H 'Content-Type: application/json' \
  --data "$(jq -n --arg u "$unit" --arg h "$host" --arg l "$log" \
    '{text: ("FAILED: " + $u + " on " + $h + "\n```\n" + $l + "\n```")}')"
```

Set `ALERT_WEBHOOK` with a drop-in or an `EnvironmentFile=` that only root can read, not in the unit file itself. The alert includes the last 30 log lines, so whoever is on call can often see the cause without logging in.

Turn it on and check it:

```bash
systemctl daemon-reload
systemctl enable --now backup-etc.timer
systemctl list-timers backup-etc.timer
systemctl start backup-etc.service      # run once by hand
systemctl status backup-etc.service     # check exit code and recent logs
```

Test the alert path on purpose before you rely on it. Point `ExecStart` at `/bin/false` in a temporary drop-in, start the service, and make sure the message arrives. An alert path that has never fired should be treated as broken.

## Seeing it across a fleet

If you already run node_exporter, start it with `--collector.systemd`. Each unit then exposes a `node_systemd_unit_state` series per state, and a Prometheus rule on `node_systemd_unit_state{state="failed"} == 1` gives you a second warning that does not depend on the webhook. The rule also covers the case that a push alert cannot report: a host that went quiet because it is down.

For an ad-hoc check, `systemctl --failed` on each host, or `systemctl list-timers --all` to compare last and next runs, will show you a timer that stopped firing.

## Why this matters

Most silent outages I have dealt with were not complex failures. They were simple jobs that had been failing for weeks without anyone knowing: certificate renewals, log rotation, backups, config exports from network gear. The script was usually fine at first. What was missing was any feedback that it had stopped working. Moving these jobs to timers with an `OnFailure` hook takes about an hour per host type. After that, a broken job shows up the next morning instead of during an incident.
