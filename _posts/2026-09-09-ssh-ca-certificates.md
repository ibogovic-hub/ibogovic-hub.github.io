---
title: Replacing authorized_keys with an SSH certificate authority
tags: Security
---

The failure mode is familiar. An engineer leaves, and someone opens a ticket to remove their public key from every host. The Ansible role that manages `authorized_keys` covers 90% of the fleet. The other 10% are the boxes that were built before the role existed, the appliance with a read-only rootfs, the jump host someone hand-configured during an incident at 03:00. Nobody can state with confidence that the key is gone, because the source of truth is a file scattered across hundreds of machines rather than a single authority.

SSH certificates fix this by inverting the trust direction. Instead of every host holding a list of keys it accepts, every host holds one CA public key and accepts any user certificate signed by it. Revocation stops being a fleet-wide config push and becomes an expiry window.

## Setting up the CA

Generate a CA keypair on something isolated — ideally an offline host or an HSM-backed signer, not the bastion itself.

```bash
ssh-keygen -t ed25519 -f /etc/ssh/ca/user_ca -C "user-ca-2026" -N ""
chmod 600 /etc/ssh/ca/user_ca
```

Sign a user key with a short validity and explicit principals. Principals are the important part: they decouple the certificate identity from the Unix username.

```bash
ssh-keygen -s /etc/ssh/ca/user_ca \
  -I "ivan@corp" \
  -n "ops,ivan" \
  -V +8h \
  -z 1042 \
  /home/ivan/.ssh/id_ed25519.pub
```

That produces `id_ed25519-cert.pub`. `-I` is the key ID that lands in the server's auth log, `-n` is the list of principals the cert is valid for, `-V` sets the validity window, `-z` is a serial you will want later for revocation lists.

On every server, trust the CA and map principals to accounts:

```
# /etc/ssh/sshd_config
TrustedUserCAKeys /etc/ssh/ca/user_ca.pub
AuthorizedPrincipalsFile /etc/ssh/auth_principals/%u
RevokedKeys /etc/ssh/ca/revoked_keys
PubkeyAuthentication yes
PasswordAuthentication no
```

```bash
mkdir -p /etc/ssh/auth_principals
echo "ops" > /etc/ssh/auth_principals/root
printf "ops\nivan\n" > /etc/ssh/auth_principals/deploy
sshd -t && systemctl reload sshd
```

Now `root` accepts any certificate carrying the `ops` principal, and `deploy` accepts `ops` or `ivan`. No usernames baked into certs, no per-host key lists.

## Host certificates too

The half that most people skip. Sign each host key with a separate host CA and clients stop being asked to blindly accept fingerprints:

```bash
ssh-keygen -s /etc/ssh/ca/host_ca -I "web01" -h \
  -n "web01.corp,10.20.3.11" -V +52w /etc/ssh/ssh_host_ed25519_key.pub
```

```
# /etc/ssh/sshd_config
HostCertificate /etc/ssh/ssh_host_ed25519_key-cert.pub
```

Client side, one line in `known_hosts` replaces thousands:

```
@cert-authority *.corp ssh-ed25519 AAAAC3Nza... host-ca-2026
```

This kills the "yes/no fingerprint" prompt as a security theatre step and makes MITM on a rebuilt host actually detectable, because the rebuilt host's new key will not be signed until someone runs the signing step.

## Verify before you trust it

Always inspect what you actually issued:

```bash
ssh-keygen -L -f ~/.ssh/id_ed25519-cert.pub
```

Check `Valid:` and `Principals:`. A cert with no principals listed is valid for *all* principals — an easy and dangerous mistake when scripting the signer.

Revocation, when you need it before expiry:

```bash
ssh-keygen -k -f /etc/ssh/ca/revoked_keys -u -s /etc/ssh/ca/user_ca.pub -z 1042 /dev/null
```

The KRL is small and pushes fast, but treat it as the emergency lever. The primary control is the validity window.

## Operational caveats

Short-lived certificates only work if issuing them is frictionless. If getting an 8-hour cert requires a ticket, engineers will ask for 90-day certs and you are back where you started with extra steps. Wire the signer to your IdP so the cert falls out of a normal login.

Clock skew matters. A host drifting a few minutes will reject valid certs or accept expired ones. NTP is now a security dependency, not just a logging nicety.

Keep a break-glass path. One `authorized_keys` entry for a key in a sealed envelope, or console access via IPMI/iDRAC. A misconfigured `AuthorizedPrincipalsFile` will lock you out of the entire fleet at once — the same centralisation that makes revocation instant makes mistakes instant.

## Why this matters

The offboarding ticket that nobody can close is the visible symptom. The real cost is that key sprawl makes access an unanswerable question: at any moment you cannot say who can reach which host. With a CA, the answer is derivable from the signing log, and stale access dies on its own within hours instead of surviving in a forgotten file. Every fleet I have worked on that migrated found orphaned keys on hosts everyone believed were already covered by config management. Assume yours has them too.
