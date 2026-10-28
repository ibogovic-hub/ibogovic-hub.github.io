---
title: "SSH hardening that survives package upgrades: using sshd_config.d drop-ins"
tags: Security
---

A few months after a careful SSH hardening pass, someone runs an audit and finds password authentication enabled again on a handful of hosts. Nobody turned it back on deliberately. On some hosts a package upgrade put a fresh `sshd_config` in place. On others a cloud-init image shipped its own drop-in file that loaded before ours. Whatever the cause, the hardening stopped working without any alert, and nobody noticed until the audit.

The fix is not to harden more aggressively. It is to put your settings in a place that upgrades leave alone and that the daemon reads in a predictable order.

## How sshd actually resolves settings

Modern OpenSSH builds on Debian, Ubuntu, RHEL 9 and Fedora ship a main `/etc/ssh/sshd_config` that begins with:

```
Include /etc/ssh/sshd_config.d/*.conf
```

Two things matter here. First, the include sits at the top, so anything in the drop-in directory is read before the rest of the main file. Second, for most keywords sshd uses the **first** value it finds, not the last. That is the opposite of how most people assume config files work.

So a vendor or cloud-init file named `50-cloud-init.conf` containing `PasswordAuthentication yes` beats your `PasswordAuthentication no` if your file sorts after it. Files load in lexical order, which means the name of the file decides which setting wins.

## A drop-in that wins

Name your file so it sorts first and keep it to policy only:

```bash
# /etc/ssh/sshd_config.d/00-hardening.conf
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
AuthenticationMethods publickey
PermitEmptyPasswords no
X11Forwarding no
AllowAgentForwarding no
AllowTcpForwarding no
MaxAuthTries 3
LoginGraceTime 20
ClientAliveInterval 300
ClientAliveCountMax 2
AllowGroups ssh-users

# Restrict algorithms to modern choices
KexAlgorithms sntrup761x25519-sha512@openssh.com,curve25519-sha256,curve25519-sha256@libssh.org
HostKeyAlgorithms ssh-ed25519,rsa-sha2-512,rsa-sha2-256
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
```

Before you deploy this, check the algorithm names against `ssh -Q kex`, `ssh -Q cipher` and `ssh -Q mac` on your oldest supported distro. An algorithm name sshd does not recognise is a fatal config error. `AllowTcpForwarding no` will also break jump hosts and anyone using port forwarding, so turn it back on where those are actually needed.

## Verify the effective config, not the file

Never trust what is in the file. `sshd -T` prints the configuration the daemon will really use after it has processed every include:

```bash
#!/usr/bin/env bash
# check-sshd.sh - exit non-zero if effective config drifts from policy
set -euo pipefail

sudo sshd -t   # syntax check first; fails loudly on bad keywords

declare -A want=(
  [passwordauthentication]=no
  [kbdinteractiveauthentication]=no
  [permitrootlogin]=no
  [x11forwarding]=no
  [maxauthtries]=3
)

effective=$(sudo sshd -T)
rc=0
for k in "${!want[@]}"; do
  got=$(awk -v k="$k" '$1==k {print $2; exit}' <<<"$effective")
  if [[ "$got" != "${want[$k]}" ]]; then
    echo "DRIFT: $k=$got (want ${want[$k]})"
    rc=1
  fi
done
exit $rc
```

If you use `Match` blocks, pass the connection context, for example `sshd -T -C user=deploy,host=jump01,addr=10.0.0.5`. That shows the settings for that specific user and source address, which is where exceptions tend to hide.

## Safe rollout

The usual way to lock yourself out is to restart sshd after a bad change. To avoid that:

1. Push the drop-in file.
2. Run `sshd -t`. If it fails, stop and do not reload.
3. Reload, not restart: `systemctl reload ssh` (or `sshd` on RHEL). A reload keeps existing sessions alive.
4. From a **second** terminal, open a new connection before closing the one you used to make the change.
5. Run the drift check.

In Ansible, the `validate: /usr/sbin/sshd -t -f %s` option on the template task is not enough by itself, because it checks the drop-in on its own and not together with the main config. Run `sshd -t` as a separate step after the file is in place, and only trigger the reload handler if that step passes.

## Watch the other drop-ins

Add a check that lists every file in `sshd_config.d/` and flags any you did not put there. Cloud images, configuration-management leftovers and vendor agents all drop files into that directory. A file you did not write is not necessarily a problem, but you should know it is there.

```bash
ls -1 /etc/ssh/sshd_config.d/ | grep -v '^00-hardening.conf$' && echo "review the files above"
```

## Why this matters

In my experience, hardening is rarely defeated by an attacker. It decays: an upgrade replaces a file, a new image adds an exception, an engineer makes a temporary change and never reverts it. Each of these is harmless when it happens, and together they leave password logins open on hosts you believe are locked down. Keeping policy in a drop-in that loads first, checking the effective config with `sshd -T` instead of reading files, and running that check on a schedule turns a one-off hardening project into a control you can actually show an auditor still works. The checks cost a few lines of shell, while a missed regression can mean months of exposure before someone finds it.
