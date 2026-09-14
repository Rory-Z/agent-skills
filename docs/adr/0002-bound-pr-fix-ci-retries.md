---
status: accepted
---

# Bound infrastructure retries in PR fix sessions

Limit this change to `pr-fix-loop`; keep `emqx-pr` behavior unchanged. A Fix Session may automatically rerun failed CI jobs for the exact current head after inspecting logs and establishing a transient infrastructure cause, such as an image-pull EOF or network timeout. Waiting alone cannot recover a completed failed run. Permission failures, authentication failures, and failures with an unknown cause do not qualify for this retry path.

After CI recovery, recheck the exact current head and all PR checks, then wait for the next Effective Review Result. When the retry budget is exhausted, stop and report failure evidence, attempt count, and the blocker. Keep the agent turn open while waiting or while a retry is running.

When a new Effective Review Result appears for the current head, process it before initiating another CI retry; leave already-running CI intact. Follow the existing paths for `changes-requested`, `blocked`, and `pass`. A Pass Signal may end the Fix Session under the existing protocol, but the final report must distinguish the actual CI status from review success.

Allow at most three additional rerun requests per invocation, shared across workflows and heads, with a five-minute wait before each request. A new invocation receives a fresh budget. Prefer this session-local bound over reconstructing counts across invocations: it bounds autonomous retries without adding persistent state. Retrying CI does not consume a Fix Cycle or open a Recovery Epoch. The user confirmed the complete design and implementation on 2026-09-14.
