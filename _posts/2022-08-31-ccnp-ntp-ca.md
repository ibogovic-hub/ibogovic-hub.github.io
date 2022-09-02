---
title: ntp and CA
tags: Cisco
---

## NTP Cisco configuration

### check the time
```sh
show clock
```
### manualy set the time on a device
```sh
set clock 16:00:00 31 August 2022
```

### Configure Timezone & Daylight Saving Time
```sh
conf t
  clock timezone CET 1
  clock summer-time PDT recurring
end
```
### Sync to Internet Time Server / Lookup on www.pool.ntp.org

```sh
conf t
  server 80.127.119.186
end
```
### set the router as Stratum 1
```sh
conf t
  ntp master 1
```

### point the router to master NTP
```sh
conf t
  ntp server <IP_Addess>
```

### configure NTP peer
```sh
conf t
  ntp peer <peer_IP>
```
## Config CA Server

```sh
conf t
  ip http server
  ip domain-name ibogovic.net
  crypto key generate rsa general-keys modulus 4096 exportable
  crypto pki server The-CA-Server
  grant auto
```

- You will need to enter a password after the no shutdown

```sh
no shut
exit
```

### Optional → enroll R2 with itself

```sh
  crypto pki trustpoint My_CA
  enrolment url http://10.0.0.2:80
  revocation-check none
exit

  crypto pki authenticate My_CA
  crypto pki enroll My_CA
```
### Wait until sync

```sh
  show ntp status
  conf t
  ip domain-name ibogovic.net

  crypto key generate rsa modulus 4096
  crypto pki trustpoint My_CA
  enrollment url http://10.0.0.2:80
  revocation-check none
exit

  crypto pki authenticate My_CA
  crypto pki enroll My_CA
end
```

### show certificate

```sh
show crypto ca certificate My_CA
```
