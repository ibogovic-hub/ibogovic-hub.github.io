---
title: Fortigate general commands
layout: article
tags: Fortinet
article_header:
  type: cover
---

## general fortigate stuff

- commands to troubleshoot vpn tunnel

```
diagnose debug console
diagnose debug enable
diagnose debug application ike -1
diagnose debug application ssld -1
diagnose debug application sslvpn -1
diagnose vpn tunnel list
diagnose debug flow
```

- ping from the xxx source address

```
execute ping-options source x.x.x.x
execute ping 
```

- reset the debugging

```
diagnose debug disable
diagnose debug reset
```

```
show full-configuration
```

> To troubleshoot tunnel mode connections shutting down after a few seconds:  
> This might occur if there are multiple interfaces connected to the Internet, for example, SD-WAN. This can cause the session to become “dirty”.  
> To allow multiple interfaces to connect, use the following CLI commands.

### If you are using a FortiOS 6.0.1 or later:

```
config system interface
  edit <name>
    set preserve-session-route enable
  next
end
```

### If you are using a FortiOS 6.0.0 or earlier:

```
 config vpn ssl settings
   set route-source-interface enable
end
```

> It is possible to identify a PSK mismatch using the following combination of CLI commands:

```
diagnose vpn ike log filter name <phase1-name> 
diagnose debug app ike -1
diagnose debug enable
```

> This will provide you with clues as to any PSK or other proposal  issues.  
> If it is a PSK mismatch, you should see something similar  to the following output:

```
ike 0:TRX:322: PSK auth failed: probable pre-shared key mismatch
ike Negotiate SA Error:
```

### general

```bash
get system interface physical
#overview of hardware interfaces
get hardware nic <nic-name>
#details of a single network interface, same as: diagnose hardware deviceinfo nic <nic-name>
fnsysctl ifconfig <nic-name>
#kind of hidden command to see more interface stats such as errors
get system status
#==show version
get system performance status
#CPU and network usage
diagnose sys top
#top with all forked processed
diagnose sys top-summary
#top easier, incl. CPU and mem bars. Forks are displayed by [x13] or whatever
execute dhcp lease-list
get system arp
diagnose ip arp list
diagnose ipv6 address list
diagnose ipv6 neighbor-cache list
diagnose sys ntp status
diagnose autoupdate versions
#lists the attack definition versions, last update, etc.
diagnose log test
#generated all possibe log entries
diagnose test application dnsproxy 6
#shows the IP addresses of FQDN objects
diagnose debug crashlog read
#shows crashlog, a status of 0 indicates a normal close of a process!
```

### network

```bash
execute ping6-options ?
execute ping6-options source <source-interface-IP>
execute ping6 <hostname|ip>
 
execute ping-options ?
execute ping-options source <source-interface-IP>
execute ping <hostname|ip>
 
execute tracert6 <hostname|ip>
 
execute traceroute <hostname|ip>
execute traceroute-options ?
```

### Routing

```bash
get router info6 routing-table
#routing table = active routes
get router info routing-table all
#IPv4 needs an "all" at the end
 
get router info6 routing-table database
#Routing Information Base WITH inactive routes
get router info routing-table database
 
get router info6 kernel
#Forwarding Information Base
get router info kernel
 
diagnose firewall proute6 list
#Policy Routes + WAN Load Balancing
diagnose firewall proute list
 
get router <routing-protocol>
#basic information about the enabled routing protocol
diagnose ip rtcache list
#route cache = current sessions w/ routing information
```

### sniffer

```bash
diagnose sniffer packet any 'host 192.168.19.134' 4 100 l
diagnose sniffer packet any 'host 8.8.8.8 and dst port 53' 4 10 a
diagnose sniffer packet wan1 'dst port (80 or 443)' 2 50 l
diagnose sniffer packet any 'net 2001:db8::/32' 6 1000 l
```

### Flow

```bash
diagnose debug reset
diagnose debug flow filter saddr 10.200.200.1
diagnose debug flow filter daddr 192.168.50.90
diagnose debug flow show function-name enable
diagnose debug enable
diagnose debug flow trace start 100
diagnose debug disable
```

### VPN

```bash
get vpn ike gateway <name>
get vpn ipsec tunnel name <name>
get vpn ipsec tunnel details
diagnose vpn tunnel list
diagnose vpn ipsec status
#shows all crypto devices with counters that are used by the VPN
get router info routing-table all

diagnose debug reset
diagnose vpn ike log-filter clear
diagnose vpn ike log-filter ?
diagnose vpn ike log-filter dst-addr4 1.2.3.4
diagnose debug app ike 255
#shows phase 1 and phase 2 output
diagnose debug enable
#after enough output, disable the debug:
diagnose debug disable
```

### SSL VPN

```bash
diagnose debug enable
diagnose vpn ssl <...>
    - list → show current connections
    - info → general ssl-vpn info
    - statistics → show stats about memory, max and current connections
    - debug-filter → debug message filter for ssl-vpn
    - hw-acceleration-status → display the status of ssl hardware acceleration
    - tunnel-test → enable / disable ssl-vpn old tunnel mode IP allocation method
    - web-mode-test → enable / disable random session ID in proxy URL for testing

diagnose debug application sslvpn -1
diagnose debug enable
    - display debug messages for ssl-vpn -1 debug level produces detailed results
```

### ssl user debug

```bash
diag debug application fnbamd 7
diag debug enable
diag test authserver ldap adserv01-test utest0000 W@is4it=gr8!
```