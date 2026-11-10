---
title: "Rolling changes with Ansible serial and max_fail_percentage"
tags: Automation
---

A playbook that pushes a new resolver config to forty Linux hosts works fine in the lab. In production one template variable is wrong, and because Ansible's default strategy runs every task against every host in parallel (up to `forks`), all forty hosts get the broken file within the same minute. Monitoring lights up everywhere at once, and the rollback has to run against a fleet that can no longer resolve the name of your package mirror.

The fix is not a smarter template. It is to change how far one mistake can travel before something stops it. Ansible has had the tools for this for years: `serial`, `max_fail_percentage`, `any_errors_fatal` and a verification task that can actually fail. Most infra repos I review use none of them.

## Batches with serial

`serial` splits the play into batches. Every task in the play finishes on batch one before batch two starts. It accepts a number, a percentage, or a list, and the list form is the useful one:

```yaml
- hosts: resolvers_clients
  serial:
    - 1
    - 10%
    - 50%
  max_fail_percentage: 0
  tasks: []
```

The first batch is a single canary host. If it survives, the next batch is 10 percent of the inventory, then the remainder in halves. The last value in the list repeats until the hosts run out.

## Stop on failure

By default a failed host is just dropped from the play and the rest continue. With `serial`, `max_fail_percentage` is evaluated per batch: if more than that percentage of the current batch fails, the play aborts and no further batches start. Setting it to `0` means any failure in a batch stops the rollout. Note that the check is "greater than", so a value of 0 really does mean zero tolerance.

`any_errors_fatal: true` is the stricter version: one failure ends the play for everyone immediately, including hosts in the current batch that have not finished. For changes where a half-applied batch is worse than a stopped one, use it.

## The part people skip: verification that can fail

Batching only helps if a broken host actually registers as failed. Writing a file and restarting a service usually succeeds even when the result is useless. So the play needs a task that tests the outcome and fails loudly:

```yaml
- name: Roll out resolver config in batches
  hosts: resolvers_clients
  become: true
  serial:
    - 1
    - 10%
    - 50%
  max_fail_percentage: 0

  tasks:
    - name: Deploy resolved drop-in
      ansible.builtin.template:
        src: resolved.conf.j2
        dest: /etc/systemd/resolved.conf.d/10-site.conf
        owner: root
        mode: "0644"
      notify: Restart resolved

    - name: Apply handlers before verifying
      ansible.builtin.meta: flush_handlers

    - name: Verify resolution of an internal and an external name
      ansible.builtin.command: "resolvectl query {{ item }}"
      loop:
        - "{{ verify_internal_name }}"
        - example.com
      register: dns_check
      changed_when: false
      retries: 3
      delay: 5
      until: dns_check.rc == 0

    - name: Pause between batches
      ansible.builtin.pause:
        seconds: 60
      run_once: true

  handlers:
    - name: Restart resolved
      ansible.builtin.systemd:
        name: systemd-resolved
        state: restarted
```

Three details matter here. `flush_handlers` forces the restart before verification, otherwise the check runs against the old config and passes. `retries`/`until` give the service a few seconds to settle, so a slow restart is not mistaken for a broken one. And the `pause` with `run_once` gives your metrics and alerting a window to notice problems that a single `resolvectl` query cannot see, such as latency or a downstream application failing.

## Things that bite

- `serial` is a play keyword. If your playbook imports several plays, each one batches independently. A host that passed play one in batch one may be in batch three for play two.
- `run_once` with `serial` runs once per batch, not once per play. That is what you want for the pause, and exactly what you do not want for a "send one notification" task.
- `delegate_to: localhost` tasks such as load balancer drains also run per batch. That is usually correct, but check that the drain and re-enable pair up inside the same batch.
- With `strategy: free` the batch boundary still holds, but ordering within a batch does not. Keep the default `linear` strategy for rollouts.
- Dynamic inventory order is not guaranteed. If you want a specific canary, put it in its own group and run that play first, or sort with `order: sorted`.

Before running, `ansible-playbook --list-hosts` shows you the batches, which is a cheap way to confirm the canary is the host you expect:

```bash
ansible-playbook -i inventory/prod rollout-resolved.yml --list-hosts
```

## Why this matters

Almost every bad automation incident I have dealt with had the same shape: a correct-looking change, applied everywhere at once, with no step that checked whether the result worked. Reviews and lint catch syntax, not the wrong value in a variable file. Batching plus a verification task that can fail turns "the whole fleet is down" into "one canary is down and the play stopped", which is a ticket instead of an outage. It costs a few minutes of extra runtime per change. Make it the default in your playbook template, and make skipping it the thing that needs a justification.
