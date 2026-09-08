---
title: When your Ansible network playbook silently ignores group_vars
tags: Automation
---

A playbook that had worked for months against a lab of IOL nodes started failing with authentication errors after I split the inventory into a proper directory layout. Same credentials, same devices, same tasks. The only change was moving `ansible_user` and `ansible_password` out of the inventory file and into `group_vars/routers.yml`, which is what every style guide tells you to do.

The failure message was the usual unhelpful one:

```
fatal: [r29]: FAILED! => {"msg": "Authentication failed."}
```

Running with `-vvvv` showed the connection plugin attempting to log in with no username at all. `ansible-inventory --list` showed the variables present and correctly scoped. So the vars existed, Ansible could see them, and the task still did not get them.

The cause is where the variables get resolved. With `connection: network_cli`, the connection is established by the persistent connection process (`ansible-connection`) before the task's variable context is fully applied in the way you expect for a normal `ssh` connection. If your inventory source is a plugin, a dynamic script, or a directory whose `group_vars` are discovered relative to a path Ansible resolves differently than you assume, the connection-level vars can end up empty while task-level vars look fine. In my case the inventory was passed as `-i inventory/lab.yml` while `group_vars/` lived beside `ansible.cfg`, not beside the inventory file. Ansible loads `group_vars` from two places: adjacent to the playbook and adjacent to the inventory source. Adjacent to `ansible.cfg` is neither.

The fix that is portable across all of these cases is to stop relying on implicit discovery for anything the connection plugin needs, and load it explicitly:

```yaml
- name: Configure lab switches
  hosts: routers
  gather_facts: false
  connection: network_cli
  vars:
    ansible_network_os: ios

  pre_tasks:
    - name: Load device credentials explicitly
      ansible.builtin.include_vars:
        file: "{{ playbook_dir }}/group_vars/routers.yml"
      no_log: true

  tasks:
    - name: Push interface description
      cisco.ios.ios_config:
        lines:
          - description MGMT - do not shut
        parents: interface Ethernet3/0
      register: cfg

    - name: Show what changed
      ansible.builtin.debug:
        var: cfg.updates
      when: cfg.changed
```

`include_vars` runs as a task, in the play's variable scope, at a precedence level (task vars) that beats almost everything else. Once the credentials are set there, the persistent connection picks them up on first use.

Two things are worth doing alongside this. First, verify your assumptions instead of trusting the directory layout:

```bash
ansible-inventory -i inventory/lab.yml --host r29 | jq 'keys'
ansible routers -i inventory/lab.yml -m debug -a 'var=ansible_user'
```

The first command tells you what the inventory layer knows. The second tells you what a task actually sees. If those two disagree, you have a discovery problem, not a credentials problem, and no amount of retyping the password will help.

Second, pin the inventory in `ansible.cfg` so the discovery path is unambiguous for everyone who runs the repo:

```ini
[defaults]
inventory = ./inventory/lab.yml
host_key_checking = False
interpreter_python = auto_silent

[persistent_connection]
command_timeout = 60
connect_timeout = 60
```

With `inventory` set in config, `group_vars/` next to that inventory file is found reliably whether the playbook is invoked from the repo root or from a CI runner with a different working directory. That single line removes an entire class of "works on my laptop" reports.

One related trap in the same family: on IOL images a lot of Layer 2 configuration simply is not present. `switchport`, `vtp`, and `vlan` commands fail outright. If your role is shared between real switches and lab nodes, guard those tasks or set `ignore_errors: true` on the L2 block, otherwise a variable fix will just move you to the next red wall of text.

Why this matters: network automation failures almost never announce themselves as configuration problems. They announce themselves as authentication problems, timeouts, or unreachable hosts, and every one of those pushes an engineer toward the wrong hypothesis. I have watched people rotate TACACS credentials over a `group_vars` path issue. The habit worth building is to distinguish "what does the inventory contain" from "what does the task receive" before touching anything on the device side. Two commands, thirty seconds, and it saves you from making a change to production identity infrastructure to fix a problem that lives entirely in your repo layout.
