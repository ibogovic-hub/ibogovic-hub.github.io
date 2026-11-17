---
title: "Validate config files before Ansible writes them"
tags: Automation
---

A template change goes out to forty hosts. The Jinja renders fine, the task reports `changed`, the handler restarts the service, and on every one of those hosts the daemon refuses to start because of a missing semicolon on line 212. Ansible worked as designed. It put the file where you told it to and restarted the service when you told it to. Nothing in that chain checked whether the file was valid.

Most config-managing modules already have a fix for this, and people still don't use it much: the `validate` parameter.

## What validate actually does

`template`, `copy`, `lineinfile`, `blockinfile` and `replace` all accept `validate`. Ansible writes the new content to a temporary file, runs your command against it with `%s` replaced by the temp path, and only moves it into place if the command exits 0. If validation fails, the task fails, the original file stays where it was, and the handler never fires.

That ordering matters. The usual alternative is a separate "check config" task after the write, and by the time that runs the broken file is already live. If anything reloads the service in between (a timer, logrotate, someone running `systemctl reload` by hand) you have an outage.

## A working set of validators

These are the ones I use most. Every one takes a file path and returns non-zero on a parse error.

```yaml
- name: Render sshd drop-in
  ansible.builtin.template:
    src: 10-hardening.conf.j2
    dest: /etc/ssh/sshd_config.d/10-hardening.conf
    mode: "0600"
    validate: /usr/sbin/sshd -t -f %s
  notify: Reload sshd

- name: Render sudoers fragment
  ansible.builtin.template:
    src: ops.sudoers.j2
    dest: /etc/sudoers.d/ops
    mode: "0440"
    validate: /usr/sbin/visudo -cf %s

- name: Render nginx site
  ansible.builtin.template:
    src: site.conf.j2
    dest: /etc/nginx/conf.d/site.conf
    validate: /usr/sbin/nginx -t -c /etc/nginx/nginx.conf -q
  notify: Reload nginx

- name: Render nftables ruleset
  ansible.builtin.template:
    src: nftables.conf.j2
    dest: /etc/nftables.conf
    validate: /usr/sbin/nft -c -f %s
  notify: Reload nftables

- name: Render chrony config
  ansible.builtin.template:
    src: chrony.conf.j2
    dest: /etc/chrony/chrony.conf
    validate: /usr/sbin/chronyd -p -f %s
  notify: Restart chrony
```

Before you copy these, there are two traps.

**sshd and drop-ins.** `sshd -t -f %s` checks the fragment as if it were the whole config. A drop-in containing only `PasswordAuthentication no` passes. A drop-in containing a `Match` block also passes, but you're testing it in isolation, so you won't catch conflicts with the main file. That's fine for syntax and not enough for semantics.

**nginx ignores %s.** The example above validates the existing tree, which doesn't contain the new file yet, so it proves nothing. Ansible also refuses a `validate` string without `%s`. The honest version builds a throwaway main config that includes the temp file:

```bash
#!/bin/sh
# /usr/local/bin/nginx-validate-site <tmpfile>
set -eu
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
cat > "$tmpdir/nginx.conf" <<EOF
events {}
http {
    include /etc/nginx/mime.types;
    include $1;
}
EOF
/usr/sbin/nginx -t -q -c "$tmpdir/nginx.conf" -p "$tmpdir"
```

Then use `validate: /usr/local/bin/nginx-validate-site %s`. Ship the script with the same role so it is always present.

## When there is no validator

Some daemons have no check mode. In that case, validate the format instead. For YAML or JSON consumed by an internal service:

```yaml
- name: Render service config
  ansible.builtin.template:
    src: app.yaml.j2
    dest: /etc/app/app.yaml
    validate: python3 -c "import sys, yaml; yaml.safe_load(open(sys.argv[1]))" %s
```

That won't catch a wrong key name, but it does catch the most common template failure: indentation broken by a loop that rendered one level too deep. For anything stricter, write a small script that loads the file against a JSON Schema and exits 1 on failure. It costs about twenty lines and you write it once.

## Validate is not a health check

`validate` answers one question: will this file parse? It won't tell you whether the service comes back healthy after the reload. Keep that as a separate step. Flush handlers, then poll the port or the status endpoint with `wait_for` or `uri`, and run the play with `serial` so a bad change stops after the first batch. Validation catches syntax before the write, and the health check catches behaviour after the reload. You want both, but only validation keeps a broken file off the disk in the first place.

One more operational detail: `validate` runs on the target host with the target's binary version. That's what you want. A config that parses on your laptop's nginx 1.27 can fail on a fleet still running 1.22, and validating on the target catches that.

## Why this matters

Most config-push outages I've had to clean up weren't logic errors. They were typos, a missing brace, or a template variable that rendered empty and left a dangling directive. Every one of them would have been stopped by a one-line `validate` on the task that wrote the file. It costs a few hundred milliseconds per host. The sudoers case alone justifies it: a broken file in `/etc/sudoers.d` can lock out the same automation account you'd use to fix it. Make `validate` mandatory in code review for any task that writes a file a daemon parses, and treat a missing one like a missing test.
