---
title: "Using Ansible check mode as a change gate, not a formality"
tags: Automation
---

A familiar failure: a playbook that "worked last week" pushes a config change to forty devices, and three of them end up in a state nobody expected. Usually the playbook did exactly what it was told. The problem is that nobody looked at what it was going to do before it did it. Most teams have `--check` somewhere in their runbook, but they treat it as a box to tick rather than as a real gate with pass/fail criteria.

This post covers how to make check mode useful: getting tasks to report honestly, turning the output into something a pipeline can decide on, and dealing with the modules that lie.

## The problem with "changed" counts

Running `ansible-playbook site.yml --check --diff` gives you a recap with `changed=N` per host. On paper that is the blast radius. In practice it's noisy for three reasons:

1. `command` and `shell` tasks are skipped in check mode by default, so anything they would do is invisible.
2. Tasks that use `register` and feed later conditionals get placeholder results, so downstream tasks may be skipped or evaluated wrong.
3. Some tasks report `changed` on every run because they aren't idempotent. That trains people to ignore the number.

If a dry run on a stable fleet shows changes, the gate is meaningless. Fix idempotency first.

## Make tasks honest

For read-only commands that later tasks depend on, force them to run during check mode and tell Ansible they never change anything:

```yaml
- name: Read current NTP servers
  ansible.builtin.command: chronyc -n sources
  register: ntp_sources
  check_mode: false
  changed_when: false

- name: Render chrony config
  ansible.builtin.template:
    src: chrony.conf.j2
    dest: /etc/chrony/chrony.conf
    mode: "0644"
  notify: restart chrony
```

For commands that really do change state, add `changed_when` based on the output, plus `creates`/`removes` where they apply. If you can't define when a task counts as changed, it probably belongs in a proper module or a small custom one.

On network gear, `cisco.ios.ios_config` and the resource modules (`ios_interfaces`, `ios_vlans`) support check mode and `--diff` well. Raw `ios_command` with config lines does not. That's a good reason by itself to move to resource modules.

## Turn the recap into a decision

Humans skim recaps. A pipeline shouldn't. The `json` stdout callback gives you machine-readable output you can test against a policy:

```bash
#!/usr/bin/env bash
set -euo pipefail

export ANSIBLE_STDOUT_CALLBACK=json
ansible-playbook -i inventory/prod site.yml --check --diff \
  --limit "${TARGET:-all}" > plan.json

python3 - <<'EOF'
import json, sys

MAX_CHANGED_HOSTS = 5

data = json.load(open("plan.json"))
stats = data["stats"]

failed = [h for h, s in stats.items() if s["failures"] or s["unreachable"]]
changed = [h for h, s in stats.items() if s["changed"]]

if failed:
    print("FAIL: errors or unreachable hosts:", ", ".join(failed))
    sys.exit(2)

print(f"{len(changed)} host(s) would change: {', '.join(changed) or 'none'}")
if len(changed) > MAX_CHANGED_HOSTS:
    print(f"BLOCK: exceeds limit of {MAX_CHANGED_HOSTS}; needs explicit approval")
    sys.exit(3)
EOF
```

Exit code 0 means proceed. 2 means the dry run itself is broken. 3 means the change is bigger than expected and someone has to approve it. Store `plan.json` as a build artifact so the reviewer sees the same diff the pipeline acted on, not one regenerated later.

Tune the threshold for each change type. Rotating a cert across the fleet is expected to touch every host. A one-line ACL fix that touches every host is a red flag.

## Pin the plan to the apply

A dry run only means something if the apply that follows runs against the same inputs. Run both from the same commit, the same inventory snapshot, and the same collection versions (pin them in `requirements.yml`). If inventory is dynamic, write the resolved host list during the check stage and pass it to the apply with `--limit @hosts.txt`. Otherwise a host added between the two stages gets changes nobody reviewed.

## Known gaps

Check mode can't predict everything. Handlers don't fire, so a service restart that would fail stays hidden. Modules that call remote APIs may not support check mode at all and will be skipped without warning unless you look for `skipped` results on those tasks. Templates that pull in live facts can render differently at apply time. Treat the plan as strong evidence, not proof, and keep a canary stage (one site or one device role) between plan and full rollout.

## Why this matters

Most automation incidents I've dealt with weren't caused by bad code. They happened because the change was bigger than whoever approved it thought. "Run check mode first" is advice everyone agrees with and few enforce. Once the dry run has an exit code, a size limit, and a saved artifact, the habit becomes a control. It also forces the idempotency cleanup that makes the rest of your automation trustworthy. A quiet dry run on a stable fleet is the best sign that your playbooks describe reality.
