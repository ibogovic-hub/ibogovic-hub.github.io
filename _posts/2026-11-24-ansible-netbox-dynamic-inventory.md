---
title: "Stop hand-editing hosts.ini: Ansible inventory straight from NetBox"
tags: Automation
---

Every team I have worked with that runs Ansible against more than a few dozen devices ends up with the same problem: two sources of truth. NetBox (or a spreadsheet pretending to be NetBox) says one thing, and the `hosts.ini` in the automation repo says another. A switch gets decommissioned in NetBox, but it stays in the inventory, so the nightly playbook fails on it for three weeks and everyone learns to ignore the red line. A new site comes online, someone forgets to add it to the right group, and it misses the next compliance push.

The fix is not discipline. The fix is to stop keeping a second list. The `netbox.netbox` collection ships an inventory plugin that builds the Ansible inventory at runtime from the NetBox API. NetBox becomes the only place where you add, remove or regroup devices.

## The minimal setup

Install the collection and its Python dependency on the control node:

```bash
ansible-galaxy collection install netbox.netbox
python3 -m pip install pynetbox
```

Then create an inventory file. The filename must end in `netbox.yml` or `netbox.yaml`, otherwise the plugin will not claim it:

```yaml
# inventory/prod.netbox.yml
plugin: netbox.netbox.nb_inventory
api_endpoint: https://netbox.example.internal
validate_certs: true
config_context: false
interfaces: false
flatten_custom_fields: true

query_filters:
  - status: active
  - has_primary_ip: true

device_query_filters:
  - role: access-switch
  - role: distribution-switch
  - role: edge-router

group_by:
  - site
  - device_roles
  - platforms

compose:
  ansible_network_os: platform.slug
  ansible_host: primary_ip4.address | ansible.utils.ipaddr('address')
```

The API token comes from the `NETBOX_TOKEN` environment variable. Do not put it in the YAML file; that file belongs in git.

```bash
export NETBOX_TOKEN="$(pass show netbox/ansible-ro)"
ansible-inventory -i inventory/prod.netbox.yml --graph
```

`--graph` is the first thing to run. It shows you the group tree exactly as Ansible will see it, and it is the fastest way to discover that half your devices have no platform assigned.

## The details that matter

**Filter on status and primary IP.** Without `status: active`, planned and decommissioned devices land in the inventory and your playbooks try to reach them. Without `has_primary_ip: true`, you get hosts with no address, and Ansible falls back to resolving the device name through DNS, which may or may not work and will fail in confusing ways.

**Map the platform slug to `ansible_network_os`.** If your NetBox platform slugs are `cisco.ios.ios`, `cisco.nxos.nxos` and so on, the `compose` line above means no per-group `ansible_network_os` variable is needed. If your slugs are something like `ios-xe`, either rename them or add a mapping in `group_vars/platforms_ios-xe.yml`. I prefer renaming: one less layer to debug.

**Strip the prefix length.** `primary_ip4.address` comes back as `10.20.0.5/24`. SSH will not accept that. The `ipaddr('address')` filter cuts it down; it needs the `ansible.utils` collection and the `netaddr` Python package.

**Groups are generated names.** `group_by: [site]` produces groups like `site_zrh1`. Your existing playbooks probably target `zurich` or `[core]`. Either rewrite the `hosts:` lines once, or keep a small static file next to the dynamic one that defines parent groups:

```ini
# inventory/zz-aliases.ini
[core:children]
device_roles_distribution-switch
device_roles_edge-router
```

Point Ansible at the whole directory (`-i inventory/`) and both sources merge. The files load in alphabetical order, so the static aliases must sort after the NetBox file, hence the prefix.

**Cache it.** The plugin makes several API calls per run. With a few thousand devices and ad-hoc commands, that adds noticeable latency and load on NetBox. Enable the built-in cache:

```yaml
cache: true
cache_plugin: jsonfile
cache_connection: ~/.cache/ansible-netbox
cache_timeout: 900
```

Fifteen minutes is a reasonable compromise. Run `ansible-inventory --flush-cache` when you have just added a device and want it now.

## Use a read-only token

The inventory only needs read access. Create a dedicated NetBox user with view permissions on DCIM and IPAM, issue a token for it, and mark the token read-only. If the automation host is compromised, the attacker gets a device list, not the ability to rewrite your source of truth.

## Guard against an empty inventory

The failure mode that bites hardest: NetBox is down or the token expired, the plugin returns zero hosts, and the scheduled playbook reports success because it ran against nothing. Add a pre-flight check to scheduled jobs:

```bash
count=$(ansible-inventory -i inventory/ --list | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["_meta"]["hostvars"]))')
if [ "$count" -lt 50 ]; then
  echo "inventory has only $count hosts, refusing to run" >&2
  exit 1
fi
```

Set the threshold to something sensibly below your real fleet size. A green run against an empty inventory is worse than a red one.

## Why this matters

Inventory drift is boring until it is the reason a security fix did not reach a site, or a playbook pushed config to a box that was supposed to be gone. In my experience the second list always rots, no matter how good the team is, because updating it is nobody's real job. Moving the inventory into NetBox makes the device lifecycle one action in one place, and it forces the data quality problems (missing platforms, missing IPs, wrong roles) into the open, where they get fixed instead of worked around.
