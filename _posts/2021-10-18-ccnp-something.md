---
title: Cisco ccnp commands
tags: CCNP
---

## NAT and PAT
#### how to configure NAT on the router
- configure inside interface
```sh
conf t
  interface gig 0/1
  ip nat inside

  interface gig 0/2
  ip nat outside
exit

ip nat inside source static 192.168.1.100 172.16.1.100
end
```

#### dynamic NAT
```sh
conf t
  interface gig 0/1
  ip nat inside

  interface gig 0/2
  ip nat outside

  access-list 1 permit 192.168.1.0 0.0.0.255
  ip nat pool POOL 172.16.1.100 172.16.1.199 netmask 255.255.255.0
  ip nat inside source list 1 pool POOL
end
wr
```
#### PAT configuration

```sh
conf t
  interface gig 0/1
  ip nat inside
  !
  interface gig 0/2
  ip nat outside
  !
  access-list 1 permit 192.168.1.0 0.0.0.255
  ip nat inside source list 1 interface gig0/2 overload
```

#### command to check the translations

```sh
show ip nat translations
```