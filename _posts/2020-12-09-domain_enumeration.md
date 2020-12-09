---
title: cmd & powershell
tags: oscp
article_header:
  type: cover
---

---
## section contains commands for domain enumeration that I'm collecting  


## to get users from a domain

- net user /domain
- net user ***username*** /domain

## get groups from a domain

- net  group /domain

## get current domain with Powershell

- [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()

