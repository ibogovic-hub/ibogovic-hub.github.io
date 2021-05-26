---
title: ipv6 and ripng
layout: article
tags: CCNP
article_header:
  type: cover
---

![GNS3-congig](/assets/images/Cisco/ipv6-and-ripng.png)
[R1-config](/assets/images/Cisco/ipv6-and-ripng-r1.txt)  
[R2-config](/assets/images/Cisco/ipv6-and-ripng-r2.txt)  
[R3-config](/assets/images/Cisco/ipv6-and-ripng-r3.txt)  
[R4-config](/assets/images/Cisco/ipv6-and-ripng-r4.txt)  

## ipv6 interface configuration  

```bash
conf t
interface Serial2/0
 no ip address
 ipv6 address 2001:22AA::1/64
 
 # “ARP” or MAC address
show ipv6 neighbors
```


## enable routing  

```
conf t
ipv6 unicast-routing
```

## add default route  

```
conf t
ipv6 route ::/0 2001:11AA::1
```

## configure RIPng on routers  

```
conf t
ipv6 unicast-routing
int s2/0
ipv6 add 2001:22AA::2/64
ipv6 rip CBTNUGGETS enable ← 
no sh

!
int s3/0
ipv6 add 2001:33AA::1/64
ipv6 rip CBTNUGGETS enable ← 
no sh
end
wr
!
```

```
show ipv6 protocols
```

## ipv6 link local address  

- always begin with “FE80”

## config  

```
ipv6 unicast-routing
ipv6 router rip RIPng enable
int s2/0
ipv6 add 2001:db8:6783:122::1/64
ipv6 rip RIPng enable
no sh
end
```
