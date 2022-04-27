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