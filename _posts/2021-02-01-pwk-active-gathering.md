---
title: Actve Gathering
tags: PWK
---

## DNS ENUMERATION

- interacting with DNS server  

```bash
host www.megacorpone.com
host -t mx www.megacorpone.com
host -t txt www.megacorpone.com
```

- automating lookups  

- create list of typical hostnames (www | ftp | mail | owa | proxy | router)  

```bash
for ip in $(cat list.txt); do host $ip.megacorpone.com; done
```

- reverse lookup brute force  

```bash
for ip in $(seq 50 100); do host 38.100.193.$ip; done | grep -v “not found”
```

- dns zone transfer  
- contains all dns servers  

```bash
host -t ns megacorpone.com
host -l megacorpone.com ns1.megacorpone.com
```

- list of the nameservers from a domain

```bash
#! /bin/bash

# simple zone transfer bash script
# $1 is the first argument given after the bash script
# check if argument was given, if not, print usage

if [ -z “$1” ]; then
    echo “[*] simple zone transfer script”
    echo “[*] usage     : $0 <domain name> ”
    exit 0
fi

# if the argument was given, identify the DNS servers for the domain  

for server in $(host -t ns $1 | cut -d “ ” -f 4); do
    # for each of these servers, attempt a zone transfer
    host -l $1 $server | grep “has address”
done
```
