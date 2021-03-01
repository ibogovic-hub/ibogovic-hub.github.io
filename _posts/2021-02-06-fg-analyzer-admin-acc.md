---
title: Analyzer and Manager "stuff"
layout: article
tags: Fortinet
article_header:
  type: cover
---

# Manager

## config admin acc Manager (ldap)

```bash
config system admin ldap 
    edit "xxxxxxxxxx" 
        set server "xxxxxxx" 
        set cnid "SamAccountName" 
        set dn "DC=xxxxxx,DC=xxxx" 
        set type regular 
        set username "CN=ldap,OU=Systemdienste,OU=ManagedUsers,OU=xxxx Group,DC=xxxxxxx,DC=xxxxxxl" 
        set password ENC xxxxxxxxxxxxxxxxxxxxxxxx
        set group "CN=xxxx,OU=xxx,OU=xxx,OU=xxx,DC=xxx,DC=local" 
        set filter "(&(objectcategory=group)(member=*))" 
        set attributes "member" 
            set adom "all_adoms" 
    next 
end
```
### diagnose commands

```bash
diagnose dvm check-integrity 
diagnose cdb check objcfg-integrity 
diagnose cdb check policy-assignment 
diagnose pm2 check-integrity all 
diagnose cdb check reference-integrity 
diagnose cdb check policy-packages 
diagnose cdb check adom-revision 
diagnose cdb check adom-integrity 

get system status 
get system performance 
execute top 
execute iotop 
diagnose fgfm session-list 
diagnose dvm device list 
diagnose debug crashlog read (Crash logs)
```

# Analyzer

## config admin acc on analyzer (ldap)  

```bash
config system admin ldap 
    edit "servername" 
        set server "some IP" 
        set cnid "SamAccountName" 
        set dn "DC=xxxx,DC=xxx" 
        set type regular 
        set username "CN=ldap,OU=xxxxx,OU=xxxxxx,OU=xxxxxxxxxx,DC=xxxxxx,DC=xxxx" 
        set password ENC xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx 
        set group "CN=xxxxxxxxxxxx,OU=xxxxxxxxxxxx,OU=xxxxxxxxxxxx,OU=xxxxxxxxxxxx,DC=xxxxxxxxxxxx,DC=xxxxxxxxxxxx" 
        set filter "(&(objectcategory=group)(member=*))" 
        set attributes "member" 
            set adom "all_adoms" 
    next 
end
```

## reset settings on Analyzer

```
execute reset all-settings 
execute reset all-except-ip erase all except IP and routes 
execute format disk 
```