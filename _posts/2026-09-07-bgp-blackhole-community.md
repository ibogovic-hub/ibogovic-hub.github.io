---
title: Stop the bleeding with RTBH before you open the ticket
tags: Cisco
---

A single customer prefix starts absorbing several gigabits of UDP reflection traffic. Your upstream circuit is congested, so everything behind it degrades: the VPN tunnels flap, the monitoring probes go red, and the noise makes the real cause harder to find. You call the transit provider, sit in a queue, and by the time a human applies a filter the incident is twenty minutes old.

Remote Triggered Black Hole (RTBH) exists so you never make that call. You advertise the victim prefix to your upstream with a well-known community, and their edge drops the traffic before it ever enters your circuit. The mechanics are boring BGP, which is exactly why it works under pressure.

## The pieces

Three things have to be in place, and only one of them is interesting.

First, a discard route. On every router that will drop traffic, a static route to Null0 for a reserved next-hop address:

```
ip route 192.0.2.1 255.255.255.255 Null0
```

Second, a trigger router. This is typically a route reflector or a dedicated box that does not forward traffic. It originates the blackhole prefix, sets the next-hop to the discard address, and tags it.

Third, the community. Your provider publishes theirs; RFC 7999 also defines the well-known value 65535:666, which most large transit networks accept. Do not guess. Read their BGP customer guide and confirm both the community and the maximum prefix length they will accept — many will only blackhole a /32.

## Trigger configuration

On the trigger router, on IOS-XE:

```
route-map RTBH-TRIGGER permit 10
 match tag 666
 set ip next-hop 192.0.2.1
 set community 65535:666 no-export additive
 set origin igp
!
router bgp 65001
 address-family ipv4 unicast
  redistribute static route-map RTBH-TRIGGER
 exit-address-family
!
neighbor 198.51.100.9 remote-as 64500
 address-family ipv4 unicast
  neighbor 198.51.100.9 send-community both
 exit-address-family
```

Blackholing a host then becomes one line:

```
ip route 203.0.113.45 255.255.255.255 Null0 tag 666
```

That static gets redistributed, picks up the community, and propagates to the upstream, which installs it pointing at their own discard interface. Traffic to that address dies at their edge. Removing the static removes the blackhole.

Note the `no-export` on the internal side if you also run RTBH inside your own AS — you want the internal blackhole to stay internal. The community you send to the transit provider is separate and must be permitted outbound by your export policy. This is the failure mode I have seen most often: the route is in the local RIB, everyone assumes it worked, and the outbound route-map to the upstream strips communities or filters /32s. Check with `show ip bgp neighbors <peer> advertised-routes` before you declare victory.

## uRPF for the source-based variant

Destination-based RTBH sacrifices the victim: the host is unreachable, which is sometimes the point and sometimes unacceptable. Source-based RTBH drops traffic by source address instead, and it needs loose-mode uRPF on the ingress interfaces:

```
interface TenGigabitEthernet0/0/0
 ip verify unicast source reachable-via any
```

With loose uRPF, any packet whose source address has no route — or resolves to Null0 — is dropped. So blackholing the attacker's /32 on the trigger causes ingress interfaces to discard packets sourced from it. This only helps against a small number of genuine sources; against a broad reflection attack the source set is too large to enumerate, and you are back to destination-based.

## Practical guardrails

Keep the trigger router out of the forwarding path so a mistake there cannot black-hole your own transit. Use a distinct tag value that appears nowhere else in your static routes, and audit it — a `tag 666` accidentally applied to an aggregate is a self-inflicted outage of the worst kind. Put a prefix-list on the redistribution that permits only /32s (and /128s if you run this for IPv6, where the equivalent discard next-hop is a reserved documentation address routed to Null0).

Test it during a maintenance window against a throwaway address you own. Verify from an off-net looking glass that the prefix appears with the community, and verify the address is genuinely unreachable from outside. Then write the runbook: the exact command, who is allowed to run it, and how it gets removed. The removal step is the one people forget, and a stale blackhole discovered three weeks later is an unpleasant conversation.

## Why this matters

The value of RTBH is not that it is clever — it is that it converts a vendor-dependency incident into a local configuration change. During an actual volumetric event, the difference between a fifteen-minute provider ticket and a fifteen-second static route is the difference between a degraded service and an outage that shows up in the monthly report. Build it while nothing is on fire, test it twice a year, and keep the runbook short enough that whoever is on call at 03:00 can execute it without thinking hard.
