---
title: GLBP
tags: Cisco
---

> Customizing GLBP Configuration

```sh
Device(config)# interface fastethernet 0/0
Device(config-if)# ip address 10.21.8.32 255.255.255.0
Device(config-if)# glbp 10 timers 5 18
Device(config-if)# glbp 10 timers redirect 1800 28800
Device(config-if)# glbp 10 load-balancing host-dependent
Device(config-if)# glbp 10 priority 254
Device(config-if)# glbp 10 preempt delay minimum 60
Device(config-if)# glbp 10 client-cache maximum 1200 timeout 245
```
- Example: Configuring GLBP MD5 Authentication Using Key Strings
The following example shows how to configure GLBP MD5 authentication using a key string:

```sh
Device(config)# interface Ethernet 0/1
Device(config-if)# ip address 10.0.0.1 255.255.255.0
Device(config-if)# glbp 2 authentication md5 key-string ThisStringIsTheSecretKey
Device(config-if)# glbp 2 ip 10.0.0.10
```

- Example: Configuring GLBP MD5 Authentication Using Key Chains
In the following example, GLBP queries the key chain “AuthenticateGLBP” to obtain the current live key and key ID for the specified key chain:

```sh
Device(config)# key chain AuthenticateGLBP
Device(config-keychain)# key 1
Device(config-keychain-key)# key-string ThisIsASecretKey
Device(config-keychain-key)# exit
Device(config-keychain)# exit
Device(config)# interface Ethernet 0/1
Device(config-if)# ip address 10.0.0.1 255.255.255.0
Device(config-if)# glbp 2 authentication md5 key-chain AuthenticateGLBP
Device(config-if)# glbp 2 ip 10.0.0.10
```

- Example: Configuring GLBP Text Authentication

```sh
Device(config)# interface GigabitEthernet 0/0/0
Device(config-if)# ip address 10.21.8.32 255.255.255.0
Device(config-if)# glbp 10 authentication text stringxyz
Device(config-if)# glbp 10 ip 10.21.8.10
```

- Example: Configuring GLBP Weighting
In the following example, the device is configured to track the IP routing state of the POS interface 5/0/0 and 6/0/0, an initial GLBP weighting with upper and lower thresholds is set, and a weighting decrement value of 10 is set. If POS interface 5/0/0 and 6/0/0 go down, the weighting value of the device is reduced.

```sh
Device(config)# track 1 interface POS 5/0/0 ip routing
Device(config)# track 2 interface POS 6/0/0 ip routing
Device(config)# interface fastethernet 0/0/0
Device(config-if)# glbp 10 weighting 110 lower 95 upper 105
Device(config-if)# glbp 10 weighting track 1 decrement 10
Device(config-if)# glbp 10 weighting track 2 decrement 10
Device(config-if)# glbp 10 forwarder preempt delay minimum 60
```

- Example: Enabling GLBP Configuration
In the following example, the device is configured to enable GLBP, and the virtual IP address of 10.21.8.10 is specified for GLBP group 10:

```sh
Device(config)# interface GigabitEthernet 0/0/0
Device(config-if)# ip address 10.21.8.32 255.255.255.0
Device(config-if)# glbp 10 ip 10.21.8.10
```

### SUMMARY STEPS
1. enable 
2. configure terminal 
3. interface type number 
4. ip address ip-address mask [secondary] 
5. glbp group ip [ip-address [secondary]] 
6. exit 
7. show glbp [interface-type interface-number] [group] [state] [brief] 