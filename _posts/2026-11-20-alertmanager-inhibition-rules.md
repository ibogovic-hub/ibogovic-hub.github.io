---
title: "Stop the alert storm: Alertmanager inhibition rules that follow your topology"
tags: Monitoring
---

A site uplink drops at 02:10. Within a minute the on-call phone gets the uplink alert, then one alert per unreachable switch behind it, then blackbox probe failures for every service at that site, then a few "target down" alerts from the Prometheus scraping those hosts. Forty pages for one fault. The engineer spends the first ten minutes scrolling through them to find the root cause, when the uplink alert already told them.

Grouping does not fix this. `group_by` packs related alerts into one notification, but "related" only means "has the same label values". The uplink alert and the probe failures carry different `alertname` values and often different `job` labels, so they end up in separate groups. What you need is a rule that says: while the cause is firing, don't page on the symptoms. In Alertmanager that is an inhibition rule.

## How inhibition works

An inhibit rule has three parts:

- `source_matchers`: the alert that, while it fires, does the muting.
- `target_matchers`: the alerts that can be muted.
- `equal`: labels that must have the same value on source and target. This keeps an outage at site A from muting alerts at site B.

Inhibited alerts are still evaluated, still visible in the Alertmanager UI and API, and still marked as inhibited there. They just don't produce notifications. Once the source resolves, any target that is still firing gets sent on the next group interval. That last point matters: if the uplink comes back and a switch stays dead, you still hear about the switch.

## Labels come first

Inhibition only works as well as your labels. If your switch alerts don't carry a `site` label, `equal: [site]` has nothing to match, and Alertmanager treats a label that is missing on both sides as equal. That means one source alert with no `site` label can mute every target alert that also lacks it. Fix the labels before you write the rules. I add them at scrape time through relabeling or file_sd target labels, so every series and every alert built on it inherits them:

```yaml
# file_sd target file, one per site
- targets: ["sw-zrh-01:9116", "sw-zrh-02:9116"]
  labels:
    site: zrh
    layer: access
- targets: ["rtr-zrh-edge:9116"]
  labels:
    site: zrh
    layer: edge
```

Then add a severity and a coarse role to each alert rule, so the matchers can stay short:

```yaml
groups:
  - name: site-connectivity
    rules:
      - alert: SiteUplinkDown
        expr: ifOperStatus{layer="edge", ifAlias=~"UPLINK.*"} == 2
        for: 1m
        labels:
          severity: critical
          role: cause
      - alert: SwitchUnreachable
        expr: up{job="snmp", layer="access"} == 0
        for: 2m
        labels:
          severity: critical
          role: symptom
```

Note the longer `for` on the symptom. If the symptom fires before the source, Alertmanager has nothing to inhibit against yet and the page goes out. Give the cause a head start.

## The rules

```yaml
inhibit_rules:
  # Uplink down at a site mutes reachability symptoms at the same site
  - source_matchers:
      - alertname = SiteUplinkDown
    target_matchers:
      - role = symptom
    equal: [site]

  # A critical alert mutes the warning of the same alert on the same instance
  - source_matchers:
      - severity = critical
    target_matchers:
      - severity = warning
    equal: [alertname, instance]

  # Planned maintenance flag mutes everything at that site except itself
  - source_matchers:
      - alertname = SiteMaintenance
    target_matchers:
      - alertname != SiteMaintenance
    equal: [site]
```

The second rule is the cheapest win in most setups: disk at 85% warning and disk at 95% critical on the same host should not both page. The third gives you a maintenance switch driven by a metric (a static exporter value or a pushgateway flag), which leaves a trace in Git and in Prometheus, unlike a silence clicked in the UI and forgotten.

## Test before you reload

`amtool` can validate the config and show you what the routing tree does with a given label set:

```bash
amtool check-config alertmanager.yml
amtool config routes test --config.file=alertmanager.yml site=zrh severity=critical role=symptom
```

`routes test` covers routing, not inhibition. To check inhibition, fire a source alert at a staging Alertmanager and query for targets:

```bash
amtool alert add SiteUplinkDown site=zrh severity=critical role=cause \
  --alertmanager.url=http://am-staging:9093
amtool alert add SwitchUnreachable site=zrh instance=sw-zrh-01 role=symptom \
  --alertmanager.url=http://am-staging:9093
amtool alert query --inhibited --alertmanager.url=http://am-staging:9093
```

If `SwitchUnreachable` doesn't show as inhibited, the label isn't where you think it is. In my experience that's the usual cause.

## Things that bite

- Inhibition is evaluated per Alertmanager instance. In an HA cluster every node needs the same config, or different nodes will make different decisions. Deploy the config from one source.
- Don't let a source inhibit itself. A broad `source_matchers: severity=critical` paired with `target_matchers: severity=critical` mutes everything. Alertmanager won't let an alert inhibit itself, but two critical alerts that share the `equal` labels can still mute each other.
- Keep an eye on the cause. If the source alert's expression breaks (renamed metric, dropped scrape), you lose the page about it and keep the inhibition logic around for nothing. Pair cause alerts with an absent-data check.

## Why this matters

On a bad night the on-call engineer's attention is the scarcest thing you have. Every symptom page is another thing they have to read, acknowledge and dismiss before they can act. I've seen teams start muting whole channels after a few storms, and then the one page that mattered got missed. Inhibition rules turn your network topology into alert logic: one page for the cause, with the symptoms still there in the UI for anyone who wants to check the blast radius. It's maybe thirty lines of YAML plus the label hygiene you should have anyway.
