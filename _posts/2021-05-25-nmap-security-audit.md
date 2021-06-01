---
title: nmap security audit
tags: nmap
---

## **tcp flags**

--> **Synchronization flag (SYN flag)**
```
a packet with SYN flag set to 1 is sent to initiate a connection to a host as per classical 3-way handshake model.  
```

--> **Acknowledgement flag (ACK flag)**
```
a packet with ACK flag set to 1 serves as a confirmation of getting the packets from sender
```

--> **Push flag (PSH flag)**
```
when PSH is set to 1, the sending application will inform that the data is to be sent immediately and on  
the receiving end the TCP header will inform that data is to be pushed to the application immediately
```

--> **Urgent flag (URG flag)**
```
this flag is used to inform the receiving station about a certain segment of data to be prioritized.
The URG flag isn't much applied in most modern applications
```
--> **Reset flag (RST flag)**
```
when this flag bit is set to 1 by sender the ongoing connection breaks up
```

--> **Finished flag (FIN flag)**
```
when this flag is set to 1 it actually means that sender has finished sending all  
data and the last packet contains the FIN flag.
```

## **understanding nmap results**

- in this example scan:


![Port status](/assets/images/nmap/initial-scan.png)  

### **port status description**  

| status | description |
| ----------- | ----------- |
| **open** | application is actively responding to the connections |
| **closed** | the port that responds to nmap probes but has no active service running |
| **filtered** | nmap can't determine whether the port is open because packet filters / firewall is preventing the probes from reaching to target port |
| **unfiltered** | the port is accessible, but nmap is unable to determine if port is opened or closed |
| **open / filtered** | when an open port does not give any response, nmap is unable to determine the port state. may be a firewall might blocking the probes |
| **closed / filtered** | in case nmap is unable to determine if port is closed or filtered |

## **nmap scan types**

### TCP SYN scan
***syntax:***
```
sudo nmap -sS <host/network/domain>
```
  - it is default scan type
  - it never completes the TCP handshake and so it is relatively faster and unobtrusive (***Half-Open scan***)  

--> here is the example of TCP SYN scan:  
![TCP SYN scan](/assets/images/nmap/tcp-syn-scan.png)  

### TCP CONNECT scan
***syntax:***
```
sudo nmap -sT <host/network/domain>
```
  - default type when TCP SYN scan is unavailable
  - nmap is asking the operating system to initiate the connection to the remote machine
  - this scan option is performing the full TCP 3 way handshake with the remote system and it takes more time compared to SYN scan
  - connection requests are logged on the remote end  

--> here is the example of TCP CONNECT scan:  
![TCP CONNECT scan](/assets/images/nmap/tcp-conn-scan.png)  

### FIN, NULL, XMAS scans
***syntax:***
```
: FIN scan
sudo nmap -sF <host/network/domain>

: NULL scan
sudo nmap -sN <host/network/domain>

: XMAS scan
sudo nmap -sX <host/network/domain>
```  
--> here is the example of mentioned scans:
![FIN scans](/assets/images/nmap/fin.png)
![NULL scans](/assets/images/nmap/null.png)
![XMAS scans](/assets/images/nmap/xmas.png)

- it is useful for firewall avoidance
- sending the packets without bit set

You can use switch ***`--reason`*** to get more info about the port result

**Null scan (-sN)**
- Does not set any bits (TCP flag header is 0)

**FIN scan (-sF)**
- Sets just the TCP FIN bit.

**Xmas scan (-sX)**
- Sets the FIN, PSH, and URG flags, lighting the packet up like a Christmas tree.

- These three scan types are exactly the same in behavior except for the TCP flags set in probe packets.
- If a RST packet is received, the port is considered closed, while no response means it is open / filtered.
- The port is marked filtered if an ICMP unreachable error (type 3, code 0, 1, 2, 3, 9, - 10, or 13) is received.

- The key advantage to these scan types is that they can sneak through certain - non-stateful firewalls and packet filtering routers.
- Another advantage is that these scan types are a little more stealthy than even a SYN scan.
- Don't count on this thoug, most modern IDS products can be configured to detect them.
- The big downside is that not all systems follow RFC 793 to the letter.  A number of systems send RST responses to the probes regardless of whether the port is open or not.  
- This causes all of the ports to be labeled closed.
- Major operating systems that do this are Microsoft Windows, many Cisco devices, BSDI, - and IBM OS/400.
- This scan does work against most Unix-based systems though.
- Another downside of these scans is that they can't distinguish open ports from certain - filtered ones, leaving you with the response open / filtered.

