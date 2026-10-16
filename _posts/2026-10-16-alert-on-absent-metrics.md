---
title: "Alerting on silence: catching metrics that quietly disappear"
tags: Monitoring
---

A common monitoring failure goes like this. A node exporter on a branch firewall host stops being scraped after someone changes a firewall rule, or a relabel config drops a target during a refactor. Your disk-full alert, `node_filesystem_avail_bytes / node_filesystem_size_bytes < 0.1`, never fires again. It isn't firing because the disk is fine. It isn't firing because the series no longer exists. Prometheus evaluates the expression, gets an empty result, and an empty result means no alert. The dashboard panel shows "No data", which nobody looks at during a quiet week.

Threshold alerts tell you when a value is bad. They say nothing when the value is gone. If you run Prometheus at any scale, you need a second class of rules that alert on missing data.

## Three layers of absence

Missing data fails at different levels, and each level needs its own check.

**The target is down.** Prometheus still knows the target exists and records `up == 0`. This is the easy case, and most people already alert on it.

**The target has vanished.** Service discovery no longer returns it at all, perhaps because a file_sd file was overwritten, a Consul tag changed, or a Kubernetes label selector stopped matching. With no target there is no `up` series, so `up == 0` never matches.

**The target is up but a metric is gone.** The exporter is running, but a collector failed, a textfile cron job stopped writing, or an upgrade renamed a metric. `up` stays at 1 while the series you actually alert on is gone.

## Rules that cover each layer

```yaml
groups:
  - name: absence
    rules:
      # Layer 1: target known but failing scrapes
      - alert: TargetDown
        expr: up == 0
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "{{ $labels.job }} target {{ $labels.instance }} is down"

      # Layer 2: an entire job has no targets at all
      - alert: JobHasNoTargets
        expr: absent(up{job="node"})
        for: 10m
        labels:
          severity: critical
        annotations:
          summary: "No targets discovered for job=node"

      # Layer 2b: fewer targets than expected (per job)
      - alert: TargetCountDropped
        expr: count by (job) (up) < count by (job) (up offset 1h) * 0.8
        for: 15m
        labels:
          severity: warning
        annotations:
          summary: "{{ $labels.job }} lost more than 20% of its targets in the last hour"

      # Layer 3: a specific series went stale on an otherwise healthy target
      - alert: FilesystemMetricsMissing
        expr: |
          up{job="node"} == 1
          unless on (instance)
          node_filesystem_size_bytes{mountpoint="/"}
        for: 15m
        labels:
          severity: warning
        annotations:
          summary: "{{ $labels.instance }} is up but exports no root filesystem metrics"

      # Layer 3b: textfile collector output stopped updating
      - alert: TextfileMetricStale
        expr: time() - node_textfile_mtime_seconds > 3600
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "{{ $labels.file }} on {{ $labels.instance }} not updated for over an hour"
```

Run `promtool check rules absence.yml` before you deploy it. The rules use standard PromQL and the metric names that node_exporter ships with.

## Notes on the patterns

`absent()` is a blunt tool. It returns a single series only when nothing matches the selector, so `absent(up{job="node"})` fires when the whole job disappears, not when one host does. Don't write a separate `absent()` rule for every host. That list goes stale as soon as the inventory changes, and keeping it in sync becomes its own source of incidents. If you need per-host coverage, compare against a source of truth. A recording rule over a static "expected hosts" metric works, or the `offset` comparison shown above. The offset rule has a known blind spot: it catches sudden drops but not a slow drift. That is usually an acceptable trade.

The `unless on (instance)` pattern is the one that catches problems people don't expect. It matches healthy targets that are missing a specific series. It is useful after exporter upgrades, when collectors get renamed or disabled by default. Pick the handful of metrics your critical alerts depend on and write one of these guards for each.

`absent_over_time()` is useful when a series is legitimately sparse, for example a batch job that pushes a metric once per run. `absent_over_time(backup_last_success_timestamp[26h])` is a better fit than a plain `absent()` that flaps between runs. Even better, alert on the timestamp value itself, as the textfile rule does. A job that runs and reports failure is different from a job that never runs, and you want to know which one you have.

## Monitor the monitor

None of this helps if Prometheus itself is down or Alertmanager can't deliver notifications. That needs a dead man's switch: an alert that always fires (`expr: vector(1)`) routed to an external receiver, which pages you when the heartbeat *stops* arriving. Several hosted services provide that receiver, or a small cron job on a separate host that checks a webhook timestamp will do. The requirement is that it runs outside the failure domain it is watching.

## Why this matters

Most of the monitoring gaps I've seen in post-incident reviews were not wrong thresholds. They were alerts that had been silently disarmed for weeks: a renamed metric after an exporter bump, a discovery file truncated by a config management run, a scrape blocked by a well-intentioned firewall change. In each case, silence looked the same as health. Adding absence rules takes an afternoon, and it changes what a quiet alert channel tells you from "probably fine" to "verified fine".
