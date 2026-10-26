---
title: "Catching interface flaps on Cisco IOS XE with EEM before users do"
tags: Cisco
---

A branch uplink that flaps three times in ten minutes rarely generates a ticket. The routing protocol reconverges, the SD-WAN overlay shifts traffic, and users notice a few frozen video calls. By the time someone opens a case, the syslog buffer has wrapped and the evidence is gone. The next week it happens again, and the cycle repeats until the link fails hard.

The problem is not detection. Every switch and router logs `%LINK-3-UPDOWN`. The problem is that a single flap is noise, a pattern is a signal, and most monitoring stacks only see individual events. Correlation happens centrally, late, and often not at all if syslog over UDP drops the messages during the very instability you want to observe.

Cisco's Embedded Event Manager (EEM) lets the device do the first layer of correlation itself. It has been on IOS and IOS XE for years, it needs no extra licence on most platforms, and it runs even when the path to your collector does not.

## Counting flaps on the box

EEM supports event correlation with occurrence counting over a time window. The applet below triggers only when an interface goes down three times within 600 seconds. When it fires, it captures the state you would otherwise ask for after the fact, writes it to flash, and raises a single high-severity syslog message that is easy to alert on.

```
event manager environment _flap_if GigabitEthernet0/0/0
!
event manager applet UPLINK-FLAP-GUARD authorization bypass
 event syslog pattern "Interface GigabitEthernet0/0/0, changed state to down" occurs 3 period 600 maxrun 120
 action 010 cli command "enable"
 action 020 cli command "show clock"
 action 025 set ts "$_cli_result"
 action 030 cli command "show interfaces $_flap_if | redirect flash:flap-intf.txt"
 action 040 cli command "show controllers $_flap_if | redirect flash:flap-ctrl.txt"
 action 050 cli command "show logging | redirect flash:flap-log.txt"
 action 060 cli command "show ip bgp summary | redirect flash:flap-bgp.txt"
 action 070 syslog priority critical msg "UPLINK-FLAP-GUARD: $_flap_if flapped 3x in 10min, diagnostics saved to flash:flap-*.txt"
```

A few practical notes from running variants of this in production:

- `occurs 3 period 600` is the important part. Without it, the applet fires on every flap and you have built a louder version of the problem you already had.
- `maxrun 120` stops a slow `show` command from hanging the applet. The default of 20 seconds is too short for `show logging` on a busy box.
- The `redirect` output overwrites on each run. That is deliberate: you want the most recent incident, and you do not want an unstable link filling flash. If you need history, append a timestamp via a Tcl policy instead of an applet.
- `show controllers` is where the evidence usually lives. CRC errors, input errors climbing, or SFP receive power drifting toward the low threshold point at physical layer causes that the carrier will otherwise deny.

If AAA command authorization is enforced through TACACS+, check how your platform treats `authorization bypass`. Some environments require a dedicated EEM user (`event manager session cli username`) so the commands are authorised and accounted for. Do not quietly disable authorization to make the script work.

## Verifying it

Test in a lab or a maintenance window by shutting and unshutting the interface three times:

```
conf t
 interface GigabitEthernet0/0/0
  shutdown
  no shutdown
end
show event manager history events
show event manager policy registered
dir flash: | include flap
```

`show event manager history events` confirms the applet ran and whether it completed or timed out. If it never triggers, the syslog pattern is almost always the reason: the exact message text differs between platforms and releases, and `logging buffered` must be enabled for the syslog detector to see it. Copy the string from `show logging` rather than from documentation.

## Where this fits

This does not replace streaming telemetry or a proper NMS. On IOS XE you can subscribe to interface state over gNMI or NETCONF and do the correlation centrally, which is the better long-term design for large estates. EEM is the pragmatic layer for the places where that is not yet true: branches with marginal links, devices behind a single WAN path, or fleets where the telemetry rollout is still on the roadmap.

It also scales cleanly through configuration management. The applet is plain config, so it goes into the same Ansible or Nornir template as the rest of the device baseline, with the interface name set per site through the environment variable.

## Why this matters

Most painful outages I have dealt with were preceded by days of small, ignored warnings. An uplink that flaps intermittently is the classic case: the carrier sees nothing at the moment you call, the logs have rotated, and the conversation becomes opinion against opinion. Having the device recognise the pattern and save its own controller counters at the moment of failure changes that conversation. You open the carrier ticket with evidence, the escalation is shorter, and the link is fixed before it takes a site down during business hours.
