---
title: "Weekly recap: control planes, container runtimes and the appliances we forget"
tags: Security
---

This week was not about one big headline. It was about trust boundaries that sit one layer below where most teams look: a Kubernetes controller acting on behalf of a user, a container runtime trusting a checkpoint, and a self-hosted code platform trusting its own URL fetcher. Add a steady stream of kernel and OpenSSL updates and a reported SD-WAN Manager zero-day, and the theme is clear. The control plane is the target.

## Kubernetes: cross-namespace pod creation via kube-controller-manager

On 23 September Kubernetes shipped fixes for CVE-2026-2270, a flaw in kube-controller-manager. According to [LinuxSecurity's write-up](https://linuxsecurity.com/news/cloud-security/kubernetes-security-cross-namespace-pod-cve-2026-2270), a user with permission to modify two objects in one namespace could influence a controller into creating a pod outside that namespace.

Why it matters operationally: namespaces are the tenancy boundary most platform teams lean on for RBAC, quotas and network policy. A controller is a privileged actor by design; if it can be steered across that boundary, your RBAC review of the user is no longer the full picture. Managed offerings will roll the control plane for you, but self-managed clusters need the controller-manager upgraded explicitly. Check what you are actually running rather than what the change ticket says:

```bash
kubectl version -o yaml | grep -E 'gitVersion'
kubectl -n kube-system get pods -l component=kube-controller-manager \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].image}{"\n"}{end}'
```

## CRI-O: checkpoint restore can carry privileges into a new pod

The more interesting runtime story is CVE-2026-92574 in CRI-O, covered by [LinuxSecurity](https://linuxsecurity.com/news/security-vulnerabilities/cri-o-restore-kubernetes-privilege-boundaries). When a pod is restored from a checkpoint, CRI-O could restore credentials, Linux capabilities, `no_new_privs` and seccomp state from the checkpoint data itself, instead of from the security context requested for the destination pod. The advisory lists CRI-O 1.34 and later as affected, and Red Hat says OpenShift is affected from 4.17 onward. At publication, fixes were merged on supported branches but not yet released.

The operational lesson is broader than the bug. Admission control validates YAML; the kernel enforces whatever the runtime actually built. Checkpoint restore breaks the assumption that those two are the same thing. Until a fixed build lands from your vendor:

- Find out whether checkpoint restore is enabled anywhere, including dev and DR clusters where experimental features tend to accumulate.
- Restrict who can create pods from checkpoint images to trusted admins and automation.
- Treat checkpoint images as privileged artifacts: constrained registries, protected build path, admission policy rejecting untrusted ones.
- Recreate any workload restored from a checkpoint of uncertain origin from a normal image.

## GitHub Enterprise Server: SSRF through the notebook viewer

[GitHub patched](https://linuxsecurity.com/news/security-vulnerabilities/github-enterprise-server-flaw-could-let-attackers-run-code) a flaw in the GHES notebook viewer that checked scheme and host of a fetched URL but not the port. That turned an approved host into a path to internal services on the appliance. Response bodies were not returned, but per GitHub's advisory, timing differences let an attacker recover an instance secret one character at a time, and a further interaction could lead to code execution. With private mode off, no login is required; with it on, any authenticated user can reach the path.

Fixed releases per branch: 3.17.21, 3.18.15, 3.19.12, 3.20.8, 3.21.6 and 3.22.1. GitHub reports no confirmed exploitation.

Why it matters: GHES is exactly the kind of appliance that gets one production instance patched and a standby or recovery image left behind. That recovery appliance holds the same secrets and the same CI credentials. Inventory every reachable instance, verify the running version on each, and narrow network reach to the appliance until all of them are done. The general pattern is worth keeping in mind for any internal tool that fetches URLs on a user's behalf: allow-listing hosts without ports is not an allow-list.

## Linux kernel, OpenSSL and the patch queue

The routine side of the week was not small. Ubuntu published a batch of kernel notices on 2 October, including [USN-8864-1](https://ubuntu.com/security/notices/USN-8864-1), GKE, FIPS and Raspberry Pi variants, plus [USN-8861-1](https://ubuntu.com/security/notices/USN-8861-1) for OpenSSL on 1 October. [LWN's daily security update lists](https://lwn.net/) show OpenSSL updates from Debian and Ubuntu, Grafana and container-tooling updates (podman, buildah, runc, skopeo) from Red Hat and AlmaLinux, and kernel updates across most distributions. LWN also noted Git 2.56.0 this week.

For homelab and fleet operators the boring advice stands: OpenSSL and kernel updates need a restart of the consuming services or the host, not only a package install. A quick check on Debian and Ubuntu hosts:

```bash
sudo apt update && apt list --upgradable 2>/dev/null | grep -E 'linux-image|openssl|libssl'
[ -f /var/run/reboot-required ] && cat /var/run/reboot-required.pkgs
sudo needrestart -r l   # list services still mapping old libraries
```

If you run Grafana from distribution packages, note that Red Hat and AlmaLinux shipped Grafana updates this week; monitoring stacks are frequently exempt from patch windows because they are "only internal".

## Cisco SD-WAN Manager: reported zero-day

A [DefSec daily brief](https://www.youtube.com/watch?v=Re_VbTuDQW8) on 1 October reported a Cisco SD-WAN Manager zero-day granting admin access, tracked as CVE-2026-76504, with fixed releases in several trains including 20.9.10.1, 20.12.8.2, 20.15.6.1, 20.18.4.1 and 26.1.2.1. I have only that secondary source, so confirm details against Cisco's own advisory before acting. If you operate SD-WAN Manager, the priority is the same regardless: management plane off the internet, access restricted to jump hosts, and audit logs reviewed for unexpected admin sessions.

## Takeaway

Three of the four items this week share a shape: a privileged component acting for a less privileged caller without fully re-checking the caller's constraints. Controllers, runtimes and URL fetchers are all confused-deputy candidates. When reviewing your own platforms, ask what each privileged service does on someone else's behalf, and whether the policy you wrote is the policy that ends up enforced.
