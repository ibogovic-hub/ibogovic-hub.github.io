---
title: ENARSI & ENCORE notes
tags: CCNP
---

---
**Notes from ENARSI and ENCORE sessions**

### NAT and PAT  

#### how to configure NAT on the router

![config](/assets/images/cisco/NTP.png)

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

### NTP  

```bash
# router - internet
conf t
  clock set 18:00:00 April 20 2021
  clock timezone UTC +1
  ntp master 3
  end
wr

# router R1
conf t
  ntp server 1.1.1.1
  clock timezone UTC +1
  clock summer-time EDT recurring
  end
wr
```

#### NTP security

- password authentication
```sh
# Internet Router
conf t
  ntp authentication-key 1 md5 Password
  ntp trusted key 1
  ntp authenticate
  end
wr

# R1
conf t
  ntp authentication-key 1 md5 Password
  ntp trusted key 1
  ntp authenticate
  end
wr
```
- access list authentication

```sh
# Internet router
conf t
  ip access-list standard NTP-CLIENT
    permit 172.16.1.1
  ntp access-group serve-only NTP-CLIENT
  end
wr

# R1
conf t
  ip access-list standard NTP-SERVER
    permit 1.1.1.1
    exit
  ntp access-group peer NTP-SERVER
  end
wr
```

#### check NTP time

```bash
show ntp status # to check the status of the sync
show ntp config # to check settings of NTP
```

---
***HSRP & VRRP***

#### basic configuration

![HSRP01](../assets/images/cisco/HSRP01.png)

```bash
# R1

conf t
  int gig 0/1
    standby 10 ip 10.1.1.1
    standby 10 preempt
    standby 10 priority 110
  end
wr

# R2

conf t
  int gig 0/1
    standby 10 ip 10.1.1.1
    standby 10 preempt
  end
wr
```

#### VRRP

```sh
# R1

conf t
  int gig 0/1
  vrrp 10 ip 10.1.1.1
  vrrp 10 priority 110
  end
wr

# R2

conf t
  int gig 0/1
  vrrp 10 ip 10.1.1.1
  vrrp 10 priority 110
  end
wr
```


#### check status

```sh
show standby brief # check HSRP status
show vrrp brief    # check VRRP status
```

---
***MULTICAST***

### Unicast