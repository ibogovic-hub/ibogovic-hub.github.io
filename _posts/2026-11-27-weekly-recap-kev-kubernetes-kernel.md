---
title: "Weekly recap: edge devices on KEV, a leaked Kubernetes platform and AI-scale kernel bug hunting"
tags: Security
---

This was a short, US-holiday week, but it was not a quiet one. Four things from the news this week are worth acting on if you run network edges, managed Kubernetes or Linux fleets. Each one comes with a note on what I would actually do on Monday.

## 1. CISA KEV additions: Cisco Expressway and friends

CISA added several entries to the Known Exploited Vulnerabilities catalog this week. The [20 November alert](https://www.cisa.gov/news-events/alerts/2026/11/20/cisa-adds-four-known-exploited-vulnerabilities-catalog) and the [23 November alert](https://www.cisa.gov/news-events/alerts/2026/11/23/cisa-adds-two-known-exploited-vulnerabilities-catalog) cover products that sit on the edge or in the management plane of most enterprises. According to a [daily briefing summarising them](https://www.pbcsnyc.com/post/daily-cybersecurity-briefing-november-24-2026), that includes Cisco Expressway, SAP NetWeaver, VMware vCenter and Apache Roller.

**Why it matters operationally:** Expressway is a collaboration edge box. It often sits in a DMZ with inbound exposure and gets patched less often than firewalls because "it's the video thing". vCenter is the opposite case. It should never be reachable from anywhere interesting, but in practice it often is. A KEV entry means someone is already exploiting it. That moves these from "next maintenance window" to "this week". Don't treat the federal deadline as your SLA.

I pull the KEV feed into the same pipeline that checks our asset inventory, so I see a match instead of reading headlines:

```bash
curl -s https://www.cisa.gov/sites/default/files/feeds/known_exploited_vulnerabilities.json \
  | jq -r '.vulnerabilities[]
      | select(.dateAdded >= "2026-11-20")
      | [.dateAdded, .cveID, .vendorProject, .product, .dueDate] | @tsv' \
  | column -t -s $'\t'
```

Join that output against your CMDB vendor and product fields and you have a first-pass exposure list in seconds.

## 2. Rackspace Spot: leaked credentials, roughly a day of access

The same [briefing](https://www.pbcsnyc.com/post/daily-cybersecurity-briefing-november-24-2026) reports, citing BleepingComputer, that attackers used leaked credentials to access Rackspace's Spot managed Kubernetes platform on 17–18 November, for about 22 hours. Kubernetes Secrets, API tokens and cluster configs may have been exposed, and customers have been told to rotate all cluster credentials.

**Why it matters operationally:** This is the failure mode that managed Kubernetes is supposed to remove, and it still happened. The platform got in through a credential, not a zero-day. If you are a customer of any managed control plane, check two things:

- Can you rotate every secret a cluster holds without a manual hunt? That covers service account tokens, registry pull secrets, cloud IAM keys and webhook signing keys. If the answer is "we'd need a war room", fix that first.
- Do your workloads keep long-lived static credentials in Kubernetes Secrets at all? Workload identity and short-lived tokens make a provider-side leak expire on its own.

Before you need to rotate, take a quick inventory of the Secret types sitting in your clusters:

```bash
kubectl get secrets -A -o json \
  | jq -r '.items[] | [.metadata.namespace, .metadata.name, .type] | @tsv' \
  | sort -k3 | column -t
```

## 3. Linux kernel bugs found at machine scale

Several sources this month covered large-scale, AI-assisted vulnerability discovery in the Linux kernel. OpenAI published [A thousand fewer paths to root](https://openai.com/index/a-thousand-fewer-paths-to-root/), describing a scan of the kernel and the triage and patch work that followed. [LinuxSecurity](https://linuxsecurity.com/news/security-trends/ai-cybersecurity-linux-kernel-patch-review) points out the obvious bottleneck: maintainers still have to review the fixes. [The Hacker News ThreatsDay bulletin](https://thehackernews.com/2026/11/threatsday-59-linux-kernel-bugs-falcon.html?m=1) separately covers a batch of kernel bugs reported by Microsoft, including working privilege-escalation exploits. Linus Torvalds has also [commented](https://www.scworld.com/brief/linus-torvalds-suggests-peak-of-linux-kernel-patch-deluge-may-be-passing) that the peak of the patch flood may be passing.

**Why it matters operationally:** The volume of local privilege-escalation fixes landing in stable kernels has gone up, and it is staying up for a while. That has two consequences:

- "Local only" is no longer a reason to defer kernel updates. Every container escape and every web-shell-to-root chain starts with a local bug.
- You need a working reboot cadence, or live patching where it is supported. A kernel that is installed but never booted is not a patched kernel.

Find hosts where the running kernel differs from the newest installed one (Debian/Ubuntu example):

```bash
running=$(uname -r)
latest=$(ls -1 /boot/vmlinuz-* | sed 's|/boot/vmlinuz-||' | sort -V | tail -n1)
[ "$running" != "$latest" ] && echo "$(hostname): running $running, installed $latest -> reboot pending"
```

Run that through Ansible ad hoc across the fleet and you have a reboot backlog list.

## 4. Palo Alto patches a kernel bug chained against its own firewalls

According to [AI Weekly's summary of a SecurityWeek report](https://aiweekly.co/ai-news-today/edition/2026-11-26), Palo Alto Networks this week patched a Linux kernel privilege-escalation bug dubbed "Fragnesia". Attackers had chained it with a separate flaw to compromise some of its firewalls in October.

**Why it matters operationally:** This ties item 3 to the network edge. Security appliances run Linux, and a kernel LPE on a firewall turns a foothold in the management plane into full control of the box. Vendor appliance kernels also lag upstream, so the general kernel fixes from item 3 reach your firewalls only when the vendor ships them. In practice:

- Track appliance advisories as their own feed, not as part of "network team patching".
- Keep management interfaces off anything except a dedicated management network, with no internet exposure.
- Forward the appliance's own system and config logs off-box, so a compromised device can't erase the evidence of its compromise.

## Takeaways for next week

- Match the latest KEV additions against inventory. Expressway and vCenter get priority.
- If you run on any managed Kubernetes platform, test a full secret rotation on a non-production cluster.
- Measure your reboot backlog. Kernel fixes are arriving faster than most patch cycles assume.
- Treat firewall and VPN appliance firmware as Linux hosts that you can't see into, and patch them with that in mind.
