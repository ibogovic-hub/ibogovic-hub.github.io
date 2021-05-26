---
title: practical examples
layout: article
tags: PWK
article_header:
  type: cover
---


## find all domain pages and corresponding IP's

wget www.megacorpone.com

> - extract all links from the file

```bash
grep “href=” index.html

grep “href=” index.html | grep “\.megacorpone” | grep -v “www\.megacorpone\.com” | head
```

> - extract more exact data from the file with awk  

```bash
grep “href=” index.html | grep “\.megacorpone” | grep -v “www\.megacorpone\.com” | awk -F “http://” ‘{print $2}’
```

> - then cut all after the sign / after the domain name  

```bash
grep “href=” index.html | grep “\.megacorpone” | grep -v “www\.megacorpone\.com” | awk -F “http://” ‘{print $2}’ | cut -d “/” -f 1
```

> - grep the file with defined regex  

```bash
grep -o ‘[^/]*\.megacorpone\.com’ index.html | sort -u > list.txt
```

> - get the IP's for all dns names  

```bash
for url in $(cat list.txt); do host $url; done
```

> - get the IP's for all dns names and save the IP's in a file  

```bash
for url in $(cat list.txt); do host $url; done | grep “has address” | cut -d “ ” -f 4 | sort -u
```

## search the exploit and download it

```bash
searchsploit afd windows -w -t
(-t = tytle, -w = link)
```

> - download all exploits locally as a file  

```bash
#! /bin/bash
# bash script to search for a given exploit and download all matches

for e in $(searchsploit afd windows -w -t | grep http | cut -f 2 -d “|” )

do
    exp_name=$(echo $e | cut -d “/" -f 5)
    url=$(echo $e | sed ‘s/exploits/raw/’)
    wget -q --no-check-certificate $url -O $exp_name
done
```

## example 3

> - create temp folder for the scan
> - scan for only open ports on the subnet  

```bash
sudo nmap -A -p80 --open 10.11.1.0/24 -oG nmap-scan_10.11.1.1-254
```

> - extract all IP's from the file  

```bash
cat nmap-scan_10.11.1.1-254 | grep 80 | grep -v “Nmap”
```

> - show only IP's  

```bash
cat nmap-scan_10.11.1.1-254 | grep 80 | grep -v “Nmap” | awk ‘{print $2}’
```

> - go trough IP's and capture screenshot with “cutycapt”  

```bash
for ip in $(cat nmap-scan_10.11.1.1-254 | grep 80 | grep -v “Nmap” | awk ‘{print $2}’); do cutycapt --url=$ip --out=$ip.png: done
```

> - add all .png files to html file for examination  

```bash
#! /bin/bash
# Bash script to examine the scan results through HTML

echo “<HTML><BODY><BR>” > web.html

ls -l *.png | awk -F : ‘{ print $1":\n<BR><IMG SRC=\""$1""$2"\" width=600><BR>"}’ >> we.html

echo “</BODY></HTML>” >> web.html
```
