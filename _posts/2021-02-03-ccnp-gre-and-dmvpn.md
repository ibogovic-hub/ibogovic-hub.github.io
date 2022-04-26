---
title: gre and dmvpn
tags: Cisco
---

## configure GRE and DMVPN on three sites



- HUB  

```
conf t
int tunnel 0
no ip split-horizon
tunnel source s2/0
tunnel mode gre multipoint
tunnel key 1234
ip nhrp network-id 1
ip nhrp authentication asdfasdf
ip nhrp map multicast dynamic
ip add 192.168.0.1 255.255.255.0
ip mtu 1400
ip tcp adjust-mss 1360
exit
```

- SPOKE 01 (R2)  

```
conf t
int tunnel 0
tunnel source s2/0
tunnel mode gre multipoint
tunnel key 1234
ip nhrp network-id 1
ip nhrp authentication asdfasdf
ip nhrp map multicast dynamic
ip nhrp nhs 192.168.0.1
ip nhrp map 192.168.0.1 51.10.1.2
ip nhrp map multicast 51.10.1.2
ip add 192.168.0.2 255.255.255.0
ip mtu 1400
ip tcp adjust-mss 1360
exit
```

- SPOKE 02 (R3)  

```
conf t
int tunnel 0
tunnel source s2/0
tunnel mode gre multipoint
tunnel key 1234
ip nhrp network-id 1
ip nhrp authentication asdfasdf
ip nhrp map multicast dynamic
ip nhrp nhs 192.168.0.1
ip nhrp map 192.168.0.1 51.10.1.2
ip nhrp map multicast 51.10.1.2
ip add 192.168.0.3 255.255.255.0
ip mtu 1400
ip tcp adjust-mss 1360
exit
```

## simple RIP routing  

```
conf t
router rip
ver 2
no auto
network 192.168.0.0
network 10.0.0.0
end
wr
!
```
