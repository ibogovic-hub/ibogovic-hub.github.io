---
title: hsrp
tags: Cisco
---

### Configuring HSRP Priority and Preemption
> In the following example, Device A is configured to be the active device for group 1 because it has the higher priority and standby device for group 2. Device B is configured to be the active device for group 2 and standby device for group 1.

![hsrp](/assets/images/cisco/hsrp02.png)

- Device A Configuration
```sh
Device(config)# interface GigabitEthernet 0/0/0
Device(config-if)# ip address 10.1.0.21 255.255.0.0
Device(config-if)# standby 1 priority 110
Device(config-if)# standby 1 preempt
Device(config-if)# standby 1 ip 10.1.0.1
Device(config-if)# standby 2 priority 95
Device(config-if)# standby 2 preempt
Device(config-if)# standby 2 ip 10.1.0.2
```

-  Device B Configuration
```sh
Device(config)# interface GigabitEthernet 0/0/0
Device(config-if)# ip address 10.1.0.22 255.255.0.0
Device(config-if)# standby 1 preempt
Device(config-if)# standby 1 priority 105
Device(config-if)# standby 1 ip 10.1.0.1
Device(config-if)# standby 2 priority 110
Device(config-if)# standby 2 preempt
Device(config-if)# standby 2 ip 10.1.0.2
```

### Configuring HSRP Object Tracking
> In the following example, the tracking process is configured to track the IP-routing capability of serial interface 1/0. HSRP on Gigabit Ethernet interface 0/0/0 then registers with the tracking process to be informed of any changes to the IP-routing state of serial interface 1/0. If the IP state on serial interface 1/0 goes down, the priority of the HSRP group is reduced by 10.

> If both serial interfaces are operational, Device A will be the HSRP active device because it has the higher priority. However, if IP routing on serial interface 1/0 in Device A fails, the HSRP group priority will be reduced and Device B will take over as the active device, thus maintaining a default virtual gateway service to hosts on the 10.1.0.0 subnet.

- Device A Configuration
```sh
Device(config)# track 100 interface serial 1/0/0 ip routing
!
Device(config)# interface GigabitEthernet 0/0/0
Device(config-if)# ip address 10.1.0.21 255.255.0.0
Device(config-if)# standby 1 preempt
Device(config-if)# standby 1 priority 110
Device(config-if)# standby 1 track 100 decrement 10
Device(config-if)# standby 1 ip 10.1.0.1
```

- Device B Configuration
```sh
Device(config)# track 100 interface serial 1/0/0 ip routing
!
Device(config)# interface GigabitEthernet 0/0/0
Device(config-if)# ip address 10.1.0.22 255.255.0.0
Device(config-if)# standby 1 preempt
Device(config-if)# standby 1 priority 105
Device(config-if)# standby 1 track 100 decrement 10
Device(config-if)# standby 1 ip 10.1.0.1
```

### Configuring HSRP Group Shutdown
In the following example, the tracking process is configured to track the IP-routing capability of Gigabit Ethernet interface 0/0/0. HSRP on Gigabit Ethernet interface 0/0/1 then registers with the tracking process to be informed of any changes to the IP-routing state of Gigabit Ethernet interface 0/0/0. If the IP state on Gigabit Ethernet interface 0/0/0 goes down, the HSRP group is disabled.

> If both Gigabit Ethernet interfaces are operational, Device A will be the HSRP active device because it has the higher priority. However, if IP routing on Gigabit Ethernet interface 0/0/0 in Device A fails, the HSRP group will be disabled and Device B will take over as the active device, thus maintaining a default virtual gateway service to hosts on the 10.1.0.0 subnet.

- Device A
```sh
Device(config)# track 100 interface GigabitEthernet 0/0/0 ip routing 
!
Device(config)# interface GigabitEthernet 0/0/1
Device(config-if)# ip address 10.1.0.21 255.255.0.0
Device(config-if)# standby 1 ip 10.1.0.1
Device(config-if)# standby 1 preempt
Device(config-if)# standby 1 priority 110
Device(config-if)# standby 1 track 100 shutdown
```

- Device B
```sh
Device(config)# track 100 interface GigabitEthernet 0/0/0 ip routing 
!
Device(config)# interface GigabitEthernet 0/0/1
Device(config-if)# ip address 10.1.0.22 255.255.0.0
Device(config-if)# standby 1 ip 10.1.0.1
Device(config-if)# standby 1 preempt
Device(config-if)# standby 1 priority 105
Device(config-if)# standby 1 track 100 shutdown
```

> If an object is already being tracked by an HSRP group, you cannot change the configuration to use the HSRP Group Shutdown feature. You must first remove the tracking configuration using the no standby track command and then reconfigure it using the standby track command with the shutdown keyword.

