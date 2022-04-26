---
title: dhcp configuraion
tags: Cisco
---


- DHCP Configuration Commands:

```
ip dhcp pool VLAN_10
```

> Creates a DHCP Pool named VLAN_10.  
> Within this Pool we will specify the items mentioned above.

```
network 172.16.10.0 255.255.255.0
```

> Specifies the network for the DHCP Pool VLAN_10 as the 172.16.10.0/24 network.

```
default-router 172.16.10.1
```

> Specifies the “default gateway” for the dhcp clients will be 172.16.10.1.

```
dns-server 172.16.2.10
```

> Specifies the DNS Server will be 172.16.2.10

```
ip dhcp excluded-address 172.16.10.1 172.16.10.20
```

> The above command tells the router to exclude addresses 172.16.10.1 thru 172.16.10.20 from DHCP allocation.  
> These addresses will not be handed out to clients.  
> The first address to be used will be 172.16.10.21.

- Optional

```
option 150 ip 172.16.2.20
```

> Specifies optional DHCP options needed.
> Above the DHCP option of 150 for TFTP Server has been set to 172.16.2.20.

- Verification:
```
Show ip dhcp binding
```
