---
title: "Replacing authorized_keys sprawl with short-lived SSH certificates"
tags: Security
---

Every infrastructure team eventually runs the same audit and finds the same thing: an engineer who left eighteen months ago still has a public key in `authorized_keys` on a handful of jump hosts, a backup server, and one forgotten monitoring box. Nobody removed it because nobody knew it was there. Key-based SSH solved the password problem but replaced it with an inventory problem, and most teams never actually solve the inventory problem. They just run scripts that try to keep up with it.

OpenSSH has shipped a better model since version 5.4: certificate authentication. Instead of distributing every user's public key to every server, you distribute one CA public key. Users get their keys signed with a validity window, a list of allowed principals, and optional restrictions. When the certificate expires, access ends. You don't have to clean anything up.

## The moving parts

There are three pieces:

1. A **user CA** key pair. Keep the private half offline, on an HSM, or behind a signing service. Servers only need the public half.
2. Each server trusts the CA through `TrustedUserCAKeys` and maps principals to local accounts with `AuthorizedPrincipalsFile`.
3. Users present a certificate (`id_ed25519-cert.pub`) next to their normal key. The client sends it automatically.

The same mechanism works the other way round too. A **host CA** signs server host keys, so clients stop getting trust-on-first-use prompts and stop training people to type `yes` without reading.

## Minimal working setup

Create the CA. Do this on a machine that is not one of your regular servers:

```bash
ssh-keygen -t ed25519 -f user_ca -C "user-ca-2026"
```

On each server, install the CA public key and set up principal mapping:

```bash
sudo install -m 0644 user_ca.pub /etc/ssh/user_ca.pub
sudo mkdir -p /etc/ssh/auth_principals
echo "ops-admins" | sudo tee /etc/ssh/auth_principals/root
echo -e "ops-admins\nops-readonly" | sudo tee /etc/ssh/auth_principals/deploy
```

Then add this to `/etc/ssh/sshd_config.d/10-ca.conf`:

```
TrustedUserCAKeys /etc/ssh/user_ca.pub
AuthorizedPrincipalsFile /etc/ssh/auth_principals/%u
AuthorizedKeysFile none
PasswordAuthentication no
KbdInteractiveAuthentication no
```

Run `sshd -t` to validate it, then reload. Setting `AuthorizedKeysFile none` is the important line. It turns off the old path completely, so a stray key dropped into a home directory does nothing. Don't set it until you've confirmed that certificate login works from a second session. Locking yourself out of a fleet is a bad afternoon.

Now sign a user key for eight hours, valid only for the `ops-admins` principal, with port and agent forwarding disabled:

```bash
ssh-keygen -s user_ca \
  -I "ivan@laptop-$(date +%F)" \
  -n ops-admins \
  -V +8h \
  -O no-port-forwarding \
  -O no-agent-forwarding \
  ~/.ssh/id_ed25519.pub
```

Check what you issued:

```bash
ssh-keygen -L -f ~/.ssh/id_ed25519-cert.pub
```

The key ID set with `-I` shows up in sshd's auth log on every login. With plain keys you see a fingerprint and have to work backwards to a person. Here the log tells you who it was and which issuance they used.

## Operational details that matter

**Validity windows are your revocation strategy.** OpenSSH supports a `RevokedKeys` file (a KRL), and you should deploy one for emergencies, but distributing revocation lists is the same inventory problem in a different form. If certificates live for a working day, the normal answer to "revoke Bob" becomes "don't issue Bob another one."

**Principals are roles, not people.** Map principals to functions such as `ops-admins`, `db-oncall`, and `ci-deploy`. Changing someone's access then happens at the signing step, usually driven by IdP group membership. You don't touch any server files.

**Automate the signing, not the CA key.** Signing by hand doesn't scale past a few people. Common options are a small internal service behind SSO, HashiCorp Vault's SSH secrets engine, or step-ca. Whichever you choose, the CA private key should never sit on a laptop, and every issuance should be logged.

**Machine identities need different rules.** CI runners and automation accounts can use longer-lived certificates restricted with `-O source-address=` and `-O force-command=`. That way a leaked credential only works from the expected subnet and can only run the intended command.

**Keep a break-glass path.** A console account or out-of-band access that doesn't depend on the signing service is mandatory. If the CA service is down during an incident, you still need a way in.

## Rolling it out without drama

Run both models in parallel first. Deploy `TrustedUserCAKeys` and keep `AuthorizedKeysFile` active. Issue certificates to the team and watch the logs until every login shows a certificate key ID instead of a bare fingerprint. Then switch hosts to `AuthorizedKeysFile none` in waves, starting with the least critical. Use configuration management for all of it: one template, one CA public key, one principals directory.

## Why this matters

The access reviews I've seen fail rarely failed on policy. They failed on state that nobody could enumerate: keys copied by hand during an outage, keys baked into golden images, keys left on boxes that outlived their owners' employment. Short-lived certificates make access a property of issuance rather than of server state. That matches how auditors, incident responders, and offboarding checklists actually reason about access. Engineers on the team see almost no change in daily use, and the reviewer finally gets an answer they can trust.
