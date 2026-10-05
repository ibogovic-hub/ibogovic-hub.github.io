---
title: "Catching interface flaps with EEM before users open tickets"
tags: Cisco
---

A distribution switch uplink starts flapping at 03:00. Spanning tree reconverges every few seconds, ARP tables churn, and by the time the first user calls the service desk at 08:00 the syslog server holds thousands of `%LINK-3-UPDOWN` lines and nobody can say when it began. The link itself is usually a dirty optic or a bad patch cable. The real problem is that nothing on the box reacted.

Cisco IOS and IOS-XE ship with the Embedded Event Manager (EEM), which can watch for syslog patterns, count them over a time window, and run CLI actions on the device itself. That makes it a good fit for a local flap guard: detect repeated up/down transitions, capture state while the fault is still happening, and optionally take the port out of service so the rest of the topology settles.

## The approach

EEM has a syslog event detector that supports `occurs` and `period` arguments. That lets you say "fire only if this pattern matches N times within T seconds", which filters out a single planned bounce during maintenance. When it fires, the applet can:

1. Capture `show interface`, transceiver diagnostics, and recent logs to flash.
2. Shut the interface (only where you have redundancy).
3. Send a distinctive syslog message your monitoring stack alerts on.

The applet below targets one uplink. Matching a specific interface name keeps the blast radius predictable; a generic regex across all ports is tempting but will happily shut down an access port a user is testing.

```
event manager environment _flap_if TenGigabitEthernet1/1/1
!
event manager applet UPLINK-FLAP-GUARD authorization bypass
 event syslog pattern "%LINK-3-UPDOWN: Interface TenGigabitEthernet1/1/1, changed state to down" occurs 5 period 120
 action 010 cli command "enable"
 action 020 cli command "show clock"
 action 030 set ts "$_cli_result"
 action 040 cli command "show interface $_flap_if | append flash:flap-evidence.txt"
 action 050 cli command "show interface $_flap_if transceiver detail | append flash:flap-evidence.txt"
 action 060 cli command "show logging | include $_flap_if | append flash:flap-evidence.txt"
 action 070 cli command "configure terminal"
 action 080 cli command "interface $_flap_if"
 action 090 cli command "shutdown"
 action 100 cli command "description FLAP-GUARD shut by EEM - check optic/cabling"
 action 110 cli command "end"
 action 120 syslog priority critical msg "FLAP-GUARD: $_flap_if shut after 5 downs in 120s"
```

A few details that matter in practice:

- `occurs 5 period 120` counts five matching messages within 120 seconds. Tune it against your logging history; a link with LACP fast timers may log differently from a plain routed uplink.
- `authorization bypass` is needed if you run TACACS+ command authorization, otherwise the applet's CLI actions are rejected because EEM has no user context. If your security policy forbids bypass, configure `event manager session cli username <user>` with a dedicated, tightly scoped AAA account instead.
- `| append flash:` writes evidence locally. On platforms where flash fills up, rotate or point it at a dedicated directory and clean it up in your change process.
- The description change is deliberate. The next engineer running `show interface status` sees why the port is down without digging through logs.

## Verify before trusting it

Do not rely on the applet firing correctly the first time it matters. In a lab (EVE-NG with IOL or a CSR/Cat8000v works fine), bounce the interface repeatedly and confirm the result:

```
show event manager policy registered
show event manager history events
dir flash: | include flap
more flash:flap-evidence.txt
```

`show event manager history events` tells you whether the detector triggered and whether the actions completed. If the policy is registered but never fires, the pattern string is almost always the culprit: check the exact message text on that platform and software version, including capitalization and whether the interface name is abbreviated.

## When not to auto-shut

Shutting a port is only safe where traffic has somewhere else to go: a port-channel member, one of two routed uplinks with ECMP, or a link protected by a backup path. On a single-homed access switch, an auto-shut converts a degraded link into a full outage. In those cases keep actions 010 to 060 and 120 and drop the shutdown. You still get the evidence and the alert, and a human decides.

Also consider that features already exist for part of this. `errdisable detect cause link-flap` with `errdisable recovery` handles the shutdown on many Catalyst platforms. EEM is useful when you want the evidence capture, a custom threshold, a specific description, or behaviour on platforms and interface types where errdisable link-flap is not available.

## Deploying at scale

Hand-configuring applets per box drifts quickly. Template the applet in Ansible or your config generator with the interface name as a variable, and audit `show running-config | section event manager` as part of compliance checks. Treat applets as code: version them, review them, and test them in the lab against the same software train as production.

## Why this matters

Most flap incidents I have worked were not hard to fix; they were hard to reconstruct. By the time someone logs in, the optic has been reseated, counters were cleared, and the transceiver light levels at failure time are gone. A small EEM applet captures that state at the moment it exists, alerts with a message that is unambiguous, and, where the design allows it, stops one bad cable from destabilising a whole distribution block. It costs a dozen lines of config and an afternoon in the lab, and it turns a 08:00 escalation into a ticket with evidence already attached.
