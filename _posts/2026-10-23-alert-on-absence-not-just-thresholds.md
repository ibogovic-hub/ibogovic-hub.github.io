---
title: "Alert on absence, not just thresholds"
tags: Monitoring
---

A backup job stopped running on a Tuesday. Nobody noticed until the following Monday, when someone needed a restore. The monitoring was fine, in the narrow sense: every alert rule evaluated correctly. The rule said "fire if backup_duration_seconds > 7200". A job that never runs never reports a duration, so the rule never had anything to compare. Silence looked exactly like health.

This is one of the most common gaps I see in monitoring setups, in the cloud and on-prem alike. Threshold alerts cover things that report bad values. They do not cover things that stop reporting at all. And the things that stop reporting are usually the ones you care about most: dead exporters, crashed cron jobs, scrape targets that vanished after a redeploy, a node that dropped off the network.

## Three kinds of silence

It helps to separate the failure modes, because each needs a different rule.

1. **The target is gone.** Prometheus can no longer scrape the endpoint. The `up` metric goes to 0, or the series disappears entirely if service discovery dropped the target.
2. **The target is up, but a specific series is missing.** The exporter runs, but the metric you alert on is no longer emitted. Common after an exporter upgrade renames a metric, or when a label value changes.
3. **The event stopped happening.** The series exists, but the timestamp of the last successful run is getting old. This is the backup case.

Most teams have case 1 partially covered with an `up == 0` rule. Cases 2 and 3 are where incidents hide.

## Rules that catch silence

Here is a set of Prometheus alerting rules I would put in any baseline. They assume a batch job pushes `job_last_success_timestamp_seconds` (via Pushgateway or a textfile collector), which is the standard pattern.

```yaml
groups:
  - name: absence
    rules:
      # Case 1: target scraped but down
      - alert: TargetDown
        expr: up == 0
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "{{ $labels.job }} on {{ $labels.instance }} is not responding"

      # Case 1b: an entire job vanished from discovery
      - alert: NodeExporterJobMissing
        expr: absent(up{job="node"})
        for: 10m
        labels:
          severity: critical
        annotations:
          summary: "No node exporter targets discovered at all"

      # Case 2: specific series went missing on a live target
      - alert: BackupMetricMissing
        expr: absent_over_time(job_last_success_timestamp_seconds{job="nightly-backup"}[2h])
        labels:
          severity: critical
        annotations:
          summary: "nightly-backup has not reported its success metric for 2h"

      # Case 3: the event is stale
      - alert: BackupStale
        expr: time() - job_last_success_timestamp_seconds{job="nightly-backup"} > 26 * 3600
        for: 15m
        labels:
          severity: critical
        annotations:
          summary: "Last successful backup was {{ $value | humanizeDuration }} ago"
```

A few notes from running these in practice.

`absent()` only works with fully specified selectors. It returns a single synthetic series with the labels from your equality matchers, so `absent(up{job=~"node.*"})` will not tell you which job disappeared. Write one rule per thing you actually depend on. It is more lines of YAML, but the alert says something useful at 03:00.

For the staleness check, set the threshold to the schedule interval plus a margin, not exactly the interval. A daily job at 01:00 that takes a little longer one night should not page. Twenty-six hours for a daily job has worked well for me.

Record the success timestamp only on success. If the job writes the timestamp at start, or on any exit, the staleness rule tells you the job ran, not that it worked. That distinction matters for backups, certificate renewals and data syncs.

## Watch the watcher

The rules above all depend on Prometheus and Alertmanager themselves being alive. If the monitoring stack dies, every rule goes quiet together, which again looks like health. The standard fix is a dead man's switch: an alert that always fires, routed to an external service that pages you when it stops receiving it.

```yaml
      - alert: Watchdog
        expr: vector(1)
        labels:
          severity: none
        annotations:
          summary: "Always firing. If this stops arriving, alerting is broken."
```

Route it in Alertmanager to a receiver with a short `repeat_interval`, pointing at a heartbeat endpoint outside your own infrastructure. Healthchecks.io, a cloud provider's heartbeat feature or a small function in a different account all work. What matters is that it does not share a failure domain with the thing it watches. A heartbeat checker running on the same cluster as Prometheus fails at the same time Prometheus does.

## Making it routine

Two habits keep this from rotting:

- **Every new scheduled job gets a staleness rule in the same change.** Treat it like a unit test. If the merge request adds a cron job or a CronJob manifest without the matching alert, it is not done.
- **Test absence on purpose.** Stop an exporter in staging, or rename a metric, and confirm the alert fires. `promtool test rules` can cover this offline with synthetic series, which belongs in CI next to your rule linting.

## Why this matters

In my experience, the incidents that hurt most are rarely the loud ones. A saturated link or a full disk gets noticed fast, because something breaks visibly. The expensive incidents are the slow, quiet ones: the backup that stopped two weeks ago, the certificate renewal job that failed silently, the log shipper that died and took your audit trail with it. Threshold alerts tell you when something is bad. Absence alerts tell you when you have stopped knowing. For an on-call team, the second is the more dangerous state, and it costs a handful of rules to cover.
