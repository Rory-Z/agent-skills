# Agent Skills

Personal Codex/agent skills managed from one Git repository.

```text
skills/
├── daily-report/
├── emqx-pr/
├── pr-fix-loop/
├── pr-review-loop/
├── pr-review-once/
└── weekly-report/
```

The active skill directories are symbolic links to these folders, so edits in
this repository take effect without copying files between locations.

To install after cloning, link each skill to the directory used by the target
agent:

```bash
ln -s /path/to/agent-skills/skills/daily-report ~/.codex/skills/daily-report
ln -s /path/to/agent-skills/skills/weekly-report ~/.codex/skills/weekly-report
ln -s /path/to/agent-skills/skills/emqx-pr ~/.agents/skills/emqx-pr
ln -s /path/to/agent-skills/skills/pr-review-loop ~/.codex/skills/pr-review-loop
ln -s /path/to/agent-skills/skills/pr-review-once ~/.codex/skills/pr-review-once
ln -s /path/to/agent-skills/skills/pr-fix-loop ~/.codex/skills/pr-fix-loop
```

Pi CLI also discovers skills from `~/.agents/skills`:

```bash
ln -s /path/to/agent-skills/skills/daily-report ~/.agents/skills/daily-report
ln -s /path/to/agent-skills/skills/weekly-report ~/.agents/skills/weekly-report
ln -s /path/to/agent-skills/skills/emqx-pr ~/.agents/skills/emqx-pr
ln -s /path/to/agent-skills/skills/pr-review-loop ~/.agents/skills/pr-review-loop
ln -s /path/to/agent-skills/skills/pr-review-once ~/.agents/skills/pr-review-once
ln -s /path/to/agent-skills/skills/pr-fix-loop ~/.agents/skills/pr-fix-loop
```

Add future skills under `skills/<skill-name>/`, then create the matching link.

Use `pr-review-once` for one single-agent Review Cycle across Standards, Spec,
and Ponytail; it publishes the same SHA-bound result protocol as `pr-review-loop`
and stops. `pr-review-loop` uses the same single-agent Review Cycle and waits for
new heads after changes are requested. Both results can drive `pr-fix-loop`.
