---
title: Detecting firewall rule drift before your auditor does
tags: Security
---

Someone opened a rule at 02:00 during an incident. It worked, the incident closed, and the rule stayed. Six months later it is still there, still `any` on source, and nobody remembers who added it or why. That is the normal state of most firewall estates, and it is why quarterly manual policy reviews find things that have been live for a quarter.

The fix is not more review meetings. It is a nightly job that compares what is actually running against what was approved, and fails loudly when they diverge.

## The shape of the problem

Firewall drift is harder to detect than config drift on a switch, for two reasons.

First, rule order matters. Two policies with identical rule sets but different sequence numbers behave differently. A naive text diff of the config dump flags every reordering as a change, which trains people to ignore the output.

Second, the same intent has many representations. An address object can be renamed, a service can be swapped from a named object to an inline port range, and a rule can be split into two. Semantically nothing changed. Line-by-line, everything changed.

So you need to normalise before you diff. Pull the policy through the API, reduce each rule to the fields that define its security behaviour, and compare those.

## Pulling and normalising

FortiGate exposes the policy table over REST. The fields that matter for a behaviour comparison are the interfaces, source, destination, service, action, and logging state.

```python
#!/usr/bin/env python3
"""Compare running FortiGate policy against a YAML baseline in Git."""
import os
import sys
import requests
import yaml

FGT = os.environ["FGT_HOST"]
TOKEN = os.environ["FGT_TOKEN"]
BASELINE = "baseline/policy.yaml"


def names(field):
    """FortiGate returns lists of {'name': ...} dicts. Flatten and sort."""
    return sorted(entry["name"] for entry in field)


def fetch_policy():
    resp = requests.get(
        f"https://{FGT}/api/v2/cmdb/firewall/policy",
        headers={"Authorization": f"Bearer {TOKEN}"},
        verify=True,
        timeout=30,
    )
    resp.raise_for_status()
    return resp.json()["results"]


def normalise(rule):
    """Reduce a rule to its security-relevant identity."""
    return {
        "name": rule.get("name", ""),
        "srcintf": names(rule["srcintf"]),
        "dstintf": names(rule["dstintf"]),
        "srcaddr": names(rule["srcaddr"]),
        "dstaddr": names(rule["dstaddr"]),
        "service": names(rule["service"]),
        "action": rule["action"],
        "logtraffic": rule.get("logtraffic", "disable"),
        "status": rule.get("status", "enable"),
    }
```

Keying on the rule name rather than the sequence number is deliberate. Names survive reordering; sequence numbers do not. If your estate has unnamed rules, fix that first — you cannot track what you cannot identify.

## Diffing against the baseline

With rules normalised into a dict keyed by name, the comparison is set arithmetic plus a field-level check on the intersection.

```python
def compare(running, baseline):
    findings = {"added": [], "removed": [], "modified": [], "critical": []}

    run_keys = set(running)
    base_keys = set(baseline)

    for name in sorted(run_keys - base_keys):
        findings["added"].append({"name": name, "rule": running[name]})

    for name in sorted(base_keys - run_keys):
        findings["removed"].append({"name": name, "rule": baseline[name]})

    for name in sorted(run_keys & base_keys):
        changed = {
            field: {"was": baseline[name][field], "now": running[name][field]}
            for field in running[name]
            if running[name][field] != baseline[name].get(field)
        }
        if changed:
            findings["modified"].append({"name": name, "changes": changed})

    # Independent of drift: flag dangerous shapes in whatever is running now.
    for name, rule in running.items():
        if rule["action"] != "accept":
            continue
        if "all" in rule["srcaddr"] or "ALL" in rule["service"]:
            findings["critical"].append(name)

    return findings


def main():
    running = {r["name"]: r for r in map(normalise, fetch_policy()) if r["name"]}
    with open(BASELINE) as fh:
        baseline = yaml.safe_load(fh) or {}

    findings = compare(running, baseline)

    for category in ("added", "removed", "modified"):
        for item in findings[category]:
            print(f"{category.upper():9} {item['name']}")
    for name in findings["critical"]:
        print(f"CRITICAL  {name}: permissive accept rule")

    drift = any(findings[c] for c in ("added", "removed", "modified"))
    sys.exit(1 if drift or findings["critical"] else 0)


if __name__ == "__main__":
    main()
```

The non-zero exit is the whole point. It turns the script into a CI gate or an Ansible pre-task rather than a report nobody reads. Run it nightly in a pipeline, and drift becomes a failed build with a named owner instead of a finding in a PDF nine weeks later.

The permissive-rule check is intentionally separate from the drift check. A rule can be perfectly in sync with your baseline and still be terrible. If `any` source with `accept` made it into the approved baseline, the drift comparison will stay silent forever. Checking the running state independently catches that.

## Making the baseline real

The baseline file only has value if changing it requires the same approval as changing the firewall. Put `baseline/policy.yaml` in the same repo as your network automation, protect the branch, and require a reviewed pull request. Now the audit trail is the Git history: who approved which rule, when, and against which ticket.

Seeding it is straightforward — run the fetch-and-normalise path once and dump the result to YAML. But do not seed blindly. Whatever is running today includes the 02:00 rules. Read through the initial dump, remove what should not be there, apply the cleaned version to the device, then commit that as the baseline. Otherwise you have automated the enforcement of your existing mess.

## Why this matters

The value here is not the diff. It is compressing the feedback loop. An unauthorised rule that lives for one night is an operational annoyance. The same rule living for a quarter is what turns up in an incident post-mortem or an audit finding, at which point you are reconstructing intent from memory and hoping the person who made the change still works there.

There is a second effect that is easy to underestimate. Once engineers know the nightly job will name their change by morning, temporary rules start coming with expiry dates and ticket references. The tooling changes the behaviour more than it catches the mistakes. That is usually the better outcome — enforcement that people route around is worse than none, but enforcement that makes the correct path the easy path tends to stick.
