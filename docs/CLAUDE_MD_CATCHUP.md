# CLAUDE.md catch-up log

Boomerang's record of going through the shared changelog (`C:\MY FILES\SharedDocs\CLAUDE_MD_CHANGES.md`). The changelog's sign-off table is the source of truth; this is the local detail.

## 2026-10-03 · CM-001 to CM-007 (first catch-up)

| Entry | Decision | What changed in Boomerang |
|---|---|---|
| CM-001 Parallel lanes + task ID reservation | Adapted | New `docs/GIT_WORKFLOW.md`. CLAUDE.md "Git" bullet replaced: one lane per chat in `Github/Boomerang-lanes/<lane>`, home repo `Github/Boomerang` stays on **`main`** (was `dev-soul`). Agents now commit in lanes, as `SoulsplosionSide` passed per commit (the VM has no git identity). IDs reserved on `main` (TASKS.md, EPICS.md, Epic template updated). `Commits.txt` / `AgentLog.md` stay in the home repo (git-ignored, lanes don't have them); AgentLog now logs ship merges and reservations. Case renames: `git mv` in the lane. |
| CM-002 "Ship merge" | Adopted | Ship-merge rules added to "Workflow for agents". |
| CM-003 Github folder read-only | Adopted | Bullet added (exceptions: git steps + git-ignored logs in the home repo, own lane, per-task grants). |
| CM-004 Ask about the changelog | Adopted | "Changing this CLAUDE.md" bullet added. |
| CM-005 Lanes deleted only on explicit ask | Adapted | In ship merge, cull branches and GIT_WORKFLOW "Deleting lanes". Cull also spares `dev-soul` and other non-agent branches. |
| CM-006 Never delete large things | Adapted | ⛔ section before "Start here". Limits: 155 files / 1 MB (`main` measured at ~465 files / 3.1 MB). |
| CM-007 Always confirm large deletes | Adopted | Folded into the CM-006 section. |
