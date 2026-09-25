---
title: Weekly recap: kernel root exploits, ISE and switch flaws, and a record patch month
tags: Security
---

This week didn't bring one big story. It brought pressure from several directions at once: public exploit code for Linux kernel privilege escalation, critical flaws in network control-plane products, exploitation of a switch vulnerability, and a Microsoft patch backlog that is still sitting unapplied in plenty of environments two weeks after release. Below are the items that I think deserve time in an operations meeting, and what I would do about each.

## 1. Public exploits for four Linux kernel local root flaws

The Hacker News reported on 18 September that [public exploits have been released for four Linux kernel flaws that enable local root](https://thehackernews.com/2026/09/public-exploits-released-for-four-linux.html). It is easy to wave off local privilege escalation. That is a mistake. In most real intrusions, the first foothold is a low-privileged account: a compromised web application user, a CI runner, a container with a shell, or a jump host account that an operator shares. Once a working exploit is public, the time from foothold to root drops to however long it takes to download and run it.

Operationally, this matters most on multi-tenant and shared hosts: build agents, bastions, Kubernetes nodes, and any Linux box where people other than admins get a shell. Those should be first in the patch queue, ahead of single-purpose appliances. Kernel updates also do nothing until you reboot, so "patched" in your package inventory doesn't mean "not vulnerable" in practice. A quick way to find hosts whose running kernel is behind the installed one:

```bash
#!/usr/bin/env bash
# Flag hosts where the running kernel differs from the newest installed kernel
running=$(uname -r)
if command -v dpkg >/dev/null 2>&1; then
  newest=$(dpkg -l 'linux-image-[0-9]*' | awk '/^ii/{print $2}' | sed 's/linux-image-//' | sort -V | tail -1)
else
  newest=$(rpm -q kernel --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' | sort -V | tail -1)
fi
echo "running=${running} newest_installed=${newest}"
[ "$running" = "$newest" ] || echo "REBOOT REQUIRED: $(hostname)"
[ -f /var/run/reboot-required ] && echo "reboot-required flag present"
```

Run it through Ansible or whatever fleet tooling you use, and turn the output into a reboot schedule rather than a report nobody reads.

## 2. Cisco ISE critical flaw and an actively exploited Cisco bug

Senserva's tracker lists [CVE-2026-76460, a critical Cisco Identity Services Engine vulnerability rated CVSS 10.0](https://senserva.com/cve/CVE-2026-76460.html), dated 16 September. It also lists [CVE-2026-76461, a Cisco issue rated CVSS 9.8 and marked as under active attack](https://senserva.com/cve/CVE-2026-76461.html). Check Cisco's own advisories for affected releases and fixed trains before acting. Don't rely on third-party summaries for version scoping.

ISE is an unusual kind of risk. It sits in the authentication path for wired, wireless, and VPN access, it usually holds privileged credentials to AD and network devices, and it tends to be reachable from wide swaths of the internal network because every NAD needs to talk RADIUS or TACACS+ to it. Compromise ISE and you control who gets on the network. The patch window is also awkward, because upgrading a distributed ISE deployment is not a five-minute job. At minimum, confirm that the admin and API interfaces are reachable only from a management network, and review which service accounts ISE holds.

## 3. Switch and control-plane flaws beyond Cisco

Two further items point the same way. SecurityWeek reports that a [recent ZyXEL switch vulnerability is being exploited by Chinese threat actors](https://www.securityweek.com/recent-zyxel-switch-vulnerability-exploited-by-chinese-hackers/). Separately, CISA's [vulnerability summary for the week of 14 September](https://www.cisa.gov/news-events/bulletins/sb26-264) includes an entry where a malicious packet sent while a P4Runtime session is being set up can give an attacker full administrative control. That second one matters to anyone running programmable data planes or SDN controllers in the lab or in production.

Both lead to the same conclusion. Management and control-plane interfaces on network gear are now a routine target, and "it's on the internal network" is not a control. If your switches still accept SSH, HTTP, SNMP, or gRPC management from user VLANs, fix that before you worry about the next advisory. On IOS-style platforms, a management ACL on the VTY lines is the minimum:

```text
ip access-list standard MGMT-ONLY
 permit 10.10.99.0 0.0.0.255
 deny   any log
line vty 0 15
 access-class MGMT-ONLY in
 transport input ssh
```

## 4. September Patch Tuesday is still worth a second look

Microsoft's September release was large. CrowdStrike's analysis counts [972 CVEs, including two exploited zero-days and 113 rated Critical](https://www.crowdstrike.com/en-us/blog/patch-tuesday-analysis-september-2026/), which it calls a new Patch Tuesday record. For infrastructure teams, the [Zero Day Initiative review](https://www.thezdi.com/blog/2026/9/8/the-september-2026-security-update-review) is the more useful read. It lists critical remote code execution fixes in Windows DHCP Server (CVE-2026-69845, CVE-2026-72979), Windows DNS Server (including CVE-2026-69730), Netlogon (CVE-2026-72982), RRAS, and SSTP.

Those are core services. DHCP, DNS, and Netlogon usually run on domain controllers or on servers that every client talks to, so network segmentation limits exposure far less than it does for a typical application server. With that many CVEs, triage by role rather than by score: patch domain controllers and DHCP/DNS servers first, then RRAS and SSTP edge hosts, then the long tail. If your process tracks "patch compliance" as a single percentage, this is a month where that number can look fine while the servers that matter most are still unpatched.

## Takeaways

- Public LPE exploits turn any shell into root. Prioritize kernel updates and reboots on shared Linux hosts.
- Treat ISE, switches, and SDN controllers as tier-zero assets. Restrict their management planes to dedicated networks.
- Triage Microsoft's September release by server role. DHCP, DNS, and Netlogon fixes come before the rest.
- Check affected versions against the vendor's own advisory before scheduling changes.

The next Patch Tuesday lands on 13 October. Close out the September backlog before it arrives.
