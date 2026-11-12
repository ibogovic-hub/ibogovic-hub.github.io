---
title: "Chrony time sync you can actually verify"
tags: Linux
---

A Kerberos login fails on one jump host and nowhere else. TLS handshakes to an internal API start failing with "certificate not yet valid" for a single node. Log correlation across a firewall cluster puts the cause after the effect. Every one of these has ended, in my experience, with somebody running `date` on two machines and seeing they disagree by minutes. Time sync is one of those services everyone assumes works because it was installed during provisioning. Nobody checks it again until something breaks.

Chrony is the default on most current distributions, and its defaults are reasonable. The problems come from how it gets deployed: one public pool line copied from a template, no local servers, no rule for large offsets after a VM resume, and no monitoring at all. Here is a configuration and a check I would put on any fleet.

## Configure sources deliberately

Use at least three internal sources so chrony can outvote a single bad one. With two sources that disagree, it has no way to tell which one is wrong. Mark them `iburst` so the first sync after boot takes seconds instead of minutes.

```ini
# /etc/chrony/conf.d/10-fleet.conf  (Debian/Ubuntu path; RHEL uses /etc/chrony.conf or sourcedir)
server ntp1.example.internal iburst
server ntp2.example.internal iburst
server ntp3.example.internal iburst

# Require agreement from at least two sources before adjusting the clock
minsources 2

# Step the clock if off by more than 1s, but only during the first 3 updates.
# After that, slew only, so running applications never see time jump.
makestep 1.0 3

# Keep the hardware clock roughly right for the next cold boot
rtcsync

# Refuse to follow a source that claims a wildly different time
maxdistance 1.0

# Log measurements for later investigation
logdir /var/log/chrony
log tracking measurements statistics
```

`makestep` is the setting people get wrong most often. If you remove the step limit, a VM restored from a snapshot taken two days ago will slew at most around 500 ppm, so it will need weeks to catch up. If you allow unlimited stepping (`makestep 1 -1`), a database or a monotonic-sensitive app can see time jump backwards in the middle of a transaction. Stepping during the first few updates and slewing after that covers boot and resume without surprising running workloads. For VMs that resume often, look at your hypervisor's guest time integration too (PTP clock device on KVM, VMware Tools time settings). Two mechanisms both fighting over the clock is a classic cause of drift that comes and goes.

## Know what "synchronised" means

`timedatectl` printing `System clock synchronized: yes` tells you very little. `chronyc tracking` tells you what you actually need to know:

```bash
chronyc tracking
chronyc sources -v
chronyc sourcestats
```

In `tracking`, look at `Leap status` (it should be `Normal`, and `Not synchronised` is your alarm), `System time` (the current offset), and `Stratum`. In `sources`, the `*` marks the selected source, `+` means combined, and `x` or `?` means chrony considers a source false or unreachable. When a host shows one `*` and two `?`, it is running on a single source and you have lost your redundancy without being told.

## A check that fails loudly

This is a small script that works as a Nagios-style check, a node_exporter textfile collector, or a systemd timer that alerts on failure. It uses the machine-readable CSV output (`-c`), so it does not break when the human-readable format changes.

```bash
#!/usr/bin/env bash
# check_chrony.sh - exit 0 OK, 1 WARN, 2 CRIT
set -euo pipefail

WARN_OFFSET=0.050   # seconds
CRIT_OFFSET=0.500
MIN_GOOD_SOURCES=2

tracking=$(chronyc -c tracking) || { echo "CRIT: chronyd not responding"; exit 2; }

# Field 5 = system time offset (s), field 3 = stratum, field 14 = leap status
offset=$(echo "$tracking" | cut -d, -f5 | tr -d '-')
stratum=$(echo "$tracking" | cut -d, -f3)
leap=$(echo "$tracking" | cut -d, -f14)

# Selected (*) or combined (+) sources count as healthy
good=$(chronyc -c sources | awk -F, '$2=="*" || $2=="+"' | wc -l)

if [[ "$leap" == "Not synchronised" ]]; then
  echo "CRIT: not synchronised (stratum $stratum)"; exit 2
fi
if awk "BEGIN{exit !($offset > $CRIT_OFFSET)}"; then
  echo "CRIT: offset ${offset}s"; exit 2
fi
if (( good < MIN_GOOD_SOURCES )); then
  echo "WARN: only $good usable sources"; exit 1
fi
if awk "BEGIN{exit !($offset > $WARN_OFFSET)}"; then
  echo "WARN: offset ${offset}s"; exit 1
fi
echo "OK: offset ${offset}s, stratum $stratum, $good sources"
```

Check the field positions against `chronyc -c tracking` on your version before you rely on them. The CSV layout has been stable for a long time, but it takes one command to confirm. The source-count check catches more real incidents than the offset check does. Offsets usually look fine right up until the last remaining source goes away.

## Don't forget the servers

Your internal NTP servers need the same discipline: several upstream sources, preferably from different operators or a local GNSS reference, plus an `allow` line that covers only your management networks. Monitor them with the same script. Put them in different failure domains too. Three NTP VMs on one hypervisor cluster count as one source the day that cluster has a bad afternoon.

## Why this matters

Clock skew rarely shows up as a time problem. It shows up as authentication failures, expired-looking certificates, a TOTP code that "doesn't work", or an incident timeline that makes no sense because the logs disagree. I have watched teams spend hours on Kerberos and PKI before anyone checked the clock. Fifteen minutes spent on a sane chrony config and a check that counts sources removes a whole category of confusing failures, and when time does go wrong, the alert names the actual cause instead of a symptom.
