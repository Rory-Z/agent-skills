---
status: accepted
---

# Bound PR fix recovery with explicit epochs

Keep PR review stateless and place all cross-cycle authority in the PR fix workflow. After the initial three Fix Cycles, or three Fix Cycles in a Recovery Epoch, another changes-requested Effective Review Result makes the Fix Session stop with `recovery-required`; the Review Session continues to evaluate only the exact current head and does not read Fix Cycle or Recovery Epoch history.

Allow multiple Recovery Epochs on the same pull request so recovery does not require PR-on-PR or abandoned PRs. Each epoch is fixed at three Fix Cycles. At `recovery-required`, the fix workflow prints a ready-to-run `$grill-with-docs` prompt containing the pull request, exact head, Effective Review Result, exhausted epoch, and its three validated Fix Cycle commits. Manual recovery grilling must produce either `DO NOT RECOVER` or a meaningful Recovery Decision stating what changed and why another bounded epoch may converge.

Only after a Recovery Decision may the user invoke `$pr-fix-loop --recover`. The fix workflow shows an exact authorization draft, waits for explicit human confirmation, revalidates the head and Effective Review Result, and then publishes the only PR-comment exception permitted to the fix workflow:

```html
<!-- pr-fix-loop:recovery-v1 head=<sha> result=<result-id> -->
```

The Recovery Authorization covers the entire referenced Effective Review Result. Its top-level GitHub comment ID identifies the epoch; existing `PR-Fix-Cycle` trailers and first-parent ancestry determine the three-cycle budget, so trailers need no epoch field. The authorization records substantive Decision, Change, and Convergence basis fields (each at least eight non-whitespace characters and not a placeholder, including `<...>` or `[...]` templates), not a generic continuation such as `continue`, `proceed`, `go ahead`, or `resume`. Repeating an authorization for the same head and result does not reset the budget, a changed head or newer Effective Review Result invalidates it before the first cycle, and an authorization for an old head is stale if any Review Result for the current descendant head already exists.

Do not add a separate Recovery Authorizer allowlist while the human, Review Session, and Fix Session share one GitHub identity; it would not create real identity separation. Reconsider that only when distinct human or bot accounts exist. This protocol permits repeated human-authorized epochs, but never an unbounded autonomous continuation.
