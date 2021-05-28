---
title: explicit proxy config
tags: Fortinet
---

## For enabling proxy

```bash
config web-proxy explicit
    set status enable
    set http-incoming-port 8080
end
```

## Setup authentication

```bash
config authentication scheme
    edit "ntlm"
        set method ntlm basic
        set user-database "server201" "server203" "server202" "server210" "server220" "local"
    next
    edit "fsso"
        set method fsso
    next
end
```

## Configure authentication

```bash
config authentication setting
    set active-auth-scheme "ntlm"
    set sso-auth-scheme "fsso"
end
```

## Configure proxy policy

```bash
config firewall proxy-policy
    edit 1
        set proxy explicit-web
        set dstintf "WAN"
        set srcaddr "group1" "group2"
        set dstaddr "all"
        set service "service"
        set action accept
        set status enable
        set schedule "always"
        set logtraffic all
        set groups "ProxyUsers" "group1"
        set webcache enable
        set utm-status enable
        set logtraffic-start enable
        set av-profile "test"
        set webfilter-profile "BasicWebAccess"
        set application-list "default"
        set profile-protocol-options "explicit_proxy"
        set ssl-ssh-profile "SSL-Cert-Inspection"
    next
end
```