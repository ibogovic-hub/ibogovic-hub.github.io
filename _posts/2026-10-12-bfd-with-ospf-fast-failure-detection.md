---
title: "BFD with OSPF: stop waiting 40 seconds for a dead neighbor"
tags: Cisco
---

A WAN circuit between two sites goes dark, but the physical interface on your router stays up because there is a carrier device or a provider switch in the path. OSPF keeps the adjacency alive until the dead timer expires. With default timers on a broadcast or point-to-point link, that is 40 seconds of traffic being forwarded into a black hole. Voice calls drop, TCP sessions stall, and the monitoring alert arrives after users have already opened tickets.

The usual first reaction is to tune OSPF hello and dead timers down aggressively. That works up to a point, but it puts the burden on the routing process itself. Hellos are processed by the control plane, and sub-second hellos across many adjacencies add CPU load and make the adjacency sensitive to any control-plane hiccup. Bidirectional Forwarding Detection (BFD) is the better tool: a lightweight protocol designed only to detect forwarding-path failure, which then notifies OSPF (or BGP, EIGRP, static routes) so the routing protocol can react immediately.

## How BFD fits in

BFD runs a session between two directly connected neighbors and exchanges small control packets at a negotiated interval. If a configured number of consecutive packets are missed, the session is declared down and every client protocol registered to that session is informed. OSPF then tears down the adjacency and reconverges without waiting for its own dead timer.

On many Cisco platforms, BFD can be offloaded to hardware or handled in a distributed way on line cards, which is why it can run at intervals that would be unwise for OSPF hellos. Check your specific platform's documentation for supported minimum intervals; virtual platforms and small branch routers typically need more conservative values than hardware-forwarding chassis.

## Configuration on IOS XE

The configuration is two parts: BFD parameters on the interface, and telling OSPF to use BFD.

```
interface GigabitEthernet0/0/1
 description WAN-to-SiteB
 ip address 10.10.12.1 255.255.255.252
 ip ospf network point-to-point
 bfd interval 300 min_rx 300 multiplier 3
!
router ospf 10
 router-id 10.255.0.1
 bfd all-interfaces
 passive-interface default
 no passive-interface GigabitEthernet0/0/1
```

With `interval 300 min_rx 300 multiplier 3`, failure is detected after roughly 900 ms. If you do not want BFD everywhere, skip `bfd all-interfaces` and enable it per interface instead:

```
interface GigabitEthernet0/0/1
 ip ospf bfd
```

Conversely, with `bfd all-interfaces` set, you can exclude a specific interface with `ip ospf bfd disable`.

The peer needs a matching configuration. BFD negotiates the actual interval as the slower of what each side offers, so a mismatch does not break the session, but it does mean your effective detection time is governed by the more conservative end.

## Verification

```
show bfd neighbors details
show ip ospf interface GigabitEthernet0/0/1 | include BFD
show ip ospf neighbor
```

In `show bfd neighbors details`, confirm the session state is Up, the registered protocol list includes OSPF, and the negotiated transmit and receive intervals are what you expect. If OSPF is not listed as a client, the session exists but will not trigger reconvergence, which is a common half-finished deployment.

To test, do not just shut the interface: that triggers link-down and OSPF reacts anyway, so you learn nothing about BFD. Instead, apply an ACL on the far end that drops UDP 3784 (BFD single-hop control) or block the path in an intermediate device. In a lab such as EVE-NG, put a switch between the routers and shut the switchport facing one side, so the router interface stays up. Watch `debug bfd event` and the OSPF adjacency log messages to confirm the adjacency drops in under a second.

## Things that bite in production

- **Echo mode and uRPF.** BFD echo mode is on by default on many IOS XE interfaces. Echo packets are sent to the neighbor with the local address as destination and looped back. Strict uRPF or certain ACLs can drop them. If sessions flap for no obvious reason, try `no bfd echo` on the interface to rule it out.
- **Too aggressive on shared or virtual links.** Running 50 ms intervals over an internet-based tunnel or on a virtual router with a busy hypervisor causes flapping, and a flapping adjacency is worse than slow detection. Start at 300 ms x 3 and tighten only where you have measured headroom.
- **Dampening.** Configure `bfd dampening` where supported, or OSPF will reconverge every time a marginal circuit drops a few packets.
- **Tunnels and multihop.** Single-hop BFD assumes direct adjacency. For GRE over the internet or eBGP multihop, use the platform's multihop BFD templates and expect to accept slower intervals.
- **CoPP.** If you run control-plane policing, make sure BFD traffic is classified and not rate-limited into false failures.

## Why this matters

In practice, most painful WAN outages I have seen were not total failures but silent ones: the provider handoff stayed up while the circuit behind it died, or a carrier Ethernet service dropped traffic in one direction. Routing protocols with default timers cannot see that quickly, and pushing their timers down trades one problem for another. BFD separates failure detection from routing, which is the right design. It costs a few lines of configuration per link, a test with a blocked path rather than a shut interface, and some discipline about intervals. The payoff is that failover happens before users notice, and your redundant links actually deliver the redundancy you paid for.
