---
title: ipv6 and ospfv3
layout: article
tags: CCNP
article_header:
  type: cover
---

![GNS3-config](/assets/images/Cisco/ipv6-and-ospfv3.png)

## configure OSPFv3 on routers  

[R1-config](/assets/images/Cisco/ipv6-and-ospfv3-r1.txt)  
[R2-config](/assets/images/Cisco/ipv6-and-ospfv3-r2.txt)  
[R3-config](/assets/images/Cisco/ipv6-and-ospfv3-r3.txt)  
[R4-config](/assets/images/Cisco/ipv6-and-ospfv3-r4.txt)  

```bash
conf t
ipv6 unicast-routing
interface s2/0
ipv6 ospf 1 area 10
exit
ipv6 router ospf 1
router-id 0.0.0.1
end
```
