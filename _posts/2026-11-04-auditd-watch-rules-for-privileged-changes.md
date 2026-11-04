---
title: "Auditd rules that answer who changed what on a server"
tags: Security
---

A service stops working on Tuesday morning. Someone edited a file under `/etc` overnight, and the shell history shows nothing useful because the change came through `sudo -i`, a config management run, or a script that never touched an interactive shell. You can tell that something changed. You can't tell who changed it, when, or which process did it.

The Linux audit subsystem answers that question, and most hosts already have `auditd` installed. The problem is usually configuration. Either there are no rules at all, or someone pasted a compliance ruleset that logs every syscall and fills the disk before anyone reads a line. A short ruleset aimed at the files and actions that actually cause incidents is more useful.

## Start from the questions you need answered

During an incident, the questions are usually these:

- Who changed sudoers, sshd config, PAM, or the user database?
- Who loaded a kernel module?
- Which process ran a command as root that a human didn't type?
- Did anyone change the audit configuration itself?

Each question maps to a small number of watch or syscall rules. Anything that doesn't answer one of those questions stays out until you have a reason to add it.

## A focused ruleset

Put this in `/etc/audit/rules.d/50-privileged.rules`. `augenrules` merges every file in that directory into `/etc/audit/audit.rules`, so you don't need to edit the generated file by hand.

```text
## Identity and authentication
-w /etc/passwd -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/sudoers -p wa -k privesc
-w /etc/sudoers.d/ -p wa -k privesc
-w /etc/pam.d/ -p wa -k pam

## Remote access
-w /etc/ssh/sshd_config -p wa -k sshd
-w /etc/ssh/sshd_config.d/ -p wa -k sshd
-w /root/.ssh/ -p wa -k rootkeys

## Scheduled execution
-w /etc/crontab -p wa -k cron
-w /etc/cron.d/ -p wa -k cron
-w /etc/systemd/system/ -p wa -k systemd

## Kernel modules
-a always,exit -F arch=b64 -S init_module,finit_module,delete_module -k modules

## Commands executed with root privileges by a real logged-in user
-a always,exit -F arch=b64 -S execve -F euid=0 -F auid>=1000 -F auid!=unset -k rootcmd

## Protect the audit configuration
-w /etc/audit/ -p wa -k auditconf

## Lock rules until reboot (keep last)
-e 2
```

Some details matter.

`-p wa` watches writes and attribute changes. Leaving out reads keeps the volume down. You usually don't care that something read `/etc/passwd` because half the system does that constantly.

The `execve` rule uses `auid`, the login UID. That value is set when a user logs in and survives `sudo` and `su`. When someone runs `sudo -i` and then edits a file, the event still carries their original UID. This rule is the one that answers "who". The `auid>=1000` filter keeps out system daemons, so you don't log every cron job that runs as root.

`-e 2` makes the rules immutable until the next reboot. An attacker who gets root can't quietly remove them with `auditctl -D`. The tradeoff is that you have to reboot to change the rules, so leave this line out until the ruleset has been stable on a few hosts for a while.

## Load and verify

```bash
sudo augenrules --check
sudo augenrules --load
sudo auditctl -l | head -30
sudo auditctl -s
```

`auditctl -s` shows `enabled 2` once the immutable flag is active. Check the `lost` counter as well. If it keeps rising, the kernel backlog is overflowing and you're dropping events. Raise `-b` (the backlog buffer) in a rules file instead of ignoring it.

## Querying during an incident

The keys are why the ruleset is useful during an incident. To see who touched sudoers in the last day:

```bash
sudo ausearch -k privesc -ts yesterday -i
```

`-i` translates numeric UIDs and syscall numbers into names. For a summary of root commands grouped by login user:

```bash
sudo aureport -x --summary -k rootcmd -ts today -i
```

The `auid` field in the output is the person, and `uid`/`euid` show the identity they were acting as. That difference is exactly what shell history loses.

## Getting the logs off the box

Local audit logs are only as trustworthy as the host. If a host is compromised, an attacker with root can edit or delete files in `/var/log/audit/`. Forward them off the host. Either use the `audisp-syslog` plugin into your existing syslog pipeline, or have your log shipper read `/var/log/audit/audit.log` directly. Then set disk handling in `/etc/audit/auditd.conf` so a full disk is visible:

```ini
max_log_file = 50
num_logs = 10
max_log_file_action = ROTATE
space_left_action = SYSLOG
admin_space_left_action = SUSPEND
```

`SUSPEND` stops audit logging rather than halting the machine. For most fleets that is the right call. Regulated environments sometimes require `HALT`, but you should know you made that choice before a disk fills on a production database.

## Rolling it out

Deploy the rules file with your config management, without `-e 2` at first. Run it for a week and look at volume per key with `aureport -k --summary`. If a key is noisy, look for a legitimate process that writes there constantly and exclude it with an `-F exe!=` filter. Once the volume is predictable, add the immutable flag.

## Why this matters

Most of the post-incident reviews I've sat through stalled on the same question: who made this change? There was nothing to show for it except a modified timestamp and some guesses. Twenty audit rules that track login identity through privilege escalation turn that argument into a single `ausearch` query. They cost almost nothing to run, they're already in the distribution, and they're useful on the bad days.
