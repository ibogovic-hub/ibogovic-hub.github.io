---
title: "Protecting the router CPU with control plane policing on IOS XE"
tags: Cisco
---

A distribution switch stops answering SSH, OSPF neighbors start flapping, and the interface counters look normal. The data plane is forwarding fine, but the route processor is at 99 percent. Someone's misconfigured monitoring host is hammering SNMP, or a broadcast storm is pushing ARP to the CPU, or a scanner found the management address. Whatever the source, all traffic punted to the CPU shares one queue, and routing protocols lose to noise.

Control plane policing (CoPP) fixes this by classifying punted traffic and rate-limiting each class separately. Your BGP and OSPF keep their share of the CPU, and SNMP floods get dropped before they reach the processes that matter.

## What the platform already does

On Catalyst 9000 switches, IOS XE ships with a system-defined policy called `system-cpp-policy` attached to the control plane. It has sensible defaults per punt queue, and you tune it rather than replace it. On ISR and ASR routers there is no such default for most traffic, so you build your own policy with MQC. The example below is for a router; the classification logic carries over to the switches.

Check what is currently applied before changing anything:

```text
show policy-map control-plane
show platform hardware qfp active feature qos interface CPP
show platform software infrastructure punt
```

The last command shows what is actually being punted and why. Look at it on a normal day so you know what "normal" means.

## Build the classes

Start with ACLs that describe traffic you expect. Be specific about sources; a class that matches "any OSPF" also matches spoofed OSPF.

```text
ip access-list extended COPP-ROUTING
 permit tcp 10.0.0.0 0.0.255.255 any eq bgp
 permit tcp 10.0.0.0 0.0.255.255 eq bgp any
 permit ospf 10.0.0.0 0.0.255.255 any
 permit udp any any eq 3784
!
ip access-list extended COPP-MGMT
 permit tcp 10.50.0.0 0.0.0.255 any eq 22
 permit udp 10.50.0.0 0.0.0.255 any eq snmp
 permit udp any eq ntp any eq ntp
 permit tcp 10.50.0.0 0.0.0.255 any eq 830
!
ip access-list extended COPP-ICMP
 permit icmp any any echo
 permit icmp any any echo-reply
 permit icmp any any ttl-exceeded
 permit icmp any any unreachable
!
class-map match-all CM-COPP-ROUTING
 match access-group name COPP-ROUTING
class-map match-all CM-COPP-MGMT
 match access-group name COPP-MGMT
class-map match-all CM-COPP-ICMP
 match access-group name COPP-ICMP
```

Port 3784 is single-hop BFD control. If you run BFD and forget it here, you will find out the hard way when the default class starts dropping it.

## Build the policy

```text
policy-map PM-COPP
 class CM-COPP-ROUTING
  police rate 2000 pps
   conform-action transmit
   exceed-action transmit
 class CM-COPP-MGMT
  police rate 500 pps
   conform-action transmit
   exceed-action drop
 class CM-COPP-ICMP
  police rate 100 pps
   conform-action transmit
   exceed-action drop
 class class-default
  police rate 200 pps
   conform-action transmit
   exceed-action drop
!
control-plane
 service-policy input PM-COPP
```

Two choices here are deliberate. The routing class transmits on exceed: it exists for visibility, not enforcement, because dropping your own BGP keepalives during a convergence event is worse than a busy CPU. And class-default drops on exceed, so anything you did not anticipate gets a small, bounded share.

The rates are starting points, not recommendations. Size them from what you observe. A router with a full table and a few hundred BGP sessions needs a very different routing rate from a branch box with two OSPF neighbors.

## Roll it out in monitor mode first

The classic CoPP outage is an engineer applying a policy that drops something nobody listed: HSRP, LDP, DHCP relay, a TACACS reply, IPsec IKE to the router itself. Avoid it by deploying every class with `exceed-action transmit` first, then watching for a week:

```text
show policy-map control-plane input
```

Look at the exceeded counters per class, and look at what lands in class-default. If class-default is busy, find out what it is before you start dropping it. An embedded packet capture on the control plane helps:

```text
monitor capture CAP control-plane in match any limit duration 60
monitor capture CAP start
show monitor capture CAP buffer brief
monitor capture CAP stop
```

Once the counters stop surprising you, switch the exceed actions to drop class by class, management and default first.

## Keep it consistent

CoPP is exactly the kind of config that drifts: one router gets a new ACL line during an incident and nobody back-ports it. Keep the policy in your templating or config management source, and include `show policy-map control-plane input` in whatever you already collect for monitoring, so drop counters become a graph rather than something you discover during an outage. A rising drop count in class-default is often the first sign of a scan or a misbehaving neighbor.

## Why this matters

Most control plane outages I have dealt with were not attacks. They were a broken monitoring poller, a layer-2 loop pushing ARP, or a neighbor in a flap loop, and the router could not protect its own routing sessions because everything shared one queue. CoPP does not make the box faster; it makes it decide what to sacrifice. Put it in carefully, observe before enforcing, and the next CPU spike costs you some SNMP polls instead of your adjacencies.
