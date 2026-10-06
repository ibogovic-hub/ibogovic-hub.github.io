---
title: "Using Ansible check mode as a nightly drift detector"
tags: Automation
---

Every network team that automates config eventually hits the same wall: the playbook ran clean in March, someone hot-fixed an ACL over SSH in June, and in September the next playbook run silently reverts the fix during a change window. Nobody notices until a service breaks. The automation was correct; the source of truth was stale, and nothing told you.

The fix is not more discipline. It is running your existing playbooks in a mode that reports differences without applying them, on a schedule, and treating any non-zero change count as an alert.

## Check mode plus diff is already a drift detector

Ansible's `--check` flag asks every module to predict whether it would change something. Combined with `--diff`, modules that support it print the delta. For network platforms, the `*_config` and resource modules (`ios_config`, `ios_interfaces`, `nxos_acls` and friends) support both. That means the playbook you already use to push config can be repurposed, unchanged, as an audit.

The catch is that a human reading `ansible-playbook` output at 03:00 is not a monitoring system. You need machine-readable results. The built-in `json` stdout callback gives you that.

```bash
#!/usr/bin/env bash
# drift-check.sh - run playbook in check/diff mode, summarise changed hosts
set -euo pipefail

PLAYBOOK=${1:-site.yml}
OUT=$(mktemp)

ANSIBLE_STDOUT_CALLBACK=json \
ANSIBLE_LOAD_CALLBACK_PLUGINS=1 \
ansible-playbook "$PLAYBOOK" --check --diff > "$OUT" || true

# Hosts where at least one task would change something
jq -r '.stats | to_entries[] | select(.value.changed > 0)
       | "\(.key) changed=\(.value.changed) failed=\(.value.failures)"' "$OUT"

DRIFTED=$(jq '[.stats[] | select(.changed > 0)] | length' "$OUT")
echo "drifted_hosts ${DRIFTED}"
rm -f "$OUT"
[ "$DRIFTED" -eq 0 ]
```

Run it from cron or a CI scheduler. Exit code non-zero means drift. Pipe the `drifted_hosts` line into a Prometheus textfile collector and you get a time series and an alert rule for free:

```yaml
groups:
  - name: config-drift
    rules:
      - alert: NetworkConfigDrift
        expr: drifted_hosts > 0
        for: 1h
        labels:
          severity: warning
        annotations:
          summary: "{{ $value }} device(s) differ from source of truth"
```

## Things that will bite you

**Not every task is check-safe.** Tasks using `command`, `shell` or `cli_command` cannot predict changes; they either skip or report changed every time. Mark read-only commands with `changed_when: false` and `check_mode: false` so they run for real (they only gather facts) and never pollute the count. Anything that genuinely mutates state through a raw command should be rewritten against a proper config module, or it will be noise forever.

**Normalisation noise.** `ios_config` compares text lines. If the device renders `ip address 10.0.0.1 255.255.255.0` and your template has extra whitespace or a different keyword order, you get permanent false drift. Resource modules (`ios_l3_interfaces`, etc.) compare structured data and are far less noisy; prefer them where they exist. Where you must use `ios_config`, render templates from the device's own `show run` output style.

**Variable loading.** With `network_cli`, make sure group and host vars actually load in the context you run from. If your scheduled job runs from a different working directory than your engineers do, inventory-relative vars may not resolve, and the playbook will happily report drift against defaults. Load them explicitly with `include_vars` at the top of the play if there is any doubt.

**Secrets in diffs.** `--diff` output can contain the lines it would change, which may include keys or SNMP communities. Mark sensitive tasks `no_log: true` or `diff: false`, and do not ship raw JSON output into a shared log index.

**Failures are not drift.** An unreachable host reports zero changes. Alert separately on `failures` and `unreachable` in the stats block, or a dead device looks perfectly compliant.

## Deciding what to do with drift

Detection is the easy part. The policy question is which side wins. Two workable rules:

1. Source of truth always wins: drift opens a ticket, and the next scheduled run reverts it unless the repo is updated first. Strict, and appropriate for security-relevant config like ACLs and AAA.
2. Device wins, repo catches up: drift generates a pull request with the observed config, an engineer reviews and merges. Friendlier for areas where emergency changes are normal.

Most teams end up with both, split by config section. Write that split down; the worst outcome is an automation that silently picks a side.

## Why this matters

In practice, the incidents caused by automation are rarely bad templates. They are good templates applied over undocumented manual fixes, during a change window, by someone who did not know the fix existed. A nightly check-mode run costs nothing extra to build because you already have the playbooks, and it turns invisible divergence into a visible, owned ticket days or weeks before it can bite. It also gives you an honest answer to the auditor's question "how do you know production matches your standard?" that is better than "we think so".
