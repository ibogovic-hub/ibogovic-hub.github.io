---
title: sec service
layout: article
tags: linux
article_header:
  type: cover
---
# Event triggered script #

---

Purpose of this page is to explain how to configure SEC service to interact with DHCP event when new device is connected to the network
simple event correlator - MAN Page [HERE](https://simple-evcorr.github.io/man.html)
---

## sec - simple event correlator ##  

- **DESCRIPTION**  
SEC is an event correlation tool for advanced event processing which can be harnessed for event log monitoring, for network and security management, for fraud detection, and for any other task which involves event correlation.  
  
- **prerequisites**  
  - we need to install SEC `sudo apt install sec`  
  - run `sudo service sec restart && sudo service sec start` to make sure that service is up and running  
  
  - create file *.rules (in my case **dhcp.rules**) and for testing purposes file is located in ***/home/ivan/Documents/***  
  - "our" configuration file (more info about rules [HERE](https://simple-evcorr.github.io/man.html#lbAK)):  
  
```bash
type=SingleWithScript  
 ptype=RegExp  
 pattern=DHCPACK.*Switch  
 script=/home/ivan/Documents/logs/main-script.py  
 rem=after this rule has matched, continue from next rule  
 continue=TakeNext  
 desc=Check for something  
 action=logonly Check new switch  
  
type=SingleWithScript  
 ptype=RegExp  
 pattern=DHCPACK.*FS-S5850  
 script=/home/ivan/Documents/logs/compare.sh  
 continue=TakeNext  
 desc=Check Switch-config S5850  
 action=logonly check switch configuration S5850  
   
type=SingleWithScript  
 ptype=RegExp  
 pattern=DHCPACK.*FS-S3900  
 script=/home/ivan/Documents/logs/compare.sh  
 desc=Check Switch-config S3900  
 action=logonly check switch configuration S3900  
```

- this will check the pattern in the **dhcpd.log** file searching for 3 things  
  - if there is a new switch
  - if there is a existing switch with name FA-S5850  
  - if there is a existing switch with name FA-S3900
- when it finds it it will run our script  
- last thing that we need to do is edit SEC service so it reads the rule at boot.  
  - edit `sudo vim /etc/default/sec` and change ***"--conf"*** and ***"--input"*** as  `DAEMON_ARGS="--conf=/home/ivan/Documents/logs/dhcp.rules --input=/var/log/dhcpd.log --pid=/var/run/sec.pid --detach --syslog=daemon"`
  
## initialisation of SEC service ##  
  
- after editing the service and restarting it we can see that now it takes our created rules and monitoring the ***"dhcpd.log"*** file  
- now we just need to wait for service to be triggered  
  
## results of SEC service ##  
  
---

For every location we will have baseline configuration for every device - backup  
This file will be used to check if the configuration is changed or it is current.
---
  
### 1. first scenario: Existing Switch  

- We have a Switch already named **"FS-S5850-SRV"** and when we plug it in to the network SEC service should check the Switch configuration.  

  - Switch is connected to the network and requests te IP
  - When log entry appears (dhcpd.log) SEC service recognises the pattern ***"DHCPACK"*** + ***"FS-S5850"*** and triggers the script related to checking Switch current configuration.  
  - if the configuration is current log message is entered as: **Configuration OK**  
  - if the configuration doesn't match script to reconfiguration will be run.  
  
### 2. second scenario: New Switch  

- We receive new Switch and only task of the field engineer is to plug in the Switch per port map schema that will be provided for that purpose.  
  - new Switch brought to the site and plugged in
  - SEC service will be triggered by pattern in **"dhcph.log"** = ***"DHCPACK"*** + ***"Switch"***  

  - and we can confirm that everything is ok by looking at the log files or connecting to the Switch.  

  - we can see that I'm logged in with my account **xxxxxxx** and Switch name has changed.
