---
title: ipv6 and ospfv3
tags: Cisco
---

![GNS3-config](/assets/images/Cisco/ipv6-and-ospfv3.png)

## configure OSPFv3 on routers  


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
