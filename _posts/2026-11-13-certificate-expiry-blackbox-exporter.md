---
title: "Catching certificate expiry with the Prometheus blackbox exporter"
tags: Monitoring
---

The outage usually starts with a ticket that says "the API is down" and ends with someone finding a certificate that expired at 02:00. Nobody forgot to renew it on purpose. The renewal job failed silently three weeks ago, or the cert was renewed on disk but the load balancer kept serving the old one, or it was a vendor-managed endpoint that nobody owned. A calendar reminder does not catch any of those cases. You need to check what the endpoint actually serves, from the outside, and alert well before the deadline.

The Prometheus blackbox exporter does this well, and most teams that run Prometheus already have it deployed for HTTP checks. They just never write the expiry alerts.

## Probe what clients see, not what is on disk

Checking the PEM file on the server tells you what you think is deployed. Probing the endpoint tells you what clients receive. Those differ more often than you would expect: a reverse proxy that was never reloaded, a CDN with its own certificate, a second node in a pool that missed the deploy. The blackbox exporter does a real TLS handshake and exposes `probe_ssl_earliest_cert_expiry`, a Unix timestamp for the earliest expiry in the presented chain. Because it looks at the whole chain, it also catches an expiring intermediate.

A minimal module in `blackbox.yml`:

```yaml
modules:
  tls_connect:
    prober: tcp
    timeout: 5s
    tcp:
      tls: true
      tls_config:
        insecure_skip_verify: false
  https_2xx:
    prober: http
    timeout: 5s
    http:
      method: GET
      valid_status_codes: []
      fail_if_not_ssl: true
```

Use `tls_connect` for anything that is not HTTP: LDAPS on 636, SMTP submission with implicit TLS on 465, internal gRPC, the management interface of a firewall. Use `https_2xx` when you also want to know the service answers.

## Scrape config with a target list you can review

Keep the targets in a file so additions go through code review like everything else:

```yaml
scrape_configs:
  - job_name: tls-expiry
    metrics_path: /probe
    params:
      module: [tls_connect]
    scrape_interval: 5m
    file_sd_configs:
      - files: ["/etc/prometheus/targets/tls_endpoints.yml"]
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: 127.0.0.1:9115
```

```yaml
- targets:
    - api.example.internal:443
    - ldap01.example.internal:636
    - vpn.example.com:443
  labels:
    owner: platform
```

The `owner` label matters more than it looks. When the alert fires, the routing decides who gets it, and "unknown owner" is exactly how certificates expire.

Five minutes is plenty for a scrape interval. Certificates do not change every second, and you will be probing endpoints you do not own.

## Alert in stages

One alert at seven days is too late for anything that needs a purchase order or a change window. Two stages work better: a ticket at 21 days, a page at 7.

```text
groups:
- name: tls-expiry
  rules:
  - alert: TLSCertExpiringSoon
    expr: (probe_ssl_earliest_cert_expiry - time()) / 86400 < 21
    for: 1h
    labels:
      severity: ticket
    annotations:
      summary: "{{ $labels.instance }} certificate expires in {{ $value | humanize }} days"
  - alert: TLSCertExpiringCritical
    expr: (probe_ssl_earliest_cert_expiry - time()) / 86400 < 7
    for: 15m
    labels:
      severity: page
  - alert: TLSProbeFailing
    expr: probe_success{job="tls-expiry"} == 0
    for: 30m
    labels:
      severity: ticket
```

The third rule is the one people skip. If the handshake fails, `probe_ssl_earliest_cert_expiry` is not exported for that probe, and the expiry alerts simply stop evaluating for that target. A host that already serves an expired certificate fails verification, the metric vanishes, and the expiry alert goes quiet exactly when it should be loudest. `probe_success == 0` covers that gap.

With short-lived ACME certificates, 21 days may be noisy if your renewal runs at 30 days remaining. That is fine: the alert then means "renewal should have happened and did not", which is the failure you care about. Adjust the threshold to sit just below your renewal point, not to a round number.

## Check it by hand

Before trusting the alert, confirm the exporter sees what you expect:

```bash
curl -s "http://127.0.0.1:9115/probe?module=tls_connect&target=ldap01.example.internal:636" \
  | grep -E 'probe_success|probe_ssl_earliest_cert_expiry'

# compare against openssl
echo | openssl s_client -connect ldap01.example.internal:636 -servername ldap01.example.internal 2>/dev/null \
  | openssl x509 -noout -enddate
```

If the two disagree, you are probably hitting a different node behind a load balancer or missing SNI. For virtual hosts on a shared IP, set `server_name` in the module's `tls_config`, or the exporter may receive the default certificate instead of the one users get.

## Things that still bite

- Internal CAs: mount the CA bundle and set `ca_file` instead of switching verification off. Skipping verification hides chain problems.
- Endpoints behind a firewall: the exporter has to run where the clients are. A probe from the monitoring VLAN says nothing about what partners see over the internet.
- Inventory drift: the target list goes stale. Once a quarter, diff it against your load balancer VIPs and DNS records.

## Why this matters

Every expired-certificate outage I have seen had a renewal process. What was missing was a check from the client's side and an owner on the alert. The blackbox exporter is usually already running; adding a module, a target file and three rules takes an afternoon. That is cheap compared with explaining why an expired LDAPS certificate locked everyone out of the VPN on a Monday morning.
