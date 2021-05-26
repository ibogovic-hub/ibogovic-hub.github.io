---
title: File & Process monitoring
layout: article
tags: PWK
article_header:
  type: cover
---

## to check the file as it gets edited

```bash
sudo tail -f /var/log/apache2/access.log
```

## every 2 sec by default but could be tweaked

```bash
watch -n 5 w
```

## downloading

```bash
wget -O <name> <link>
curl -o <name> <link>
axel -a -n 20 -o <name> <link>
```
