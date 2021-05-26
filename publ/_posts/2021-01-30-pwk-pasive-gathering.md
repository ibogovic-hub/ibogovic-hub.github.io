---
title: passive gathering
layout: article
tags: PWK
article_header:
  type: cover
---


## WHOIS

```bash
whois megacorpone.com | less
whois IP | less
```

## GOOGLE HACKING

### ***(<https://www.exploit-db.com/google-hacking-database>)***  

```bash
site:megacorpone.com
filetype:php
-filetype:html
intitle:"index of" "parent directory"
```

## NETCRAFTING

## ***(<https://www.netcraft.com/>) <https://searchdns.netcraft.com/>***

## RECON-NG

> marketplace serarch github

```bash
<https://github.com/lanmaster53/recon-ng-marketplace/wiki/API-Keys>
```

```bash
marketplace info recon/domain-hosts/google_site_web
marketplace install recon/domain-hosts/google_site_web
marketplace load recon/domain-hosts/google_site_web
info
options set SOURCE megacorpone.com
run
show  hosts
marketplace info recon/hosts-hosts/resolve
marketplace install recon/hosts-hosts/resolve
marketplace load recon/hosts-hosts/resolve
info
run
show hosts
```

## OPEN-SOURCE CODE
- GITHUB  
• filename:users
- SHODAN  
• hostname:megacorpone.com  
- SECURITY HEADERS SCANNER  
• <https://securityheaders.com>  
- SSL SERVER TEST  
• <https://www.ssllabs.com/ssltest>  
- PASTEBIN  
• <https://pastebin.com>  

## user information gathering  

- EMAIL HARVESTING  
• theharvester -d megacorpone.com -b google  

- PASSWORD DUMPS  
• rockyou.txt  

- SOCIAL MEDIA TOOLS  
• social-searcher ( <https://www.social-sercher.com> )  
• site-specific tools  
    ◇ <https://digi.ninja/projects/twofi.php> - for generating twiter word list  
    ◇ <https://github.com/initstring/linkedin2username>  
- STACK OVERFLOW  <https://osinthframework.com>
- MALTEGO  
• <https://www.paterva.com/index.php>  
