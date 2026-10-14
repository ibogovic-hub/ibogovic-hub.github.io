---
title: "Replacing authorized_keys sprawl with short-lived SSH certificates"
tags: Security
---

Every infrastructure team eventually runs the same audit: someone leaves, and you need to prove their access is gone. You grep `authorized_keys` across a few hundred hosts and find their key in places nobody remembers granting. Some keys have no comment, some belong to laptops decommissioned years ago, and a few were copied into service accounts "temporarily". The root problem is that a raw public key in `authorized_keys` is a permanent grant with no expiry, no identity binding beyond a free-text comment, and no central revocation.

OpenSSH has shipped a fix for this since version 5.4: certificate authorities. Instead of distributing user public keys to every host, you distribute one CA public key, and users present a certificate signed by that CA. The certificate carries a validity window, a list of allowed principals, and optional restrictions. If certificates live for hours instead of forever, offboarding mostly stops being a problem.

## The moving parts

There are three pieces:

1. A user CA key pair, kept offline or in an HSM/vault. Its public half goes to every server.
2. Servers that trust the CA via `TrustedUserCAKeys` and map certificate principals to local accounts.
3. A signing step, run on demand after the user authenticates against something you already trust (SSO, MFA, a bastion).

Optionally, a host CA does the reverse: it signs host keys so clients stop blindly accepting TOFU fingerprints. That is worth doing too, but user certificates give the faster security return.

## Setting up the user CA

Generate the CA key somewhere that is not a general-purpose server:

```bash
ssh-keygen -t ed25519 -f user_ca -C "user-ca-2026"
```

On every server, install `user_ca.pub` and configure sshd:

```
# /etc/ssh/sshd_config.d/10-user-ca.conf
TrustedUserCAKeys /etc/ssh/user_ca.pub
AuthorizedPrincipalsFile /etc/ssh/auth_principals/%u
AuthorizedKeysFile none
PasswordAuthentication no
KbdInteractiveAuthentication no
```

`AuthorizedKeysFile none` is the important line. It disables the legacy path entirely, so a stray key dropped into a home directory no longer grants access. Only roll this out after certificate login is confirmed working, and keep console access to the host during the change.

`AuthorizedPrincipalsFile` decouples certificate identity from the Unix account. For the `deploy` account:

```
# /etc/ssh/auth_principals/deploy
netops
sre-oncall
```

Anyone holding a valid certificate with principal `netops` or `sre-oncall` can log in as `deploy`. Group membership now lives in your signing logic, not scattered across hosts.

## Signing a short-lived certificate

```bash
ssh-keygen -s user_ca \
  -I "ivan.bogovic@example.ch" \
  -n netops \
  -V +8h \
  -O no-agent-forwarding \
  -O no-port-forwarding \
  id_ed25519.pub
```

This produces `id_ed25519-cert.pub` next to the user's key. The `-I` identity is written to the sshd log on every login, giving you an attributable audit trail even when people share an account like `deploy`. `-V +8h` sets a working-day lifetime. The `-O` flags strip capabilities most sessions never need; add them back per role when someone actually does.

Inspect what was issued:

```bash
ssh-keygen -L -f id_ed25519-cert.pub
```

The client picks up the certificate automatically when it sits next to the private key, so users notice no difference beyond a daily re-sign.

## Automating the signing step

Signing by hand does not scale, and putting the CA private key on a laptop defeats the purpose. Practical options:

- HashiCorp Vault's SSH secrets engine, which signs against roles with allowed principals and TTLs, authenticated through your existing OIDC provider.
- Smallstep's `step-ca`, which does the same with an OIDC-driven `step ssh login` flow.
- A small internal service on a hardened bastion that checks MFA and calls `ssh-keygen -s` with a key it cannot export.

Whichever you pick, the rule is the same: the CA key never leaves the signing service, and the service decides principals from directory group membership, not from what the user asks for.

## Revocation and rollout notes

Short lifetimes are the main revocation mechanism, but for emergencies sshd supports a key revocation list via `RevokedKeys /etc/ssh/revoked_keys`, built with `ssh-keygen -k`. Push it with the same configuration management that pushes the CA key. Note that sshd refuses all keys if the configured `RevokedKeys` file is missing or unreadable, so deploy an empty KRL first.

Plan CA rotation from day one: `TrustedUserCAKeys` accepts multiple keys, so you can trust old and new CAs in parallel while you switch the signer.

Keep a break-glass path. A single local account with a key stored in a sealed vault, or out-of-band console access, saves you when the signing service is down at 3 a.m.

## Why this matters

In practice, SSH access reviews fail not because teams are careless but because static keys accumulate faster than anyone audits them. Every migration, incident and "just for tonight" fix leaves another line in another `authorized_keys`. Moving to an 8-hour certificate tied to an SSO identity turns access from something you have to clean up into something that expires by default. The audit question changes from "where might this person still have a key?" to "who was issued a certificate, and when?", and the signing service log already answers that.
