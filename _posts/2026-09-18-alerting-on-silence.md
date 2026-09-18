---
title: Alerting on silence, not just on thresholds
tags: Monitoring
---

A backup job stopped running on a Tuesday. Nobody noticed until the following Monday, when someone needed a restore. The monitoring stack was healthy the whole time: the dashboard panel for "backup duration" was empty, every alert rule evaluated to no data, and no-data was configured to be ignored because it had been noisy six months earlier. The system was not broken. It was silent, and silence had been defined as success.

This is the single most common failure mode I see in Prometheus-based stacks. Threshold alerts answer "is this value bad?" They cannot answer "is this value still arriving?" Those are different questions and they need different rules.

## The three kinds of missing

It helps to separate them, because the fix differs for each.

**The series never existed.** A scrape target was renamed, a recording rule typo'd, an exporter was never deployed on the new host. Your alert on `node_filesystem_avail_bytes` for `/data` has been evaluating against an empty vector since the day it was written. It has never fired and never will.

**The series stopped.** The exporter is up, the scrape succeeds, but a specific metric disappeared — a systemd timer unit was disabled, a job stopped pushing to the Pushgateway, a cron wrapper stopped writing its textfile collector output.

**The target stopped.** The host is down or the scrape is failing. `up == 0` covers this, and most people do have that rule. It is the easy case.

For the first case, `absent()` is the tool:

```yaml
groups:
  - name: absence
    rules:
      - alert: BackupMetricAbsent
        expr: absent(backup_last_success_timestamp_seconds{job="backup"})
        for: 30m
        labels:
          severity: warning
        annotations:
          summary: "No backup_last_success metric is being reported at all"

      - alert: BackupStale
        expr: >
          time() - max by (instance) (backup_last_success_timestamp_seconds) > 36 * 3600
        for: 15m
        labels:
          severity: critical
        annotations:
          summary: "{{ $labels.instance }} last successful backup was {{ $value | humanizeDuration }} ago"

      - alert: ExporterTargetDown
        expr: up{job="backup"} == 0
        for: 10m
        labels:
          severity: critical
```

Note the shape of `BackupStale`. It does not alert on "the backup failed" — it alerts on "a success has not been recorded recently." That inversion is the whole point. A failure alert requires the failing component to be alive enough to report its own failure. A staleness alert requires nothing from the failing component at all, which is exactly what you want when the failure mode is "the process no longer runs."

`absent()` has a sharp edge worth knowing: it returns a series with only the label matchers you wrote in the selector, not the labels of the missing data. If you write `absent(backup_last_success_timestamp_seconds)` with no matchers, the resulting alert has essentially no labels and tells you nothing about which instance is missing. For per-instance absence you need `absent_over_time()` against a known inventory, or better, a join against a target list:

```promql
count by (instance) (up{job="node"} == 1)
  unless
count by (instance) (backup_last_success_timestamp_seconds)
```

That expression means "hosts that are up and scraped, but have no backup metric." It produces one series per offending host with a usable `instance` label, and it degrades gracefully: if the whole job disappears, the left side goes empty too, which is why you still keep the plain `absent()` rule as a backstop.

The generating side matters as much as the rule. A textfile collector that writes only on success is correct; one that writes on every run with a status label is worse, because a crashing wrapper writes nothing either way and you have gained nothing. Write the timestamp last, after the work has demonstrably succeeded:

```bash
#!/usr/bin/env bash
set -euo pipefail
OUT=/var/lib/node_exporter/textfile/backup.prom
restic backup /data --tag nightly
printf 'backup_last_success_timestamp_seconds %s\n' "$(date +%s)" > "$OUT.tmp"
mv "$OUT.tmp" "$OUT"
```

`set -e` plus writing the file only after the command returns zero plus the atomic rename gives you a metric that is genuinely a proof-of-success, not a proof-of-execution. Without the rename, the exporter can read a half-written file mid-scrape.

The last piece is testing. Absence rules are the only rules you cannot verify by waiting — they fire when nothing happens, so a broken absence rule looks identical to a healthy system. Use `promtool test rules` with a unit test that supplies an empty series, or stop the generating job deliberately in a lab and confirm the page arrives.

## Why this matters

Every postmortem I have sat through where the answer was "we had no idea" involved a signal that stopped rather than a signal that went red. Thresholds catch degradation; they are blind to disappearance, and disappearance is what happens when something crashes hard, gets decommissioned by mistake, or falls out of a config management run. Reviewing which of your alerts would still fire if the thing they watch simply vanished is a short exercise and it usually finds something uncomfortable the first time.
