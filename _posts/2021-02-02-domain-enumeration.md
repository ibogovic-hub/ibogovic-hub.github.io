---
title: Domain Enumeration
layout: article
tags: PWK
article_header:
  type: cover
---

## to get users from a domain

```cmd
net user /domain
net user <username> /domain
```

## get groups from a domain

```cmd
net  group /domain
```

## get current domain with Powershell

```powershell
[System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
```
