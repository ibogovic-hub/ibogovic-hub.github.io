---
title: "Default-deny egress on Linux servers with nftables"
tags: Security
---

Most incident timelines I have read share one boring step: the compromised host reached out. A web shell pulled a second stage over HTTPS, a cryptominer talked to its pool, a reverse shell connected to a VPS somewhere. Inbound rules were fine. Nobody had ever written an outbound rule, because "servers need to talk to the internet" and the policy stopped there.

A database server does not need to talk to the internet. Neither does most of your fleet. It needs DNS to your resolvers, NTP to your time sources, your package mirror, your log collector and maybe a handful of APIs. Everything else is either a misconfiguration or an attacker. Default-deny egress turns both of those into a logged, visible event instead of a silent success.

## Start by measuring, not blocking

If you flip a server to drop all outbound traffic on day one, you will find the dependencies the hard way. Run the policy in log-only mode first. With nftables that means an accept policy plus a log rule at the end of the output chain, so anything not explicitly allowed gets recorded but still passes.

Collect for a week or across a full patch and backup cycle. Monthly jobs, certificate renewals and licence checks are the ones that bite you if you only watch for a day.

## The ruleset

This is a starting point for a typical internal Linux server. Adjust the sets to your environment; the structure is what matters.

```text
#!/usr/sbin/nft -f
# /etc/nftables.d/egress.nft

table inet egress {
    set dns_servers {
        type ipv4_addr
        elements = { 10.10.0.53, 10.10.1.53 }
    }
    set ntp_servers {
        type ipv4_addr
        elements = { 10.10.0.123 }
    }
    set mirrors {
        type ipv4_addr
        flags interval
        elements = { 10.20.5.0/28 }
    }
    set log_collectors {
        type ipv4_addr
        elements = { 10.30.0.10 }
    }

    chain output {
        type filter hook output priority filter; policy accept;

        oif "lo" accept
        ct state established,related accept

        ip daddr @dns_servers udp dport 53 accept
        ip daddr @dns_servers tcp dport 53 accept
        ip daddr @ntp_servers udp dport 123 accept
        ip daddr @mirrors tcp dport { 80, 443 } accept
        ip daddr @log_collectors tcp dport 6514 accept

        # Root-owned processes only for anything below; app users stay boxed
        meta skuid 0 ip daddr 10.0.0.0/8 tcp dport 22 accept

        limit rate 10/minute burst 20 packets \
            log prefix "EGRESS-DENY " level warn
        # Step 2: uncomment once the log is quiet
        # drop
    }
}
```

A few choices worth explaining.

`ct state established,related accept` early on keeps return traffic for inbound connections working. Without it, your SSH sessions and any service you host break the moment you start dropping.

Sets keep the rules readable and let you update destinations atomically with `nft add element` from config management, without reloading the whole table.

`meta skuid` matches the owning UID of the socket. It is a cheap way to say "the web server user may only talk to the database, root may also SSH to the jump hosts". It only works on locally generated traffic, which is exactly what an output chain sees.

The rate-limited log rule matters. An attacker, or a broken app retrying in a loop, can otherwise flood journald with deny lines.

## Turning it on

Once the log has been quiet for a full cycle, remove the comment on `drop` (or change the chain policy to drop and keep the log line). Validate before loading:

```bash
sudo nft -c -f /etc/nftables.d/egress.nft && \
sudo nft -f /etc/nftables.d/egress.nft
sudo journalctl -k --since "1 hour ago" | grep EGRESS-DENY | \
  awk '{for(i=1;i<=NF;i++) if($i ~ /^(DST|DPT|UID)=/) printf "%s ", $i; print ""}' | \
  sort | uniq -c | sort -rn | head
```

That one-liner gives you a ranked list of what is being denied, by destination, port and UID. On a clean server it should be empty. When it is not, you either found a missing dependency or something you need to look at closely.

Ship those kernel log lines to your SIEM and alert on them. An internal server trying to reach an unknown external IP on 443 at 03:00 is one of the highest-signal alerts you can have, and it costs almost nothing to produce.

## Things that will trip you up

Container runtimes and Kubernetes CNIs install their own nftables or iptables rules, and forwarded container traffic hits the forward hook, not output. Host egress filtering does not cover pods; use network policies there.

Hostname-based allow lists do not exist at this layer. If a vendor API lives behind a CDN with rotating addresses, route it through an egress proxy and allow only the proxy. That is cleaner anyway, because the proxy can log the hostname.

IPv6. If the host has a global v6 address and you only wrote `ip daddr` rules, add the `ip6` equivalents or block v6 egress explicitly. Otherwise you have built a very neat filter with a door next to it.

## Why this matters

Inbound hardening reduces the chance of compromise. Egress filtering reduces what a compromise can do, and makes it loud. In my experience the second one pays off more often, because something eventually gets in: a vulnerable plugin, a leaked key, a bad dependency. When that happens, the difference between "the attacker pulled tooling and exfiltrated data" and "we got an alert for a blocked connection and rebuilt one host" is often a ruleset like the one above, written months earlier on a quiet afternoon.
