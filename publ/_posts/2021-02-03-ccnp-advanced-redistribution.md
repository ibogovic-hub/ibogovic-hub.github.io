---
title: Advanced redistribution
layout: article
tags: CCNP
article_header:
  type: cover
---

![GNS3 config](/assets/images/Cisco/advanced-redistribution-gns3.png)

## create specific seed metric and tags EIGRP and OSPF

[R1-config](/assets/images/Cisco/advanced_redistribution-R1.txt)  
[R2-config](/assets/images/Cisco/advanced_redistribution--R2.txt)  
[R3-config](/assets/images/Cisco/advanced_redistribution-R3.txt)  
[R4-config](/assets/images/Cisco/advanced-redistribution-R4.txt)  

- R2

```
router eigrp 100  
 network 10.1.23.0 0.0.0.255  
 network 10.1.24.0 0.0.0.255  
!  
router ospf 1  
 no auto-cost  
 network 10.1.12.0 0.0.0.255 area 0  
!  
!  
!  
access-list 1 permit 10.4.0.0 0.0.0.255  
access-list 1 permit 10.4.1.0 0.0.0.255  
access-list 2 permit 10.4.2.0 0.0.0.255  
access-list 2 permit 10.4.3.0 0.0.0.255  
access-list 3 permit 10.4.4.0 0.0.0.255  
no cdp log mismatch duplex  
!  
route-map EIGRP-TO-OSPF permit 10
 match ip address 1
 set metric 100
 set tag 10
!
route-map EIGRP-TO-OSPF permit 20
 match ip address 2
 set metric 200
 set tag 20
!
route-map EIGRP-TO-OSPF deny 30
 match ip address 3
!
route-map EIGRP-TO-OSPF permit 40
 set metric 300
 set tag 30
!
```

## redistribute EIGRP to OSPF

- R2

```
conf t
router ospf 1
redistribute eigrp 100 subnets route-map EIGRP-TO-OSPF
```

## OSPF routes redistibuted to EIGRP should have metric of

- R2

```
conf t
route-map OSPF-TO-EIGRP
set metric 400 20 255 1 1500
set tag 40
```

##  redistribute OSPF to EIGRP

- R2

```
conf t
router eigrp 100
redistribute ospf 1 route-map OSPF-TO-EIGRP
```

## block subnets by tag

- R2

```
conf t
route-map OSPF-TO-EIGRP deny 5
 match tag 10 20 30
!
route-map EIGRP-TO-OSPF deny 5
 match tag 40
```

## force EIGRP better route

- R2

```
conf t
router eigrp 100
 network 10.1.23.0 0.0.0.255
 network 10.1.24.0 0.0.0.255
 redistribute ospf 1 route-map OSPF-TO-EIGRP
 distance eigrp 90 105   <--
!
```
