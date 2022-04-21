---
title: troubleshooting commands
tags: Linux
---

>some commands that are usefull

```sh
# general log viewing
journalctl -xn
--> n
    - Show the most recent journal events and limit the number of events shown / default 10 lines
--> x
    - Augment log lines with explanation texts from the message catalog.  
    This will add explanatory help texts to log messages in the output where this is available

# to get the logs from speciffic unit/service
journalctl -u <unit/service>
    - Show messages for the specified systemd unit UNIT (such as a service unit), or for any of the units matched by PATTERN

# get the logs related to boot events
journalctl -b
    - Show messages from a specific boot. This will add a match for "_BOOT_ID=".
    - The argument may be empty, in which case logs for the current boot will be shown.

# get the latest logs and follow
journalctl -f
    - Show only the most recent journal entries, and continuously print new entries as they are appended to the journal

# get the logs from specified time
journalctl --since '10 min ago'
    - Start showing entries on or newer than the specified date, or on or older than the specified date, respectively.  
    Date specifications should be of the format "2012-10-30 18:17:16". If the time part is omitted, "00:00:00" is assumed.  
    If only the seconds component is omitted, ":00" is assumed.  
    If the date component is omitted, the current day is assumed.  Alternatively the strings "yesterday", "today", "tomorrow" are understood, which refer to 00:00:00 of the day before the current day, the current day, or the day after the current day, respectively. "now" refers to the current time.  
    Finally, relative times may be specified, prefixed with "-" or "+", referring to times before or after the current time, respectively.
```
[ref-page](https://manpages.org/journalctl)