---
title: Weekly Recap: A Bgp Hijack In The Supply Chain, Eight Stable Kernels, And Agent Guardrails
tags: Security
---

Three things this week are worth an operator's attention: a software update poisoned via BGP hijacking, a large stable-kernel drop landing mid-week, and the direction vendors are taking with AI agent controls. None of these are exotic research findings. All three change something you should be doing on Monday.

## A malicious update delivered by hijacking the route to the update server

SecurityWeek reported that a malicious Virtualizor update was served to customers after the route to the vendor's distribution infrastructure was hijacked at the BGP layer ([SecurityWeek](https://www.securityweek.com/malicious-virtualizor-update-served-via-bgp-hijacking/)). The mechanism matters more than the specific product. This is not a compromised build server and not a stolen signing key. The vendor's own infrastructure was fine; the internet's opinion of where that infrastructure lived was not.

Most of our supply-chain controls assume the network is a dumb pipe and that TLS plus a signature is enough. TLS only helps if the attacker cannot obtain a valid certificate for the hijacked prefix, and domain-validated issuance is itself reachable over the same hijacked path. Package signature verification helps if — and only if — the update client actually enforces it and the trust anchor is pinned out-of-band. Plenty of appliance and control-panel update mechanisms still do a plain fetch-and-execute.

Operationally, the takeaways are unglamorous:

- Inventory every system in your estate that pulls and applies updates automatically from a vendor-controlled endpoint without independent signature verification. Those are your exposure.
- Egress-filter those hosts. A hypervisor control panel does not need arbitrary outbound internet; it needs a handful of named destinations.
- Turn on RPKI route origin validation on your own edge if you have not. It does not stop every hijack, but it removes the cheapest class of them, and the ecosystem coverage is now good enough that the drop-invalid policy is defensible in production.

If you run BIRD, checking that you are actually rejecting invalids rather than merely computing the state is a two-minute exercise:

```bash
# Verify RPKI table is populated and the ROA check is wired into the import filter
birdc show route table rpki4 count
birdc show route table rpki4 for 8.8.8.0/24 all | head -20

# Confirm invalids are being dropped, not just logged
birdc show route filtered protocol upstream1 count
```

And the corresponding filter fragment, so the check is enforced rather than advisory:

```
function is_rpki_ok()
{
  case roa_check(rpki4, net, bgp_path.last) {
    ROA_INVALID: return false;
    else: return true;
  }
}

protocol bgp upstream1 {
  ipv4 {
    import filter {
      if ! is_rpki_ok() then reject;
      accept;
    };
  };
}
```

Also worth doing: subscribe your own prefixes to a BGP monitoring feed so you learn about a hijack from an alert rather than from a customer. Detection latency here is the whole game.

## Eight stable kernels on Wednesday

LWN noted eight stable kernel releases landing on 2 September ([LWN](https://lwn.net/)), with the 7.1.x and 7.2.x lines among those refreshed ([kernel version history](https://en.wikipedia.org/wiki/Linux_kernel_version_history)). A batch that size on a single day is the usual signal that a fix touching a widely shared subsystem got backported across every maintained branch.

The practical problem for most shops is not applying the patch, it is knowing which of your hosts need a reboot and getting them rebooted without a change-freeze argument. If you are not already tracking that as a first-class metric, it is a small amount of work:

```bash
# Debian/Ubuntu: which hosts have a pending kernel reboot
test -f /var/run/reboot-required && echo "REBOOT_REQUIRED $(hostname)"

# RHEL-family equivalent
needs-restarting -r || echo "REBOOT_REQUIRED $(hostname)"

# Running vs. installed kernel, distro-agnostic sanity check
printf 'running: %s\n' "$(uname -r)"
ls -1 /lib/modules | sort -V | tail -1 | xargs printf 'newest installed: %s\n'
```

Wire that into your existing node exporter textfile collector and you get a fleet-wide "hosts running a stale kernel" panel for essentially no effort. The value is not the dashboard — it is that pending-reboot count becomes a number someone owns, instead of a thing that gets discovered during an incident.

## Vendors are shipping guardrails for AI agents, which means you now own agent policy

The Black Hat vendor round-up describes a common pattern across announcements: guardrails for skill discovery, blocking of risky operations, MCP security controls, command monitoring against built-in or custom policy, and anti-tampering to stop an agent or user disabling the tooling ([SecurityWeek](https://www.securityweek.com/black-hat-usa-2026-summary-of-vendor-announcements-part-2/)). InformationWeek's read of the conference was that the AI conversation moved from novelty toward operational concerns ([InformationWeek](https://www.informationweek.com/cybersecurity/at-black-hat-2026-security-leaders-go-deeper-to-get-ahead)).

Strip the product framing and what is being sold is an authorization layer for non-human actors that hold real credentials. That is a problem most organisations have already created and not yet governed. If an agent in your environment can run arbitrary commands with a service account, the interesting questions are the boring identity ones: which identity does it authenticate as, what is that identity allowed to do, where does its command history land, and who reviews it.

You do not need a product to start. Give each agent its own identity rather than a shared one. Scope that identity down to what it demonstrably needs. Ship its command log to the same place as your human session logs, and make the log destination something the agent cannot write to. Anti-tampering as a feature is only meaningful if the audit trail is outside the agent's blast radius — which is the same argument we have been making about root-owned syslog for twenty years.

## What ties these together

Two of these three items are failures of trust boundaries that were assumed rather than enforced: the update path was trusted because it usually works, and the agent is trusted because it was convenient to give it broad rights. The kernel item is the reminder that the unglamorous hygiene work — knowing what is running, knowing what needs a reboot — is what makes the other two survivable. Pick one of the three commands above and actually run it against your fleet this week.