[source](https://nmap.org/book/man-port-scanning-techniques.html)

### UDP scan
***syntax:***
```
sudo nmap -sU -p <port> <host/network/domain>
```
  - this scan uses UDP protocol and useful to scan for devices with UDP services running
  - well-known services running on UDP like:
    - DNS (port 53)
    - SNMP (ports 161 / 162)
    - DHCP (ports 67 / 68)
  - UDP scan can be done along with TCP scan
  - note that UDP scanning is time consuming and has to be used by specifying ports  

--> here is the example of mentioned scan:  
![UDP scan](/assets/images/nmap/udp-scan.png)  

### SCTP init scan
***syntax:***
```
sudo nmap -sY <host/network/domain>
```
  - SCTP (Stream Control Transmission Protocol) designed to transport Public Telephone Network (PSTN) signaling messages over IP networks
  - as per [rfc4960](https://datatracker.ietf.org/doc/html/rfc4960) this has wider applications
  - this is relatively newer alternative to TCP and UDP protocols with newer features and characteristics of TCP & UDP
  - like SYN scan it is stealth as it never completes the full handshake  

--> here is the example of mentioned scan:  
![SCTP scan](/assets/images/nmap/sctp-scan.png)  

### other interesting nmap scans

| scan type | option | description |
| - | - | - |
| TCP ACK scan | -sA | useful for mapping firewall rulesets & tests for firewall statefulness and check for ports filtering status |
| TCP Maimon scan | -sM | similar to NULL, FIN and XMAS scan except the probe is FIN/ACK. In such situations the response from remote systems should be RST for open or closed port. But some BSD based systems simply drop the packets if port is open |
| IP protocol scan | -sO | allows us to determine which IP protocols (TCP, UDP, ICMP, IGMP etc...) are supported by remote system |

--> ACK scan (difference with SYN scan):  
![ACK scan](/assets/images/nmap/ack-scan.png)  

## operating system detection
- the nmap-os-db database has more than 2600+ known OS fingerprints
- nmap performs extensive TCP ISN(Initial Sequence Numbers) sampling combined with various other parameters from the response and maps it with it database to give out details about the remote OS.
- it is very useful for determining vulnerability of target hosts, tailoring exploits, network inventory & support, detecting unauthorized devices.

## Host discovery
- to scan every port of every IP address is rather unnecessary, inefficient & waste of time.
- with proper host discovery for a target network we can narrow down our scope to the devices to be tested.
- discovering hosts sometimes can be straightforward or complex, depending on the network being audited.
- nmap offers lots of possible options for host discovery.
- apart from the most basic ICMP pings, nmap employs different combination of TCP SYN/ACK UDP, SCTP INIT, ARP probes to locate hosts on a network.

| Option | Information | Example syntax |
| - | - | - |
| -sL (list scan) | lists out each hos on the network with a reverse DNS resolution without sending any packet to the target host | nmap -sL <network_range> |
| -sn (no port scan) | tells nmap not to perform any port scan after host discovery. This is also known as "ping scan". In older versions of nmap known as -sP | nmap -sn <network_range> |
| -Pn (no ping) | nmap will skip the host discovery phase and directly start an active port scan against all the IPs in the range without confirming if the host is available or not. We ca skip the ping & port scan by using the options -sn & -Pn together | nmap -Pn <target_IP/range> |
| -PS <port_list> | TCP SYN ping - sends an empty TCP packet with SYN flag set to default port 80. Alternate ports can be specified if needed | nmap -PS <target_IP/range> or nmap -PS 22,21,53 <target_range> |
| -PA <port_list> | TCP ACK ping - similar to the TCP SYN ping. Only difference is that the TCP packet with ACK flag is set and sent. Probes with both -PS & -PA can be sent | nmap -PA <target_IP/range> or nmap -PA 21,22,53 <target_IP/range> or nmap -PS -PA <target_IP/range> |
| -PU <port_list> | UDP ping - sends and empty UDP packet to port 40125. Such scan can bypass firewalls with strict TCP based filtering | nmap -PU <target_IP/range> |
| -PE / -PP / -PM | ICMP ping - by default, nmap send icmp type 8 (echo request) pings to discover hosts. Other options with different ICMP types can also be sent if ICMP type 8 is blocked | nmap -sn -PE <target_IP> or namp -sn -PP <target_IP> or nmap -sn -PM <target_IP> |

### other useful options

| Option | Information | Example syntax |
| - | - | - |
| --disable-arp-ping | additional option - nmap does ARP neighbor discovery of locally connected ethernet hosts, irrespective of any options provided. This option has to be explicitly used if we need to disable ARP-ND (neighbor discovery) | nmap -sn -PE <target_IP> --disable-arp-ping |
| --traceroute | trace route to host - works with all scan types except for -sT (connect scan) & -sl (idle scan) | nmap -sS <target_IP> --traceroute |
| -n | no DNS resolution - tells nmap to not do DNS resolution on discovered hosts | nmap -PS -sn -n <target_IP> |
| -R | do DNS resolution - this option will "always" perform a resolution against a discovered host | nmap -PS -sn -R <target_IP> |
| --dns-servers server1,server2,...,serv... | use specified DNS servers - to speed up scans, we can explicitly set the use of DNS servers and bypassing the default system resolvers | nmap -PS -sn -R <target_IP> --dns-servers 8.8.8.8,1.1.1.1 |

## nmap scripts

- syntax example:
  - sbm vulnerability  
  ***syntax:***
    ```
    sudo nmap --script smb-vuln-ms17-010 -p 445 192.168.56.104
    ```
    ![smb-script](/assets/images/nmap/script-smb.png)

  - VSFTPD & UnrealIRCD backdoor check  
  ***syntax:***
    ```
    sudo nmap -sV --script ftp-vsftpd-backdoor -p 21 192.168.56.103
    ```
    - vsftpd
    ![vsftpd-script](/assets/images/nmap/scan-vsftpd.png)
    ***syntax:***
    ```
    sudo nmap -sV --script ftp-vsftpd-backdoor -p 6667 192.168.56.103
    ```
    - vsftpd
    ![vsftpd-script](/assets/images/nmap/scan-irc.png)  

- here is the nmap script [source website](https://nmap.org/book/nse-scripts-list.html).

- and useful guide [here](https://securitytrails.com/blog/nmap-scripts-nse) from securitytrails.

**scripts can be found locally**
- ***/usr/share/nmap/scripts/***
- ***/usr/share/nmap/nselib/***

## SQL server auditing

- some user and database data is required for this
- this command will list all databases on SQL server

### list databases
***syntax:***
```
nmap -p 3306 --script mysql-databases --script-args mysqluser=root,mysqlpass=password 192.168.56.103
```
![sql-databases-scan](/assets/images/nmap/scan-sql-databases.png)

### list users
***syntax:***
```
nmap -p 3306 --script mysql-users --script-args mysqluser=root,mysqlpass=password 192.168.56.103
```
![sql-users-scan](/assets/images/nmap/scan-sql-users.png)

### bruteforcing the credencials on sql server
***syntax:***
```
nmap -p 3306 --script mysql-brute 192.168.56.103
```
![sql-brute-scan](/assets/images/nmap/scan-sql-brute.png)

- cis script for security audit of sql configuration
### SQL security audit
***syntax:***
```
nmap -p 3306 --script mysql-audit --script-args mysql-audit.username=root,mysql-audit.password=password,mysql-audit.filename=/usr/share/nmap/nselib/data/mysql-vis.autit 192.168.56.103
```
![sql-audit-scan1](/assets/images/nmap/scan-sql-audit01.png)
![sql-audit-scan2](/assets/images/nmap/scan-sql-audit02.png)
![sql-audit-scan3](/assets/images/nmap/scan-sql-audit03.png)

## SMTP server audit
### open SMTP server check
- we will be performing SMTP server security audit
- first one is to check SMTP open server which is high security issue.

***syntax:***
```
nmap -sV -p 25 --script smtp-open-relay 192.168.56.103
```
![smtp-audit01](/assets/images/nmap/scan-smtp-audit01.png)

### SMTP user enumeration
- next one is user enum script that performs enumeration of existing users on SMTP server

***syntax:***
```
nmap -p 25 smtp-enum-users --script-args smtp-enum-users.method=VRFY,smtp-enum-users.domain=metasploitable.localdomain 192.168.56.103
```
![smtp-audit01](/assets/images/nmap/scan-smtp-audit02.png)

## advanced script scans
- next one is scanning port 80 with all scripts that are in the category "not exploit"  
***syntax***
```
sudo nmap -sV --script "not exploit" -p 80 192.168.56.103
```
--> this will provide huge amount of information
 