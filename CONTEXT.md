# Agent Skills

This context defines the language used by reusable agent workflows in this repository.

## Language

**Review Cycle**:
An adversarial evaluation of one exact pull-request head revision using both the code-review and Ponytail review perspectives.
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

**Trusted Reviewer**:
The current GitHub identity or an explicitly allowlisted GitHub login whose Review Results may drive a Fix Cycle.
_Avoid_: Collaborator, commenter

**Pass Signal**:
An Effective Review Result declaring that every required review perspective passed.
_Avoid_: LGTM comment, approval
