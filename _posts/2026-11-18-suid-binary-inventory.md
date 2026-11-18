---
title: "Inventory and trim the SUID binaries on your servers"
tags: Security
---

Every post-exploitation checklist has the same early step: `find / -perm -4000`. An attacker with a low-privilege shell lists every setuid-root binary on the box and checks each one against known escape techniques. Most of the fleets I've looked at fail this check in the same way. Nobody chose those binaries. They came in with the base image, a package someone needed once, or a vendor agent, and they never got reviewed again.

The fix isn't exotic. Know what is setuid or setgid, decide which of those binaries you actually need, strip the rest, and alert when the list changes.

## Take the inventory

Start with a list you can diff. Limit the search to local filesystems so it doesn't wander into NFS mounts, and include setgid binaries, since a setgid binary that grants the `shadow` or `disk` group is nearly as dangerous as setuid root.

```bash
#!/usr/bin/env bash
# suid-inventory.sh - list setuid/setgid files with owner, mode and package
set -euo pipefail

find / -xdev \( -perm -4000 -o -perm -2000 \) -type f -print0 2>/dev/null |
  while IFS= read -r -d '' f; do
    mode=$(stat -c '%a %U:%G' "$f")
    pkg=$(dpkg -S "$f" 2>/dev/null | cut -d: -f1 || true)
    printf '%s\t%s\t%s\n' "$f" "$mode" "${pkg:-UNOWNED}"
  done | sort
```

On RHEL-family systems, replace `dpkg -S` with `rpm -qf`. Pay attention to the package column. If a setuid file shows up as `UNOWNED`, no package manager put it there. It could be a manual install, a leftover from a vendor tarball, or something worse. Investigate every one of these before you look at anything else.

Note that `-xdev` skips other mounts, so run the script once for each local filesystem if `/usr`, `/opt` or `/var` are mounted separately.

## Decide what stays

A typical minimal Debian server ends up with something like `passwd`, `chsh`, `chfn`, `gpasswd`, `newgrp`, `su`, `sudo`, `mount`, `umount` and `unix_chkpwd`. That's a short list, but plenty of it is unnecessary on a server where nobody logs in interactively and identity comes from a directory:

- `chsh` and `chfn` let users change their shell and GECOS fields. Servers rarely need that, and these two have a long history of bugs.
- `newgrp` and `gpasswd` only matter if you use group passwords. You almost certainly don't.
- `mount` and `umount` only need setuid for user-mountable entries in fstab. Without those entries, root can mount without the bit.
- Anything installed by tooling, such as old `pkexec`, legacy `ping` on distributions that haven't moved to file capabilities, or helpers from X11 or desktop packages pulled in by a careless dependency.

Removing the package is better than stripping the bit. If the package has to stay, use `dpkg-statoverride` so an upgrade doesn't quietly put the bit back. A plain `chmod u-s` lasts until the next upgrade of that package.

```bash
# Persistently drop setuid on chfn/chsh across package upgrades (Debian/Ubuntu)
for b in /usr/bin/chfn /usr/bin/chsh /usr/bin/newgrp /usr/bin/gpasswd; do
  dpkg-statoverride --update --add root root 0755 "$b"
done
dpkg-statoverride --list
```

On RHEL, the equivalent is to manage the mode in your configuration management run and have it enforced on every run. Where a binary needs one privilege and not full root, replace the setuid bit with a file capability. `ping` needing `cap_net_raw` is the classic case:

```bash
chmod u-s /usr/bin/ping
setcap cap_net_raw+ep /usr/bin/ping
getcap /usr/bin/ping
```

## Mount options do the rest

Data and scratch filesystems should never honour setuid at all. Mount `/tmp`, `/var/tmp`, `/home` and any application data volumes with `nosuid` (and `nodev`). Then a binary an attacker drops into a writable path is just a binary.

```text
tmpfs        /tmp      tmpfs  defaults,nosuid,nodev,noexec  0 0
/dev/vg0/data /srv/data ext4   defaults,nosuid,nodev         0 2
```

Test `noexec` on `/tmp` before you roll it out, because some installers and build tools break on it. `nosuid` almost never causes problems.

## Make it a drift check

A one-off cleanup decays. Commit the approved list and compare against it on a schedule. Anything new gets flagged:

```bash
#!/usr/bin/env bash
set -euo pipefail
baseline=/etc/security/suid-baseline.txt
current=$(mktemp)
/usr/local/sbin/suid-inventory.sh | cut -f1,2 > "$current"
if ! diff -u "$baseline" "$current"; then
  logger -p authpriv.warning -t suid-drift "SUID/SGID set changed on $(hostname)"
  exit 1
fi
```

Run it from a systemd timer or your existing compliance job. Ship the warning to wherever your other security events go. A nonzero exit after a package upgrade is usually harmless, but it should still be a decision someone reviews: either approve the new binary and update the baseline, or override it. If you already run auditd, also watch `chmod` and `fchmodat` calls that set mode bits 04000. That catches the change as it happens, while the timer catches it on the next run.

## Why this matters

Local privilege escalation bugs in setuid helpers keep turning up, and every one of them is only exploitable on hosts where the helper is installed and setuid. In incident reviews, the painful question is rarely "why did we have the bug?" It's "why was that binary setuid on a database server in the first place?" A short reviewed list, `nosuid` on writable mounts and a drift check that fires on change remove a whole class of escalation paths, and the work takes about an afternoon per image. It also turns the next "patch now" advisory for a setuid helper into a quick check: either the binary is on your list, or the advisory doesn't apply to you.
