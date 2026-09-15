# Pages Ahead Agent Instructions

## Communication

- Use the `caveman` skill at `full` intensity unless the user asks for normal mode or another intensity.

## Persistent Task Continuity

For every multi-step task, maintain `.agent/CURRENT_TASK.md` as the durable checkpoint.

1. Read `.agent/CURRENT_TASK.md` and relevant planning files before continuing unfinished work.
2. At task start, replace the checkpoint with the current objective, scope, constraints, and first actions.
3. Update it after every material investigation, decision, edit batch, test run, failure, or blocker, and before a long-running command or likely context compaction.
4. Record concise facts: what changed, exact files, commands or tests and outcomes, unresolved issues, and the next executable action. Do not paste large raw outputs.
5. Never record secrets, credentials, tokens, signing material, or private user data.
6. If context is compacted or a task resumes later, read the checkpoint first, validate it against the current workspace, and continue from `Next actions` instead of restarting.
7. When work completes, mark the checkpoint `complete` and add a concise entry to `.agent/WORK_LOG.md`.

Follow the detailed format in `.agent/CONTINUITY_PROTOCOL.md`.
