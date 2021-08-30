---
title: OSPF special area configuration
tags: CCNP
---

![GNS3-config](/assets/images/Cisco/ospf-sa-config.png)

[R1-config](/assets/images/Cisco/ospf-sa-R1.txt)  
[R2-config](/assets/images/Cisco/ospf-sa-R2.txt)  
[R3-config](/assets/images/Cisco/ospf-sa-R3.txt)  
[R4-config](/assets/images/Cisco/ospf-sa-R4.txt)  
[R5-config](/assets/images/Cisco/ospf-sa-R5.txt)  
[R6-config](/assets/images/Cisco/ospf-sa-R6.txt)  
[R7-config](/assets/images/Cisco/ospf-sa-R7.txt)  
[R8-config](/assets/images/Cisco/ospf-sa-R8.txt)  
[virtual-link-config](/assets/images/Cisco/ospf-sa-virtual-link.txt)  

## redistribute static as E1 routes

```
conf t
router ospf 1
redistribute static subnets metric-type 1 50
```

- metric-type 1 - increments the metric
- metric-type 2 - don't increment metric

## block neighbour forming 

```
conf t
router ospf 1
passive-interface default ( block all )
```

- to enable per interface

```
conf t
router ospf 1
no passive-interface fa0/2
```

## authentication md5

```
 interface FastEthernet0/0
 ip address 10.100.1.1 255.255.255.0
 ip ospf authentication message-digest <--
 ip ospf message-digest-key 1 md5 cisco <--
 duplex auto
 speed auto
!
```

## limited capacity router - we could block routes from outside of OSPF system

- R4  

```
conf t
router ospf 1
area 45 stub   <--
```

- R5

```
conf t
router ospf 1
area 45 stub  <--
```

## block 3, 4 and 5 LSA's in area 23

R2

```
conf t 
router ospf 1
area 23 stub no-summary  <--
```

- R3

```
conf t 
router ospf 1
area 23 stub     <--
```

## default route initial cost of 100 in area 23

- R2

```
conf t 
router ospf 1
area 23 default-cost 100  <--
```

## create virtual link for R8 to enable comunication

- R6

```
conf t
router ospf 1
area 67 virtual-link 7.7.7.7  <--
```

- R7

```
conf t
router ospf 1
area 67 virtual-link 6.6.6.6  <--
```

- must be connected to area 0