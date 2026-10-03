# Git workflow: parallel lanes

Several agent chats can work on Boomerang at the same time. Each chat works in its own **lane** (a private clone of the repo) instead of the shared folder, so chats never switch branches or edit files under each other. Everything here is local: agents never talk to GitHub. Sol pushes and pulls with GitHub Desktop.

The rules (what's allowed, and what "ship lane" means) are in [CLAUDE.md - Workflow for agents](../CLAUDE.md#workflow-for-agents). This file is the how-to. (Adopted from BugBuilder via the shared changelog, CM-001/002/005/008.)

## Folders

| Folder | What it is | Who changes it |
|---|---|---|
| `C:\MY FILES\Github\Boomerang` | The **home repo**. Stays on `main`, clean. GitHub Desktop pushes and pulls here; Sol tests from here. | Sol. Agents only run the git steps below in it (reserve an ID, receive a branch, ship lane, cull) and append to the git-ignored `Commits.txt` / `AgentLog.md`. Never edit its tracked files by hand, switch its branch, or leave it dirty. |
| `C:\MY FILES\Github\Boomerang-lanes\<lane>` | One **lane** per task. `<lane>` is the branch name without `agent/` (e.g. `T-123-short-name`, `docs-short-name`). | Only the chat that created it. Never touch another chat's lane. |

In `device_bash`, always reach both through the `Github` mount (`$HOME/mnt/Github/Boomerang`, `$HOME/mnt/Github/Boomerang-lanes/<lane>`), not the separate `Boomerang` mount, so the relative path between them works. **Run every git command from the lane's root folder**: the lane's remote, `home`, is the relative path `../../Boomerang`.

Commit with Sol's normal git identity, passed per commit (the Cowork VM has no git identity configured; don't change git config):
`git -c user.name="SoulsplosionSide" -c user.email="116596822+LaurKnill@users.noreply.github.com" commit …`

## 1. Create a lane

The mounted drive is slow with many small files, so clone through a bundle in the VM's scratch space:

```sh
cd "$HOME/mnt/Github/Boomerang" && GIT_OPTIONAL_LOCKS=0 git bundle create "$HOME/home.bundle" main
cd "$HOME/mnt/Github/Boomerang-lanes" && git clone -q -o home "$HOME/home.bundle" <lane>
cd <lane> && git remote set-url home ../../Boomerang && git fetch home \
  && git switch -c agent/<lane> home/main && git branch --unset-upstream
rm "$HOME/home.bundle"
```

- Create `Github/Boomerang-lanes/` first if it doesn't exist (`mkdir -p`).
- Creating the bundle can take a minute or more. Give that command a long timeout and don't run it twice at once.
- Split these into separate `device_bash` calls if one would run past the time limit.
- No upstream is set on purpose: always push with an explicit branch name (step 4).
- `Commits.txt`, `AgentLog.md` and `sourcemap.json` are git-ignored, so a new lane doesn't have them. Generate `sourcemap.json` in the lane if you need it; write `Commits.txt` / `AgentLog.md` entries in the **home repo's** copies.

## 2. Reserve a task ID (before adding any new task)

Task IDs are reserved **on `main` in the home repo** so two chats can't claim the same one:

1. In the home repo, check it's on `main` and clean: `git branch --show-current` prints `main` and `git status --porcelain` prints nothing. If not, **stop and ask Sol**; don't stash, switch or commit their changes.
2. Re-read `Next free ID` in `TASKS.md` right before editing. Bump it by the number of IDs you need (with a one-line `sed -i` or python edit of that line only).
3. Commit only that file: `git add TASKS.md && git commit -m "docs: reserve T-123 (Short title)"` (several IDs: `reserve T-123 to T-125`). If git reports a lock (another chat is committing), wait a few seconds and start again from step 2.
4. Bring it into your lane: in the lane, `git fetch home && git merge home/main`.
5. Add the task to its list (`TASKS.md` or `docs/epics/<epic>/TASKS.md`) in your lane, using the reserved ID.

This reservation commit is the **only** commit an agent may make on `main` without a ship lane. It changes nothing but the `Next free ID` line.

## 3. Work

Edit, run checks and commit in the lane, as usual. Keep the task's Notes current: branch, lane folder, what changed, what to test in Studio.

## 4. Hand back for testing

```sh
git push home agent/<lane>
```

The branch appears in the home repo (and in GitHub Desktop). Move the task to `Review` with the branch and lane in its Notes, and add the client-facing line to the home repo's `Commits.txt`. Push again after any later commits.

How Sol can test a branch:
- In GitHub Desktop, switch the home repo to the branch, test, then switch back to `main`. (Agents can't ship lane while the home repo is on another branch.)
- Or open the lane folder in VS Code and run `rojo serve` there.

## 5. Ship lane

Only when Sol says "ship lane" for this branch (see CLAUDE.md for exactly what counts).

1. In the lane: `git fetch home && git merge home/main`. Resolve any conflicts in the lane and commit. For the `Next free ID` line, keep the highest number.
2. If you resolved conflicts or changed code, say so. Sol tested the branch before the merge-in; a non-trivial conflict resolution is worth a re-test. Ask before going on if it touched game code.
3. `git push home agent/<lane>`.
4. In the home repo, check it's on `main` and clean (as in step 2.1). If not, stop and tell Sol.
5. `git merge --ff-only agent/<lane>`. If it refuses because `main` moved, go back to step 1.
6. Add an `AgentLog.md` entry (home repo) for the merge: date, merged commit SHA, task ID(s), summary, how to undo.
7. **Keep the lane and its branch.** A ship lane only catches `main` up; it never deletes the lane folder or the branch. Keep working in the same lane afterwards (the next ship lane merges the new commits). See "Deleting lanes".
8. Tell Sol it's merged into local `main` and that it goes to GitHub when they click **Push origin** in GitHub Desktop.

Never push to GitHub, force-push, rebase or reset `main`, or merge into `main` any other way.

## Cull branches

When Sol says "cull branches": in the home repo, delete the branches merged into local `main` (`git branch --merged main`), except `main`, the checked-out one, any branch a lane folder still uses, and branches that aren't agent branches (`dev-soul` and other people's branches are Sol's to manage). Never delete an unmerged branch or another chat's lane that's still in progress. Branches on GitHub can't be deleted from here; tell Sol which remote ones remain.

## Deleting lanes

A lane folder is deleted **only when Sol explicitly asks for that lane to be deleted**, and (CLAUDE.md's "Never delete large things") only after confirming with a multiple-choice prompt. Nothing else is permission: not a ship lane, "cull branches", a task moved to `Done`, or the branch being merged. Before deleting, check `git status` in the lane shows nothing uncommitted and that its commits are in `main` or pushed into the home repo; if not, tell Sol and ask again.

## Permissions (Cowork)

Before the first git command that writes, request delete permission once for `C:\MY FILES\Github` (it covers the home repo and the lanes; also list `C:\MY FILES\Github\Boomerang` if it's connected as its own folder), and tell Sol it's for git's lock files (and, later, for deleting lanes Sol asks to delete). If git prints `unable to unlink … Operation not permitted`, follow CLAUDE.md's lock-file steps.
