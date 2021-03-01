---
title: create ldap accounts
layout: article
tags: Fortinet
article_header:
  type: cover
---

## reset settings on Analyzer

```
execute reset all-settings 
execute reset all-except-ip erase all except IP and routes 
execute format disk 
```

## config admin acc (ldap)

```bash
# on manager
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

# on analyzer 
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