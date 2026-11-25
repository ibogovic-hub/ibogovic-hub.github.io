---
title: "A kernel sysctl baseline that closes the easy doors"
tags: Security
---

A low-privileged shell on a server is not the end of an incident, it is the start of one. What happens next depends a lot on what the kernel is willing to tell and hand to that user. On a default install, an unprivileged account can often read kernel symbol addresses, read the full kernel log, load eBPF programs, attach ptrace to sibling processes, and create user namespaces. Each of those is a common step in a local privilege escalation chain. None of them is needed by a typical web, database or monitoring host.

The fix is a small set of sysctls, shipped as a drop-in file, checked into the same repo as the rest of your host config. This post walks through the baseline I use, what each setting breaks, and how to verify it actually applied.

## The baseline

Put this in `/etc/sysctl.d/60-hardening.conf`. The numeric prefix matters: files are applied in lexical order and later values win, so make sure nothing with a higher number (some distro packages ship `99-*` files) overrides you.

```ini
# Hide kernel pointers from /proc and logs, even for root without CAP_SYSLOG
kernel.kptr_restrict = 2

# Only privileged users can read dmesg
kernel.dmesg_restrict = 1

# Disallow unprivileged eBPF; 2 = disabled and cannot be re-enabled at runtime
kernel.unprivileged_bpf_disabled = 1
net.core.bpf_jit_harden = 2

# ptrace only on direct descendants (1); use 2 for admin-only on hosts without debuggers
kernel.yama.ptrace_scope = 1

# No perf events for unprivileged users
kernel.perf_event_paranoid = 3

# Disable the magic SysRq key except sync/remount-ro/reboot (16+32+128)
kernel.sysrq = 176

# Protect against symlink/hardlink tricks in world-writable sticky dirs
fs.protected_symlinks = 1
fs.protected_hardlinks = 1
fs.protected_fifos = 2
fs.protected_regular = 2

# No core dumps from setuid binaries
fs.suid_dumpable = 0

# Network: ignore redirects and source routing, log martians
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.tcp_syncookies = 1
```

Load it without a reboot:

```bash
sudo sysctl --system
```

`--system` reads every directory in the standard search path, so it also shows you which file set which value. Read that output once; it is the fastest way to spot a later file overriding yours.

## What it breaks

This is the part that decides whether the baseline survives its first week.

- **`ptrace_scope = 1`** breaks attaching `gdb` or `strace -p` to an arbitrary process as a normal user. Root still can. On build or developer hosts you may want to leave this at 0; on production servers nobody should be attaching debuggers as a regular user anyway.
- **`unprivileged_bpf_disabled = 1`** has no effect on root-run tooling like bpftrace, Cilium or most observability agents, because they run privileged. It only stops ordinary users loading programs. Several recent distros already default to 2.
- **`perf_event_paranoid = 3`** is a Debian/Ubuntu-specific value (patched kernels). On upstream kernels, values above 2 behave like 2. Unprivileged `perf` stops working either way; profiling becomes a sudo task.
- **User namespaces** are deliberately not in the list. Disabling them (`user.max_user_namespaces = 0`) removes a large attack surface but breaks rootless Podman, Flatpak, some browsers' sandboxes and systemd features that use private namespaces. Decide per host role, not globally.
- **Redirect settings** are wrong on a host that is actually a router or a VPN gateway. Those get their own role file.

## Verifying it stuck

Writing the file is not the same as having the settings. Containers, a stray `99-` file from a package, or a module loaded later (the `net.ipv4.conf.*` keys for interfaces that appear after boot) can all leave you with a different runtime state. Check the running values, not the file:

```bash
#!/bin/sh
# check-sysctl.sh - exit non-zero if any runtime value differs from the baseline
rc=0
grep -Ev '^\s*(#|$)' /etc/sysctl.d/60-hardening.conf | while IFS='=' read -r key want; do
    key=$(echo "$key" | xargs); want=$(echo "$want" | xargs)
    have=$(sysctl -n "$key" 2>/dev/null) || { echo "MISSING $key"; continue; }
    [ "$have" = "$want" ] || echo "DRIFT $key want=$want have=$have"
done | tee /dev/stderr | grep -q . && rc=1
exit $rc
```

Run it from your config management in check mode or as a node-exporter textfile collector job, and alert on a non-zero result. Note that `kernel.yama.ptrace_scope` will report missing on kernels without Yama; that is a real finding, not a script bug.

For new interfaces, `net.ipv4.conf.default.*` covers anything created after the setting is applied, while `all` covers the global switch. Setting both is the habit that avoids surprises with VLAN or bridge interfaces created later.

## Why this matters

In most post-incident reviews I have been part of, the initial foothold was not the interesting part; the step from service account to root was, and it was usually a kernel or local bug that a hardened default would have made harder or noisier. These settings cost nothing at runtime, take an afternoon to roll out per host role, and remove information leaks that exploit authors rely on. The real work is not the file, it is the role split and the drift check that keeps it true six months later.
