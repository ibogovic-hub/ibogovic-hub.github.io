---
title: ntp and ca config
layout: article
tags: CCNP
article_header:
  type: cover
---

![GNS3-confg](/assets/images/Cisco/ntp-ca.png)

## R2 → as the CA Server

# Sync the time first / Set local time zone

```
conf t

clock timezone CET 1
clock summer-time PDT recurring
end
```

## Set clock close to current date

```
clock set 15:00:00 Jan 25 2021
```

## Sync to Internet Time Server / Lookup on www.pool.ntp.org

```
conf t
server 80.127.119.186
end
```

## Wait until time is sync'd

```
show ntp status
```

## Config CA Server

```
conf t
ip http server
ip domain-name ibogovic.net

crypto key generate rsa general-keys modulus 4096 exportable

crypto pki server The-CA-Server
grant auto
```

## You will need to enter a password after the no shutdown

```
no shut

exit
```

## Optional → enroll R2 with itself

```
crypto pki trustpoint My_CA
enrolment url http://10.0.0.2:80
revocation-check none
exit

crypto pki authenticate My_CA
crypto pki enroll My_CA
```

## R1 → as the NTP Client  

## Sync the time first / Set local time zone

```
conf t

clock timezone CET +1
clock summer-time PDT recurring
end
```

## Set clock close to current date

```
clock set 15:00:00 Jan 25 2021

conf t
ntp server 10.0.0.2
end
```

## Wait until sync

```
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

## show certificate

```
show crypto ca certificate My_CA
```
