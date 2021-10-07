---
title: policy routing
tags: CCNP
---

## route traffic from client 1 to ISP2

```
conf t
ip access-list extended CLIENT1
permit ip host 192.168.1.20 any
exit
route-map POLICY 10
match ip add CLIENT1
set ip next-hop 201.1.1.2
end
```

## route traffic for telnet and https from client 2 to ISP1

```
conf t
ip access-list extended CLIENT2
permit tcp host 192.168.1.21 any eq 23
permit tcp host 192.168.1.21 any eq 443
exit
route-map POLICY 20
match ip add CLIENT2
set ip next-hop 200.1.1.2
end
```

## route all other traffic to ISP 2

```
conf t
route-map POLICY 30
set ip next-hop 201.1.1.2
end
```

## enable policy based routing on the interface

```
conf t
int e0/0
ip policy route-map POLICY
end
```

## enable router traffic primary ISP 1

```
conf t
ip access-list extended ROUTER
permit ip any any
exit
route-map ROUTER_TRAFFIC permit 10
match ip add ROUTER
set ip next-hop verify-availability 200.1.1.2 10 track 1
set ip next-hop 201.1.1.2
exit
ip local policy route-map ROUTER_TRAFFIC
end
```

## ip sla configuration

```
conf t
track 1 ip sla 1 reachability
ip sla 1
 icmp-echo 200.1.1.2
 threshold 2
 timeout 1000
 frequency 3
ip sla schedule 1 life forever start-time now
```

```
ip-sla
router-config
```
