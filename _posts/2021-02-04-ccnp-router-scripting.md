---
title: router scripting
tags: CCNP
---

## TCL Script:

```bash
tclsh
foreach ipaddr {
 10.1.1.1
 10.1.1.2
 10.1.1.3
 10.1.1.4
 10.1.1.1
 10.1.1.2
 10.1.1.3
} { ping $ipaddr}
```

> tclsh ping.tcl

## EEM Script:

```bash
event manager applet GIG0_DOWN
 event syslog pattern "Interface GigabitEthernet0/0, changed state to administratively down" period 1
 action 1.0 cli command "enable"
 action 2.0 cli command "config terminal"
 action 3.0 cli command "interface g0/0"
 action 4.0 cli command "shutdown"
 action 5.0 cli command "no shutdown"
 action 6.0 syslog msg "What's going on? GIG 0/0 went down!"
!
end
```

> debug event manager action cli

## Linux Shell Script:

```bash
for x in 1 2 3
 do
 ping 10.1.1.$x
 done
 
function testping(){
 ping 10.1.1.1
  ping 10.1.1.2
  ping 10.1.1.3
  ping 10.1.1.4
}

 
function testecho(){
 echo 10.1.1.1
  echo 10.1.1.2
  echo 10.1.1.3
  echo 10.1.1.4
}
```