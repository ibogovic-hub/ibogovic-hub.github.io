---
title: "Alerting on silence: catching the metrics that stop arriving"
tags: Monitoring
---

A disk fills up on a backup host. Nobody gets paged. The post-mortem shows the alert rule was correct: `node_filesystem_avail_bytes` below 10 percent for 15 minutes. The problem was that the node exporter on that host had died three weeks earlier after a package upgrade, and a rule that compares a missing series to a threshold returns nothing. Nothing is not a firing alert. The dashboard panel showed "No data", and nobody looks at a dashboard for a host that never complains.

This is the most common blind spot I see in Prometheus setups. Threshold rules only fire on data that exists. When the data disappears, the rule goes quiet, and the quiet looks exactly like health.

## Three ways a series goes missing

It helps to separate the cases, because each needs a different check:

1. **The target is unreachable.** Prometheus still knows about the target from service discovery, scrapes fail, and `up` goes to 0. This is the easy case.
2. **The target vanishes from discovery.** A Consul registration expires, a Kubernetes pod is gone, a file_sd entry gets deleted by a bad config push. There is no `up` series at all any more, so `up == 0` never matches.
3. **The target is up but a specific metric stops.** The exporter answers, but a collector fails, a textfile collector script stops writing, or a relabel rule drops the series. `up` is 1 and everything looks green.

Most teams cover case 1 and assume they are done.

## Rules that cover all three

```yaml
groups:
  - name: meta-monitoring
    rules:
      # Case 1: target known but failing scrapes
      - alert: TargetDown
        expr: up == 0
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "{{ $labels.job }} on {{ $labels.instance }} is not scrapeable"

      # Case 2: an expected job has no targets at all
      - alert: JobMissing
        expr: absent(up{job="node"})
        for: 10m
        labels:
          severity: critical
        annotations:
          summary: "No targets discovered for job=node"

      # Case 2b: fewer targets than yesterday (catches partial discovery loss)
      - alert: TargetCountDropped
        expr: |
          count by (job) (up)
            < 0.9 * count by (job) (up offset 1d)
        for: 15m
        labels:
          severity: warning

      # Case 3: a specific series stopped while the target stays up
      - alert: FilesystemMetricMissing
        expr: |
          up{job="node"} == 1
          unless on (instance)
          node_filesystem_avail_bytes{mountpoint="/"}
        for: 15m
        labels:
          severity: warning

      # Textfile collector freshness (backup scripts, cron results)
      - alert: TextfileStale
        expr: time() - node_textfile_mtime_seconds > 3 * 3600
        for: 10m
        labels:
          severity: warning
```

A few notes from running these:

- `absent()` only works for a series you name explicitly. It takes no label set from the data, so you cannot write one generic `absent()` rule for every host. Use it for whole jobs, and use the `unless` pattern for per-instance checks.
- The `unless on (instance)` form is the workhorse. It returns every instance that is up but lacks the expected series, with labels intact, so routing and silences work normally.
- The `offset 1d` comparison is noisy during planned decommissions. That is acceptable; a decommission is a change, and a change should be acknowledged.
- Textfile collector metrics are the worst offenders. A backup script that writes `backup_last_success_timestamp` and then stops running leaves the last value in place forever if the file is not removed. Alert on freshness, not on the value.

## Who watches Prometheus

All of the above assumes Prometheus and Alertmanager are themselves running and able to send. If Prometheus crashes, every rule above goes silent at once. The standard fix is a dead man's switch: an alert that always fires.

```yaml
      - alert: Watchdog
        expr: vector(1)
        labels:
          severity: none
        annotations:
          summary: "Alerting pipeline heartbeat"
```

Route it in Alertmanager to an external receiver that expects a ping every few minutes and pages you when the pings stop. That external receiver must live outside the failure domain: a different cloud account, a SaaS heartbeat service, or at minimum a different site. A watchdog that runs on the same VM as Prometheus proves nothing.

Two more checks I add in every setup:

- `prometheus_notifications_dropped_total` and `alertmanager_notifications_failed_total` increasing. A rotated Slack webhook or an expired SMTP password produces alerts that fire correctly and are delivered nowhere.
- `prometheus_rule_evaluation_failures_total` increasing. A typo in a recording rule breaks every alert built on top of it, quietly.

## Testing it instead of trusting it

`promtool test rules` lets you feed synthetic series into rules and assert what fires. Write one test per missing-data rule where the series simply stops partway through the input. If the test does not produce an alert, neither will production. Then, once a quarter, stop an exporter on a non-critical host on purpose and time how long it takes for a human to be notified.

## Why this matters

Every serious monitoring gap I have dealt with was a silence, not a wrong threshold. Thresholds get tuned because noisy alerts annoy people into fixing them. Missing data annoys nobody, so it survives for weeks until the one incident where it counts. Treat "no data" as a state you alert on, monitor the monitoring from outside its own failure domain, and test the pipeline end to end. It is a small set of rules, and it is the difference between a monitoring system and a dashboard collection.
