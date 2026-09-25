---
title: Alerting on metrics that stop existing
tags: Monitoring
---

A few months into running Prometheus at home and at work, the most dangerous outage I have seen was not a spike or a threshold breach. It was silence. An exporter crashed, its target dropped out of service discovery, and every alert built on its metrics quietly evaluated to nothing. No series, no comparison, no firing. The dashboard showed "No data", which nobody looks at at 03:00.

This is a structural property of PromQL, not a bug. An expression like `node_filesystem_avail_bytes / node_filesystem_size_bytes < 0.1` returns an empty vector when the underlying series disappear. An empty result means "no alert". So the more complete your failure, the quieter your monitoring becomes.

## Three layers of failure

It helps to separate the ways data can go missing:

1. **The target is known but unreachable.** Prometheus still scrapes it and records `up == 0`. This is the easy case.
2. **The target vanished from discovery.** A Kubernetes pod is gone, a file_sd entry was removed by a bad deploy, a Consul service deregistered. There is no `up` series at all anymore.
3. **The target is up but a specific metric is gone.** The exporter is healthy, but a collector failed, a label changed after an upgrade, or the application stopped emitting a counter because a code path no longer runs.

Most setups only cover the first layer. The other two need explicit handling.

## Rules that catch silence

```yaml
groups:
  - name: meta-monitoring
    rules:
      # Layer 1: known target down
      - alert: TargetDown
        expr: up == 0
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "{{ $labels.job }} on {{ $labels.instance }} is down"

      # Layer 2: an entire job disappeared from discovery
      - alert: JobMissing
        expr: absent(up{job="node"})
        for: 10m
        labels:
          severity: critical
        annotations:
          summary: "No 'node' targets discovered at all"

      # Layer 2b: fewer targets than expected
      - alert: JobShrunk
        expr: count(up{job="node"}) < 4
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Only {{ $value }} node targets present, expected 4"

      # Layer 3: a specific metric vanished for a specific host
      - alert: MetricMissingPerInstance
        expr: |
          up{job="node"} == 1
          unless on (instance)
          node_filesystem_avail_bytes{mountpoint="/"}
        for: 15m
        labels:
          severity: warning
        annotations:
          summary: "{{ $labels.instance }} is up but reports no root filesystem metric"

      # Layer 3b: series went stale compared to an hour ago
      - alert: SeriesDisappeared
        expr: |
          count by (instance) (node_filesystem_avail_bytes offset 1h)
          unless
          count by (instance) (node_filesystem_avail_bytes)
        for: 15m
        labels:
          severity: warning
```

A few notes on these:

`absent()` only works with fully specified selectors. It returns a single synthetic series when nothing matches, which means it cannot tell you *which* instance is missing. Use it for "the whole job is gone", not for per-host checks.

The `unless on (instance)` pattern is the workhorse for layer 3. It takes the set of targets you know are alive and subtracts those that are emitting the metric you care about. What remains is the list of hosts that are healthy but lying by omission.

The `offset 1h` comparison catches drift without hardcoding counts. It fires when something that existed an hour ago no longer does. It self-heals after an hour, which is either a feature or a trap depending on how you route it; I send it to a ticket queue, not a pager.

Hardcoded counts like `< 4` are ugly but honest. If you know you have four hypervisors, say so. Keep the number next to the inventory source, or generate the rule from it.

## Watching the watcher

None of this helps if Prometheus itself or Alertmanager dies. The standard answer is a dead man's switch: a rule that always fires, routed to an external service that alerts when the heartbeat *stops*.

```yaml
      - alert: Watchdog
        expr: vector(1)
        labels:
          severity: none
        annotations:
          summary: "Heartbeat. If this stops arriving, the alerting pipeline is broken."
```

Route it in Alertmanager to a webhook with a short `repeat_interval` (a few minutes), pointing at any external heartbeat checker, self-hosted or SaaS, running outside the failure domain you are monitoring. Hosting that checker on the same box as Prometheus defeats the purpose.

Also check `prometheus_notifications_dropped_total` and `alertmanager_notifications_failed_total`. A misconfigured SMTP relay or expired chat webhook token turns every alert into a log line nobody reads.

## Testing it

`promtool test rules` supports input series that simply stop. Write a test where a series has values for the first ten minutes and then nothing, and assert that your missing-metric alert fires. If you cannot write that test, you probably do not have that coverage.

## Why this matters

Every serious monitoring gap I have dealt with came down to the same pattern: the system that should have told us something was wrong was itself part of what broke. Threshold alerts are written against the failure you imagined. Absence alerts are written against the failure you did not. They are cheap to add, rarely noisy once tuned, and they turn "we found out from a user" into "we found out from the pager". Treat the monitoring pipeline as production infrastructure with its own health checks, and assume that silence is a signal until proven otherwise.
