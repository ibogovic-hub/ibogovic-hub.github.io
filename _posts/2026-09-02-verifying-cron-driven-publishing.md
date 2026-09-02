---
title: Verifying Cron-Driven Publishing with a Guard Script
tags: Automation
---

A recurring failure mode in home-lab automation: a scheduled job reports success while producing nothing. The job runs, the agent responds, the scheduler records `ok` — and the artifact never exists.

## The failure

A daily blog-publishing job on my Hermes VM ran for days with `last_status: ok`. The repository had not received a commit since 2024. Two independent bugs stacked:

1. The agent loop terminated early — `Turn ended: reason=text_response(finish_reason=tool_calls)` after two API calls, well inside a 150-call budget. Generation stopped before the git work began.
2. The cron session pinned a model string the provider no longer served, returning `HTTP 400: model not available`.

Neither surfaced, because "the agent returned a string" was treated as success.

## The fix

Separate authoring from publishing. The agent writes a markdown file to a drop directory and stops. A plain shell script owns every step that can actually fail:

```bash
git push --quiet origin "$BRANCH" || fail "push rejected"

local_sha=$(git rev-parse HEAD)
remote_sha=$(git ls-remote origin "refs/heads/$BRANCH" | cut -f1)
[ "$local_sha" = "$remote_sha" ] || fail "push did not land"
```

The last three lines matter most. `git push` can exit zero in cases where the ref did not move; comparing the local SHA against `git ls-remote` verifies the commit reached the server rather than trusting the exit code.

The script also validates before it commits — Jekyll filename pattern, YAML front matter present, no clobbering an existing post:

```bash
if ! [[ "$base" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-.+\.md$ ]]; then
    echo "PUBLISH_SKIP: bad filename: $base"
    continue
fi
```

Every outcome prints a greppable prefix: `PUBLISHED`, `PUBLISH_SKIP`, `PUBLISH_NOOP`, `PUBLISH_FAILED`. A monitor can assert on those tokens without parsing prose.

## The principle

Give the non-deterministic component the creative work and none of the verification. A language model deciding whether its own push succeeded is a model grading its own homework. A twelve-line shell check comparing two SHAs is not.

If a scheduled job cannot fail loudly, it is not automation — it is a job that has not told you it is broken yet.
