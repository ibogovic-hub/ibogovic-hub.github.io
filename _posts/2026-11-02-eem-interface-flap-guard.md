---
title: "Catching flapping uplinks with EEM before users do"
tags: Cisco
---

A branch uplink starts flapping at 02:40. Each bounce lasts a few seconds. That is too short to trip the monitoring poll interval and long enough to drop every VoIP call and tear down the IPsec tunnel. By morning the only evidence is a ticket saying "the phones were weird overnight" and a log buffer that has already wrapped. I have lost more hours to this pattern than to any hard outage. A hard-down link is easy to diagnose. A link that keeps coming back is not.

The fix does not need a new tool. Cisco IOS and IOS-XE have shipped the Embedded Event Manager (EEM) for years, and it is the right place to catch this. EEM runs on the box, sees every syslog event as it happens and can act within a second. Your poller only sees whatever state the interface is in when it next asks.

## What we want the device to do

1. Count line-protocol down events on a specific uplink.
2. If it goes down more than N times in a window, treat it as flapping, not as a single outage.
3. Capture evidence while the problem is happening: interface counters, controller errors, the optic's DOM readings and the last log lines.
4. Write that evidence to local flash and send one clearly tagged syslog message that the SIEM or alerting pipeline can match.

We do not want EEM to shut the interface automatically. On a single-homed branch that turns a degraded link into a dead one. Collect the evidence and alert. Leave the decision to a person or a higher-level system that knows the topology.

## The applet

```cisco
event manager environment _flap_if GigabitEthernet0/0/0
!
event manager applet UPLINK-FLAP-GUARD authorization bypass
 event tag down syslog pattern "%LINEPROTO-5-UPDOWN: Line protocol on Interface GigabitEthernet0/0/0, changed state to down" occurs 3 period 300
 trigger
  correlate event down
 action 0.10 cli command "enable"
 action 0.20 cli command "term length 0"
 action 0.30 cli command "show clock"
 action 0.31 regexp "([0-9:]+)" "$_cli_result" ts
 action 0.40 cli command "show interface $_flap_if | redirect flash:flap-intf.txt"
 action 0.50 cli command "show controllers $_flap_if | append flash:flap-intf.txt"
 action 0.60 cli command "show interfaces $_flap_if transceiver detail | append flash:flap-intf.txt"
 action 0.70 cli command "show logging | include $_flap_if | append flash:flap-intf.txt"
 action 0.80 syslog priority errors msg "UPLINK_FLAP: $_flap_if down 3x in 300s, evidence in flash:flap-intf.txt"
 action 0.90 cli command "clear counters $_flap_if" pattern "confirm"
 action 1.00 cli command "y"
```

A few notes from running variants of this in production:

- **`occurs 3 period 300`** does the important work. One down event is noise. Three in five minutes is a pattern worth looking at. Tune these numbers per site: a satellite or LTE backup link needs a looser threshold than a metro fibre handoff.
- **`authorization bypass`** stops the applet from failing silently when AAA command authorization is enabled and the TACACS server is unreachable, which can happen while the uplink is flapping. Check this against your own AAA policy first. Some security teams will want a dedicated local EEM user instead.
- **`redirect` then `append`** keeps one evidence file per incident and overwrites the previous one. If you need history, build the filename from the timestamp. Watch flash space on small ISRs, though.
- **Clearing counters at the end** means the next capture shows deltas, not counters that have been building since the last reload. Remove it if your NMS depends on monotonic counters. Some pollers handle a reset badly.

## Verifying it without waiting for a real flap

Do not deploy an applet you have never seen fire. In a lab, or during a maintenance window on a redundant link, bounce the interface:

```cisco
conf t
 interface GigabitEthernet0/0/0
  shutdown
  no shutdown
  shutdown
  no shutdown
  shutdown
  no shutdown
end
show event manager history events
more flash:flap-intf.txt
```

`show event manager history events` should list the applet with a timestamp. If it does not, the usual cause is the syslog pattern. Platforms and releases differ slightly in message format, for example the exact interface name string or a subinterface suffix. Copy the pattern from the device's own `show logging` output. Never type it from memory.

## Where it fits

EEM is not a monitoring system and should not try to be one. It is a local first responder: it captures state that would otherwise be gone by the time anyone logs in. The syslog line it emits is the integration point. Match `UPLINK_FLAP:` in the SIEM or log pipeline, open a ticket with the device name attached, and the on-call engineer starts with optic power levels and CRC counters, not a blank screen. Push the applet out with the same config management you already use, whether that is Ansible, Nornir or a template in your controller, so it is versioned like any other config.

## Why this matters

The most expensive network incidents I have dealt with were the intermittent ones. A dead link gets fixed within the hour. A flapping one can drag on for a week because nobody can reproduce it, the carrier says their side is clean and the evidence keeps expiring. Capturing a degrading optic or a rising error counter while it happens, on the device, often turns "we cannot see anything" into a concrete fault you can hand to the carrier. A dozen lines of EEM and one tested syslog pattern are enough to get there.
