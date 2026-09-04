---
title: Your alert did not fire because the metric disappeared
tags: Monitoring
---

The worst monitoring outage I have dealt with was not a flood of alerts. It was silence. A batch of VMs was migrated to a new hypervisor cluster, the node_exporter systemd unit did not come back on four of them, and for nineteen hours nobody was paged about disk usage, memory pressure, or anything else on those hosts. Every dashboard panel showed a clean flat line ending somewhere in the past, and every alert rule evaluated to "no data", which in Prometheus means "not firing".

This is the structural blind spot in threshold-based alerting: `node_filesystem_avail_bytes / node_filesystem_size_bytes < 0.1` can only fire if the series exists. When the exporter dies, the series goes stale after five minutes and the vector becomes empty. An empty vector is not a violation. It is nothing. Prometheus is behaving exactly as documented, and the on-call engineer sleeps through it.

## Absence is a signal, not a gap

The fix has two halves, and most teams only implement the first one.

Half one is the obvious `up == 0` alert. Every scrape target gets a synthetic `up` series, so this catches an exporter that is down but still known to service discovery:

```yaml
groups:
  - name: target-health
    rules:
      - alert: TargetDown
        expr: up == 0
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "{{ $labels.job }} target {{ $labels.instance }} unreachable"

      - alert: TargetFlapping
        expr: changes(up[30m]) > 4
        for: 0m
        labels:
          severity: warning
        annotations:
          summary: "{{ $labels.instance }} scrape state changed {{ $value }} times in 30m"
```

Half two is the one that actually saved me: detecting targets that vanished from service discovery entirely. If the VM is deleted from the inventory, from Consul, or from the file_sd JSON, there is no `up` series to be zero. The target simply stops existing, and `up == 0` will never match.

For that you need to compare against history. `absent_over_time` handles the single-series case, but for a fleet you want a per-instance comparison using an offset:

```yaml
      - alert: TargetVanished
        expr: |
          count by (job, instance) (up offset 1h)
            unless
          count by (job, instance) (up)
        for: 15m
        labels:
          severity: critical
        annotations:
          summary: "{{ $labels.instance }} was scraped 1h ago and is now gone from SD"
          description: >
            Target disappeared from service discovery rather than failing scrape.
            Check inventory, file_sd output, and whether the host was
            decommissioned without removing its monitoring entry.
```

The `unless` operator does set subtraction on label sets: series present an hour ago, not present now. The `for: 15m` absorbs legitimate churn from autoscaling or rolling replacements. If your environment replaces instances faster than that, drop `instance` from the grouping and alert on the count of targets per job falling below an expected floor instead.

There is a third case worth covering. The exporter is up, the scrape succeeds, but one specific collector silently stopped producing metrics — a textfile collector whose cron job died, or a `mysqld_exporter` that lost its DB connection while its own `/metrics` endpoint kept answering. `up` is 1 the whole time. For those, assert on the metric you actually depend on:

```yaml
      - alert: BackupMetricStale
        expr: |
          time() - max by (instance) (node_systemd_unit_state{name="restic-backup.service"} * 0) 
            > 0
          or
          absent(backup_last_success_timestamp_seconds)
        for: 10m
        labels:
          severity: critical
```

Simpler and more robust in practice: `time() - backup_last_success_timestamp_seconds > 86400`, combined with an `absent()` rule for the same metric. Freshness and existence are two different failure modes and both need explicit rules.

## Testing it before you trust it

Do not deploy absence alerts unverified. `promtool` runs unit tests against rule files, and absence logic is exactly the kind of thing that looks right and silently never fires:

```yaml
# absent_test.yml — run with: promtool test rules absent_test.yml
rule_files:
  - alerts.yml
evaluation_interval: 1m
tests:
  - interval: 1m
    input_series:
      - series: 'up{job="node",instance="vm174:9100"}'
        values: '1+0x70 stale'
    alert_rule_test:
      - eval_time: 90m
        alertname: TargetVanished
        exp_alerts:
          - exp_labels:
              severity: critical
              job: node
              instance: vm174:9100
```

Run that in CI on every change to your rule files. It takes seconds and it is the only way to know that a rule which is supposed to fire on nothing actually does.

## Why this matters

Alerting maturity is usually measured by how few false positives you have. That metric is backwards. Every environment I have inherited had decent threshold alerts and no coverage for missing data, because false negatives are invisible — you do not get a page telling you that you did not get a page. The failure only surfaces during an incident review, when someone reconstructs a timeline and notices the metrics stop before the outage started. Spend an afternoon writing `up == 0`, a service-discovery vanish rule, and freshness assertions on the handful of metrics you genuinely rely on. It is the cheapest reliability work available, and it is the difference between monitoring a system and monitoring the parts of a system that happen to still be reporting.
