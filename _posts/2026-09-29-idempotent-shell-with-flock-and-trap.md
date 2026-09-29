---
title: "Stop cron jobs from stepping on each other with flock and trap"
tags: Automation
---

A backup script runs every 15 minutes from cron. For months it takes four minutes. Then the NFS target slows down, one run takes twenty, and cron starts the next one anyway. Now two copies of rsync are writing into the same destination, the second one deletes files the first one is still transferring, and the temp directory fills the root filesystem. Nobody notices until the monitoring alert for disk usage fires at 03:00.

This failure pattern is common and entirely avoidable. Cron has no idea whether the previous run finished. Neither does a systemd timer unless you configure it properly. Unless the script itself guards against overlap and cleans up after itself, it isn't safe to schedule.

## The two primitives

Two tools cover most of this: `flock(1)` from util-linux for mutual exclusion, and the shell `trap` builtin for cleanup. Both come with every mainstream distribution, so there's nothing to install and no daemon to run.

`flock` takes an advisory lock on a file descriptor. The kernel releases the lock when the process holding the descriptor exits, including when it's killed with SIGKILL or the box panics and reboots. That matters because you never have to clean up a stale lock. The classic PID-file approach doesn't have this property. A PID file left behind by a crashed run blocks every later run until someone deletes it by hand, or worse, the PID gets reused and the check passes for the wrong process.

`trap` runs a handler when the shell exits or receives a signal. Use it to remove temp files, unmount things, and log how the run ended.

## A template worth copying

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

readonly NAME="nightly-sync"
readonly LOCK="/run/lock/${NAME}.lock"
readonly LOG_TAG="${NAME}[$$]"

log() { logger -t "$LOG_TAG" -- "$*"; }

# Acquire the lock on fd 9; exit quietly if another run holds it.
exec 9>"$LOCK"
if ! flock -n 9; then
    log "previous run still active, skipping"
    exit 0
fi

WORKDIR="$(mktemp -d "/var/tmp/${NAME}.XXXXXX")"

cleanup() {
    local rc=$?
    rm -rf -- "$WORKDIR"
    if [[ $rc -eq 0 ]]; then
        log "finished ok"
    else
        log "failed rc=$rc"
    fi
    exit "$rc"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

log "starting, workdir=$WORKDIR"

# Bound runtime so a hung mount cannot hold the lock forever.
timeout --kill-after=60 1800 \
    rsync -a --delete --partial-dir="$WORKDIR/partial" \
    /srv/data/ /mnt/backup/data/
```

A few details here are easy to get wrong.

**The lock file is opened with `exec 9>`, not wrapped around a subshell.** Opening the descriptor in the main shell ties the lock to the script's whole lifetime. Child processes inherit fd 9, so a background child that outlives the script will keep holding the lock. Usually you want that. If you don't, close it in the child with `9>&-`.

**`flock -n` exits instead of waiting.** For periodic jobs, skipping a run is almost always correct. Queued runs pile up behind a slow one and then all fire together. If you really need to wait, use `flock -w 300` so the wait has a limit.

**The skip path exits 0.** A skipped run is not a failure. If it exited non-zero, cron would email you every 15 minutes during a slow period and you would learn to ignore the mail. Log the skip instead. If skips keep happening, alert on that from your log pipeline.

**`INT` and `TERM` get separate traps that call `exit`.** In bash, the `EXIT` trap fires on a normal exit or `set -e` failure. Whether it fires on signals depends on the shell and version. Converting the signal to an explicit `exit` with the conventional code (128 + signal number) makes the cleanup behave the same way everywhere.

**`timeout` puts a limit on the whole run.** A lock with no timeout just turns a hang into a silent outage: every later run skips politely forever. `--kill-after` sends SIGKILL if the process ignores SIGTERM, which rsync blocked in uninterruptible NFS I/O sometimes does.

## The systemd equivalent

If the job runs from a systemd timer, the unit already gives you part of this. A oneshot service won't start a second instance while the first is still active, so the timer won't overlap it. `RuntimeMaxSec=` bounds the runtime, `PrivateTmp=yes` handles temp cleanup, and the journal captures the exit status. Keep the `flock` anyway if anyone might run the script by hand or from another scheduler. That's how most overlap incidents actually start: someone runs it manually during an incident while the timer fires at the same time.

## Checking it works

Test the lock before trusting it. Run the script in one terminal. In a second terminal, run `flock -n /run/lock/nightly-sync.lock true; echo $?`. It should print 1 while the first run is active. Then `kill -9` the first run and repeat the check. It should print 0 right away, with no stale lock left behind. Finally, send SIGTERM to a running copy and confirm the work directory is gone and the log shows `failed rc=143`.

## Why this matters

Most scheduled-job incidents I have dealt with were not caused by bad logic in the job. They came from the job running at the wrong time: twice at once, on top of a half-finished previous run, or stuck forever while holding something. These bugs stay hidden while everything is fast and show up exactly when the infrastructure is already under stress, which is the worst time to debug them. The template above is about thirty lines. It turns "usually fine" into behavior you can predict and explain in a postmortem. Make it the default for every script that goes into cron.
