---
title: "Idempotent network config backups: only commit what actually changed"
tags: Automation
---

Most teams that back up device configs nightly end up with the same problem: a Git repository full of noise. Every run produces a commit, but half the diffs are timestamps, NTP clock-period counters or "Last configuration change" banners. When something really does change at 2 a.m., nobody notices it because the history has trained everyone to ignore the diffs.

The fix is not a bigger tool. It is three small rules: normalise the output before you store it, commit only when the normalised text differs, and make the commit message say which devices changed.

## Normalise first

On Cisco IOS, `show running-config` starts with lines that change on every pull even when nothing meaningful did:

```
Building configuration...
Current configuration : 18342 bytes
! Last configuration change at 01:12:09 CET Tue Oct 27 2026 by netops
! NVRAM config last updated at 01:12:11 CET Tue Oct 27 2026 by netops
ntp clock-period 36028797
```

None of those belong in a diff. Strip them with a short list of regex patterns kept next to the script, so adding a new vendor's noise is a one-line change rather than a code edit.

## A minimal collector

The script below uses Netmiko to pull configs, filters the volatile lines, writes one file per device, and lets Git decide whether anything changed. It assumes an existing Git repo in `configs/` and credentials coming from the environment, not the file.

```python
#!/usr/bin/env python3
import os
import re
import subprocess
from pathlib import Path
from netmiko import ConnectHandler

REPO = Path("configs")
DEVICES = ["sw-core-01.lab", "sw-access-01.lab", "rtr-edge-01.lab"]

NOISE = [
    r"^Building configuration\.\.\.$",
    r"^Current configuration : \d+ bytes$",
    r"^! Last configuration change at .*$",
    r"^! NVRAM config last updated at .*$",
    r"^ntp clock-period \d+$",
]
NOISE_RE = re.compile("|".join(NOISE))


def normalise(text: str) -> str:
    lines = [l.rstrip() for l in text.splitlines() if not NOISE_RE.match(l.strip())]
    return "\n".join(lines).strip() + "\n"


def fetch(host: str) -> str:
    conn = ConnectHandler(
        device_type="cisco_ios",
        host=host,
        username=os.environ["NET_USER"],
        password=os.environ["NET_PASS"],
    )
    try:
        return conn.send_command("show running-config", read_timeout=60)
    finally:
        conn.disconnect()


def git(*args: str) -> str:
    return subprocess.run(
        ["git", "-C", str(REPO), *args], check=True, capture_output=True, text=True
    ).stdout


def main() -> None:
    failed = []
    for host in DEVICES:
        try:
            (REPO / f"{host}.cfg").write_text(normalise(fetch(host)))
        except Exception as exc:
            failed.append(f"{host}: {exc}")

    git("add", "-A")
    changed = git("diff", "--cached", "--name-only").split()
    if changed:
        names = ", ".join(Path(c).stem for c in changed)
        git("commit", "-m", f"config change: {names}")
        print(f"committed: {names}")
    else:
        print("no changes")

    if failed:
        print("FAILED:\n" + "\n".join(failed))
        raise SystemExit(1)


if __name__ == "__main__":
    main()
```

A few deliberate choices here:

- **Git is the change detector.** No hashing, no state file. `git diff --cached --name-only` is empty when nothing moved, so the run exits quietly.
- **Failures do not block successes.** One unreachable switch should not stop the other forty from being backed up, but the job still exits non-zero so the scheduler flags it.
- **The commit message is the alert.** "config change: sw-core-01.lab" is searchable and can be forwarded to chat as-is.

## Running it

Schedule it with a systemd timer or cron, and pipe non-empty output somewhere people read. A simple wrapper:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd /opt/netbackup
out=$(./collect.py 2>&1) || status=$?
if [[ "$out" != "no changes" ]]; then
  printf '%s\n' "$out" | mail -s "netbackup $(hostname)" netops@example.com
fi
exit "${status:-0}"
```

Now the mailbox only gets mail when a config changed or a device failed. That is the whole point.

## Where it breaks

Normalisation lists drift. A firmware upgrade adds a new volatile line, and suddenly every night commits again. Treat that as a signal: look at the diff, add the pattern, move on. Also be careful not to over-filter. Stripping `ntp clock-period` is safe; stripping all lines that contain a number is not, and I have seen that mistake hide an ACL change.

Secrets are the other trap. Type 7 passwords and SNMP communities end up in the repo. Either mask them in `normalise()` or keep the repository on the same access level as the devices themselves. Do not push it to a shared GitLab group because "it is only configs".

## Why this matters

In every incident review I have sat through where the question was "what changed?", the answer was either instantly available or nowhere. A backup job that commits every night is technically a backup, but operationally it is useless because nobody reads it. Cutting the noise to zero turns the same repository into a change log people actually trust, and that is what makes the 2 a.m. diff visible before the 8 a.m. ticket arrives.
