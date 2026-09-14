---
title: Draining a border router without dropping traffic
tags: Cisco
---

The maintenance window starts at 23:00. You need to reload a border router that carries two eBGP sessions to transit providers and an iBGP mesh to the core. The naive approach is `shutdown` on the uplinks, or worse, just reloading the box. Both do the same thing: the BGP sessions die, the peers tear down the routes learned from you, and the rest of the internet reconverges after the fact. For the seconds that takes, traffic is still being sent to a router that no longer has a path. You get a blackhole, not a drain.

The distinction matters because BGP has no notion of "I am about to go away." A session teardown is indistinguishable from a crash. What you want is to make your paths less attractive *while the sessions are still up*, let the network reconverge with everything still forwarding, and only then pull the cable.

## The mechanism

RFC 8326 defines GRACEFUL_SHUTDOWN, a well-known BGP community (65535:0) that says: keep these routes, but treat them as lowest preference. A receiving router that honours it sets LOCAL_PREF to 0 on ingress, which demotes the path without withdrawing it. If an alternative exists, it wins immediately, and the traffic has already moved before you touch anything.

You cannot assume your transit providers honour it — many do, some do not, and the only way to know is to ask or test. What you *can* always control is your own side: your ingress policy on eBGP, and your iBGP local-pref.

Here is a drain policy on IOS-XE that works regardless of whether the far end cooperates. It has two halves: outbound, we tag and prepend so external peers deprefer us; inbound, we set local-pref to 0 so our own core stops choosing this router as the exit.

```
ip bgp-community new-format
ip community-list standard GSHUT permit 65535:0

route-map DRAIN-OUT permit 10
 set community 65535:0 additive
 set as-path prepend 65001 65001 65001

route-map DRAIN-IN permit 10
 set local-preference 0

router bgp 65001
 address-family ipv4 unicast
  neighbor 198.51.100.1 route-map DRAIN-OUT out
  neighbor 198.51.100.1 route-map DRAIN-IN in
```

Apply, then force the policy without bouncing the session:

```
clear ip bgp 198.51.100.1 soft in
clear ip bgp 198.51.100.1 soft out
```

Soft reconfiguration with route refresh is the point of the whole exercise. The session never resets, so there is no hold-timer gap and no route flap damping penalty at the far end.

Verify before you believe it. The counter you care about is how much traffic is still arriving:

```
show ip bgp neighbors 198.51.100.1 advertised-routes | include 65535:0
show ip bgp 0.0.0.0/0
show interfaces TenGigabitEthernet0/0/0 | include rate
```

If the input rate on the transit link has not dropped substantially after 30-60 seconds, your peer is not honouring the community and is not reacting to the prepend either — usually because they have a static local-pref on their side that outranks AS-path length. At that point you have two options: call them, or accept the hit and shut the session with a graceful restart timer.

The inbound half is the one people forget. Even after external traffic stops arriving, your own core routers may still be selecting this box as the best exit for outbound flows, because iBGP local-pref hasn't changed. `DRAIN-IN` setting local-preference 0 on routes learned from the transit peer means those routes lose to the paths reflected from the other border router, and outbound traffic shifts too. Drain is bidirectional or it isn't a drain.

Undoing it is symmetric: remove the route-maps from the neighbor statement, soft-clear both directions, and watch the rate climb back. Do that *before* you declare the window closed, and confirm the prefix count matches what you had pre-maintenance with `show ip bgp summary`.

## Why this matters

I have watched a "routine" reload cause a four-minute partial outage because someone shut an uplink at the CLI and assumed BGP would handle it. BGP did handle it — correctly, and in exactly the time convergence takes, which is not zero. The customer-visible symptom was intermittent timeouts, which is far harder to diagnose at 23:10 than a clean hard failure would have been.

The habit worth building is treating a planned change and an unplanned failure as different events requiring different tools. Failure handling is what BFD, timers and graceful restart are for. Planned drains are what policy is for. Write the drain and undrain route-maps once, keep them in the config permanently unapplied, and the maintenance procedure becomes two commands and a verification step instead of an improvisation under time pressure. That difference is what separates a window that ends on time from one that turns into an incident review.
