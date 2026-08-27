# Agent Skills

Personal Codex/agent skills managed from one Git repository.

```text
skills/
├── daily-report/
├── emqx-pr/
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
```

Add future skills under `skills/<skill-name>/`, then create the matching link.
