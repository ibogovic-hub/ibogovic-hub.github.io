---
title: mac address conflict
tags: Fortinet
---

- Changing the HA group ID to avoid MAC address conflicts 

- Change the Group ID to change the virtual MAC address of all cluster interfaces. You can change the Group ID from the FortiGate CLI using the following command:

```bash
config system ha 
set group-id <id_integer> 
end 
```

## Example topology

The topology below shows two clusters. The Cluster_1 internal interfaces and the Cluster_2 port 1 interfaces are both connected to the same broadcast domain. In this topology the broadcast domain could be an internal network. Both clusters could also be connected to the Internet or to different networks.

> Example HA topology with possible MAC address conflicts:

