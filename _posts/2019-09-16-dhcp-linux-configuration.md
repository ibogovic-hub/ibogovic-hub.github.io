---
title: linux dhcp config
tags: Linux
---

# DHCP config for testing purposes #

* platform used: *4.9.0-9-amd64 #1 SMP Debian 4.9.168-1+deb9u4 (2019-07-19) x86_64 GNU/Linux*

1. first we need to install *dhcp* and *vlan* packages
copy paste the code:  

```bash
sudo apt install isc-dhcp-server vlan
```

2. now we need to edit two files that will allow us to use dhcp ***isc-dhcp-server* file and *dhcpd.conf* file**

## *isc-dhcp-server*
### isc-dhcp-server

```bash
sudo vim /etc/default/isc-dhcp-server
```

* in my case I'm using **enp0s31f6** interface..  

```bash
# Defaults for isc-dhcp-server (sourced by /etc/init.d/isc-dhcp-server)

# Path to dhcpd's config file (default: /etc/dhcp/dhcpd.conf).
#DHCPDv4_CONF=/etc/dhcp/dhcpd.conf
#DHCPDv6_CONF=/etc/dhcp/dhcpd6.conf

# Path to dhcpd's PID file (default: /var/run/dhcpd.pid).
#DHCPDv4_PID=/var/run/dhcpd.pid
#DHCPDv6_PID=/var/run/dhcpd6.pid

 #Additional options to start dhcpd with.
# Don't use options -cf or -pf here; use DHCPD_CONF/ DHCPD_PID instead
OPTIONS=""

# On what interfaces should the DHCP server (dhcpd) serve DHCP requests?
# Separate multiple interfaces with spaces, e.g. "eth0 eth1".
INTERFACESv4="enp0s31f6"
INTERFACESv6=""
```

## *dhcp.conf*  

```bash
sudo vim /etc/dhcp/dhcpd.conf
```

* here we need to declare all networks that we are going to use.

* in my case I'm using 172.100.100.0/24 as my ***default VLAN***
* 172.100.10.0/24 as ***VLAN 10***  
* 172.100.20.0/24 as ***VLAN 20***  

```bash
# dhcpd.conf
#
# Sample configuration file for ISC dhcpd
#

# option definitions common to all supported networks...
option domain-name "something.local";
option domain-name-servers 8.8.8.8, 8.8.4.4;

default-lease-time 600;
max-lease-time 7200;

# The ddns-updates-style parameter controls whether or not the server will
# attempt to do a DNS update when a lease is confirmed. We default to the
# behavior of the version 2 packages ('none', since DHCP v2 didn't
# have support for DDNS.)
ddns-update-style none;
deny duplicates;

subnet 172.100.100.0 netmask 255.255.255.0 {
interface enp0s31f6;

option routers 172.100.100.1;
option domain-name-servers 172.100.100.1;
option subnet-mask 255.255.255.0;
option broadcast-address 172.100.100.255;
authoritative;
pool{
        range 172.100.100.10 172.100.100.15;
}
}


#VLAN - 10

subnet 172.100.10.0 netmask 255.255.255.0 {
        option routers 172.100.10.1;
        option subnet-mask 255.255.255.0;
        option broadcast-address 172.100.10.255;
        authoritative;
        pool {
                range 172.100.10.100 172.100.10.150;
        }
}

#VLAN - 20

subnet 172.100.20.0 netmask 255.255.255.0 {
        option routers 172.100.20.1;
        option subnet-mask 255.255.255.0;
        option broadcast-address 172.100.20.255;
        authoritative;
        pool {
                range 172.100.20.100 172.100.20.150;
        }
}

# If this DHCP server is the official DHCP server for the local
# network, the authoritative directive should be uncommented.
authoritative;

# Use this to send dhcp log messages to a different log file (you also
# have to hack syslog.conf to complete the redirection).
log-facility local7;

# No service will be given on this subnet, but declaring it helps the
# DHCP server to understand the network topology.

---output omitted---
```
  
* if you want to enable logging it is necessary to uncomment line <64>  
`#log-facility local7;`  

* edit the line in **rsyslog.conf and create log file**  
--> `sudo vim /etc/rsyslog.conf` - add `local7.* /var/log/dhcpd.log*`  
--> `touch /var/log/dhcpd.log` - change permissions `sudo chmod 777 /var/log/dhcpd.log`  

3. next step is to configure local interface to support **vlan tagging**  
we already installed vlan package at the beginning, so now we need to assign IP's and VLAN's to the interfaces:  
--> add this lines to your networks file:  
  
```bash
iface enp0s31f6.10 inet static
    address 172.100.10.1
    netmask 255.255.255.0
    vlan-raw-device enp0s31f6

iface enp0s31f6.20 inet static
    address 172.100.20.1
    netmask 255.255.255.0
    vlan-raw-device enp0s31f6
```  

--> or copy paste this way (edit subnets and interfaces per your requirements):  

```bash
sudo ip addr add 172.100.10.1/24 dev enp0s31f6.10
sudo ip addr add 172.100.20.1/24 dev enp0s31f6.20
```
  
--> **enable vlan tagging on virtual interfaces**  

```bash
sudo vconfig add enp0s31f6 10
sudo vconfig add enp0s31f6 20
```
  
* I have USB and PCI network so I had to disable my USB network:  

```bash
sudo ifconfig enxc8f750a56483 172.100.100.1 down
```

--> now bring all your interfaces up:  

```bash
sudo ifconfig enp0s31f6 172.100.100.1 up
sudo ifconfig enp0s31f6.10 172.100.10.1 up
sudo ifconfig enp0s31f6.20 172.100.20.1 up
```
  
4. now you are ready to enable isc-dhcp-server and start the service:  

```bash
sudo /lib/systemd/systemd-sysv-install enable isc-dhcp-server
sudo service isc-dhcp-server start
```
<!--more-->
