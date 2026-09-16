---
title: Retiring authorized_keys with an SSH certificate authority
tags: Security
---

The offboarding ticket says "remove Ivan's key from all hosts." You grep your Ansible repo, find the key in three group_vars files, one legacy `authorized_keys` template, and a snowflake jump host nobody has touched since a migration. You push the change, and two weeks later someone restores a VM from a backup image that still carries the key. That is the real failure mode of public-key SSH at scale: revocation is a distributed search problem, and you only find out you lost when you lose.

SSH certificates fix this by inverting the trust direction. Instead of every server holding a list of every key, every server holds one CA public key, and every user holds a short-lived certificate signed by that CA. Nothing to remove at offboarding — you simply stop signing. OpenSSH has supported this since 5.4; it is not new, it is just under-deployed because the tooling story was bad until people started wrapping it.

## Building the CA

Keep the CA key offline or in an HSM. For a lab or small estate, an ed25519 key on a hardened, non-routable host is a reasonable start.

```bash
# On the CA host, once
ssh-keygen -t ed25519 -f /etc/ssh/ca/user_ca -C "user CA $(hostname)"
chmod 600 /etc/ssh/ca/user_ca

# Sign a user key: 8 hour validity, principal = role, not username
ssh-keygen -s /etc/ssh/ca/user_ca \
  -I "ivan@2026-09-16" \
  -n netops,readonly \
  -V +8h \
  -z 1042 \
  /home/ivan/.ssh/id_ed25519.pub

# Inspect what you just issued
ssh-keygen -L -f /home/ivan/.ssh/id_ed25519-cert.pub
```

`-I` is the key ID, which is what lands in the server's auth log — make it identify a human and an issuance event, because that is your audit trail. `-n` sets principals. Do not put usernames there. Put roles. The mapping from role to local account is the server's job.

## Server side

Distribute only the CA public key. This is the entire server-side configuration:

```
# /etc/ssh/sshd_config.d/60-ca.conf
TrustedUserCAKeys /etc/ssh/ca/user_ca.pub
AuthorizedPrincipalsFile /etc/ssh/auth_principals/%u
RevokedKeys /etc/ssh/ca/revoked_keys

PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin prohibit-password
```

And the principal map, which is where role-to-account translation happens:

```bash
install -d -m 0755 /etc/ssh/auth_principals
printf 'netops\nsre\n' > /etc/ssh/auth_principals/admin
printf 'readonly\n'     > /etc/ssh/auth_principals/monitor
sshd -t && systemctl reload ssh
```

Now a certificate carrying `netops` can log in as `admin` on every host with that file, and as nothing at all on hosts where `admin` does not list `netops`. You get coarse RBAC without LDAP, without a directory dependency in the login path, and without a network call at authentication time — which matters at 03:00 when the thing you are trying to fix is the directory.

## Constraining what the certificate can do

Certificates carry extensions. The defaults are permissive; tighten them explicitly at signing time:

```bash
ssh-keygen -s /etc/ssh/ca/user_ca -I "monitor-job@2026-09-16" \
  -n readonly -V +1h \
  -O clear \
  -O permit-pty \
  -O source-address=10.20.0.0/24 \
  -O force-command="/usr/local/bin/ro-shell" \
  ci_key.pub
```

`-O clear` drops all default extensions, then you add back only what is needed. `source-address` is enforced by sshd, not by a firewall you might forget to reload. `force-command` is how you give a CI runner or a monitoring agent exactly one verb.

## Revocation, for the cases you still need it

Short lifetimes are the primary control — an 8-hour cert means a stolen laptop is a stolen 8-hour window, not a permanent foothold. But you still want a break-glass path. That is what the `-z` serial number is for:

```bash
# On the CA, maintain a KRL keyed by serial
ssh-keygen -k -f revoked_keys -u -s /etc/ssh/ca/user_ca.pub \
  -z 1042 /dev/null
```

Ship `revoked_keys` with the same config-management run that ships the CA public key. One file, one push, effective everywhere.

## Why this matters

The operational win is not cryptographic elegance, it is that access becomes a property of time rather than a property of filesystem state scattered across your estate. In an environment with restored snapshots, golden images built months ago, appliances with their own SSH stacks, and the inevitable host that fell out of config management, `authorized_keys` audits are never truly complete — you are proving a negative across machines you may not have an inventory of. With a CA, an unmanaged host is still a risk, but a departed engineer's expired certificate is worthless on it anyway.

The migration is also low-drama: `TrustedUserCAKeys` coexists with existing `authorized_keys` files, so you can roll the CA out everywhere first, verify certificate logins in the auth log for a couple of weeks, and only then start deleting static keys. Do it in that order. The reverse order is how you lock yourself out of the jump host on a Friday.
