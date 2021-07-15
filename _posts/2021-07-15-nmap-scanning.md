---
title: nmap scanning
tags: nmap
---

## basic scan of one IP
nmap 192.168.1.1

## basic scan of subnet
nmap 192.168.1.0/24

## create and scan from a file
nmap -iL test.txt

## random scan and exclude IP
nmap -iR 50

### exclude IP
nmap 192.168.1.0/24 --exclude 192.168.1.100

## export results to a file
### txt
nmap 192.168.1.0/24 -oN /root/output.txt

### xml 
nmap 192.168.1.0/24 -oX /root/output.xml

### grepable file
nmap 192.168.1.0/24 -oG /root/output

### all format export
nmap 192.168.1.0/24 -oA /root/output