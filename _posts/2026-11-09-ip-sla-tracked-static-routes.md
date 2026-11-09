---
title: "Failing over a static default route when the ISP breaks upstream"
tags: Cisco
---

A branch router has two uplinks: a fibre circuit as the primary and an LTE or cheap DSL line as the backup. The setup is two static default routes, with the backup given a higher administrative distance. That works until the fibre provider has an outage somewhere past the handoff. Your interface stays up/up and the next hop on the provider CPE still answers ARP, so the primary route stays in the table. Meanwhile, nothing gets past the provider's aggregation router. The backup route never installs, and you find out from a user ticket.

A static route only depends on the state of the interface and whether the next hop resolves. It knows nothing about reachability beyond that. To fail over on a real upstream failure, the route has to depend on a test that crosses the provider network. On IOS and IOS XE you do this with IP SLA and object tracking.

## The pieces

There are three parts:

1. An IP SLA operation that regularly probes something beyond the provider edge.
2. A track object that turns the probe result into up or down.
3. A static route that is tied to that track object, so it is removed when the track goes down.

Pick the probe target carefully. If you probe the provider's next hop, you are back to testing the handoff. A stable address a few hops in works better, ideally two different ones, so that one anycast resolver having a bad day doesn't send the whole branch to LTE.

## Configuration

```text
! Probe 1: ICMP to a public resolver, forced out the primary uplink
ip sla 10
 icmp-echo 9.9.9.9 source-interface GigabitEthernet0/0/0
 frequency 10
 timeout 2000
 threshold 2000
ip sla schedule 10 life forever start-time now

! Probe 2: a second, independent target
ip sla 11
 icmp-echo 1.1.1.1 source-interface GigabitEthernet0/0/0
 frequency 10
 timeout 2000
 threshold 2000
ip sla schedule 11 life forever start-time now

! Track each probe, with dampening so one lost packet does not flap the route
track 10 ip sla 10 reachability
 delay down 30 up 60
track 11 ip sla 11 reachability
 delay down 30 up 60

! Primary path is "up" if either target answers
track 20 list boolean or
 object 10
 object 11

! Primary default route depends on track 20
ip route 0.0.0.0 0.0.0.0 GigabitEthernet0/0/0 203.0.113.1 track 20 name PRIMARY-FIBRE
! Floating backup
ip route 0.0.0.0 0.0.0.0 Cellular0/1/0 250 name BACKUP-LTE

! Keep the probes pinned to the primary even when the default moves
ip route 9.9.9.9 255.255.255.255 GigabitEthernet0/0/0 203.0.113.1
ip route 1.1.1.1 255.255.255.255 GigabitEthernet0/0/0 203.0.113.1
```

The last two host routes are the part most people leave out. Without them, the default route moves to LTE as soon as the primary is withdrawn. The probes then follow it, succeed over LTE, and bring the track back up. The primary route goes back in, the probes fail again, and the router flaps between the two paths every minute. `source-interface` alone does not stop this on every platform and release, because the forwarding decision still comes from the routing table. Pinning the probe targets to the primary next hop makes the test measure only the primary path. The trade-off is that you lose general reachability to those two addresses over the backup, so pick probe targets your users don't rely on, or use addresses you own.

The `delay down 30 up 60` timers are deliberately asymmetric. You want to fail away fairly quickly, but come back only after the primary has been stable for a full minute. A circuit that is bouncing during a provider maintenance window is worse than just staying on LTE for a while.

## Verifying it

Check it before the outage, not during:

```text
show ip sla statistics 10
show track brief
show ip route static
debug track
```

To test failover without calling the provider, temporarily add an ACL inbound on the primary interface that drops ICMP echo replies from the two probe targets. Track 10 and 11 should go down, then track 20 after the 30 second delay. The PRIMARY-FIBRE route should disappear from `show ip route` and the LTE route should install. Remove the ACL and confirm the primary comes back about 60 seconds later. Run the same test with only one target blocked to prove the boolean OR keeps you on fibre.

Add logging for track state changes so they reach your syslog or alerting pipeline:

```text
track 20 list boolean or
 object 10
 object 11
!
event manager applet TRACK20-DOWN
 event track 20 state down
 action 1.0 syslog priority errors msg "Primary uplink failed reachability, default route moved to LTE"
```

## Things that bite

- NAT: if the branch uses PAT with `ip nat inside source route-map` per uplink, existing translations survive the failover and keep pointing at the dead path. Clear them on the track event, or keep timeouts short for the traffic that matters.
- Return traffic for anything hosted at the branch arrives on whichever public IP DNS points to. Failing over outbound traffic does not move inbound services.
- VRFs: if the uplink is in a front-door VRF, the probes need `vrf` configured under the IP SLA, and the pinned host routes go into that VRF.
- LTE data caps: a probe running every 10 seconds over the backup is cheap, but it isn't free. Keep probes on the primary only.

## Why this matters

Most branch outages I've dealt with were not a dead interface. They were a provider fault one or two hops in, where the link light stayed green. Floating static routes give you redundancy on paper, but failover only happens if the router can see the failure. Adding IP SLA and tracking takes about twenty lines of config. That turns "we have a backup line" from a line item in the contract into something that actually carries traffic at 3 a.m. Before you call the site redundant, test it with the ACL trick.
