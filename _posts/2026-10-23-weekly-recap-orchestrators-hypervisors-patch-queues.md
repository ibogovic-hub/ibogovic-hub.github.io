---
title: "Weekly recap: orchestrators, hypervisor escapes and the patch queue"
tags: Security
---

This week was mostly about the parts of the stack we treat as plumbing: SD-WAN management planes, the kernel networking code under our hypervisors, and the vendor bulletins that land in everyone's ticket queue at once. Here are four things I'd look at before the weekend, and what I'd actually do about them.

## 1. Another exploited zero-day in Arista VeloCloud Orchestrator

SecurityWeek [reports](https://www.securityweek.com/attackers-exploit-third-velocloud-orchestrator-zero-day-in-four-months/) that attackers are exploiting a critical SQL injection flaw in the VeloCloud Orchestrator (VCO). It gives access to privileged internal functions and operator-level privileges. By their count it is the third exploited VCO zero-day in four months.

Why it matters: the orchestrator is the control plane for every edge it manages. Operator privileges on a VCO let an attacker push configuration, change routing and steer traffic across the whole SD-WAN fabric, which is a much bigger blast radius than one compromised edge. Three exploited bugs in one quarter is also a pattern. If you run VCO on-prem, it should stop being something you patch when convenient and start being treated as an internet-facing asset under active attack.

What I'd do:

- Apply the vendor fix as soon as it's available, and check the advisory for interim mitigations.
- Restrict access to the management UI and API to a management network or a jump host. Don't leave it open to the internet "for the partners."
- Review VCO audit logs for new operator accounts, unexpected API tokens and configuration pushes nobody can explain.
- Check whether the product shows up in [CISA's KEV catalog](https://www.cisa.gov/known-exploited-vulnerabilities-catalog), and use that as the deadline if you're regulated.

## 2. A kernel networking bug that lets a guest attack the host

AlmaLinux published a [write-up](https://almalinux.org/blog/) on "PwnEscape", a flaw in the Linux kernel networking stack. A malicious virtual machine can use it to leak host memory and crash the host, and in the researcher's lab it ran code as root on the host. I'm not repeating the identifier here because I haven't confirmed it against the upstream advisory. Take the CVE ID from your distribution's tracker, not from aggregators.

Why it matters: guest-to-host escapes break the assumption multi-tenant virtualisation depends on. That includes your own lab, your VDI farm and every KVM host running untrusted or semi-trusted workloads. A crash alone is serious: one guest can take down every other VM on the node.

The fix is a kernel update, so you need a reboot, so you need a maintenance window and live migration. The order I'd use:

1. Inventory hosts that run guests you don't fully control.
2. Patch and reboot those first. Evacuate VMs with live migration where you can.
3. Confirm the running kernel matches the installed one. A patched package on disk with the old kernel still running is the classic false sense of security.

```bash
# Show running vs newest installed kernel, and flag hosts that still need a reboot
running=$(uname -r)
latest=$(rpm -q --last kernel 2>/dev/null | head -1 | awk '{print $1}' | sed 's/^kernel-//')
echo "running: $running"
echo "latest:  ${latest:-n/a (non-RPM host)}"
[ -n "$latest" ] && [ "$running" != "$latest" ] && echo "REBOOT REQUIRED"
# Debian/Ubuntu equivalent
[ -f /var/run/reboot-required ] && cat /var/run/reboot-required*
```

Run that through Ansible ad-hoc or your RMM across the fleet, and you have a reboot list in minutes instead of a spreadsheet exercise.

## 3. Stable kernels and the 7.3 cycle

LWN flagged [four stable kernel releases on Wednesday](https://lwn.net/), along with development statistics for the 7.3 kernel and a piece on removing `__get_user()` and `__put_user()`. The last one is deep kernel work, but the direction matters. Unchecked user-memory accessors have caused real bugs for years, and removing them is the kind of quiet hardening that pays off over the next decade.

Operationally, stable-kernel weeks like this one are when distribution kernels move, and when the hypervisor fix above shows up in your package mirrors. If you pin kernels in image pipelines (Packer, golden AMIs, PXE images), this is the week to rebuild images instead of patching hosts after deployment.

Also worth a look if you care about the automation side of kernel maintenance: the Linux Plumbers talk on [Syzbot's AI-assisted patching workflow](https://lpc.events/event/20/contributions/2597/). The interesting part isn't "AI writes patches." It's that fuzzer findings get turned into reviewable candidate fixes, which could shorten the gap between a bug being found and a stable backport existing.

## 4. Atlassian's October bulletin: 176 entries, all third-party

According to [SecurityWeek](https://www.securityweek.com/), Atlassian's October security bulletin lists 176 vulnerability entries. Fourteen are critical, and all are in third-party components.

Why it matters: this is what supply-chain risk looks like in practice. Most of these bugs aren't in Atlassian's code. They're in the libraries bundled with it, and you inherit all of them when you self-host Jira or Confluence. The count also shows that a raw CVE total doesn't tell you much. What matters is how many are reachable in your deployment, and the vendor bulletin usually doesn't answer that.

How I'd approach it:

- Self-hosted Data Center instances: plan the upgrade to the fixed release instead of hand-picking CVEs. With 14 critical issues, triaging each one costs more than upgrading.
- Generate an SBOM for internally deployed apps if you don't already, so the next "bundled library" bulletin turns into a query instead of a fire drill.
- Take these instances off the internet and put them behind SSO or VPN if they're still exposed. Most mass exploitation of collaboration tools starts with a public login page.

## The common thread

None of these are exotic. They are management planes, hypervisors and bundled dependencies, the infrastructure layers we tend to trust because they've been around for years. The work for next week is the usual: shrink management exposure, make reboots routine, and know what's inside the software you run.

Have a good weekend. Patch first, then ride.
