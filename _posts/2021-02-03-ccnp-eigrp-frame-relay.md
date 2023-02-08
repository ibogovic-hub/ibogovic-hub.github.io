---
title: eigrp frame relay
tags: Cisco
---

```
conf t
int loo0
ip add 10.1.1.1 255.255.255.255
int loo1
ip add 10.1.2.1 255.255.255.255
int loo2
ip add 10.1.3.1 255.255.255.255
end
wr
```

- HQ  

```
conf t
int s2/0
encapsulation frame-relay
no sh
int s2/0.102 point-to-point
ip address 10.1.102.1 255.255.255.252
frame-relay interface-dlci 102
int s2/0.103 point-to-point
ip address 10.1.103.1 255.255.255.252
frame-relay interface-dlci 103

int s2/0.102
ip summary-address eigrp 55 10.1.0.0 255.255.252.0
int s2/0.103
ip summary-address eigrp 55 10.1.0.0 255.255.252.0
```

- EAST  

```
conf t
int s2/0
encapsulation frame-relay
no sh
int s2/0.201 point-to-point
ip address 10.1.102.2 255.255.255.252
frame-relay interface-dlci 201

int s2/0.201
ip summary-address eigrp 55 10.2.0.0 255.255.252.0
```

- WEST  

```
conf t
int s2/0
encapsulation frame-relay
no sh
int s2/0.301 point-to-point
ip address 10.1.103.2 255.255.255.252
frame-relay interface-dlci 301

int s2/0.301 point-to-point
ip summary-address eigrp 55 10.3.0.0 255.255.252.0

conf t
router eigrp 55
no auto
network 10.0.0.0
```