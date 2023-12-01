---
title: Journalctl commands
tags: Linux
---

> collection of useful commands

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
[journalctl - ref HERE](https://linuxhandbook.com/journalctl-command/)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

## check logs for speciffic time
---

```
journalctl --since "2023-01-19 14:00:00" --until "2023-01-19 15:00:00"
journalctl -u salt-master.service --since="2023-04-10" --until="2023-04-11"
```
### Display only N recent lines of journal logs
```
journalctl -n 25
```
### Show journal logs in real time
```
journalctl -f
```
### Show only kernel messages with -k
```
journalctl -k
```
### Filter journal logs for a specific systemd service
```
# Filtering is a strong point of journal logs. You can filter logs based on the systemd services.
journalctl -u <service_name>
journalctl -u ssh
```
### Show messages from a particular boot session
```
# The journalctl command allows you to access logs belonging to a specific boot session using the option -b.
# You can list all the boot sessions with --list-boots flag.
journalctl --list-boots
```

### Filter logs for a certain time interval
```
journalctl -S-10h - last 10 hours
journalctl --since=yesterday --until=now
```

### You can also specify date or date time combination:
```
journalctl --since "2020-07-10"
```

### You can also specify a time period with the dates and time:
```
journalctl --since "2020-07-10 15:10:00" --until "2020-07-12"
```

### Show only errors in logs with journalctl
```
journalctl -p 3 -xb
-p 3 : filter logs for priority 3 (which is error)
-x : provides additional information on the log (if available)
b : since last boot (which is the current session)
```
### This table lists all the priority levels.
Priority | Code
---
0	| emerg
1	| alert
2	| crit
3	| err
4	| warning
5	| notice
6	| info
7	| debug

### You can also display logs for a range of severity. For example, if you want to see all the warning, notice and info logs from the current session, you can use:
```
journalctl -p 4..6 -b0
```
### Check how much disk space logs are taking
```
journalctl --disk-usage
```

[journal cleanup - ref HERE](https://linuxhandbook.com/clear-systemd-journal-logs/)

### First thing you should do is to rotate journal files. This will mark the currently active journal logs as archive and create fresh new logs. It’s optional but a good practice to do so.
```
sudo journalctl --rotate
```

### Clear journal log older than x days
```
# Let’s say you want to keep the log history of just two days. To delete all entries older than two days, use this command:
sudo journalctl --vacuum-time=2d
```

### Here’s what the output may look like:
```
Vacuuming done, freed 1.6G of archived journals from /var/log/journal/1b9ab93094fa4978beba80fd3c48a18c
```

### Restrict logs to a certain size
```
# Another way is to restrict the log size. This will delete the journal log files until the disk space taken by journal logs falls below the size you specified.
sudo journalctl --vacuum-size=100M
```

### This will reduce the log size to around 100 MB.
```
Vacuuming done, freed 40.0M of archived journals from /var/log/journal/1b9ab93094fa4978beba80fd3c48a18c.
```