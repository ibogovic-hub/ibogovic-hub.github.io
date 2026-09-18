---
title: Edge Devices And Build Pipelines Took The Week's Damage
tags: Security
---

This was not a quiet week. The pattern across the notable items is consistent and unflattering: the things that break are the things nobody owns end to end — internet-facing network appliances, policy servers, and CI plugins. None of them are the systems a platform team reviews in a sprint. All of them sit at the top of a blast radius.

## MikroTik RouterOS: authentication bypass chained to full admin

CERT Polska disclosed a chained exploitation path in RouterOS, nicknamed MikroTrick, combining an SSH public-key validation flaw with an argument-handling flaw in the login path. The first issue means RouterOS compares only part of an authorised public key, so an attacker who knows a valid username and the public modulus of its key can construct a different key pair the device will accept. The second lets an unauthenticated session alter the trusted policy mask. Chained, an attacker who can reach the SSH port from the internet gets full administrative control with no credentials and no user interaction. A scan on 5 September found roughly 122,500 RouterOS devices with SSH exposed directly to the internet, and CERT Polska reports evidence of exploitation predating the patched builds.

Operationally, the interesting part is not the bug class — it is the exposure count. A compromised edge router is not an end target; it is a pivot with the ability to rewrite forwarding rules, firewall policy, VPN credentials and persistent accounts that survive a reboot. The documented indicator of compromise is an SSH user account named `-2`, an artefact of the username parsing flaw. If you run RouterOS anywhere — including in a lab, including on a site you inherited — audit accounts and configuration changes back to early September, not just from the disclosure date.

Details and detection guidance: [CERT Polska](https://cert.pl/en/posts/2026/09/mikrotik-routeros-cve/), [MikroTik advisory](https://mikrotik.com/supportsec/september-2026-vulnerability), [Help Net Security](https://www.helpnetsecurity.com/2026/09/07/mikrotik-routeros-ssh-vulnerabilities-exploited/).

The first move is not patching, it is finding out what you actually expose. This is boring and should be a scheduled job rather than an incident response task:

```bash
# Enumerate reachable SSH on management ranges and flag banner strings.
# Run from a host that sits where an attacker would, not from inside the mgmt VLAN.
nmap -Pn -p 22 --open -sV --version-light \
     -oG - 203.0.113.0/24 \
  | awk '/22\/open/ {print $2, $0}' \
  | grep -i -E 'routeros|mikrotik|dropbear' || echo "no RouterOS SSH found in range"
```

Then remove the exposure rather than relying on the patch alone: SSH on network devices belongs behind a management VLAN or a VPN-gated management plane, and it belongs on key auth with an explicit allow-list of source prefixes.

## Cisco: ISE under active exploitation, FMC bypass with no workaround

Two separate Cisco stories landed. A critical Identity Services Engine vulnerability is reported exploited in the wild, alongside a broader set of ISE patches. Separately, a maximum-severity bypass in on-premises Secure Firewall Management Center affects multiple release trains, with Cisco stating there is no workaround — the fix is the upgrade. The cloud-delivered management service was remediated automatically; on-premises appliances were not.

The ISE case deserves more attention than it will get. ISE is not a perimeter box, it is the thing that decides who gets onto the network and with what authorisation profile. Compromise there is not lateral movement, it is policy authorship. If your NAC posture assumes ISE integrity as a precondition — and every NAC posture does — then an ISE incident invalidates the segmentation assumptions you built downstream of it.

The FMC advisory carries a specific operational instruction worth repeating: the flaw has been public since March, so log review should reach back to March rather than to September. That is a materially different evidence-collection exercise, and most retention policies will not cover it comfortably. Worth checking your actual retention window before you find out during an investigation.

Coverage: [securityonline.info on the ISE flaws](https://securityonline.info/cisco-ise-vulnerabilities-2/), [exploited-in-the-wild report](https://securityonline.info/cisco-ise-vulnerability-exploited/).

## Jenkins: twenty plugin flaws, sandbox bypasses leading to RCE

Jenkins published an advisory covering twenty plugin vulnerabilities, with Script Security sandbox bypasses among them leading to remote code execution. This is the least dramatic item of the week and probably the one with the widest quiet reach.

Build infrastructure holds deployment credentials, cloud roles, signing keys and direct write access to production. A sandbox bypass in a pipeline script layer is a straight path from "someone can submit a PR that triggers a build" to "someone can run code on the controller with the controller's identity". The defensive posture that actually helps is not faster plugin patching — although do that — it is treating the Jenkins controller as a Tier 0 asset: no shared credentials, per-job scoped secrets, ephemeral agents, and controller egress restricted to what the build genuinely needs.

Details: [Jenkins September plugin advisory coverage](https://securityonline.info/jenkins-plugin-vulnerabilities-september-2026/).

## Patch volume as a governance problem

Microsoft's September release set a record for CVE count, including two elevation-of-privilege flaws confirmed exploited and a large block of unauthenticated network-reachable RCEs spanning DNS, DHCP, NFS, SSTP and RRAS. CrowdStrike's [analysis](https://www.crowdstrike.com/en-us/blog/patch-tuesday-analysis-september-2026/) makes the structural point cleanly: at this volume, a "patch everything within the month" programme is no longer a design that maps onto reality. Prioritisation driven by exploitation status, KEV listing and your own exposed service inventory is not a maturity upgrade — it is the only version of the work that finishes.

The thread connecting all four items: the asset inventory is the control. Patching cadence, detection coverage and prioritisation all degrade to guesswork without it. If you do one thing next week, make it an honest external-facing inventory of management interfaces — and then delete the ones nobody can justify.
