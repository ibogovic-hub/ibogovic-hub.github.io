---
title: "Pre-commit hooks that keep broken YAML out of your infra repo"
tags: Automation
---

The pipeline failed at 17:40 on a Friday. Someone had pushed a one-line change to an Ansible inventory, and a tab character had slipped into a YAML file. The CI job caught it, but only after the merge, only after the deploy stage had already started on half the hosts, and only after the person who pushed it had logged off. The fix took thirty seconds. The cleanup took an hour.

Nothing about that failure needed CI. A YAML parser on the engineer's laptop would have rejected the file before it ever left the machine. That is what pre-commit hooks are for, and most infrastructure repositories I have seen either do not use them or installed them once and let them rot.

## What belongs in a local hook

The rule I use: a hook must be fast, deterministic and not need network access to anything internal. If it takes more than a few seconds on a normal commit, people will start using `--no-verify` and the whole thing is dead. That rules out full playbook runs, Terraform plans against real state and anything needing VPN.

What fits comfortably:

- YAML and JSON syntax checks
- Trailing whitespace, mixed line endings, files without a final newline
- `ansible-lint` on changed playbooks and roles
- `shellcheck` on shell scripts
- Secret detection, so a token does not end up in history you then have to rewrite
- Blocking accidental commits of large files or private keys

## A working configuration

The `pre-commit` framework handles hook installation, pins versions and only runs each hook against the staged files that match. Put this in `.pre-commit-config.yaml` at the repository root:

```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.6.0
    hooks:
      - id: check-yaml
        args: [--allow-multiple-documents]
      - id: check-json
      - id: end-of-file-fixer
      - id: trailing-whitespace
      - id: mixed-line-ending
        args: [--fix=lf]
      - id: check-added-large-files
        args: [--maxkb=512]
      - id: detect-private-key
      - id: check-merge-conflict

  - repo: https://github.com/adrienverge/yamllint
    rev: v1.35.1
    hooks:
      - id: yamllint
        args: [-c, .yamllint.yaml]

  - repo: https://github.com/koalaman/shellcheck-precommit
    rev: v0.10.0
    hooks:
      - id: shellcheck

  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.18.4
    hooks:
      - id: gitleaks

  - repo: https://github.com/ansible/ansible-lint
    rev: v24.7.0
    hooks:
      - id: ansible-lint
        files: ^(playbooks|roles)/
```

Check the revisions against the upstream repositories before you copy this; run `pre-commit autoupdate` once and commit the result. Then install it:

```bash
pip install --user pre-commit
cd ~/src/network-automation
pre-commit install
pre-commit run --all-files
```

The first `--all-files` run is the painful one. On an older repository expect hundreds of whitespace fixes and a handful of real problems. Commit the mechanical fixes in a single dedicated commit so `git blame` stays useful, and add that commit hash to `.git-blame-ignore-revs`.

## Keep yamllint honest but not hostile

Default yamllint rules will complain about line length in every inventory with long descriptions. Tune it once instead of letting people ignore it:

```yaml
extends: default
rules:
  line-length:
    max: 160
    level: warning
  truthy:
    allowed-values: ["true", "false"]
  comments:
    min-spaces-from-content: 1
  document-start: disable
```

The `truthy` rule earns its place. `yes`, `no`, `on` and `off` are a classic source of surprise in YAML 1.1 parsers, and switch configs are full of words like that.

## Hooks are a convenience, CI is the contract

Local hooks can be skipped. New clones do not have them installed until someone runs `pre-commit install`. So run the same configuration in CI as the enforcing gate:

```bash
pre-commit run --all-files --show-diff-on-failure
```

Same file, same versions, same result locally and in the pipeline. When CI fails, the engineer can reproduce it with one command instead of reading pipeline logs.

Two things I would not compromise on. First, pin every `rev`. Floating to a branch means a linter release can break every commit across the team on a Monday morning. Second, keep slow checks out of the commit hook. If you want `ansible-lint` on the whole repository with production profile rules, put that in CI only, or use the `stages: [pre-push]` option so it runs on push instead of every commit.

## Why this matters

Most outages I have cleaned up after in automation repos were not clever bugs. They were indentation, a stray merge marker, a credential pasted into a vars file for "just a quick test". Every one of those is detectable in under a second on the laptop where it was typed. Moving that check left does not make anyone a better engineer, but it removes a whole class of Friday-evening incidents and keeps review time focused on whether the change is right, not whether it parses.
