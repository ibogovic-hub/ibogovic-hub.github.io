---
title: "Alerting on silence: catching the metrics that stop arriving"
tags: Monitoring
---

A storage node in a lab cluster ran out of inodes on a Saturday. Nobody got paged. The disk-usage alert was correct and well tuned, but node_exporter on that host had crashed two days earlier, and a Prometheus alert built on a series that no longer exists does not fire. It evaluates to an empty result, and an empty result is indistinguishable from "everything is fine". The dashboard panel showed a flat line ending on Thursday, which nobody was looking at.

This is the most common blind spot I see in Prometheus setups. Teams invest in thresholds and forget that every threshold assumes the data is still flowing. This post covers the three layers I use to close that gap.

## Layer 1: the scrape target itself

Prometheus generates an `up` series for every target it tries to scrape. If the scrape fails, `up` is 0. This catches the exporter crashing while the host stays reachable, or a firewall change blocking the port.

```yaml
groups:
  - name: meta-monitoring
    rules:
      - alert: TargetDown
        expr: up == 0
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "{{ $labels.job }} target {{ $labels.instance }} is down"

      - alert: JobHasNoTargets
        expr: absent(up{job="node"})
        for: 10m
        labels:
          severity: critical
        annotations:
          summary: "No node targets discovered at all"
```

The second rule matters more than people expect. If service discovery breaks, for example a file_sd JSON file gets truncated by a bad deploy, or a Consul query returns nothing, the targets disappear entirely. `up == 0` then has nothing to match, and you are back to silence. `absent()` returns a single series with value 1 when its selector matches nothing, which is exactly the inverse behaviour you need.

## Layer 2: individual series that vanish

A target can be up while a specific metric disappears. Common causes: a textfile collector script that stops writing its `.prom` file, an exporter upgrade that renames a metric, or a relabel rule that quietly drops a label set. `up` stays at 1 and your alert keeps evaluating to nothing.

For known-critical series, use `absent_over_time` so a single missed scrape does not trigger noise:

```yaml
      - alert: BackupMetricMissing
        expr: absent_over_time(backup_last_success_timestamp_seconds{job="node"}[2h])
        labels:
          severity: critical
        annotations:
          summary: "Backup completion metric not reported for 2h"
```

The limitation is that `absent()` only works when you name the series explicitly, and it loses per-instance labels. For a fleet, compare against what existed earlier:

```promql
count by (instance) (node_filesystem_avail_bytes offset 1h)
  unless
count by (instance) (node_filesystem_avail_bytes)
```

This returns every instance that reported filesystem metrics an hour ago but does not now, with the instance label intact for routing. Pair it with `up == 1` if you want to separate "exporter died" from "collector disabled".

## Layer 3: the monitoring stack itself

None of the above helps if Prometheus or Alertmanager is the thing that died. An alerting system cannot reliably report its own absence. The standard pattern is a dead man's switch: an alert that always fires, sent to an external receiver that pages you when the heartbeat stops.

```yaml
      - alert: Watchdog
        expr: vector(1)
        labels:
          severity: none
        annotations:
          summary: "Heartbeat - this should always be firing"
```

In Alertmanager, route it to a webhook on something outside your infrastructure: a hosted heartbeat service, or a small cron job on a separate box that checks when the last POST arrived. Set `repeat_interval` short, for example 5 minutes, so the external side sees a steady pulse:

```yaml
route:
  routes:
    - matchers: [ 'alertname="Watchdog"' ]
      receiver: heartbeat
      repeat_interval: 5m
      group_wait: 0s
receivers:
  - name: heartbeat
    webhook_configs:
      - url: https://heartbeat.example.net/ping/prom-main
```

Run `promtool check rules` in CI on every rules change. A YAML error that causes Prometheus to refuse a reload is another quiet way to lose alerting, since the old ruleset keeps running and nobody notices the new rule never loaded. `prometheus_config_last_reload_successful == 0` is worth an alert too.

## Practical notes

- Keep `for:` on absence alerts longer than your scrape interval times a few, or restarts during patch windows will page you.
- Silence planned decommissions properly. Otherwise the `offset` comparison fires for every retired host and people learn to ignore it.
- Grafana panels with "No data" are not alerts. Treat them as a symptom you happened to see, not coverage.

## Why this matters

In every incident review I have sat through where monitoring "missed" something, the threshold was rarely the problem. The data had stopped, and the system treated silence as health. Thresholds get tuned because false positives are loud and annoying; missing data gets ignored because it is quiet by definition. Spending an afternoon on `absent`, a fleet-wide disappearance query, and an external heartbeat is cheap compared with explaining why a full disk sat unnoticed for two days behind an alert that was technically correct.