> The following example shows how to change the configuration of a tracked object to include the HSRP Group Shutdown feature:
```sh
Device(config)# no standby 1 track 100 decrement 10
Device(config)# standby 1 track 100 shutdown
```
### Configuring HSRP MD5 Authentication Using Key Strings
```sh
Device(config)# interface GigabitEthernet 0/0/0
Device(config-if)# standby 1 priority 110
Device(config-if)# standby 1 preempt
Device(config-if)# standby 1 authentication md5 key-string 54321098452103ab timeout 30
Device(config-if)# standby 1 ip 10.21.0.10
```
### Configuring HSRP MD5 Authentication Using Key Chains
> In the following example, HSRP queries the key chain “hsrp1” to obtain the current live key and key ID for the specified key chain:
```sh
Device(config)# key chain hsrp1
Device(config-keychain)# key 1
Device(config-keychain-key)# key-string 54321098452103ab
Device(config-keychain-key)# exit
Device(config)# interface GigabitEthernet 0/0/0
Device(config-if)# standby 1 priority 110
Device(config-if)# standby 1 preempt
Device(config-if)# standby 1 authentication md5 key-chain hsrp1
Device(config-if)# standby 1 ip 10.21.0.10
```

### Configuring HSRP MD5 Authentication Using Key Strings and Key Chains
> The key ID for key-string authentication is always zero. If a key chain is configured with a key ID of zero, then the following configuration will work:

- Device 1
```sh
Device(config)# key chain hsrp1
Device(config-keychain)# key 0
Device(config-keychain-key)# key-string 54321098452103ab
Device(config-keychain-key)# exit
Device(config)# interface GigabitEthernet 0/0/0
Device(config-if)# standby 1 authentication md5 key-chain hsrp1
Device(config-if)# standby 1 ip 10.21.0.10
```

- Device 2
```sh
Device(config)# interface GigabitEthernet 0/0/0
Device(config-if)# standby 1 authentication md5 key-string 54321098452103ab
Device(config-if)# standby 1 ip 10.21.0.10
```

### Configuring HSRP Text Authentication
```sh
Device(config)# interface GigabitEthernet 0/0/0
Device(config-if)# standby 1 priority 110
Device(config-if)# standby 1 preempt
Device(config-if)# standby 1 authentication text company2
Device(config-if)# standby 1 ip 10.21.0.10
```

### Configuring Multiple HSRP Groups for Load Balancing
> You can use HSRP or multiple HSRP groups when you configure load sharing. In the figure below, half of the clients are configured for Router A, and half of the clients are configured for Router B. Together, the configuration for Routers A and B establish two Hot Standby groups. For group 1, Router A is the default active router because it has the assigned highest priority, and Router B is the standby router. For group 2, Router B is the default active router because it has the assigned highest priority, and Router A is the standby router. During normal operation, the two routers share the IP traffic load. When either router becomes unavailable, the other router becomes active and assumes the packet-transfer functions of the router that is unavailable. The standby preempt interface configuration command is necessary so that if a router goes down and then comes back up, preemption occurs and restores load sharing.

Figure 4. HSRP Load Sharing Example  
![hsrp2](/assets/images/cisco/hsrp03.png)

> The following example shows Router A configured as the active router for group 1 with a priority of 110 and Router B configured as the active router for group 2 with a priority of 110. The default priority level is 100. Group 1 uses a virtual IP address of 10.0.0.3 and Group 2 uses a virtual IP address of 10.0.0.4.

### Router A Configuration
```sh
Router(config)# hostname RouterA
!
Router(config)# interface GigabitEthernet 0/0/0
Router(config-if)# ip address 10.0.0.1 255.255.255.0
Router(config-if)# standby 1 priority 110
Router(config-if)# standby 1 preempt
Router(config-if)# standby 1 ip 10.0.0.3
Router(config-if)# standby 2 preempt
Router(config-if)# standby 2 ip 10.0.0.4
```

### Router B Configuration
```sh
Router(config)# hostname RouterB
!
Router(config)# interface GigabitEthernet 0/0/0
Router(config-if)# ip address 10.0.0.2 255.255.255.0
Router(config-if)# standby 1 preempt
Router(config-if)# standby 1 ip 10.0.0.3
Router(config-if)# standby 2 priority 110
Router(config-if)# standby 2 preempt
Router(config-if)# standby 2 ip 10.0.0.4
```

### Improving CPU and Network Performance with HSRP Multiple Group Optimization
> The following example shows how to configure an HSRP client and master group:
```sh
Device(config)# interface GigabitEthernet 0/0/0
Device(config-if)# no shutdown
Device(config-if)# standby mac-refresh 30  
! Client Hello message interval
!
Device(config)# interface GigabitEthernet 0/0/1
Device(config-if)# no shutdown
Device(config-if)# ip vrf forwarding VRF2
Device(config-if)# ip address 10.0.0.100 255.255.0.0
Device(config-if)# standby 1 ip 10.0.0.254
Device(config-if)# standby 1 priority 110
Device(config-if)# standby 1 preempt
Device(config-if)# standby 1 name HSRP1   
!Server group
!
Device(config)# interface GigabitEthernet 0/0/2
Device(config-if)# no shutdown
Device(config-if)# ip vrf forwarding VRF3
Device(config-if)# ip address 10.0.0.100 255.255.0.0
Device(config-if)# standby 2 ip 10.0.0.254
Device(config-if)# standby 2 follow HSRP1   
! Client group
!
Device(config)# interface GigabitEthernet 0/0/3
Device(config-if)# no shutdown
Device(config-if)# ip vrf forwarding VRF4
Device(config-if)# ip address 10.0.0.100 255.255.0.0
Device(config-if)# standby 2 ip 10.0.0.254
Device(config-if)# standby 2 follow HSRP1   
! Client group
```
### Configuring HSRP Support for ICMP Redirect Messages
> Device A Configuration—Active for Group 1 and Standby for Group 2
```sh
Device(config)# interface GigabitEthernet 0/0/0
Device(config-if)# ip address 10.0.0.10 255.0.0.0
Device(config-if)# standby redirect
Device(config-if)# standby 1 priority 120 
Device(config-if)# standby 1 preempt delay minimum 20
Device(config-if)# standby 1 ip 10.0.0.1
Device(config-if)# standby 2 priority 105 
Device(config-if)# standby 2 preempt delay minimum 20
Device(config-if)# standby 2 ip 10.0.0.2
```

> Device B Configuration—Standby for Group 1 and Active for Group 2
```sh
Device(config)# interface GigabitEthernet 0/0/0
Device(config-if)# ip address 10.0.0.11 255.0.0.0
Device(config-if)# standby redirect
Device(config-if)# standby 1 priority 105 
Device(config-if)# standby 1 preempt delay minimum 20
Device(config-if)# standby 1 ip 10.0.0.1
Device(config-if)# standby 2 priority 120 
Device(config-if)# standby 2 preempt delay minimum 20
Device(config-if)# standby 2 ip 10.0.0.2
```

### Configuring HSRP Virtual MAC Addresses and BIA MAC Address
> In an Advanced Peer-to-Peer Networking (APPN) network, an end node is typically configured with the MAC address of the adjacent network node. In the following example, if the end nodes are configured to use 4000.1000.1060, HSRP group 1 is configured to use the same MAC address:
```sh
Device(config)# interface GigabitEthernet 0/0/0
Device(config-if)# ip address 10.0.0.1
Device(config-if)# standby 1 mac-address 4000.1000.1060
Device(config-if)# standby 1 ip 10.0.0.11
```

> In the following example, the burned-in address of Token Ring interface 3/0 will be the virtual MAC address mapped to the virtual IP address:
```sh
Device(config)# interface token 3/0
Device(config-if)# standby use-bia
```

> Note	
You cannot use the standby use-bia command and the standby mac-address command in the same configuration.
Example: Linking IP Redundancy Clients to HSRP Groups
The following example shows HSRP support for a static Network Address Translation (NAT) configuration. The NAT client application is linked to HSRP via the correlation between the name specified by the standby name command. Two devices are acting as HSRP active and standby, and the NAT inside interfaces are HSRP enabled and configured to belong to the group named “group1.”

### Active Device Configuration
```sh
Device(config)# interface BVI 10 
Device(config-if)# ip address 192.168.5.54 255.255.255.255.0 
Device(config-if)# no ip redirects 
Device(config-if)# ip nat inside 
Device(config-if)# standby 10 ip 192.168.5.30 
Device(config-if)# standby 10 priority 110 
Device(config-if)# standby 10 preempt 
Device(config-if)# standby 10 name group1 
Device(config-if)# standby 10 track Ethernet 2/1 
! 
! 
Device(config)# ip default-gateway 10.0.18.126 
Device(config)# ip nat inside source static 192.168.5.33 10.10.10.5 redundancy group1 
Device(config)# ip classless 
Device(config)# ip route 10.10.10.0 255.255.255.0 Ethernet 2/1 
Device(config)# ip route 172.22.33.0 255.255.255.0 Ethernet 2/1 
Device(config)# no ip http server 
```

