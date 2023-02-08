---
title: bgp route tagging
tags: Fortinet
---

>> some commands and configurations related to bgp  

## general comma

- show router bgp
- show router route-map
- get router info bgp community-info (to check all communities configured)
- get router info bgp community 64550:2000
- get router info bgp summary

## spoke side config

```
config neighbor-group
    edit “advpn01-spokes
        ...
        set remote-as 64550
        set route-map-out “rm-tag-routes”
        set additional-path both
    next
```

## branch side config

```
config router bgp
    set as 64550
    set router-id 10.73.50.200
    set ibgp-multipath enable
    set additional-path enable
    config neighbor
        edit “192.168.200.1”
            set soft-reconfiguration enable
            set remote as 64550
            set route-map-in “rm-tag-routes-in”
            set additional-path both
            set adv-additional-path 4
        next
        edit “192.168.201.1”
            set soft-reconfiguration enable
            set remote as 64550
            set route-map-in “rm-tag-routes-in”
            set additional-path both
            set adv-additional-path 4
        next
    end
    config network
        edit 1
            set prefix x.x.x.x x.x.x.x
        next
        edit 2
            set prefix x.x.x.x x.x.x.x
        edit 3
            set prefix x.x.x.x x.x.x.x
        next
        edit 4
            set prefix x.x.x.x x.x.x.x
        next
    end
end
```

## route-map

```
config router route-map
    edit “rm-tag-routes-in”
        config rule
            edit 1
                set match-community “inbound-communities”
                unset set-ip-nexthop
                unset set-ip6-nexthop
                unset set-ip6-nexthop-local
                unset set-originator-id
                set set-route-tag 2000
            next
        end
    next
end
```

## community list

```
config router community-list
    edit “inbound-communities”
        config rule
            edit 1
                set action permit
                set match “64550:2000”
            next
        end
    next
end
```

## clear bgp sessions

```
exec router clear bgp ip <neighbour_ip>
```

## sd-wan config

```
config system sdwan
    config service
        edit 1
            set name “best_path_datacenter”
            set mode priority
            set route-tag 2000
            set health-check “datacenter_ping”
            set link-cost-threshold 50
            set priority-members 1 4
        next
    end
end
```

## debug commands

- diag sys sdwan route-tag-list
- diag sys sdwan service