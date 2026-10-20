---
title: "Catching config drift with Ansible check mode before it catches you"
tags: Automation
---

A change window goes sideways at 02:00. The playbook that worked last month now fails halfway through, because someone added a manual ACL entry on three routers during an incident and never wrote it back to the source of truth. The playbook didn't break. The assumption that devices matched the repo broke, and nobody noticed for weeks.

Drift like this is the normal state of a network that humans can still touch. The fix is not to ban CLI access. It is to make drift visible on a schedule, cheaply, without changing anything.

## Check mode plus diff is a drift detector

Most Ansible network resource modules (`cisco.ios.ios_acls`, `ios_interfaces`, `ios_vlans`, and similar) support `check_mode` and `diff`. Run with `state: merged` or `state: replaced` in check mode and the module computes what it *would* push, without pushing it. If the result reports `changed: true`, the device has drifted from your intended state.

That gives you a read-only audit that uses the exact same data and logic as your deployment playbook. No second tool, no parallel model of the network to keep in sync.

```yaml
# drift_check.yml
- name: Detect ACL and interface drift
  hosts: ios_routers
  gather_facts: false
  connection: ansible.netcommon.network_cli
  check_mode: true
  diff: true

  pre_tasks:
    - name: Load intended state explicitly
      ansible.builtin.include_vars:
        dir: "host_vars/{{ inventory_hostname }}"

  tasks:
    - name: Compare ACLs against intended state
      cisco.ios.ios_acls:
        config: "{{ acls }}"
        state: replaced
      register: acl_result

    - name: Compare interfaces against intended state
      cisco.ios.ios_interfaces:
        config: "{{ interfaces }}"
        state: replaced
      register: intf_result

    - name: Record drift per host
      ansible.builtin.set_fact:
        drifted: "{{ acl_result.changed or intf_result.changed }}"
        drift_commands: "{{ (acl_result.commands | default([])) + (intf_result.commands | default([])) }}"

  post_tasks:
    - name: Write drift report
      ansible.builtin.copy:
        dest: "reports/drift-{{ inventory_hostname }}.txt"
        content: "{{ drift_commands | join('\n') }}\n"
      delegate_to: localhost
      check_mode: false
      when: drifted | bool
```

Two details matter here. First, the `copy` task overrides `check_mode: false`, because you actually want the report on disk while everything else stays dry. Second, the `include_vars` in `pre_tasks` is deliberate: with `network_cli` in some setups the expected `host_vars` are not picked up the way you assume, and a drift check that silently compares against an empty variable set will happily report "replace everything". Load intended state explicitly and fail loudly if it is missing.

## Choosing the state carefully

`state: merged` only tells you that something you defined is missing or different. It will not notice extra entries someone added by hand. `state: replaced` and `state: overridden` will, because they compute what must be removed to match the intended config. For drift detection that is exactly what you want, and since nothing is pushed, the usual danger of `overridden` (wiping unmanaged config) does not apply. Just make sure nobody copies the task into a deploy playbook without removing `check_mode`. Putting `check_mode: true` at play level, as above, rather than per task, makes that mistake harder.

## Scheduling and output

Run it from cron or your CI runner nightly:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd /opt/netauto
rm -f reports/drift-*.txt
ansible-playbook -i inventory/prod.yml drift_check.yml
if compgen -G "reports/drift-*.txt" > /dev/null; then
  for f in reports/drift-*.txt; do
    echo "== ${f#reports/drift-}"; cat "$f"
  done | mail -s "Network drift detected" netops@example.com
fi
```

The report contains the actual commands Ansible would run to restore intended state. That is far more useful to the on-call engineer than a generic "config changed" alert, because it answers the immediate question: what is different, and what would reconciling it do?

## Handling the findings

Every drift item has two possible resolutions. Either the change was correct and the repo is stale, in which case someone opens a merge request and updates `host_vars`. Or the change was wrong or temporary, in which case the next deploy run removes it. The important part is that a human makes that call within a day, not during the next unrelated change window.

Expect noise in the first week. Platform defaults, ordering differences in ACL sequence numbers, and descriptions that differ only in whitespace will all show up. Fix these in the data model rather than suppressing them in the report; a drift check people learn to ignore is worse than none.

## Why this matters

In practice, most failed network changes I have seen were not caused by bad playbooks but by devices that no longer matched what the playbook expected. Incident fixes, vendor TAC sessions and "just this once" CLI edits accumulate quietly. A nightly read-only drift check turns that silent accumulation into a short daily list, reuses the automation you already trust, and means the change window starts from a known state instead of a hopeful one.
