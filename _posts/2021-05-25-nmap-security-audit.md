---
title: nmap security audit
layout: article
tags: nmap
article_header:
  type: cover
---

---
## tcp flags

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
when PSH is set to 1, the sending application will inform that the data is to be sent immediately and on the receiving end the TCP header will inform that data is to be pushed to the application immediately
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
when this flag is set to 1 it actually means that sender has finished sending all data and the last packet contains the FIN flag.
```