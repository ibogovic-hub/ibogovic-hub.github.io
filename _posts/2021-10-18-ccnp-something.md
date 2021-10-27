---
title: ENARSI & ENCORE notes
tags: CCNP
---

---
# **Notes from ENARSI and ENCORE sessions**  

---  

# NAT and PAT  

## how to configure NAT

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

## dynamic NAT  

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

## PAT configuration  

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

### command to check the translations

```sh
show ip nat translations
```

---
# ***NTP***

---

```sh
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

## NTP security

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

### check NTP

```sh
show ntp status # to check the status of the sync
show ntp config # to check settings of NTP
```

---
# ***HSRP & VRRP***

---

## HSRP

![HSRP01](/assets/images/cisco/HSRP01.png)

```sh
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

- adjust timers
```sh
conf t
  int gig 0/1
  standby version 2
  standby timers msec 50 msec 200
  end
wr

# debug command
debug standby terse

# tracking if internet interface is down
conf t
  int gig 0/1
    standby 10 track 1 decrement 20
    exit
  track 1 interface gig 0/2 line-protocol
    end
wr
```

## VRRP

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


### check status

```sh
show standby brief # check HSRP status
show vrrp brief    # check VRRP status
```

---
# ***NETWORK MANAGEMENT***  

---

## SNMP

```sh
# ver 2c
conf t
  snmp-server community COMUNITYro ro
  snmp-server community COMUNITYrw rw
  snmp-server location world, WO
  snmp-server contact daffy duck
  snmp-server host 3.3.3.3 version 2c COMUNITYsrv
  !
  snmp-server enable traps
  end
wr
```
```sh
# ver 3
conf t
  snmp-server engineID local 123456789
  snmp-server group DEMO-GROUP v3 priv
  snmp-server user DEMO-USER DEMO-GROUP v3 auth sha Password priv aes 256 Password
  end
wr
```

## SYSLOG

```sh
conf t
  logging 2.2.2.2
  logging trap 5 # notifications
  end
wr
```

## NETFLOW

```sh
conf t
  int gig 0/1
  ip flow ingress
  int gig 0/2
  ip flow ingress
  exit
  ip flow-export source gig 0/1
  ip flow-export version 5
  ip flow-export destination 192.168.1.50 9995
  end
wr
```
- to check the flow
```sh
show ip cache flow
```

# ***SPAN, RSPAN & ERSPAN***


![sample](/assets/images/cisco/cisco-span.png)

## SPAN

```sh
# SW01
conf t
  monitor session 1 source interface gig 0/1 - 2
  monitor session 1 destination interface gig 0/3
```

```sh
# check the status
show monitor session 1
```

## RSPAN

```sh
# SW01
conf t
  monitor session 1 type rspan-source
    no shutdown
    source interface gig 2
    destination
      erspan-id 1
      ip address 10.1.1.2
```