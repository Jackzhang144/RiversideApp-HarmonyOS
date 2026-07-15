# 05 — 裁决冻结参考中的契约证据冲突

Type: research
Status: resolved
Assignee: Codex
Blocked by: 01

## Question

For the frozen Flutter reference commit `9d8b13c`, which behaviour is authoritative where captures and current tests/models disagree?

Resolve, from the current Flutter source and tests, the authenticated-group predicate and Chat Reaction model/presentation semantics discovered by the parity audit. Record the exact implementation rules and test assertions that later ArkTS tickets must reproduce. Do not change either client; publish a short cited decision note as the answer.

## Answer

The authoritative source/test decision is [Flutter `9d8b13c` 契约冲突裁决](../../../docs/research/flutter-9d8b13c-contract-conflict-decisions.md).

`isVerified` recognises five school-alumni group names or their primary/flair group IDs, while `rs_developer` is only a role/flair source. Chat Reaction is a complete product behaviour: it is parsed from `reactions[]`, rendered with selected state and user summary, sent through the Chat reaction endpoint, then refreshed. Both conflicting capture comments are explicitly superseded by the frozen implementation and tests.
