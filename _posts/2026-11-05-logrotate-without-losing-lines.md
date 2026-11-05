---
title: "Logrotate without losing lines or filling the disk"
tags: Linux
---

A familiar ticket: the disk on an application server is at 100%, yet `du` across the filesystem adds up to a fraction of that. Somebody runs `lsof +L1` and finds a 40 GB log file marked `(deleted)` that is still held open by the application. Logrotate did its job and renamed and compressed the file, but nobody told the process to reopen it. The process kept writing into an inode with no name, and the space never came back.

The opposite failure is just as common and harder to spot. Someone "fixes" the first problem by adding `copytruncate`, and from then on a few lines go missing at every rotation. Nobody notices until an incident timeline has a gap at exactly 00:00.

Both problems come from not knowing how the application handles its log file descriptor. That is the decision that matters, and the directives follow from it.

## Three ways an application can write logs

**It reopens on a signal.** nginx (USR1), rsyslog (HUP) and most well-behaved daemons work this way. Logrotate renames the file, the daemon gets the signal, and it opens a fresh file under the original name. Nothing is lost and space is freed when the compressed copy is written. This is the case you want.

**It never reopens.** Many in-house Java and Python services open the file once at startup. Renaming does nothing useful because the process keeps writing to the renamed file. `copytruncate` exists for this case. Logrotate copies the contents and then truncates the original in place. Anything written between the copy and the truncate is lost, and the window grows with file size. The app also needs to open the file with `O_APPEND`. Without it, the process keeps writing at its old offset after the truncate and you get a sparse file that looks enormous.

**It writes to stdout.** If the service runs under systemd, let journald handle it and leave logrotate out of it. If it runs in a container, the runtime's log driver is responsible for rotation.

## A config that handles the signal case properly

```text
/var/log/myapp/*.log {
    daily
    rotate 14
    maxsize 500M
    missingok
    notifempty
    compress
    delaycompress
    dateext
    dateformat -%Y%m%d-%s
    create 0640 myapp adm
    sharedscripts
    postrotate
        systemctl kill -s HUP --kill-whom=main myapp.service 2>/dev/null || true
    endscript
}
```

A few of these directives matter more than they look:

- `maxsize 500M` together with `daily` rotates when either condition is met. This only helps if logrotate runs more than once a day. On systemd distributions, check `systemctl cat logrotate.timer`. Many ship it as `OnCalendar=daily`, so a log that runs away at 09:00 has the whole day to fill the disk. Add a drop-in with `OnCalendar=hourly` if you rely on size limits.
- `delaycompress` leaves the most recent rotated file uncompressed. A process that hasn't reopened yet may still write to it for a moment, and tools that tail rotated files can still read it.
- `dateformat` with `%s` keeps names unique when size-based rotation fires more than once a day. Without it, the second rotation of the day fails because the target name already exists.
- `sharedscripts` sends one HUP for the whole glob instead of one per file.
- `--kill-whom=main` signals only the main process, not every worker in the cgroup. Some workers treat HUP as "exit".

## Test it before the night it matters

Logrotate ships with a dry run, and most people never use it:

```bash
# Show what would happen, without doing anything
logrotate -d /etc/logrotate.d/myapp

# Actually rotate now, using a scratch state file so the real schedule is untouched
logrotate -f -v -s /tmp/logrotate-test.state /etc/logrotate.d/myapp

# Confirm the process let go of the old file
lsof -p "$(systemctl show -p MainPID --value myapp.service)" | grep -E '\.log'
lsof +L1 | grep myapp
```

If `lsof +L1` still shows a deleted log after a forced rotation, your postrotate signal isn't working. Either the app ignores it or you sent it to the wrong PID. Find out now, not when the disk alarm goes off.

Also check the state file and the last run. A syntax error in a single file under `/etc/logrotate.d/` can stop processing for other entries, depending on the version and the error. `journalctl -u logrotate.service --since today` shows it quickly. It's worth alerting on the unit failing, because a broken logrotate fails silently until a disk fills up.

## When you are stuck with copytruncate

Some vendor software can't be signalled or restarted. In that case:

- Rotate on size more often, so each copy is small and the loss window is short.
- Check the file is opened with `O_APPEND`. `cat /proc/<pid>/fdinfo/<fd>` shows a `flags` field you can decode.
- Write down in the config file that you accept losing lines, so the next engineer doesn't assume the logs are complete.

## Why this matters

Over the years I've seen more disk-full outages caused by log handling than by data growth. Almost all of them came from a deleted-but-open file or a logrotate timer that ran less often than people thought. The fix takes a few minutes per service: know whether the app reopens, signal it correctly, rotate on size, and run the dry run once. The payoff is the night when you need the logs from 23:59 to 00:01 and they are all there.
