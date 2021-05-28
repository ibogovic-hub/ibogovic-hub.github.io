---
title: port scanning
tags: PWK
---

## tcp scanning

> simplest tcp scanning is usualy called "connect scan" and relies on a 3-way tcp hand shake mechanism

- filter for wireshark so we can capture only interesting traffic

![Wireshark](/assets/images/pwk/wireshark-capture.png)

```bash
host 10.11.0.18 and not arp
```

- now we can run netcat scan on speciffic ports

```bash
nc -nvv -w 1 -z 10.11.1.220 3388-3390
```
> ***-w*** --> specifies the conneciotn timeout in seconds  
> ***-z*** --> specifies the zero I/O mode and used for scanning

- inspect the wireshark traffic

## udp scanning

- since upd is stateless it uses different scanning mechanism

```bash
nc -nv -u -z -w 1 10.11.1.115 160-162
```

> ***-u*** --> specifies the udp scan

## port scanning with nmap

- default nmap scan will scan 1000 most known ports
- to examine the traffic generated with the scan we can create two iptable rules

```bash
sudo iptables -I INPUT 1 10.11.1.220
```
