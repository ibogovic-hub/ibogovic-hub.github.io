---
title: Cisco commands
tags: Cisco
---

# Some commands

## default config on the devices
```sh
# remove system alerts
no service config

# stop checking the web for names
no ip domain-lookup

# disable console / session timeout 
# --> only in LAB enviroment
line cons 0
    exec-timeout 0 0

line vty 0 15
    exec-timeout 0 0

# disable anoying messages when you are typing
line cons 0
    logging synchronous

line vty 0 15
    logging synchronous
```

## configure DHCP
```sh
conf t
# to exclude some IP's
ip dhcp excluded-address 172.16.0.1 172.16.0.99
ip dhcp excluded-address 172.16.0.200 172.16.0.254
# define pool name and network
ip dhcp pool PC-Pool
    network 172.16.0.0 255.255.255.0
# define gateway and dns
    default-router 172.16.0.1
    dns-server 172.16.0.2
```

## DMVPN
