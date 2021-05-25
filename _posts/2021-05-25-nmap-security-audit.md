---
title: nmap security audit
layout: article
tags: nmap
article_header:
  type: cover
---

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

### - TCP SYN scan (`-sS`)
  - it is default scan type
  - it never completes the TCP handshake and so it is relatively faster and unobtrusive (***Half-Opnen scan***)  

--> here is the example of TCP SYN scan:  
![TCP SYN scan](/assets/images/nmap/tcp-syn-scan.png)  

### - TCP CONNECT scan (`-sT`)
  - default type when TCP SYN scan is unavailable
  - nmap is asking the operating system to initiate the connection to the remote machine
  - this scan option is performing the full TCP 3 way handshake with the remote system and it takes more time compared to SYN scan
  - connection requests are logged on the remote end  

--> here is the example of TCP CONNECT scan:  
![TCP CONNECT scan](/assets/images/nmap/tcp-conn-scan.png)  

- FIN, NULL, XMAS scans (`-sF` - FIN scan, `-sN` - NULL scan, `-sX` - XMAS scan)
  - 
- UDP scan
- SCTP init scan