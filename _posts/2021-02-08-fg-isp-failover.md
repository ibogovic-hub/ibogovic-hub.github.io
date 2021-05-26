---
title: isp failover
layout: article
tags: Fortinet
article_header:
  type: cover
---

## Connect the two FortiGates on the wan2 port 

- Go to System > Network > Interface 
- Assign FortiGate1 an IP Address on wan2 172.16.0.1/30 
- Assign FortiGate2 an IP Address on wan2 172.16.0.2/30 
- Go to Router > Static > Static Routes 

- On FortiGate1 create a new route 

```
Destination 0.0.0.0/0.0.0.0 
Device wan2 
Gateway 172.16.0.2 
Distance 11 (greater than your default route) 
```

- On FortiGate2 do the same but 

```
Gateway 172.16.0.1 
```

- Create a new Static route on FortiGate1 

```
Destination 10.0.0.0/8 
device wan2 
Gateway 172.16.0.2 
Distance 10 
```

- On FortiGate2 do the same but 

```
Destination 192.168.0.0/16 
Gateway 172.16.0.2 
```

- Now go to Policy&Objects > Objects > Addresses 

- On FortiGate1 create an object for Network_fortigate2 with 192.168.0.0/16 
- On FortiGate2 create an object for network_fortigate1 with 10.0.0.0/8 

- Go to Policy&Objects > IPv4 > Policies 

- On FortiGate1 create new Policy 

```
Incoming Interface: wan2 
Source Address: network_fortigate2 
Outgoing Interface: wan1 
Destination Address: all 
Enable NAT 
configure rest as needed 
```

- On FortiGate2 do the same but 

```
Source Address: network_fortigate1 
Go to Router > Static > Settings 
Create two new Link Health Monitor 
Interface wan1/wan2 
Gateway on wan2 Fortigate1: 172.16.0.2 / on fortigate2: 172.16.0.1 
On wan1 Gateway from your ISPs 
Enable health check 
Ping 
8.8.8.8 (or whatever you like) 
```

- The optimal way would be a HA setup with both devices, 
- that way if one internet connection fails the other takes over AND if one of the FortiGates dies the other takes over 

- To configure the routing of the two interfaces - GUI 
Go to Network > Static Routes and select Create New or IPv6 Route. 
For low-end FortiGate units, go to Network > Static Routes and select Create New or IPv6 Route. 
Set the Destination IP/Mask to the address and netmask of 0.0.0.0/0.0.0.0 if it’s an IPv4 route. If it’s an IPv6 route, set Destination IP/Mask to the address and netmask of ::/0 

- Select the Device to the primary connection, WAN1. 
Enter the Gateway address. 
Select Advanced. 
Set the Distance to 10. 
Select OK. 

- Repeat steps 1 through 7 setting the Device to WAN2 and a Distance of 20. 

### To configure the IPv4 routing of the two interfaces - CLI 

```bash
config router static 
edit 0 
set dst 0.0.0.0 0.0.0.0 
set device WAN1 
set gateway <gateway_address> 
set distance 10 
next 
edit 0 
set dst 0.0.0.0 0.0.0.0 
set device WAN2 
set gateway <gateway_address> 
set distance 20 
next 
end
```

### To configure the IPv6 routing of the two interfaces - CLI 

```bash
config router static6 
edit 0 
set dst ::/0 
set device WAN1 
set gateway <gateway_address> 
set distance 10 
next 
edit 0 
set dst ::/0 
set device WAN2 
set gateway <gateway_address> 
set distance 20 
next 
end
```

### Security policies 

- When creating security policies, you need to configure duplicate policies to ensure that after traffic fails over WAN1, regular traffic will be allowed to pass through WAN2 as it did with WAN1.
- This ensures that fail-over will occur with minimal affect to users. For more information on creating security policies see the Firewall Guide. 