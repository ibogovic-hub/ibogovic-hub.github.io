---
title: "Weekly recap: a remote root in the TCP stack, Tailworm, and an ASA VPN DoS"
tags: Security
---

This was another week where the patch queue set the agenda. Here are the four items I would put in front of an infrastructure team on Monday, and what I would do about each one.

## 1. CVE-2026-98432: Linux kernel IPv4 TCP use-after-free, and Ubuntu is still waiting

This is the big one. CVE-2026-98432 is a use-after-free in the code the kernel runs while setting up incoming IPv4 TCP connections. The kernel CVE team rates it 9.8. On October 27 Anthropic's Frontier Red Team described a working exploit: remote, zero-click root against servers with a Multipath TCP (MPTCP) listener. The full chain has not been published. A public proof of concept for the race and the kernel pointer leak has been out since October 29.

ThreatDefence keeps a [patch status page](https://threatdefence.com/article/linux-kernel-tcp-cve-2026-98432-mitigation-hunting) that is the most useful single reference I have found. As of November 6, RHEL, Alma, Rocky, Oracle, Debian, SUSE, Amazon Linux, Azure Linux, COS and Proxmox all have fixed kernels. [AlmaLinux](https://almalinux.org/blog/) has the fix in production repos for 8, 9 and 10. Ubuntu does not. The fixed kernels have been in `-proposed` since late October while Canonical runs certification testing, and there is no USN or Livepatch notice. That also leaves AKS and GKE Ubuntu node images, OpenShift and CentOS Stream 9 exposed. The same page cites Marcus Hutchins: internet-wide scanning for MPTCP listeners since November 2. It is not in CISA KEV yet, and no exploitation in the wild has been reported.

Why it matters operationally: most estates are mixed. The RHEL side is probably already patched through normal cycles, and the Ubuntu side will sit there for days unless someone owns it. Google's GKE bulletin adds that an unprivileged process inside a container can trigger the bug locally, so "nothing listens on MPTCP" is not a full answer on shared nodes.

First, find out what is actually exposed:

```bash
# Is MPTCP enabled, and is anything listening on it?
sysctl net.mptcp.enabled
ss -Mltn

# Running kernel vs. what the package manager has
uname -r
apt list --installed 2>/dev/null | grep -E '^linux-image-[0-9]'
```

Canonical and Red Hat both publish an interim nftables rule that drops IPv4 TCP packets carrying IP options. Use their exact rule and persistence steps, not a hand-rolled one. Canonical says the rule reduces the risk but does not fully prevent exploitation. Treat it as a stopgap. If you can accept the risk of a `-proposed` kernel, take only the kernel packages from that pocket, never the whole pocket.

## 2. Tailworm: Tailscale SSH port forwarding to root on other nodes

Erica Windisch of Cyberdione Labs disclosed a flaw in Tailscale SSH, nicknamed "Tailworm". An attacker who already controls one device on a tailnet can abuse a port-forwarding flaw to get root on other servers. It only works where Tailscale SSH allows port forwarding. Tailscale fixed it in [v1.104.4](https://github.com/tailscale/tailscale/releases/tag/v1.104.4). The [PacketWatch report for November 2](https://packetwatch.com/resources/threat-intel/cyber-threat-intelligence-report-11-02-2026) has the summary.

Why it matters: many of us use a tailnet as the management plane precisely because it removes exposure to the internet. That model assumes every node on the tailnet is trustworthy, and this bug turns one compromised laptop into lateral movement. Patch the clients, then review your ACLs and SSH policy. If nobody needs forwarding over Tailscale SSH, do not allow it. Check `tailscale version` across the fleet. Do not assume auto-update is on everywhere.

## 3. Cisco ASA/FTD remote access VPN DoS, plus a crowded KEV list

Cisco published an advisory ([cisco-sa-asaftd-tunnel-dos-s6mgkb75](https://sec.cloudapps.cisco.com/security/center/content/CiscoSecurityAdvisory/cisco-sa-asaftd-tunnel-dos-s6mgkb75)) for a denial of service in ASA and FTD. Three conditions all have to hold: the software version is vulnerable, the SSL remote access VPN login service is reachable, and secondary authentication is configured at tunnel-group scope. That narrows the exposure a lot, so check your tunnel-group config before you treat it as an emergency.

Separately, the same PacketWatch report lists this period's CISA KEV additions. They include an ASA/FTD NULL pointer dereference, two Ivanti Connect Secure flaws, the PHP pair behind October's "php2shell" incident, a GitLab integer overflow, four Plex Media Server bugs and an Arista VeloCloud Orchestrator SQL injection. [SecurityWeek](https://www.securityweek.com/) also reported a Cisco fix for an RCE in UCS Central Software, WatchGuard fixes for authentication and MitM flaws, and SonicWall declining to fix GMS issues.

Why it matters: VPN headends are still the edge device attackers prefer. A DoS on the remote access VPN is an outage for every remote worker, even without code execution. If you run ASA or FTD with secondary auth, schedule the upgrade. If you still run SonicWall GMS, "won't fix" is your cue to plan its retirement.

## 4. OpenSSH "SSHole" and a musl password quirk

[SecurityWeek](https://www.securityweek.com/openssh-rushes-patches-for-sshole-authentication-bypass/) reports that OpenSSH is rushing out patches for an authentication bypass nicknamed "SSHole". I have not seen enough detail yet to say which configurations are affected, so I will not guess. Watch your distribution's advisory and treat it as a priority when it lands. sshd is on every Linux box you own.

SecurityWeek also covered a quieter one. On Linux distributions that use musl libc without PAM, some accounts accept any password between 257 and 1024 characters. If you run Alpine-based appliances or containers with local password authentication, which you should not, check it.

## What I'm doing this week

- Inventory every Ubuntu host and node pool, apply the vendor nftables mitigation, and track Canonical's release daily instead of waiting for the next maintenance window.
- Push Tailscale 1.104.4 everywhere and audit the SSH section of the tailnet policy.
- Confirm whether any ASA/FTD tunnel group uses secondary auth.
- Keep an eye on the OpenSSH advisory.

Same lesson as the last few weeks: the gap between "fixed upstream" and "fixed on my box" is where the risk sits. Know which of your vendors close that gap quickly and which don't.
