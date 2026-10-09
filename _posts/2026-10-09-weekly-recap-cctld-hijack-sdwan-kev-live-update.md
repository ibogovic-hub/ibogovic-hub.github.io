---
title: "Weekly recap: ccTLD hijacks, SD-WAN Manager in KEV, NetScaler again, and kernel live update"
tags: Security
---

Four items from this week that deserve time in an infrastructure team's Monday stand-up. The common thread is trust boundaries you probably treat as fixed: the DNS hierarchy above your zones, the management plane of your WAN fabric, the edge ADC, and the reboot as the only safe way to patch a kernel.

## 1. Country-code TLDs hijacked, certificates issued for Google domains

SecurityWeek [reported](https://www.securityweek.com/) that attackers hijacked the .gh, .sl and .as ccTLDs and used that position to get HTTPS certificates for several Google domains. Once someone controls delegation at the TLD level, domain-validation checks pass because the attacker answers for the domain. The CA did what it was supposed to do.

**Why it matters operationally:** most organisations defend their own registrar account and zone. Very few watch for compromise *above* that point. Three practical controls:

- **CAA records** limit which CAs may issue certificates. They will not stop an attacker who controls the parent zone, because the attacker can serve their own CAA. They do still shrink the attack surface for weaker cases.
- **Certificate Transparency monitoring** is the control that actually catches this. If a certificate appears for your name that you did not request, you want to know within minutes.
- **DNSSEC validation** on your resolvers raises the bar when the attacker can change delegation but cannot sign with the legitimate keys. It does not help when the TLD's own signing infrastructure is compromised.

A quick CT check you can put in a cron job:

```bash
#!/usr/bin/env bash
# List certificates logged for a domain in the last 7 days via crt.sh
DOMAIN="example.com"
SINCE=$(date -u -d '7 days ago' +%Y-%m-%d)
curl -s "https://crt.sh/?q=%25.${DOMAIN}&output=json" \
  | jq -r --arg since "$SINCE" \
      '.[] | select(.entry_timestamp >= $since)
           | [.entry_timestamp, .issuer_name, .name_value] | @tsv' \
  | sort -u
```

Compare the issuer column against your CAA policy, and alert on anything you don't expect.

## 2. Cisco Catalyst SD-WAN Manager added to CISA KEV

CISA's [Known Exploited Vulnerabilities catalog](https://www.cisa.gov/known-exploited-vulnerabilities-catalog) now lists CVE-2026-76504, a hex-encoding flaw in Catalyst SD-WAN Manager. Improper handling of URI encoding in HTTP requests lets an unauthenticated remote attacker get admin-level access. Other Catalyst SD-WAN Manager entries were also added in early October.

**Why it matters operationally:** SD-WAN Manager is the control plane for your whole overlay. Admin on the manager means policy pushes to every edge, so an attacker can reroute traffic, disable segmentation, or add tunnels. KEV listing means exploitation has been seen in the wild, not just proven possible.

What to do this week:

- Patch to Cisco's fixed release for your train. Do not just rely on a workaround.
- Confirm the manager UI and API are not reachable from the internet. If they have to be reachable for a managed-service model, restrict access to known source ranges.
- Review the manager's audit log for template or policy changes you can't match to a change ticket. Look before you patch, not only after, or you lose the window of evidence.

## 3. Citrix NetScaler ADC: another critical patch

The Hacker News [reports](https://thehackernews.com/?m=1) that Citrix has released patches for another critical NetScaler ADC and Gateway flaw. I don't have the advisory details from a primary source yet, so check Citrix's security bulletin for the affected builds before you act.

**Why it matters operationally:** NetScaler has been a repeat initial-access vector, and earlier campaigns kept their access through stolen session tokens even after patching. The process is the same as before. Patch first, then kill active sessions, then hunt for webshells and unexpected files under the appliance's writable paths. If you run NetScaler as the remote-access front door, plan for an out-of-band patch cycle. Don't wait for the monthly window.

## 4. Linux Plumbers 2026: live update is getting real

[Linux Plumbers Conference 2026](https://lpc.events/event/20/contributions/) ran 5 to 7 October. The Live Update microconference is the most relevant track for operators. Sessions covered:

- **LUO support in systemd:** the talk states that systemd v261 can preserve service and nspawn container state across kexec through the existing File Descriptor Store API.
- PCI core and VFIO support for keeping passthrough devices (NICs, NVMe, GPUs) running through a host kernel upgrade.
- IOMMU state preservation.
- Compatibility of serialised state between the old and new kernel.

Separately, the Build Systems track covered bitwise-reproducible kernels and hash-based module integrity checking to replace build-time signing keys.

**Why it matters operationally:** most kernel patch delays come from the reboot, not the patch. Hypervisor hosts with passthrough devices are the worst case. If live update matures upstream, the trade-off between patch latency and VM downtime changes a lot. That is still in progress, and much of this work is patch series rather than merged code. For now, track it, and if you run your own virtualisation fleet, test kexec-based upgrades in a lab. Reproducible kernels plus hash-based module integrity also matter for anyone doing measured boot or attestation. Your attestation policy gets much simpler when a published hash can be checked independently.

## Takeaways

- Add CT log monitoring for every domain you own. It is cheap, and it is the only control in this list that would have caught the ccTLD attack.
- Treat SD-WAN managers and ADCs as tier-zero assets: no internet exposure, out-of-band patching, and log review before remediation.
- Start testing kexec and live update in the lab. The upstream pieces are coming together, and the teams that already have tested runbooks will patch faster.
