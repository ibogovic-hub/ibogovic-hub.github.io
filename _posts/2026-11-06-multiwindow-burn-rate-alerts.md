---
featured: true
title: "Multiwindow burn-rate alerts instead of error-rate thresholds"
tags: Monitoring
---

Most teams start with an alert like "page if the 5xx rate is above 1% for five minutes". It looks reasonable on the whiteboard. In production it does two bad things at once: it pages at 3 a.m. for a thirty-second blip that fixed itself, and it stays quiet while a slow 0.5% error leak eats the entire month's error budget over a week. The threshold has nothing to do with what you actually promised your users.

If you have an SLO, there is a better question to alert on: how fast are we spending the error budget, and will we run out before the window ends? That is a burn rate, and alerting on it across two windows at once fixes both failure modes.

## Burn rate in one paragraph

Take a 99.9% availability SLO over 30 days. The error budget is 0.1% of requests. A burn rate of 1 means you are failing exactly 0.1% of requests and will use the whole budget by the end of the window. A burn rate of 14.4 means you will use it in about two days; at that speed, one hour costs you 2% of the monthly budget. That is worth waking someone up for. A burn rate of 1 for a day is worth a ticket, not a page.

The multiwindow part: you require the burn rate to be high over a long window (so blips do not page) and over a short window (so the alert clears quickly once the problem is fixed, instead of staying red for an hour after recovery). This is the approach described in the Google SRE Workbook, and it holds up well in practice.

## Recording rules first

Computing ratios over 1h and 6h windows directly inside alert expressions is expensive and hard to read. Record the error ratio per window once, then alert on the recorded series.

```yaml
groups:
  - name: slo-api-recordings
    interval: 30s
    rules:
      - record: slo:api_errors:ratio_rate5m
        expr: |
          sum(rate(http_requests_total{job="api",code=~"5.."}[5m]))
          /
          sum(rate(http_requests_total{job="api"}[5m]))
      - record: slo:api_errors:ratio_rate30m
        expr: |
          sum(rate(http_requests_total{job="api",code=~"5.."}[30m]))
          /
          sum(rate(http_requests_total{job="api"}[30m]))
      - record: slo:api_errors:ratio_rate1h
        expr: |
          sum(rate(http_requests_total{job="api",code=~"5.."}[1h]))
          /
          sum(rate(http_requests_total{job="api"}[1h]))
      - record: slo:api_errors:ratio_rate6h
        expr: |
          sum(rate(http_requests_total{job="api",code=~"5.."}[6h]))
          /
          sum(rate(http_requests_total{job="api"}[6h]))
      - record: slo:api_errors:ratio_rate3d
        expr: |
          sum(rate(http_requests_total{job="api",code=~"5.."}[3d]))
          /
          sum(rate(http_requests_total{job="api"}[3d]))
```

Adjust the label matchers to whatever your services export. If your traffic is gRPC, count the relevant status codes instead of HTTP 5xx; decide up front whether client errors count against the SLO and write it down.

## The alerts

Two paging conditions and one ticket condition cover most services. The constant 0.001 is the error budget for a 99.9% target.

```yaml
groups:
  - name: slo-api-alerts
    rules:
      - alert: ApiErrorBudgetBurnFast
        expr: |
          (
            slo:api_errors:ratio_rate1h > (14.4 * 0.001)
            and
            slo:api_errors:ratio_rate5m > (14.4 * 0.001)
          )
          or
          (
            slo:api_errors:ratio_rate6h > (6 * 0.001)
            and
            slo:api_errors:ratio_rate30m > (6 * 0.001)
          )
        labels:
          severity: page
        annotations:
          summary: "API is burning its 30d error budget fast"
          runbook: "https://wiki.example.internal/runbooks/api-slo"
      - alert: ApiErrorBudgetBurnSlow
        expr: |
          slo:api_errors:ratio_rate3d > (1 * 0.001)
          and
          slo:api_errors:ratio_rate6h > (1 * 0.001)
        labels:
          severity: ticket
        annotations:
          summary: "API error budget is being consumed faster than planned"
```

Note what is missing: no `for:` clause. The long window already provides the smoothing that `for: 5m` was trying to give you, and the short window handles fast reset. Adding `for:` on top only delays the page.

## Test before you trust it

`promtool` can unit-test rules against synthetic series, which is worth doing once so you know the alert fires when you think it does.

```bash
promtool check rules slo-api-recordings.yml slo-api-alerts.yml
promtool test rules slo-api-tests.yml
```

A minimal test feeds a steady 2% error ratio for two hours and asserts that `ApiErrorBudgetBurnFast` is firing at the 1h mark. Write a second case with a 30-second spike and assert nothing fires. Those two cases are exactly the failure modes of the old threshold alert.

## Things that bite

Low-traffic services are the main trap. At ten requests per minute, a single failure in a 5-minute window is a 2% error ratio and will satisfy the short-window condition. The long window usually saves you, but for very quiet endpoints consider adding a minimum request-rate guard, or grouping several small services into one SLO.

Label cardinality matters too. If you record the ratio per route or per pod, you multiply the series count by every window. Record at the level you actually page on, usually per service.

Finally, the numbers 14.4 and 6 assume a 30-day window. If your SLO window is 28 days or a calendar month, the maths shifts slightly; it rarely changes the operational outcome, but do the calculation once rather than copying constants blindly.

## Why this matters

The cost of a noisy pager is not the individual false page, it is the slow erosion of trust: after a few weeks people start acknowledging alerts without looking. Burn-rate alerts tie paging directly to the promise made to users, so every page answers "are we going to break the SLO" instead of "did a number cross a line". In teams I have run, switching from raw thresholds to multiwindow burn rates cut the overnight pages to the ones that actually needed a human, and it caught the slow leaks that the old alerts never saw.
