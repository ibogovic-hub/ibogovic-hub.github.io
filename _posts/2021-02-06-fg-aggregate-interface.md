---
title: aggregate interface
layout: article
tags: Fortinet
article_header:
  type: cover
---

## web-based manager

1. Go to Network > Interface and select Create New > then Interfaces
2. Enter the Name as Aggregate.
3. For the Type, select 802.3ad Aggregate.

- If this option does not appear, your FortiGate unit does not support aggregate interfaces.

4. In the Physical Interface Members click to add interfaces, select port 4, 5 and 6.
5. Select the Addressing Mode of Manual.
6. Enter the IP address for the port of eq. 10.13.101.100/24.
7. For Administrative Access select HTTPS and SSH.
8. Select OK.

## To create aggregate interface - CLI

```
config system interface
edit Aggregate
set type aggregate
set member port4 port5 port6
set vdom root
set ip 172.20.120.100/24
set allowaccess https ssh
end
```