### Standby Device Configuration
```sh
Device(config)# interface BVI 10 
Device(config-if)# ip address 192.168.5.56 255.255.255.255.0 
Device(config-if)# no ip redirects 
Device(config-if)# ip nat inside 
Device(config-if)# standby 10 priority 95 
Device(config-if)# standby 10 preempt 
Device(config-if)# standby 10 name group1 
Device(config-if)# standby 10 ip 192.168.5.30 
Device(config-if)# standby 10 track Ethernet 3/1 
Device(config-if)# exit 
Device(config)# ip default-gateway 10.0.18.126 
Device(config)# ip nat inside source static 192.168.5.33 3.3.3.5 redundancy group1
Device(config)# ip classless 
Device(config)# ip route 10.0.32.231 255.255.255 Ethernet 3/1 
Device(config)# ip route 10.10.10.0 255.255.255.0 Ethernet 3/1 
Device(config)# no ip http server 
```

### Configuring HSRP Version 2
> The following example shows how to configure HSRP version 2 on an interface with a group number of 350:
```sh
Device(config)# interface vlan 350
Device(config-if)# standby version 2
Device(config-if)# standby 350 priority 110 
Device(config-if)# standby 350 preempt 
Device(config-if)# standby 350 timers 5 15
Device(config-if)# standby 350 ip 172.20.100.10 
```

### Enabling SSO-Aware HSRP
> The following example shows how to set the redundancy mode to SSO. HSRP is automatically SSO-aware when this mode is enabled.
```sh
Device(config)# redundancy
Device(config-red)# mode sso
```

> If SSO HSRP is disabled using the no standby sso command, you can reenable it as shown in the following example:
```sh
Device(config)# interface GigabitEthernet 1/0/0
Device(config-if)# ip address 10.1.1.1 255.255.0.0
Device(config-if)# standby priority 200 
Device(config-if)# standby preempt
Device(config-if)# standby sso
```

### Enabling HSRP MIB Traps
> The following examples show how to configure HSRP on two devices and enable the HSRP MIB trap support functionality. As in many environments, one device is preferred as the active one. To configure a device’s preference as the active device, configure the device at a higher priority level and enable preemption. In the following example, the active device is referred to as the primary device. The second device is referred to as the backup device:

- Device A
```sh
Device(config)# interface GigabitEthernet 0/0/0
Device(config-if)# ip address 10.1.1.1 255.255.0.0
Device(config-if)# standby priority 200 
Device(config-if)# standby preempt
Device(config-if)# standby ip 10.1.1.3
Device(config-if)# exit
Device(config)# snmp-server enable traps hsrp
Device(config)# snmp-server host yourhost.cisco.com public hsrp
```

- Device B
```sh
Device(config)#interface GigabitEthernet 1/0/0
Device(config-if)# ip address 10.1.1.2 255.255.0.0
Device(config-if)#  standby priority 101
Device(config-if)# standby ip 10.1.1.3
Device(config-if)# exit
Device(config)# snmp-server enable traps hsrp
Device(config)# snmp-server host myhost.cisco.com public hsrp
```

### HSRP BFD Peering
> Hot Standby Router Protocol (HSRP) supports Bidirectional Forwarding Detection (BFD) as a part of the HSRP group member health monitoring system. Without BFD, HSRP runs as a process in a multiprocess system and cannot be guaranteed to be scheduled in time to service large numbers of groups with millisecond hello and hold timers. BFD runs as a pseudo-preemptive process and can therefore, be guaranteed to run when required. Only one BFD session between two devices can provide early failover notification for multiple HSRP groups.

> In the following example, the standby bfd and the standby bfd all-interfaces commands are not displayed. HSRP support for BFD is enabled by default when BFD is configured on a device or an interface by using the bfd interval command. The standby bfd and standby bfd all-interfaces commands are needed only if BFD has been manually disabled on a device or an interface.

- Device A
```sh
DeviceA(config)# ip cef
DeviceA(config)# interface FastEthernet2/0
DeviceA(config-if)#  no shutdown
DeviceA(config-if)# ip address 10.0.0.2 255.0.0.0
DeviceA(config-if)# ip router-cache cef
DeviceA(config-if)# bfd interval 200 min_rx 200 multiplier 3
DeviceA(config-if)# standby 1 ip 10.0.0.11
DeviceA(config-if)# standby 1 preempt
DeviceA(config-if)# standby 1 priority 110
DeviceA(config-if)# standby 2 ip 10.0.0.12
DeviceA(config-if)# standby 2 preempt
DeviceA(config-if)# standby 2 priority 110
```

- Device B
```sh
DeviceB(config)# interface FastEthernet2/0
DeviceB(config-if)# ip address 10.1.0.22 255.255.0.0
DeviceB(config-if)# no shutdown
DeviceB(config-if)# bfd interval 200 min_rx 200 multiplier 3
DeviceB(config-if)# standby 1 ip 10.0.0.11
DeviceB(config-if)# standby 1 preempt
DeviceB(config-if)# standby 1 priority 90
DeviceB(config-if)# standby 2 ip 10.0.0.12
DeviceB(config-if)# standby 2 preempt
DeviceB(config-if)# standby 2 priority 80
```