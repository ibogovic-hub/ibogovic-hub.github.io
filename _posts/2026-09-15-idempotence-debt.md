---
title: Your Playbook Is Not Idempotent And You Already Know It
tags: Automation
---

A run that reports `changed=14` on a host nobody touched since yesterday is not automation. It is a scheduled outage generator waiting for the right Tuesday. Most teams discover this the same way: someone finally wires the nightly config-enforcement job into a change-detection alert, and the alert fires every single night on every single host. The reflex is to silence the alert. The correct move is to fix the tasks, because a permanently-`changed` task is a task whose blast radius you have never actually measured.

There are only a handful of root causes, and they repeat everywhere.

**Shell and command tasks with no guard.** `ansible.builtin.command` cannot know whether its work was needed, so it reports `changed` unconditionally. People "fix" this with `changed_when: false`, which is worse than the original problem: now the task lies in the other direction, and a genuine config drift is invisible. The honest fix is to make the condition explicit.

```yaml
- name: Check whether the sysctl value is already applied
  ansible.builtin.command:
    cmd: sysctl -n net.ipv4.conf.all.rp_filter
  register: rp_filter_now
  changed_when: false
  check_mode: false

- name: Apply strict reverse-path filtering
  ansible.posix.sysctl:
    name: net.ipv4.conf.all.rp_filter
    value: "1"
    sysctl_set: true
    state: present
    reload: true
  when: rp_filter_now.stdout | trim != "1"
```

The first task is a read, so `changed_when: false` is truthful there. `check_mode: false` forces it to run even under `--check`, otherwise the second task has nothing to evaluate and your dry run is meaningless. That pairing — a truthful read plus a guarded write — is the shape you want everywhere you cannot use a proper module.

**Templates that embed volatile data.** A `template` task that renders a timestamp, a `ansible_date_time` fact, or an unordered dict will rewrite the file every run. Dict ordering is the sneaky one: if you iterate a Jinja mapping without `| dictsort`, you can get stable output for months and then a reordered file after a fact-cache change. Sort every loop that feeds a rendered file, and keep generated-on banners out of files you diff.

**Package and service state expressed as actions.** `state: latest` is not a state, it is an instruction to change things whenever upstream changes. It will be idempotent right up to the moment a maintainer pushes a release, which is precisely the moment you did not want a surprise. Pin to `state: present` with an explicit version, and move upgrades into a separate, deliberate play that a human schedules.

**Network devices that normalise your input.** This is the one that burns network engineers specifically. You push `permit ip 10.0.0.0 0.0.0.255 any`, the device stores it, and on read-back it returns something semantically identical but textually different — reordered ACEs, expanded abbreviations, a normalised mask. A naive line-by-line comparison sees drift forever. The fix is to compare against what the device reports, not against what you sent: use the resource modules (`cisco.ios.ios_acls`, `ios_l3_interfaces`, and friends) which parse device state into structured facts and diff at that level, rather than `ios_config` with raw `lines`. Where a resource module does not exist yet, gather the running config once, parse it, and let a Python filter do the comparison — do not ask `ios_config` to be smart about text it cannot model.

The cheap enforcement mechanism is CI, not discipline. Run the role twice against a container or a lab device and fail the build if the second run is not clean:

```bash
ansible-playbook -i inventory site.yml
ansible-playbook -i inventory site.yml | tee /tmp/second.log
grep -qE 'changed=[1-9]' /tmp/second.log && { echo "NOT IDEMPOTENT"; exit 1; }
exit 0
```

Molecule does this for you with its `idempotence` scenario step, and if you already have Molecule in the repo there is no excuse for not turning it on. The point is that idempotence is a property you test, not a property you intend.

## Why this matters

The operational value of idempotence is not elegance, it is that `--check` becomes trustworthy. When every task reports honestly, a dry run against production is a real answer to "what will this change tonight," and you can hand that output to a change board instead of arguing from first principles. When half your tasks always report `changed`, the dry run is noise, nobody reads it, and the first time anyone learns what the playbook actually does is during the incident review. I have watched a team carry that debt for two years because the fix looked like tedium; the actual cost was that they could never run enforcement in anything but a maintenance window. Clean second runs buy you the ability to run automation continuously, and continuous enforcement is the only kind that catches drift before it matters.
