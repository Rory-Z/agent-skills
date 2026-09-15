# Agent Skills

This context defines the language used by reusable agent workflows in this repository.

## Language

**Review Cycle**:
An evaluation of one exact pull-request head revision across Standards, Spec, and Ponytail. Both workflows share context in one agent; the once workflow stops after one cycle and the loop workflow waits for successor heads.
_Avoid_: Review round, review run

**Review Session**:
One invocation of the PR review workflow whose conclusions come only from its own Review Cycles and are never inherited from another Review Session.
_Avoid_: Reviewer, review process

**Review Result**:
The top-level pull-request conversation comment produced by a Review Cycle and bound to the reviewed head revision.
_Avoid_: PR comment, review comment

**Effective Review Result**:
The newest Review Result from a Trusted Reviewer for the exact current pull-request head revision.
_Avoid_: Latest comment, active review

**Fix Cycle**:
A bounded attempt to address one Review Result and publish a new pull-request head revision.
_Avoid_: Fix round, repair run

**Fix Session**:
One invocation of the PR fix workflow that may perform multiple Fix Cycles until it observes a Pass Signal or blocker.
_Avoid_: Fixer, repair process

**Non-convergent Review/Fix Interaction**:
A pull-request state where the initial three Fix Cycles, or the three Fix Cycles of an active Recovery Epoch, are followed by another changes-requested Review Result. It requires renewed human judgment rather than another automatic fix.
_Avoid_: Review churn, endless loop

**Recovery Epoch**:
A same-pull-request recovery stage opened after a Non-convergent Review/Fix Interaction and bounded to at most three further Fix Cycles.
_Avoid_: Cycle reset, retry window

**Recovery Decision**:
The outcome of manual recovery grilling that either rejects another Recovery Epoch or states what changed and why another bounded epoch may converge.
_Avoid_: Retry rationale, continue instruction

**Recovery Authorization**:
A GitHub-visible form of a confirmed Recovery Decision, published by the PR fix workflow and bound to one exact pull-request head and its entire Effective Review Result. It opens one Recovery Epoch.
_Avoid_: Continue instruction, approval

**Trusted Reviewer**:
The current GitHub identity or an explicitly allowlisted GitHub login whose Review Results may drive a Fix Cycle.
_Avoid_: Collaborator, commenter

**Pass Signal**:
An Effective Review Result declaring that every required review perspective passed.
_Avoid_: LGTM comment, approval
