---
title: hardening
tags: Cisco
---

## steps to harden your device


### Create an Enable Secret Password

```sh
conf t
enable secret nekipass # first create an “enable secret” password
```
### Encrypt Passwords on the device„

```sh
service password-encryption
```

### Use an external AAA server for User Authentication (radius)

```sh
enable secret nekipass #Create first an “enable secret” password
aaa new-model # Enable the AAA service
aaa authentication login default group radius enable # Use RADIUS for authentication with “enable” password as fallback
radius-server host 192.168.1.10 # assign the internal AAA server 
radius-server key ‘secret-key’ # secret key configured on AAA server
ine vty 0 4  
login authentication default # Apply AAA authentication to VTY lines (Telnet, SSH etc)
exit
line con 0 # Apply AAA authentication to console port
login authentication default
```

### Create separate local accounts for User Authentication

```sh
username john-admin secret pass1
username david-admin secret pass2
username mary-admin secret pass3
```

### Configure Maximum Failed Authentication Attempts

```sh
config terminal
username john-admin secret somesecret
aaa new-model
aaa local authentication attempts max-fail 5  # max 5 failed login attempts
aaa authentication login default local
```

### Restrict Management Access to the devices to specific IPs only

```sh
config terminal
access-list 10 permit 192.168.1.0 0.0.0.15
line vty 0 15
access-class 10 in  # Apply IP restrictions to all VTY lines (for Telnet or SSH)
```

### Enable Logging

```sh
config terminal
logging trap 6  # Enable logging level 6 for logs sent to external server
logging buffered 5  # Enable logging level 5 for logs stored locally in buffer
service timestamps log datetime msec show-timezone  # Include timestamps in logs with millisecond precision
logging host 192.168.1.2 # Send logs to external log server
logging source-interface ethernet 1/0  # Use Eth1/0 to send log messages
```

### Enable Network Time Protocol (NTP)

```sh
config terminal
ntp server 1.1.1.1
ntp server 2.2.2.2
```

### Use Secure Management Protocols if possible

```sh
config terminal
hostname London
ip domain-name mydomain.com
ip ssh version 2
crypto key generate rsa modulus 2048
ip ssh time-out 60
ip ssh authentication-retries 3 
line vty 0 15
transport input ssh
```

### Restrict and Secure SNMP Access

```sh
config terminal
access-list 11 permit 192.168.1.0 0.0.0.15
access-list 12 permit 192.168.1.1
snmp-server community somecommunityname RO 11 # Create Read Only (RO) community string and use ACL 11 to allow SNMP access
snmp-server community Xcv4#56&454sdS RW 12 # Create Read Write (RW) community string and use ACL 12 to allow SNMP access
```


## Hardening phase
### Configure AAA service:
```sh
aaa new-model
```

### Configure AAA Authentication for Login:
```sh
aaa authentication login default local-case
```

### Configure AAA Authentication for Enable Mode:
```sh
aaa authentication enable default enable
```

### Configure AAA Authentication for Local Console Line:
```sh
line console 0
login authentication default
exit
```

### Configure AAA Authentication for VTY Lines:
```sh
line vty 0 4
login authentication default
exit
line vty 5 15
login authentication default
exit
```

### Set and secure passwords:
```sh
service password-encryption
enable secret 0 <password>
```

## Configure Local User and Encrypted Password:
```sh
username <username> password <password>
Note: Use the following syntax for version after 12.0(18)S, 12.1(8a)E, 12.2(8)T:
username <username> secret <password>
```

### Configure SSH:
```sh
hostname <device_hostname>
domain-name <domain-name>
crypto key generate rsa modulus 2048
```

### Configure SSH for Remote Device Access:
```sh
ip ssh timeout 60
ip ssh authentication-retries 3
```

### Configure VTY Transport SSH:
```sh
line console 0
transport input ssh
exit
line vty 0 4
transport input ssh
exit
line vty 5 15
transport input ssh
exit
```

### Configure Timeout for Login Sessions:
```sh
line vty 0 4
exec-timeout 5 0
exit
line vty 5 15
exec-timeout 5 0
exit
```

### Disable Auxiliary Port:
```sh
line aux 0
no exec
exec-timeout 0 10
transport input none
exit
```

### Disable SNMP server (in-case not in use):
```sh
no snmp-server

# Disable SNMP Community Strings private and public:
no snmp-server community private
no snmp-server community public
```

### Configure Clock Timezone – GMT:
```sh
clock timezone GMT <hours>
```

### Disable Router Name and DNS Name Resolution (in-case not in use):
```sh
no ip domain-lookup
```

### Disable CDP Run Globally:
```sh
no cdp run
```

### Disable PAD service (in-case not in use):
```sh
no service pad
```

### Disable Finger Service:
```sh
no service finger
```

### Disable Maintenance Operations Protocol (MOP):
```sh
interface <interface-id>
no mop enabled
exit
```

### Disable DHCP server (in-case not in use):
```sh
no service dhcp
```

### Disable IP BOOTP server (in-case not in use):
```sh
no ip bootp server
```

### Disable Identification Service:
```sh
no identd
```

### Disable IP HTTP Server (in-case not in use):
```sh
no ip http server
```

### Disable Remote Startup Configuration:
```sh
no boot network
no service config
```

### Configure TCP keepalives Services:
```sh
service tcp-keepalives-in
service tcp-keepalives-out
```

### Disable small-servers:
```sh
no service tcp-small-servers
no service udp-small-servers
```

### Disable TFTP Server:
```sh
no tftp-server
```

### Configure Logging:
```sh
logging on
logging buffered 16000
logging console critical
```

### Configure Service Timestamps for Debug and Log Messages:
```sh
service timestamps debug datetime msec show-timezone localtime
service timestamps log datetime msec show-timezone localtime
```

### Disable IP source-route:
```sh
no ip source-route
```

### Disable Directed Broadcast:
```sh
interface <interface-id>
no ip directed-broadcast
exit
```

### Configure Unicast Reverse-Path Forwarding:
```sh
interface <interface-id>
ip verify unicast reverse-path
exit
```

### Disable IP Proxy ARP:
```sh
interface <interface-id>
no ip proxy-arp
exit
```

### Disable Gratuitous-Arps:
```sh
no ip gratuitous-arps
```

### Configure switch port-security:
```sh
switchport port-security
switchport port-security violation shutdown
switchport port-security maximum 1
switchport port-security mac-address sticky
```
