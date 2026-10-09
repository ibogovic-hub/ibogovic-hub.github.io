---
title: "Your quietest Prometheus target might be your most broken one"
tags: Monitoring
---

A common failure in a mature Prometheus setup is not a noisy alert. It is the alert that never fires. An exporter stops reporting, a relabel rule drops a target, or a host leaves service discovery, and every rule that depends on that series goes quiet. No series means no evaluation. No evaluation means no alert. The dashboard shows a flat gap, and nobody reads that gap as an incident.

I have seen this with disk alerts and with backup checks. Someone changes `metrics_path` on a scrape job and gets the path wrong. The target goes to `up == 0`, but the alert was written as `node_filesystem_avail_bytes / node_filesystem_size_bytes < 0.1`. Once the target is down, that expression has no inputs, so it returns nothing and the alert stays green until the disk fills.

## Why threshold rules fail open

PromQL drops series that do not exist. That works well for cardinality and badly for safety. A comparison like `metric < threshold` only alerts on series that are present and breaching. If a series is missing, the rule treats it the same as a healthy one.

So you need two kinds of rules:

1. **Threshold rules** answer: is a value I can see bad?
2. **Presence rules** answer: am I still seeing the values I expect?

Most teams write plenty of the first kind and very few of the second.

## Three layers of presence checking

**Layer 1: target health.** This is the minimum. Alert when a target is down, and give it enough `for:` time to ride out a restart.

**Layer 2: expected series per job.** A target can be `up == 1` and still not export the metric you care about. Examples include a textfile collector whose cron job died, or an exporter module that fails one probe and quietly skips its output. `absent()` and `absent_over_time()` catch this.

**Layer 3: staleness of the value itself.** Some metrics are timestamps, such as "last successful backup" or "last config sync". The series exists and keeps getting scraped, but the job behind it stopped running days ago. Compare the value to `time()`.

## A working rule file

```yaml
groups:
  - name: presence
    rules:
      # Layer 1: scrape target down
      - alert: TargetDown
        expr: up == 0
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "{{ $labels.job }} target {{ $labels.instance }} is down"

      # Layer 1b: an entire job vanished from discovery
      - alert: ScrapeJobMissing
        expr: absent(up{job="node"})
        for: 10m
        labels:
          severity: critical
        annotations:
          summary: "No targets at all for job=node - check SD / relabeling"

      # Layer 2: target up but key metric not exported
      - alert: FilesystemMetricsMissing
        expr: |
          up{job="node"} == 1
          unless on(instance)
          node_filesystem_avail_bytes{fstype!~"tmpfs|overlay"}
        for: 15m
        labels:
          severity: warning
        annotations:
          summary: "{{ $labels.instance }} is up but exports no filesystem metrics"

      # Layer 3: value present but stale
      - alert: BackupStale
        expr: time() - backup_last_success_timestamp_seconds > 26 * 3600
        for: 10m
        labels:
          severity: critical
        annotations:
          summary: "Backup on {{ $labels.instance }} last succeeded {{ $value | humanizeDuration }} ago"

      # Layer 3b: the timestamp series itself disappeared
      - alert: BackupMetricAbsent
        expr: absent_over_time(backup_last_success_timestamp_seconds[2h])
        labels:
          severity: critical
        annotations:
          summary: "Backup freshness metric not seen for 2h"
```

Validate the file with `promtool check rules presence.yml` before you reload.

The `unless on(instance)` rule does more work than it looks like. It takes every node target that is up and removes the ones that do export filesystem metrics. Whatever is left is broken in a way `up` alone cannot show. Because it keeps the `instance` label, the alert names the exact host. `absent()` cannot do that, since it only knows the labels you wrote into the selector.

## Pitfalls

- **`absent()` with label matchers** only returns labels from equality matchers. `absent(up{job=~"node.*"})` fires with no useful labels, so write one rule per job, or use the `unless` pattern.
- **Staleness thresholds should match the schedule, plus slack.** For a daily backup, 26 hours avoids paging on a job that runs late. 24 hours will page every time the job takes a little longer than usual.
- **Do not forget the monitoring stack itself.** Prometheus cannot alert that Prometheus is dead. Use an always-firing watchdog alert routed to an external dead man's switch, or have a second Prometheus scrape the first. Alertmanager needs the same coverage.
- **Federated and remote-write setups add another gap.** If the upstream stops receiving samples, the central rules go quiet in exactly the same way. Run presence rules where the data finally lands, not only at the edge.

## Auditing what you already have

A quick check: for each threshold rule, ask what happens if the left-hand series disappears. If the answer is "nothing fires", either pair the rule with a presence check or rewrite it with `or` so a missing series also triggers the alert. A one-off look at `count by (job) (up)` against your inventory also shows targets that dropped out of discovery without anyone noticing.

## Why this matters

Noisy alerts get fixed because they annoy people. Silent ones last for months, because nothing makes anyone look at them. In practice, the incidents that hurt most were the ones where the monitoring had a gap: backups that had not run for weeks, or a disk that filled on a host whose exporter had been gone since the last migration. Presence rules are cheap to write, rarely fire, and the times they do fire tend to be the failures you would otherwise find out about from users. Treat "no data" as an alert condition, not as a sign that everything is fine.
