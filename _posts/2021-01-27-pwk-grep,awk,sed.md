---
title: grep, awk & sed
layout: article
tags: PWK
article_header:
  type: cover
---

## prvih par redova u logu

```bash
head -n 10 neki.log
```

## pokazati koliko ima riječi

```bash
wc -l neki.log
```

## extract IP add from the file

- log output  | space del print 1 field | count how many

```bash
cat neki.log | cut -d “ ” -f 1 | sort -u | uniq -c | sort -urn
```

## extract GET request

```bash
cat neki.log | grep ‘IP-Add’ | cut -d “\”" -f 2 | uniq -c
```

## grep the log for word “admin”

```bash
cat neki.log | grep ‘IP add’ | grep ‘/admin ’ | sort -u
```

## reverse search all except ‘admin’

```bash
cat neki.log | grep ‘IP add’ grep -v ‘/admin ’
```
