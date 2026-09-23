---
title: The sudoers rules that quietly hand out root
tags: Security
---

A rule like this lives in almost every infrastructure estate I have audited:

```
%deploy ALL=(ALL) NOPASSWD: /bin/systemctl restart app-*
```

It reads as "the deploy group may restart application units, nothing else." It is
actually a root shell, and the reason is that sudo matches the command line as a
glob pattern, not as an intent. `app-*` will happily match an argument the author
never imagined, and systemctl is not the only binary with a side door.

## Why the wildcard leaks

sudo's command matching uses `fnmatch(3)` with `FNM_PATHNAME`. The pattern is
compared against the fully qualified command plus the arguments the user typed.
Two consequences bite:

1. A trailing `*` in the argument position matches *multiple* arguments, including
   ones that change the meaning of the command.
2. sudo does not know which arguments a program treats as dangerous. That knowledge
   has to be encoded by you, and a glob cannot encode it.

So the rule above permits, among other things:

```bash
sudo systemctl restart app-x --root=/ -p ExecStart=/bin/sh
```

and more generally anything whose first argument starts with `app-`. The same class
of problem shows up with `find`, `tar`, `rsync`, `awk`, `git`, `zip`, `less` — any
tool that can execute a helper or write an arbitrary file. GTFOBins exists precisely
because this pattern is endemic.

Even without a wildcard, a bare `sudo tar` or `sudo find` in a rule is game over:
`find . -exec /bin/sh \;` runs the shell as root by design, not as a bug.

## Finding the bad rules you already have

You do not need a scanner. Two passes over the estate cover most of it. First, list
every rule that contains a wildcard in an argument position or grants a known
shell-escape binary:

```bash
#!/usr/bin/env bash
# audit-sudoers.sh - flag risky rules on the local host
set -euo pipefail

FILES=(/etc/sudoers)
[[ -d /etc/sudoers.d ]] && while IFS= read -r f; do FILES+=("$f"); done \
  < <(find /etc/sudoers.d -type f ! -name '*~' ! -name '*.bak')

ESCAPES='(^|/)(find|tar|rsync|awk|gawk|perl|python[0-9.]*|vi|vim|less|more|man|git|zip|nmap|env|nsenter|systemctl|journalctl|apt|dnf|yum)([[:space:]]|$)'

for f in "${FILES[@]}"; do
  grep -nE '^[^#]*ALL[[:space:]]*=' "$f" | while IFS=: read -r ln rule; do
    case "$rule" in
      *"(ALL) ALL"*|*"(ALL:ALL) ALL"*) echo "FULL-ROOT  $f:$ln  $rule" ;;
    esac
    [[ "$rule" == *'*'* ]] && echo "WILDCARD   $f:$ln  $rule"
    grep -qE "$ESCAPES" <<<"$rule" && echo "ESCAPABLE  $f:$ln  $rule"
  done
done

echo "--- effective rules per human user ---"
getent passwd | awk -F: '$3>=1000 && $3<65534 {print $1}' | while read -r u; do
  sudo -l -U "$u" 2>/dev/null | sed -n '/may run/,$p' | sed "s/^/[$u] /"
done
```

The second half matters more than the first. `sudo -l -U <user>` resolves group
membership, aliases, includes and Defaults, so it shows what the host will actually
permit — which is frequently wider than what any single file suggests.

## Writing rules that hold

Replace globs with exact, fully specified command lines. sudo matches these
literally and refuses anything else:

```
Cmnd_Alias APP_SVC = /usr/bin/systemctl restart app-api.service, \
                     /usr/bin/systemctl restart app-worker.service, \
                     /usr/bin/systemctl status app-api.service

%deploy ALL=(root) NOPASSWD: APP_SVC
```

Where a variable argument is genuinely required, put the validation in a wrapper you
own and grant sudo only on the wrapper — a script that whitelists unit names and
execs systemctl, owned by root, mode 0755, in a root-owned directory. That moves the
decision from a glob into code you can test.

Then tighten the environment:

```
Defaults!APP_SVC  env_reset, secure_path="/usr/sbin:/usr/bin:/sbin:/bin"
Defaults          use_pty, logfile="/var/log/sudo.log"
```

`use_pty` prevents a backgrounded process from surviving with the elevated pty, and
`env_reset` with an explicit `secure_path` closes the PATH-hijack route into any
script the permitted command calls.

Finally, validate before you ship. `visudo -c -f` parses without installing, which
makes it safe to run in CI on the file your Ansible role is about to push:

```bash
visudo -c -f roles/sudo/files/10-deploy || exit 1
```

## Why this matters

Privilege escalation findings in internal reviews rarely come from an unpatched
kernel. They come from a rule someone wrote during an incident three years ago to
unblock a deploy, which was never narrowed afterwards. The rule looks scoped, passes
casual review, and survives every audit that only checks "is anyone in the wheel
group who should not be."

The audit is cheap — one script, one run, a few hours of narrowing. The alternative
is discovering during an incident that your least-privileged service account was
never least-privileged at all, and that every host in the fleet inherited the same
line from the same role.
