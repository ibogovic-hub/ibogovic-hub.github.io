---
title: "Sub-second OSPF failover with BFD on IOS-XE"
tags: Cisco
---

A distribution switch loses its uplink to the core, but the link doesn't go down. The fiber is intact and the optic still shows light. What broke is the transport in between: a media converter, a carrier Ethernet circuit, or a DWDM transponder that keeps signalling line-up while forwarding nothing. OSPF is running on default timers, so the neighbor stays in FULL until the 40-second dead interval runs out. For those 40 seconds, traffic hashed onto that path gets dropped. VoIP calls fail, storage replication stalls, and the monitoring system raises an alert about an interface that looks perfectly healthy.

Most teams first try to fix this by lowering the OSPF hello and dead timers. That helps, but it scales badly. Every hello is handled by the routing process on the control plane. Aggressive timers across dozens of adjacencies add CPU load, and a busy route processor can then miss hellos and flap adjacencies that were fine. Bidirectional Forwarding Detection (BFD) is the right tool here. It is a lightweight liveness protocol, usually offloaded or handled in a fast path, and it tells OSPF when the forwarding path has died.

## How it fits together

BFD does not discover neighbors on its own. OSPF forms the adjacency and registers the neighbor with BFD. BFD then exchanges small control packets at the interval you configure. When a set number of packets in a row go missing, BFD declares the session down and notifies OSPF, which tears down the adjacency straight away instead of waiting for the dead timer. OSPF keeps its default timers, which stay slow and safe, while failure detection moves to something built for it.

The detection time is the negotiated interval multiplied by the multiplier. With 300 ms and a multiplier of 3, a dead path is detected in about 900 ms. How low you can safely go depends on the platform. Check the platform's BFD scale and supported-interval documentation before copying numbers from a blog post, this one included.

## Configuration

This is a minimal, working IOS-XE configuration for a routed point-to-point uplink:

```
interface TenGigabitEthernet1/0/48
 description UPLINK-CORE-A
 no switchport
 ip address 10.255.0.1 255.255.255.252
 ip ospf network point-to-point
 ip ospf 1 area 0
 bfd interval 300 min_rx 300 multiplier 3
 no bfd echo
!
router ospf 1
 router-id 10.0.0.11
 passive-interface default
 no passive-interface TenGigabitEthernet1/0/48
 bfd all-interfaces
```

A few of these choices are deliberate:

- `ip ospf network point-to-point` removes the DR/BDR election on a /30. It speeds up adjacency formation and makes the logs easier to read.
- `no bfd echo` turns off echo mode. Echo mode sends packets that the neighbor loops back through its forwarding plane, which is efficient. It also needs `no ip redirects` and uRPF behaviour that doesn't get in the way, and it doesn't work well through some firewalls and carrier gear. Asynchronous mode is the safer default on mixed estates.
- `bfd all-interfaces` under the OSPF process is convenient. If you only want BFD on selected links, use `ip ospf bfd` on each interface instead and leave the process-level command out.

Configure the other end the same way. BFD negotiates to the slower of the two sides, so a mismatch won't break the session, but it will quietly slow down detection.

## Verification

```
show bfd neighbors details
show ip ospf neighbor detail | include BFD|Neighbor
show ip ospf interface TenGigabitEthernet1/0/48 | include BFD
```

In the BFD output, check that the session state is `Up`, that the registered protocol is `OSPF`, and that the negotiated TX/RX intervals match what you intended. A session that's up but registered to no client does nothing useful.

To test it, don't shut the interface. That triggers a link-down event, which OSPF reacts to anyway, so it proves nothing about BFD. Reproduce the real failure instead: put an ACL on the far end that drops UDP 3784, or drop traffic on an intermediate device while the link stays up. You should see `%BFD-6-BFD_SESS_DESTROYED` followed by the OSPF adjacency going down in under a second, and the routing table converging onto the alternate path.

## Operational caveats

BFD makes failure detection sensitive, and a sensitive detector will also react to short congestion events. If an uplink regularly runs near line rate and control-plane policing is tight, BFD packets can be dropped and the adjacency will flap when nothing has actually failed. Make sure CoPP allows BFD traffic (UDP 3784/3785), and think about pairing BFD with OSPF dampening, or at least alerting on BFD state changes, so that flapping is visible.

Take care during ISSU and supervisor switchovers as well. Some platforms keep BFD sessions up through a stateful switchover and others don't. Check the behaviour on your hardware before you depend on it in a maintenance window.

## Why this matters

Physical links that stay up while forwarding nothing are one of the most common causes of long, confusing outages in campus and WAN networks. The interface is green, the neighbor is FULL, and users are complaining. I've spent time on bridges while someone looked for a fault in a device that was reporting itself healthy, and the fix was a timer the network had been waiting on all along. BFD turns that 40-second grey failure into a sub-second reroute that nobody notices. It needs about three lines of configuration per link, and it is among the cheapest resilience improvements you can make on a routed network.
