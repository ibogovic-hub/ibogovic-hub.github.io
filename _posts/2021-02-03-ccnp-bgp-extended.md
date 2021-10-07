---
title: bgp-extended
tags: CCNP
---

## ***weight configuration***

- R1  

```
conf t
router bgp 5500
neighbor 10.1.12.2 weight 200 ← 
exit
clear ip bgp *
```

## ***next hop address***

- R2  

```
conf t
router bgp 5500
neighbor 10.1.12.1 next-hop-self
exit
clear ip bgp *
```

- R3  

```
conf t
router bgp 5500
neighbor 10.1.13.1 next-hop-self
exit
clear ip bgp *
```

### ***origin***

i = iBgp → typed network command
? = redistribution

## ***local preference***

- R3  

```bash
# (per router)
conf t
router bgp 5500
 bgp default local-preference 850

# (apply to AS)
conf t
ip access-list standard ROUTES_FOR_R2
 permit 200.0.0.0 0.255.255.255
ip access-list standard ROUTES_FOR_R3
 permit 150.1.50.0 0.0.0.255
 permit 150.2.50.0 0.0.0.255
!
!
route-map LOCAL_PREF permit 10
 match ip address ROUTES_FOR_R3
 set local-preference 1000
!
route-map LOCAL_PREF permit 20
 match ip address ROUTES_FOR_R2
 set local-preference 10
!
route-map LOCAL_PREF permit 30


router bgp 5500
 bgp log-neighbor-changes
 neighbor 10.1.2.2 remote-as 5500
 neighbor 10.1.13.1 remote-as 5500
 neighbor 10.1.13.1 next-hop-self
 neighbor 10.1.36.6 remote-as 777
 neighbor 10.1.36.6 route-map LOCAL_PREF in ← 
 default-metric 200
!
```

### metric  

- R3  

```
router bgp 5500
 default-metric 200
!

route-map METRIC
set metric 200
```

### temporary disable neighbor  

- R1  

```
conf t
router bgp 5500
neighbor 10.1.12.2 shutdown ←
```