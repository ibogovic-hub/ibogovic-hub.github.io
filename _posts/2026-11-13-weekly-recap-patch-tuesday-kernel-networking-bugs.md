---
title: "Weekly recap: Patch Tuesday volume, kernel networking bugs and a busy stable week"
tags: Security
---

This week was mostly about patching. Nothing exotic, but the volume and the location of the bugs matter for anyone running Windows fleets, Linux routers, VPN gateways or container hosts. Here are the items I think are worth a senior engineer's time, and what I would actually do about each.

## 1. November Patch Tuesday: large release, one exploited zero-day

Microsoft's November release landed on Tuesday, 10 November. CrowdStrike's [analysis](https://www.crowdstrike.com/en-us/blog/patch-tuesday-analysis-november-2026/) counts 1,252 CVEs, including one exploited zero-day and 68 rated Critical, with elevation of privilege as the leading category. Tenable's [write-up](https://www.tenable.com/blog/microsoft-november-2026-patch-tuesday-addresses-1093-cves-cve-2026-124194) gives a lower total of 1,093. The vendors count differently, depending on whether they include third-party and Chromium-based fixes, so don't build a report around either number.

Operationally the count matters less than the shape. When elevation of privilege leads the list, an initial foothold anywhere in the estate turns into a much bigger problem. Prioritise the exploited zero-day first, then internet-facing and identity-adjacent systems like domain controllers, RD gateways and management jump hosts. Everything else goes through the normal ring rollout. If your pilot ring is still a handful of hand-picked machines, a release this size is a good reason to widen it. More code changed means more chance of a regression that only shows up on a specific driver or role.

## 2. Microsoft's write-up on 59 Linux kernel bug reports

On 11 November the Microsoft Security blog published [Lessons from 59 Linux Kernel Bug Reports](https://www.microsoft.com/en-us/security/blog/2026/11/11/lessons-from-59-linux-kernel-bug-reports/). The selected findings are almost entirely in networking code: bridged IPv6 fragmentation, IPv6 IPsec routing, next-hop replacement in IPv4, the GTP tunnel driver, xfrm, and a use-after-free in rhashtable walks. The post traces that last one from a netlink socket listing all the way to a kernel write.

This is relevant for network engineers because these are exactly the subsystems a Linux box uses when it acts as a router, an IPsec endpoint or a mobile-core component. A lot of us run Linux in those roles without thinking of it as "network gear", for example strongSwan gateways, VyOS or FRR routers, and container hosts with bridged IPv6. The common pattern is lifetime and locking errors on error paths and during concurrent teardown. That is the kind of bug you trigger by flapping an interface or deleting a tunnel under load, and nobody exercises those paths in normal testing.

What I would do:

- Inventory which hosts actually load `xfrm`, `gtp`, bridge and IPv6 forwarding paths, rather than assuming "it's just a server".
- Make sure those hosts are on a maintained stable or distro kernel branch and are not pinned to an old build because "it works".
- Unload modules you don't need. If nothing uses GTP, it should not be loadable.

A quick check of what is loaded and whether the box is forwarding:

```bash
# Network-relevant modules currently loaded
lsmod | grep -E '^(xfrm|esp4|esp6|gtp|bridge|br_netfilter)' || echo "none of the listed modules loaded"

# Is this host routing?
sysctl net.ipv4.ip_forward net.ipv6.conf.all.forwarding

# Running kernel vs. installed packages (Debian/Ubuntu)
uname -r
dpkg -l 'linux-image-*' | awk '/^ii/{print $2, $3}'
```

And to block an unused module persistently:

```bash
echo 'install gtp /bin/false' | sudo tee /etc/modprobe.d/disable-gtp.conf
```

## 3. Three stable kernels in one day, and distros following

[LWN](https://lwn.net/) reported three new stable kernels on Tuesday: 7.3.4, 6.18.63 and 6.12.117. According to LWN, 7.3.4 carries more than 1,250 patches, 6.18.63 more than 860, and 6.12.117 more than 1,530.

When a long-term branch like 6.12 takes over 1,500 patches in one point release, upstream is backporting a lot of fixes. Some of that flow is the bug classes described above. For appliance-style Linux deployments where you build your own kernel, this is the week to rebase. On distro kernels, watch for your vendor's rebuild. Don't cherry-pick, because you won't know which of those patches are security-relevant until the CVE assignments catch up.

Kernel updates also mean reboots. If you don't have a check for "kernel installed but not running", now is a good time to add one. On Debian and Ubuntu, `/var/run/reboot-required` exists for this. On RHEL-likes, `needs-restarting -r` does the same job.

## 4. Distro security updates: DNS, SSH and container tooling

The LWN security update lists for the week are long, but a few package names stand out for infrastructure teams. Red Hat shipped updates for bind (several streams), podman, runc, buildah, skopeo, nginx and squid. Fedora and Ubuntu updated unbound. Red Hat and SUSE both shipped openssh and openssl updates, and SUSE also updated haproxy, docker and ansible-core.

Resolvers, the container runtime and SSH sit on almost every critical path. A resolver bug can redirect or black-hole traffic for everything downstream. A runc bug is a container-boundary problem. My priority order would be:

1. Resolvers (bind, unbound)
2. Container runtimes on multi-tenant hosts
3. SSH and TLS libraries on bastions
4. Reverse proxies

For resolvers, run `named-checkconf` or `unbound-checkconf` before restarting after the upgrade, and confirm resolution from a client rather than trusting the service status.

## Takeaway

Nothing this week needs an emergency all-hands, but it adds up to a full maintenance window: Windows rings, kernel rebases on Linux network roles, and resolver and runtime updates. The Microsoft kernel write-up is the item worth reading in full. It is a useful reminder that a Linux host doing IPsec or bridged IPv6 is part of the network attack surface and should be patched on the same schedule as the routers.
