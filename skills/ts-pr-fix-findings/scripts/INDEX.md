---
title: "ts-pr-fix-findings Scripts"
description: "Index of scripts in skills/ts-pr-fix-findings/scripts/."
status: active
version: "1.0"
created: 2026-07-08
last-updated: 2026-09-07
owner: wave-2-dispatch-index-automation
dependencies: []
tags: [index, scripts]
---

# ts-pr-fix-findings Scripts

Index of scripts in skills/ts-pr-fix-findings/scripts/.

Paths below are relative to this index's directory. On Claude Code marketplace installs, resolve them through ${CLAUDE_PLUGIN_ROOT}/<repo-relative-path>; on other platforms, resolve from the loaded skill directory or the taegosts-skills checkout.

| Link | Description |
|------|-------------|
| [check-thread-resolution.sh](./check-thread-resolution.sh) | Check which review threads are resolved vs unresolved |
| [fetch-issue-comments.sh](./fetch-issue-comments.sh) | Fetch PR issue-level comments (not threaded inline review comments) |
| [fetch-review-comments.sh](./fetch-review-comments.sh) | Fetch threaded inline review comments (not issue-level comments) |
| [post-pr-comment.sh](./post-pr-comment.sh) | Post a top-level (issue-level) comment on a GitHub PR |
| [request-re-review.sh](./request-re-review.sh) | Request re-review from a specific reviewer on a GitHub PR |
| [resolve-thread.sh](./resolve-thread.sh) | Resolve a GitHub PR review thread |
