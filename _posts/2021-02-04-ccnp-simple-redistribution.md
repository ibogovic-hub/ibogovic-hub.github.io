---
title: simple redistribution
tags: Cisco
---

## enable full redistribution EIGRP - OSPF

```
router eigrp 1
 network 10.1.16.0 0.0.0.255
 redistribute ospf 1 metric 100 100 100 100 100 route-map FILTER_OSPF_TO_EIGRP
!
router ospf 1
 redistribute eigrp 1 metric 100 subnets
 network 10.1.23.0 0.0.0.255 area 0
 distribute-list 1 out
!
```

## OSPF implement distribute-list to show only odd numbered loopback networks

- R2  

```
conf t
access-list 1 permit 10.1.1.0 0.0.0.255
access-list 1 permit 10.1.3.0 0.0.0.255
access-list 1 permit 10.1.5.0 0.0.0.255
!
router ospf 1
 redistribute eigrp 1 metric 100 subnets
 network 10.1.23.0 0.0.0.255 area 0
 distribute-list 1 out <--
!
```

## implement route-map filtering for EIGRP to show only /24

- R2  

```
conf t
ip prefix-list ivan seq 5 permit 10.0.0.0/8 le 24

route-map FILTER_OSPF_TO_EIGRP permit 10
 match ip address prefix-list ivan

router eigrp 1
 redistribute ospf 1 metric 100 100 100 100 100 route-map FILTER_OSPF_TO_EIGRP
!
```
