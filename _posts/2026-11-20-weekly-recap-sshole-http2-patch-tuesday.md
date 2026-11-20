---
title: "Weekly recap: sshole, HTTP/2 heap bugs and a heavy Patch Tuesday"
tags: Security
---

This was a patching week, not a feature week. Nothing on the list is new in kind. Most of it is plumbing we tend to assume is fine: OpenSSH on embedded images, the HTTP/2 stack in front of our apps, and the Windows DNS and DHCP roles that everything else depends on. Here is what I would put on a change board this week, and why.

## 1. "sshole": OpenSSH on musl-based systems allows passwordless login

F5 Labs' [weekly threat bulletin](https://www.f5.com/labs/articles/weekly-threat-bulletin-november-11th-2026) covers an authentication bypass dubbed "sshole". It involves OpenSSH combined with musl libc and is tracked as CVE-2026-123158, with CVE-2016-6210 listed alongside it. The affected technologies listed are Alpine Linux, Buildroot, Docker, OpenWrt and the Yocto Project, and the victim industries include telecommunications, industrial control and medical devices. Softcat's [Patch Tuesday roundup](https://www.softcat.com/blog/post-patch-tuesday-roundup-november-2026) notes that Linux distributions have shipped fixes and links to the [OpenSSH release notes](https://www.openssh.org/releasenotes.html#10.6p2).

Why it matters operationally: glibc-based servers are not where I would look first. The risk is in Alpine container images that run sshd (they should not, but some do), OpenWrt routers, and appliances built with Buildroot or Yocto that your vendors will be slow to patch. For a network team, that means out-of-band management boxes, console servers and anything else with a small Linux image.

Start by finding out where you actually have musl and sshd together:

```bash
# On a host or inside a container: is libc musl, and is sshd present?
ldd --version 2>&1 | head -1
command -v sshd && sshd -V 2>&1 | head -1

# Across running containers on a Docker host
for c in $(docker ps -q); do
  printf '%s ' "$(docker inspect -f '{{.Name}}' "$c")"
  docker exec "$c" sh -c 'ls /lib/ld-musl-* >/dev/null 2>&1 && echo musl || echo other; command -v sshd || true' 2>/dev/null | tr '\n' ' '
  echo
done
```

If you can't patch an appliance this week, limit TCP/22 to your management jump hosts at the network layer. Do that anyway, but treat it as a stopgap and keep the patch ticket open.

## 2. HTTP/2 again: Node.js and Apache mod_http2

HTTP/2 implementations were the second theme. Node.js shipped its [November security releases](https://nodejs.org/en/blog/vulnerability/november-2026-security-releases) on 11 November. The items I would read first:

- CVE-2026-123863 (high): one unauthenticated request can remotely abort a default HTTP/2 server.
- CVE-2026-123864 (high): on HTTPS servers, a zero-length TLS write can make the server copy its own heap into a request body. [Phoenix Security](https://phoenix.security/node-js-vulnerabilities-cve-2026-123864-tls-key-leak-http2-crash/) says this can leak TLS private keys and other users' requests.
- CVE-2026-123867 (medium): CA-only SNI client-CA overrides fail open to the default CA. In plain terms, per-host mTLS authorization can be bypassed.
- CVE-2026-123871 (medium): proxy credentials appear in `ERR_PROXY_INVALID_CONFIG` error messages, so they end up in container logs and your log pipeline.

Phoenix says there is no workaround and that the fixed versions are 22.23.5, 24.22.3 and 26.13.1. The proxy credential bug is the one people will underrate. If your services take `HTTPS_PROXY` with embedded credentials, assume those credentials may already be sitting in your log aggregation. Rotate them, and fix the log retention while you are at it.

On the Apache side, Phoenix also wrote up [HTTP2Reset (CVE-2026-119618)](https://phoenix.security/cve-2026-119618-apache-mod-http2-rce/), a pre-auth heap corruption bug in `mod_http2` with RCE potential. Distro `mod_http2` updates appeared in this week's [LWN security update lists](https://lwn.net/). If you run httpd as a reverse proxy, check that the updated package is installed and that the service was restarted. A package that is installed but not reloaded is the usual gap.

```bash
# RHEL-family: confirm package version and that httpd restarted after the update
rpm -q mod_http2 httpd
systemctl show httpd -p ActiveEnterTimestamp
```

## 3. Patch Tuesday: DNS, DHCP and network stack on Windows

Microsoft's November release is large. ZDI's [review](https://www.thezdi.com/blog/2026/11/10/the-november-2026-security-update-review) is the easiest way to read it. For infrastructure teams the clusters that matter are:

- Windows DHCP Server: several RCEs. ZDI's table lists CVE-2026-88243 at CVSS 9.8.
- Windows DNS Server and DNS client: a group of RCE and elevation-of-privilege entries.
- Network stack: Schannel (CVE-2026-119952), NAT (CVE-2026-113862) and TCP/IP, all critical. Kerberos has an elevation-of-privilege entry rated 9.8 (CVE-2026-85844).

Softcat also flags a zero-day exploited in the wild. A crafted Office file leaks NTLMv2 hashes, which is one more reason to keep pushing NTLM off your network.

Operational note: DHCP and DNS servers are the ones change boards like to push "to next window" because rebooting them is uncomfortable. That is backwards. If you run failover pairs, patch one node, check that leases and resolution still work, then do the partner. If you don't run failover pairs, this month's list is a good argument for getting them.

## 4. Edge devices are still being exploited

Softcat's vendor roundup is a reminder that perimeter devices are still the main entry point. It lists two Ivanti Connect Secure vulnerabilities that were chained and exploited as zero-days since at least October, and a SonicOS SSL-VPN authentication bypass that has been exploited. The same roundup lists Fortinet's monthly batch (FortiOS, FortiManager, FortiAnalyzer, FortiSASE) and critical Cisco fixes for Catalyst SD-WAN Controller, Secure Email Gateway and Meraki.

If you run any of these, patching is not enough. Assume the device may have been compromised before you patched it. Check for unexpected local accounts and configuration changes, and review session logs from the past several weeks. Rotate any credentials the device stored. Ivanti appliances have needed this treatment repeatedly.

## What I am taking into next week

- Inventory sshd on musl-based images and appliances. Nobody has a complete list of these until they go and build one.
- Treat the Node.js proxy credential leak as a credential rotation task, not only an upgrade.
- Patch DNS and DHCP this cycle, one node of each failover pair at a time.
- For any exploited edge device, patch first, then run a compromise assessment.
