---
title: "Finding the label that is eating your Prometheus memory"
tags: Monitoring
---

The Prometheus server that ran happily for a year starts getting OOM-killed after a routine deploy. Nothing in the scrape config changed. Restarts take longer each time because the WAL replay grows, and the dashboards go blank during every replay. In almost every case I have seen, the cause is the same: someone added a label whose values are unbounded, and the number of active series went from hundreds of thousands to millions.

Prometheus memory scales roughly with the number of active series in the head block, not with the number of targets. One histogram with ten buckets and a `user_id` or `request_path` label can produce more series than your whole node_exporter fleet. The fix is rarely more RAM. It is finding the offending metric and label, and stopping it at the scrape.

## Step one: confirm it is series growth

Check the head series count over time before you blame anything:

```text
prometheus_tsdb_head_series
rate(prometheus_tsdb_head_series_created_total[5m])
```

A step change in `prometheus_tsdb_head_series` lined up with a deploy is your answer. A steady high creation rate with a flat total means churn: series being created and abandoned, typically from pod names or label values that include a timestamp or ID.

## Step two: find the metric

The TSDB status endpoint already does the counting for you. It lists the top metric names by series count and the top label names by value count:

```bash
curl -s http://localhost:9090/api/v1/status/tsdb \
  | jq '.data | {seriesCountByMetricName, labelValueCountByLabelName}'
```

The same data is on the `/tsdb-status` page in the web UI. If the server is too unstable to answer, run the analysis offline against a copy of the data directory:

```bash
promtool tsdb analyze /var/lib/prometheus/data
```

That prints highest-cardinality labels, label pairs and metric names for the latest block. It is slow on large blocks but does not need the server running.

## Step three: find the label within the metric

Once you have a suspect metric, ask which label explodes it. This query is expensive, so run it against a single metric name, never `{__name__=~".+"}` on a struggling server:

```text
count by (__name__) ({__name__="http_server_request_duration_seconds_bucket"})
count(count by (path) (http_server_request_duration_seconds_bucket))
count(count by (instance) (http_server_request_duration_seconds_bucket))
```

Repeat the middle line for each label. The one returning tens of thousands of distinct values is the culprit. In my experience it is usually one of: raw URL paths with IDs embedded, client IPs, user or tenant IDs, error message strings, or Kubernetes labels copied wholesale by a relabel rule that used `labelmap` too generously.

## Step four: stop it at the scrape

The right long-term fix is in the application: template the route (`/api/orders/{id}`), not the raw path. That takes a release cycle. In the meantime, drop or rewrite it in Prometheus with `metric_relabel_configs`, which run after the scrape and before ingestion:

```yaml
scrape_configs:
  - job_name: orders-api
    kubernetes_sd_configs:
      - role: pod
    metric_relabel_configs:
      # Collapse numeric IDs in paths to a placeholder
      - source_labels: [path]
        regex: '(.*)/[0-9]+(/.*)?'
        target_label: path
        replacement: '${1}/:id${2}'
      # Drop a debug metric nobody queries
      - source_labels: [__name__]
        regex: 'orders_cache_entry_age_seconds.*'
        action: drop
      # Remove a label entirely
      - regex: 'client_ip'
        action: labeldrop
```

Be careful with `labeldrop`: if two series differ only by the dropped label, they now collide and the scrape reports duplicate samples. Rewriting to a bounded set of values is safer than deleting.

## Step five: put a ceiling on it

Relabelling fixes today's problem. Limits stop the next one from taking the server down. Prometheus supports per-job limits that fail the scrape instead of ingesting the excess:

```yaml
  - job_name: orders-api
    sample_limit: 50000
    label_limit: 30
    label_value_length_limit: 200
```

When a target exceeds `sample_limit`, the whole scrape is rejected and `up` goes to 0 for that target. That is the behaviour you want: one team's dashboard breaks, instead of everybody's monitoring. Alert on it so the owning team finds out:

```text
increase(prometheus_target_scrapes_exceeded_sample_limit_total[15m]) > 0
```

Pick the limit from current reality, not theory. Look at `scrape_samples_post_metric_relabeling` per job, take the peak over a couple of weeks, and set the limit with headroom of perhaps two to three times. Revisit it when the service legitimately grows.

## What to put in the review checklist

Cardinality problems are cheap to catch in code review and expensive to catch in production. The questions I ask when a new metric lands:

- Is every label value from a known, bounded set?
- Would this label still be bounded at ten times today's traffic or tenant count?
- Is a histogram really needed, or would a counter and a sum do?
- Does a log line or a trace serve this better than a metric?

The last one matters most. Per-request detail belongs in logs and traces, where high cardinality is the point. Metrics are for aggregates.

## Why this matters

Monitoring that falls over under load is worse than no monitoring, because it fails exactly when you need it and you lose trust in it afterwards. I have sat through incidents where the first twenty minutes went to figuring out why Prometheus was down rather than why the service was. Every one of those traced back to a single label nobody thought about. Running the TSDB status check monthly and setting a `sample_limit` on every job turns that from an outage into a failed scrape with a named owner.
