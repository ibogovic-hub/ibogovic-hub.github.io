---
title: When ansible check mode lies to you
tags: Automation
---

A colleague ran a playbook with `--check` against forty switches, saw "ok=120 changed=0", and shipped it to production on a Friday. The apply run rewrote the management VRF on six devices and dropped them off the network. The check run had not been wrong exactly — it had been silent about the parts it could not evaluate.

This is the single most common automation failure I see in network and Linux fleets: treating `--check` as a dry run when it is really a best-effort simulation whose fidelity varies per module, per connection plugin, and per task.

## Where the fidelity goes

Three distinct failure classes hide behind a clean check run.

**Modules that do not implement check mode.** A module without `supports_check_mode=True` is skipped entirely in check runs. It reports `skipped`, not `changed`, and anything downstream that depended on its side effects now evaluates against stale facts. `command` and `shell` are the obvious offenders, but plenty of collection modules are too.

**Registered variables that never exist.** Task A runs a command, registers `result`, task B templates `result.stdout`. In check mode task A is skipped, `result` has no `stdout`, and task B either fails loudly or — worse — you wrapped it in `ignore_errors` two years ago and it fails quietly.

**Conditionals that depend on prior state.** `when: "'vrf Mgmt' not in running_config.stdout"` is only meaningful if the config was actually fetched. Check mode against `network_cli` does fetch config for most `*_config` modules, but the `diff` it produces is computed against the *current* device state, not against the state the earlier tasks in the same play would have created. Ordering effects vanish.

## Making check mode falsifiable

The fix is not to abandon `--check`; it is to make the playbook fail when check mode cannot answer the question. Force the issue with an assertion that runs only in check mode:

```yaml
- name: Fail fast if any task cannot be evaluated in check mode
  hosts: switches
  gather_facts: false
  connection: network_cli
  tasks:
    - name: Load device variables explicitly
      ansible.builtin.include_vars:
        dir: "{{ playbook_dir }}/group_vars"
        extensions: [yml]

    - name: Fetch running config
      cisco.ios.ios_command:
        commands:
          - show running-config
      register: running
      check_mode: false          # read-only: safe to really run

    - name: Guard against unevaluated state
      ansible.builtin.assert:
        that:
          - running is defined
          - running.stdout is defined
          - running.stdout | length > 0
        fail_msg: >-
          running-config was not retrieved; downstream conditionals
          would be evaluated against undefined state. Refusing to continue.

    - name: Apply management VRF
      cisco.ios.ios_config:
        lines:
          - "ip vrf forwarding {{ mgmt_vrf }}"
          - "ip address {{ mgmt_ip }} {{ mgmt_mask }}"
        parents: "interface {{ mgmt_iface }}"
      diff: true
      register: vrf_change

    - name: Show what would change
      ansible.builtin.debug:
        var: vrf_change.updates | default([])
      when: vrf_change.updates is defined
```

Two things are doing the work here. `check_mode: false` on the read task promotes it to "always really run", so registered facts exist in both modes and conditionals stay meaningful. The `assert` turns an ambiguous skip into a hard stop — a check run that cannot see device state now fails instead of printing `changed=0`.

For the modules-without-check-mode class, audit rather than assume:

```bash
ansible-playbook site.yml --check --diff -v 2>&1 \
  | awk '/^skipping:|^TASK \[/ {print}' \
  | grep -B1 '^skipping:' \
  | grep '^TASK'
```

Every task name that appears is a blind spot. Either the module needs `check_mode: false` because it is genuinely read-only, or it needs a `changed_when`/`creates` guard, or you accept that this playbook is not check-safe and you say so in the README.

## Ordering effects

There is no clean fix for the third class inside Ansible. A check run simulates each task against real current state, never against simulated intermediate state. If task 3 only makes sense after task 2 created a VLAN, check mode will evaluate task 3 against a device with no VLAN. The honest answer is to split such playbooks at the dependency boundary and gate the second half behind an explicit variable, or to validate the whole sequence in a lab that mirrors production — for IOS-style targets an EVE-NG or CML topology with the same image family is enough.

## Why this matters

Check mode gives you a number, and numbers are persuasive in a change-approval meeting. `changed=0` reads as "this is safe" to everyone in the room, including the person who wrote the playbook. The actual meaning is narrower: "of the tasks that could be evaluated, none reported a pending change." The gap between those two sentences is where outages live.

Treat a check run as a test that can fail, not a report that prints. If the playbook cannot prove it saw the device, it should refuse to say anything at all.
