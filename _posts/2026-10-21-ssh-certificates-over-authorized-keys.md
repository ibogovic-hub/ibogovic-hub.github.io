---
title: "Replacing authorized_keys sprawl with SSH certificates"
tags: Security
---

Somebody leaves the team. You revoke their VPN access, disable their directory account, and close the ticket. Six months later an audit finds their public key still sitting in `~/.ssh/authorized_keys` on forty Linux hosts, two jump boxes, and a network automation server. Nobody intended this. The key went in through a quick `ssh-copy-id` years ago, and no inventory tracked it.

This is the normal state of most fleets that rely on plain public key authentication. Keys don't expire, they aren't tied to an identity system, and they spread every time someone takes a shortcut. OpenSSH has had a built-in fix since version 5.4: certificates signed by a certificate authority you control. No extra daemon, no vendor product. Just `ssh-keygen` and a few lines of `sshd_config`.

## How it works

You create a CA key pair. Hosts are configured to trust any user key signed by that CA, as long as the certificate is valid for that principal (a username or role) and hasn't expired. Users still hold their own private keys. What changes is that access comes from a short-lived signature, not from the key being copied to each server.

The same mechanism works the other way round. Host certificates let clients verify servers without the "trust on first use" prompt that everyone clicks through.

## Setting up the user CA

Generate the CA key on a machine you treat like a root CA: offline, or at minimum locked down with restricted access and logging.

```bash
# On the CA host
ssh-keygen -t ed25519 -f /etc/ssh-ca/user_ca -C "user-ca-2026"

# Sign a user's public key: valid 8 hours, principal "ops"
ssh-keygen -s /etc/ssh-ca/user_ca \
  -I "ivan.bogovic@2026-10-21" \
  -n ops \
  -V +8h \
  -O no-port-forwarding \
  ~/incoming/id_ed25519.pub

# Inspect the result
ssh-keygen -L -f ~/incoming/id_ed25519-cert.pub
```

The `-I` identity string appears in the server's auth log on every login. Put something that maps back to a person and a request in it. When you investigate an incident later, you'll be glad you did.

## Configuring the servers

Copy only the CA's public key to each host, then tell sshd to trust it and map principals to local accounts:

```text
# /etc/ssh/sshd_config.d/10-ca.conf
TrustedUserCAKeys /etc/ssh/user_ca.pub
AuthorizedPrincipalsFile /etc/ssh/auth_principals/%u
AuthorizedKeysFile none
RevokedKeys /etc/ssh/revoked_keys
```

```bash
# Local account "admin" accepts certificates carrying principal "ops"
echo "ops" | sudo tee /etc/ssh/auth_principals/admin
sudo touch /etc/ssh/revoked_keys
sudo sshd -t && sudo systemctl reload ssh
```

`AuthorizedKeysFile none` is the important line. It turns off the old mechanism completely, so a stray key dropped into a home directory does nothing. Keep a break-glass path, such as console access or a single tightly controlled certificate with a longer lifetime, before you roll this out widely. Locking yourself out of a fleet with a config push is a mistake you only need to make once.

Push these files with whatever configuration management you already run. These are a handful of static files, which is about the easiest thing an Ansible role can manage.

## Host certificates

Sign each host's key with a separate host CA:

```bash
ssh-keygen -s /etc/ssh-ca/host_ca -I web01 -h \
  -n web01.example.internal,web01 -V +52w \
  /etc/ssh/ssh_host_ed25519_key.pub
```

Add `HostCertificate /etc/ssh/ssh_host_ed25519_key-cert.pub` on the server. On the client, add a single line to `known_hosts`:

```text
@cert-authority *.example.internal ssh-ed25519 AAAA...hostcakey
```

Now rebuilding a VM no longer triggers the "REMOTE HOST IDENTIFICATION HAS CHANGED" warning, which people have learned to override by habit. A real mismatch becomes a real alarm again.

## Operational details that matter

**Lifetimes.** Short user certificates (hours, not months) make revocation mostly unnecessary, because access lapses on its own. Use the `RevokedKeys` list for the rare case where you must cut access before a certificate expires, and remember it only works if it's distributed promptly.

**Issuance.** Running `ssh-keygen -s` by hand doesn't scale beyond a small team. Teams usually wrap signing in a small service that checks the user's SSO session and group membership before signing. HashiCorp Vault's SSH secrets engine and Smallstep are common choices. The key design point is that group membership in your identity provider decides the principal, not a person with shell access to the CA.

**Clock skew.** Certificate validity depends on time. A host with a broken NTP setup will reject valid certificates or accept expired ones. Monitor time sync if you aren't already.

**Network gear.** Support on routers and switches varies by platform and software version. Expect to keep separate handling for network devices, typically AAA via TACACS+ or RADIUS, and don't assume a Linux rollout plan carries over.

**CA rotation.** Name CA keys by year. `TrustedUserCAKeys` accepts multiple keys in one file, so you can run old and new CAs side by side during a rotation instead of switching everything at once.

## Why this matters

Every offboarding I've seen go wrong had the same root cause: access granted in many places and revoked in one. Static SSH keys are the clearest example. They're invisible to the identity system, they never expire, and they're found by auditors instead of by whoever owns the systems. Moving to certificates doesn't make anyone more careful. It removes the need for care. Access expires by default, every login names a person, and the only file worth auditing on a server is the one containing your CA's public key. For a change that uses tools already installed on every host, that's a large reduction in risk.
