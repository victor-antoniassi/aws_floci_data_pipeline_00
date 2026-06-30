---
description: Push main project repo + nested openspec specs repo to GitHub
---

Push both repositories for this project.

1. Run `git status --short` in both repos (`.` and `openspec/`) to check for uncommitted changes.

2. If there are changes to commit in either repo:
   - If the user included a message draft after `/push-all`, use it as the basis for the commit message (interpret and refine as needed, e.g. a short description becomes a conventional commit message)
   - If no message was provided, generate a concise conventional commit message from the actual diff

3. Stage all changes (`git add -A`) and commit in each repo that has pending changes.

4. Push both repos:
   - `git push origin main`
   - `git -C openspec push origin main`

5. Confirm both pushes succeeded and report the result back to the user.
