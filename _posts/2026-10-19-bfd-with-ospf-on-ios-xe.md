---
title: "Fast failure detection with BFD and OSPF on IOS XE"
tags: Cisco
---

A WAN circuit goes grey. The carrier's CPE keeps the Ethernet handoff up, so your router never sees link down. OSPF keeps believing the neighbor is alive until the dead timer expires, which is 40 seconds by default on broadcast and point-to-point networks. For those 40 seconds, traffic is blackholed into a path that no longer forwards anything. Voice drops, TCP sessions stall, and the monitoring alert arrives after users have already called the service desk.

This is the classic case for Bidirectional Forwarding Detection (BFD). It's not new, but I still find it missing on a surprising number of production edges, usually because someone tried aggressive OSPF hello timers years ago, saw CPU spikes or flaps, and backed out.

## Why not just tune OSPF timers

You can set `ip ospf dead-interval minimal hello-multiplier 4` and get sub-second detection. The problem is that OSPF hellos are processed by the control plane. Under load (a big SPF run, a BGP churn event, an SNMP poller hammering the box), hello processing can get delayed, and you end up with adjacency flaps caused by the detection mechanism itself. Every flap triggers LSA flooding and SPF across the area, so one aggressive timer on one edge router can create work for every router in the area.

BFD separates liveness detection from the routing protocol. It's a lightweight protocol with one job: prove the forwarding path between two neighbors works. On many platforms it runs in hardware or in a dedicated process. When it detects failure, it tells the registered client protocols (OSPF, BGP, EIGRP, static routes), and they tear down immediately. The routing protocol hello timers can stay at their conservative defaults.

## Basic configuration

On IOS XE, BFD timers are set per interface, and the routing protocol registers as a client. A minimal setup for a point-to-point WAN link:

```cisco
interface GigabitEthernet0/0/1
 description WAN-to-DC2
 ip address 10.255.0.1 255.255.255.252
 ip ospf network point-to-point
 bfd interval 300 min_rx 300 multiplier 3
 no bfd echo
!
router ospf 10
 router-id 10.0.0.1
 bfd all-interfaces
 passive-interface default
 no passive-interface GigabitEthernet0/0/1
```

With 300 ms intervals and a multiplier of 3, detection time is about 900 ms. Instead of enabling `bfd all-interfaces`, you can opt in per interface with `ip ospf bfd`, and opt out with `ip ospf bfd disable`. I prefer the per-interface form on routers where only some links justify it.

I disable echo mode here because echo packets are looped back by the peer's forwarding plane. That works well on directly connected links, but it adds failure modes when there's a provider device in the middle that drops or rate-limits packets with the router's own address as destination. Asynchronous mode alone is predictable and easier to troubleshoot.

## Verification

```cisco
show bfd neighbors details
show ip ospf interface GigabitEthernet0/0/1 | include BFD
show ip ospf neighbor detail | include BFD
```

In `show bfd neighbors details`, check that the session is `Up`, that the registered protocol is listed as `OSPF`, and that the negotiated intervals match what you expect. BFD negotiates down to the slower of the two peers' values, so a mismatched configuration on the far end silently gives you longer detection times than you designed for.

## Things that bite in production

**Timer choice is about the platform, not ambition.** Check whether your platform offloads BFD to hardware. If it runs on the route processor, 50 ms timers on dozens of sessions are asking for false positives during control-plane load. 300 ms x 3 is a reasonable starting point for WAN edges. Go lower only after checking the platform documentation and testing under load.

**Dampening.** A flapping circuit with BFD flaps fast, and every flap triggers SPF. Configure `bfd dampening` (available on recent IOS XE releases), or at least make sure your SPF and LSA throttle timers are sane:

```cisco
router ospf 10
 timers throttle spf 50 200 5000
 timers throttle lsa 50 200 5000
```

**Control plane policing.** If you run CoPP, make sure BFD (UDP 3784 for single-hop, 4784 for multihop, 3785 for echo) is classified into a protected class. I have seen a templated CoPP policy drop BFD under load and cause exactly the outage BFD was meant to shorten.

**Both ends.** BFD needs both peers configured. On a managed circuit where the other side is a provider router, coordinate before enabling it, or OSPF will happily run without it and you'll think you're protected.

**Static routes.** If you have floating statics toward a provider next hop, `ip route static bfd` lets static routes use the same mechanism. That's often a bigger win than OSPF on small branch sites.

## Why this matters

Most WAN outages I've dealt with weren't clean link-down events. They were grey failures: a carrier problem behind a CPE that kept the port lit, a congested provider core, a half-dead optic. Routing protocols with default timers handle these badly, and over-tuning them moves the instability into the control plane. BFD is the cleanest answer: conservative routing timers, fast and dedicated liveness detection, and failover measured in about a second instead of most of a minute. The configuration is a handful of lines. The real work is choosing timers your hardware can sustain, protecting the packets in CoPP, and checking that both ends actually negotiated what you intended.
