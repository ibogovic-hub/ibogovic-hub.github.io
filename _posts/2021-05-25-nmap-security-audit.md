---
title: nmap security audit
layout: article
tags: nmap
article_header:
  type: cover
aside:
  toc: true
sidebar:
  nav: layouts
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

- in this example ports 80 and 81 are being scanned:


![Port status](/assets/images/nmap/initial-scan.png)  

### **port status description**  

| status | description |
| ----------- | ----------- |
| **open** | appllication is actively responding to the connections |
| **closed** | the port that responds to nmap probes but has no active service running |
| **filtered** | nmap can't determine whether the porti is open because packet filters / firewall is preventing the probes from reaching to target port |
| **unfiltered** | the port is accessible, but nmap is unable to determine if port is opened or closed |
| **open / filtered** | whan an open port does not give any response, nmap is unable to determine the port state. may be a firewall might blocking the probes |
| **closed / filtered** | in case nmap is unable to determine if port is closed or filtered |

## **nmap scan types**

### TCP SYN scan
***syntax:***
```
sudo nmap -sS <host/network/domain>
```
  - it is default scan type
  - it never completes the TCP handshake and so it is relatively faster and unobtrusive (***Half-Opnen scan***)  

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
![FIN, NULL and XMAS scans](/assets/images/nmap/fin-null-xmas.png)

- it is usefull for firewall avoidance
- sending the packets without bit set

You can use switch ***`--reason`*** to get more info about the port result

**Null scan (-sN)**
- Does not set any bits (TCP flag header is 0)

**FIN scan (-sF)**
- Sets just the TCP FIN bit.

**Xmas scan (-sX)**
- Sets the FIN, PSH, and URG flags, lighting the packet up like a Christmas tree.
  
```
These three scan types are exactly the same in behavior except for the TCP flags set in probe packets.  
If a RST packet is received, the port is considered closed, while no response means it is open|filtered.  
The port is marked filtered if an ICMP unreachable error (type 3, code 0, 1, 2, 3, 9, 10, or 13) is received.

The key advantage to these scan types is that they can sneak through certain non-stateful firewalls and packet filtering routers.  
Another advantage is that these scan types are a little more stealthy than even a SYN scan.  
Don't count on this though—most modern IDS products can be configured to detect them.  
The big downside is that not all systems follow RFC 793 to the letter.  A number of systems send RST responses to the probes regardless of whether the port is open or not.  
This causes all of the ports to be labeled closed.  
Major operating systems that do this are Microsoft Windows, many Cisco devices, BSDI, and IBM OS/400.  
This scan does work against most Unix-based systems though.  
Another downside of these scans is that they can't distinguish open ports from certain filtered ones, leaving you with the response open|filtered.
```  
[source](https://nmap.org/book/man-port-scanning-techniques.html)

### UDP scan
***syntax:***
```
sudo nmap -sU -p <port> <host/network/domain>
```
  - this scan uses UDP protocol and usefull to scan for devices with UDP services running
  - well-known services running on UDP like:
    - DNS (port 53)
    - SNMP (ports 161 / 162)
    - DHCP (ports 67 / 68)
  - UDP scan can be done along with TCP scan
  - note that UDP scanning is time cunsuming and has to be used by specifying ports  

--> here is the example of mentioned scan:  
![UDP scan](/assets/images/nmap/udp-scan.png)  

### SCTP init scan
***syntax:***
```
sudo nmap -sY <host/network/domain>
```
  - SCTP (Stream Control Transmission Protocol) designed to transport Public Telephone Network (PSTN) signaling messages over IP netowrks
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

