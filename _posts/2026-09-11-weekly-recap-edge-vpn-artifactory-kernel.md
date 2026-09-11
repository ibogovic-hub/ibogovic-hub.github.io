---
title: Weekly recap: edge VPN patches, a poisoned artifact store, and a kernel branch that quietly died
tags: Security
---

Four things from this week that actually change what you should be doing on Monday. No product launches, no conference keynotes — just the items that move patch windows and change assumptions.

## Check Point ships critical VPN fixes

SecurityWeek is carrying a Check Point advisory covering critical vulnerabilities in its VPN stack ([securityweek.com](https://www.securityweek.com/check-point-patches-critical-vpn-vulnerabilities/)). I am not going to quote a CVSS number I have not verified against the vendor bulletin — go read the Check Point advisory directly before you size the change.

What matters operationally is the pattern, not the individual bug. Remote-access VPN concentrators are the single most reliably exploited class of enterprise infrastructure of the last three years, across every major vendor. They are internet-facing by definition, they terminate authentication, and they are almost always excluded from the normal server patch cadence because "it's a network device" and the maintenance window needs a change advisory board.

If your VPN gateways are on a quarterly cycle, that is the finding. The realistic target is: vendor advisory to patched-in-production inside seven days for anything rated critical on an internet-facing termination point, with a pre-approved standing change record so you are not negotiating the window while the exploit is being weaponised. Everything else — the WAF in front, the geo-fencing, the MFA — is compensating control, not a fix.

Practical hygiene item while you are in there: know what your gateway actually exposes. From an external host, not from inside:

```bash
# What TLS/IKE surface does the gateway present to the internet?
nmap -Pn -sS -p 443,500,4500 --script ssl-enum-ciphers vpn.example.com

# IKE endpoints answer UDP; confirm separately
nmap -Pn -sU -p 500,4500 vpn.example.com
```

If the portal answers on ports you did not intend to publish, the patch is the second problem.

## CISA added six KEV entries in two days

CISA pushed two Known Exploited Vulnerabilities updates in rapid succession — four entries on 9 September and two more on 10 September ([cisa.gov](https://www.cisa.gov/news-events/cybersecurity-advisories)).

KEV remains the single highest signal-to-noise vulnerability feed available for free. It is not "things that are scary," it is "things with confirmed in-the-wild exploitation." If your vulnerability management programme is still ranking purely on CVSS base score, you are prioritising theoretical severity over observed attacker behaviour, and you will spend a sprint on a 9.8 that nobody has ever exploited while a 7.5 with a public Metasploit module sits open.

Wire KEV into your pipeline rather than reading it. The catalogue is published as machine-readable JSON:

```bash
curl -sS https://www.cisa.gov/sites/default/files/feeds/known_exploited_vulnerabilities.json \
  | jq -r '.vulnerabilities[]
      | select(.dateAdded >= "2026-09-01")
      | [.cveID, .vendorProject, .product, .dueDate] | @tsv' \
  | column -t
```

Join that CVE list against whatever your scanner or SBOM inventory produces, and let the intersection drive the emergency queue. Everything outside the intersection goes in the normal cycle. That one join is worth more than most commercial risk-scoring add-ons.

## Artifactory flaws chained to admin and backdoor implants

The Hacker News reports attackers chaining two JFrog Artifactory flaws to obtain admin control and plant backdoors ([thehackernews.com](https://thehackernews.com/?m=1)).

This is the one that should worry network and platform people most, because the blast radius is not the server. An artifact repository is a build-time trust anchor. If an attacker holds admin on it, they can republish a signed-looking internal library, a base container image, or a Helm chart, and every downstream pipeline pulls the poisoned version on the next build. The compromise propagates through your own CI, using your own credentials, into production — and none of it looks like an intrusion at the network layer, because it is just builds doing what builds do.

Two defences are worth the effort. First, treat the artifact store as tier-zero infrastructure alongside your directory service and PKI, with the same access model and the same patch SLA — not as "a dev tool the platform team runs." Second, verify at consumption time rather than trusting the repository's word: pin digests instead of tags for container images, and make your pipeline fail closed on a signature or digest mismatch. A registry compromise you can detect at pull time is an incident; one you cannot is a supply-chain breach with an unknown start date.

## Kernel 7.1 reached end of security support

Per endoflife.date, the 7.1 branch ended security support on 2 September 2026, with 7.1.13 as its final release; 7.2 (released 16 August 2026) is the current mainline branch, and the LTS lines 6.18, 6.12, 6.6 and 6.1 all received updates on the same date ([endoflife.date/linux](https://endoflife.date/linux)).

Also on the calendar: 5.15 and 5.10 both drop out of security support at the end of December 2026. That is a real deadline for anyone with embedded appliances, older container hosts, or vendor-locked platforms shipping those trees. Three and a half months is enough time to plan a migration and not enough to discover mid-December that a driver you depend on was removed.

Worth noting from the 7.1 notes: legacy code removals including i486, some PCI and PCMCIA drivers ([Wikipedia](https://en.wikipedia.org/wiki/Linux_kernel_version_history)). Modern kernels are shedding old hardware support faster than they used to. If you run anything genuinely old in a lab or on a factory floor, check driver presence before you commit to a version bump, not after.

Quick inventory across a fleet:

```bash
ansible all -m shell -a 'uname -r' -o | sort -k3
```

Sort the output, find the long tail, and start there.
