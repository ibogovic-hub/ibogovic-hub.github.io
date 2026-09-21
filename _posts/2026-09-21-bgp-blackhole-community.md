---
title: Stopping a volumetric flood with RTBH before your upstream picks up the phone
tags: Cisco
---

A single /32 behind your edge starts absorbing several gigabits of UDP. Your transit link saturates, and everything else on that circuit — VPN tunnels, SIP trunks, management SSH — degrades with it. Filtering on your own edge router does nothing useful: the traffic has already crossed the link you care about. The only place to drop it is upstream, and you need that to happen in seconds, not after a ticket queue.

Remotely Triggered Black Hole (RTBH) is the mechanism, and most transit providers already support it. It is unglamorous, it has been in IOS since the early 2000s, and it works. The part people get wrong is the pre-wiring: RTBH only helps if the route-map, the discard route, and the peering policy are already in place before the incident.

## The three pieces

**1. A discard next-hop.** Pick an address from 192.0.2.0/24 (TEST-NET-1) and statically route it to Null0. Anything resolving to that next-hop gets dropped by CEF at line rate with no ACL lookup.

**2. A trigger router.** Ideally not your production edge — a small router or a Linux box running a BGP daemon that peers iBGP with your edge and does nothing but originate blackhole routes.

**3. A route-map** that stamps the blackhole community and sets the next-hop, applied outbound toward your upstream.

## Configuration on the trigger router

```
! Discard next-hop
ip route 192.0.2.1 255.255.255.255 Null0

route-map RTBH-TRIGGER permit 10
 match tag 666
 set ip next-hop 192.0.2.1
 set community 65535:666 no-export additive
 set origin igp
route-map RTBH-TRIGGER deny 20

router bgp 64512
 address-family ipv4 unicast
  redistribute static route-map RTBH-TRIGGER
  neighbor 10.0.0.1 activate
  neighbor 10.0.0.1 send-community both
  neighbor 10.0.0.1 next-hop-self
 exit-address-family
```

Triggering a blackhole for a victim host is then a one-liner:

```
ip route 198.51.100.77 255.255.255.255 Null0 tag 666
```

The static route gets redistributed, the route-map rewrites next-hop to 192.0.2.1 and tags it with the well-known BLACKHOLE community. Removing the static route withdraws it. No BGP session touched, no policy reload.

## On the edge router, toward transit

Your upstream will publish the community they expect — commonly 65535:666 (RFC 7999 BLACKHOLE) or a provider-specific value like 3356:9999. You must explicitly permit /32 prefixes out to them, because your normal outbound prefix-list almost certainly caps at your aggregate:

```
ip prefix-list TO-TRANSIT permit 203.0.113.0/24
ip prefix-list TO-TRANSIT permit 198.51.100.0/24 ge 32 le 32

route-map TRANSIT-OUT permit 10
 match ip address prefix-list TO-TRANSIT
 match community BLACKHOLE-COMM
 set community 3356:9999 additive
route-map TRANSIT-OUT permit 20
 match ip address prefix-list TO-TRANSIT
```

Two things to verify before you need this. First, that the upstream actually honours the community — ask, and ask them to confirm with a test prefix during a maintenance window. Second, that your own iBGP does not leak the /32 with 192.0.2.1 as next-hop anywhere that lacks the Null0 route, because then it becomes an unresolvable route rather than a discard.

## Verification

```
show bgp ipv4 unicast 198.51.100.77/32
show ip cef 198.51.100.77
show ip route 192.0.2.1
```

The CEF entry should read `attached to Null0`. If it shows a real interface, your discard route is missing and you have just advertised a black hole that does nothing locally while your upstream drops the traffic — an asymmetry that produces confusing partial outages.

## The obvious cost

RTBH completes the attack for the targeted host. You are dropping all traffic to that address to save the circuit. That is a business decision, not a network one, so agree the policy in advance: which prefixes may be blackholed unilaterally, who authorises it out of hours, and what the maximum duration is before someone must re-evaluate. Ours is a 30-minute auto-expiry enforced by removing the static route from a scheduled job — long enough to survive a burst, short enough that nobody forgets.

## Why this matters

The failure mode I have seen repeatedly is not that RTBH is hard, it is that nobody tested it. The route-map exists in the config from a project three years ago, the upstream changed their community scheme after a merger, and the on-call engineer discovers this at 03:00 while the circuit is at 100 percent. Treat RTBH like a backup restore: exercise it on a schedule with a harmless test prefix, capture the expected `show` output in your runbook, and confirm the community with your provider annually. The configuration is ten lines. The confidence that it works when the link is already saturated is what actually takes effort.
