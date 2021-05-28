---
title: processes
tags: PWK
---


## background process

```bash
ping -c 400 localhost > ping_results.txt &

ctrl + Z → suspends the current job
bg        → brings the job back
```

## check the running job

```bash
ping -c 400 localhost > ping_results.txt &
ctrl + Z
find / -name sbd.exe

→ jobs = lists all current jobs
→ fg %1 = takes the job under the number 1 to the foreground

ps -ef → list all processes and full formating
ps -fC → gets the process

kill <pid>
```
