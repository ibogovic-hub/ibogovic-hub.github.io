---
title: Alert rules that survive contact with a real on-call rotation
tags: Monitoring
---

A node exporter dropped off the network at 03:12 on a Sunday. By 03:14 the on-call engineer had eleven pages: one for the scrape target being down, one for "no data" on disk space, one for CPU idle crossing a threshold because the last sample was stale, and eight more from per-filesystem rules that evaluated against absent series. The host was a non-production jump box that nobody would have cared about until Monday. The engineer acknowledged everything, silenced the instance, and went back to sleep. Three weeks later the same silence pattern was applied reflexively to a storage node that actually was failing.

That is the real failure mode of Prometheus alerting. It is not that the rules are wrong in isolation; it is that they fan out. One root cause produces N pages, the human learns that pages are noise, and the signal you actually built the system for gets swallowed.

There are three fixes that do most of the work, and none of them require a new tool.

## 1. Make absence a single alert, and gate everything else on it

The cheapest win is to stop alerting on metrics that are missing. If `up == 0`, every other rule for that instance is meaningless. Alertmanager's inhibition rules handle this, but you have to actually give the alerts matching labels.

```yaml
# alertmanager.yml
inhibit_rules:
  - source_matchers:
      - alertname = "InstanceDown"
    target_matchers:
      - severity =~ "warning|critical"
    equal: ["instance"]

route:
  group_by: ["alertname", "cluster", "instance"]
  group_wait: 45s
  group_interval: 5m
  repeat_interval: 4h
  receiver: default
```

`group_wait: 45s` matters more than people expect. With the default 30s you frequently fire the symptom alert before the `InstanceDown` alert has been evaluated and delivered, which defeats the inhibition entirely. Set `group_wait` to comfortably exceed your rule evaluation interval plus the `for:` duration skew between the two rules.

## 2. Alert on burn, not on instantaneous thresholds

`node_filesystem_avail_bytes / node_filesystem_size_bytes < 0.1` fires on any filesystem that happens to sit at 91 percent full forever. What you care about is whether it will run out before someone can act. `predict_linear` over a window answers that directly.

```yaml
# rules/disk.yml
groups:
  - name: disk
    interval: 1m
    rules:
      - alert: DiskWillFillIn4Hours
        expr: |
          predict_linear(
            node_filesystem_avail_bytes{fstype!~"tmpfs|overlay|squashfs"}[6h],
            4 * 3600
          ) < 0
          and on (instance, device)
          node_filesystem_avail_bytes / node_filesystem_size_bytes < 0.20
        for: 30m
        labels:
          severity: critical
        annotations:
          summary: "{{ $labels.device }} on {{ $labels.instance }} projected full"
          description: >-
            {{ $labels.mountpoint }} at
            {{ $value | printf "%.0f" }} projected free bytes in 4h.
```

The `and on (...)` clause is the part that keeps this sane. Pure `predict_linear` will happily project a 2 TB volume to zero because of a log rotation blip; requiring the filesystem to already be under 20 percent free removes almost all of that. The `for: 30m` removes the rest.

Validate the rule file before you ship it. `promtool` catches label typos and template errors that would otherwise only appear when the alert fires at 03:00:

```bash
promtool check rules rules/disk.yml
promtool test rules tests/disk_test.yml
```

## 3. Put the runbook link in the alert, or delete the alert

An alert with no documented response is a request for improvisation under time pressure. The rule is simple: every alert annotation carries a `runbook_url`, and if you cannot write two sentences describing what the responder should do, the alert becomes a dashboard panel instead of a page. This single policy removed more rules from our config than any deliberate cleanup effort did, because writing the runbook forces you to admit that "CPU is high" has no action attached to it.

A useful companion check is a rule that alerts on your own alerting: `ALERTS{alertstate="firing"}` counted over a week tells you which rules fire most and get resolved without human action. Those are your deletion candidates.

## Why this matters

The value of a monitoring stack is not the number of conditions it can detect. It is whether the person holding the pager believes the next page. That belief is a finite resource, and every self-resolving 03:00 alert spends some of it. I have watched a well-instrumented environment become functionally unmonitored because the team had built an unconscious habit of silencing first and reading second — the data was all there, the dashboards were good, and the outage still ran forty minutes longer than it needed to. Fewer rules, each with a projection window, an inhibition path, and a written response, will beat a comprehensive ruleset that nobody trusts.
