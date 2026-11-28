---
name: commit-own-lines-in-shared-folder
description: "several sessions edit truthnukeproject at once, often in the same files; how to commit only my lines and test exactly that"
metadata:
  node_type: memory
  type: project
  originSessionId: cb6bacdc-e38f-4285-8661-140a3382e226
  modified: 2026-11-19T14:10:33.242Z
---

Several sessions often share E:\My projects\MessengersOfTruth\truthnukeproject, with uncommitted work in the same files. On
2026-11-19, walls/threads, passive merges, wander, basic armour and feel were all uncommitted together in Combat.gd,
combat_ui.gd, CLAUDE.md and the ledger. A commit takes only my own lines (aaa7f8e was done this way):
- To pick my hunks, filter `git diff -- <file>` by each hunk's old start line and fix the new start lines of the dropped
  ones, then `git apply --cached`. For rows that sit next to others' (the ledger), use `-U0` with `--unidiff-zero`. There a
  pure insertion's new start must be exact, since git inserts at that line.
- Never leave my files staged while tests run: another session's `git commit` takes the whole index, mine included.
- To test exactly the commit, export the index with `git checkout-index -a --prefix=<scratch>/idx/`. Move the harness
  copy's `.godot` into it, which skips a full import, and run `<idx>/tests/run.sh`. Then stage from that export
  (`git hash-object -w --path=<p>` plus `git update-index --cacheinfo 100644,<sha>,<p>`) and commit at once, after checking
  that HEAD and the index have not moved.
- Warnings about invalid UIDs of sfx .wav files in such a run come from the gitignored designer's sounds. They are not errors.

**Why:** committing whole shared files would publish other sessions' unfinished work under my message, and files left staged get
swept into someone else's commit.
**How to apply:** whenever a commit is asked for while `git status` shows changes that are not mine. Related:
[[commit-means-publish]], [[designer-edits-in-open-editor]].
