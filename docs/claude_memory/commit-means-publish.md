---
name: commit-means-publish
description: "Commits go to GitHub; the PUBLIC itch page is not published to until the user says so; the playtest build goes to the restricted page when asked (2026-11-19)"
metadata:
  node_type: memory
  type: feedback
  originSessionId: daf832bf-a3b0-42bb-854e-4dde88e2fdd6
  modified: 2026-11-28T02:10:23.368Z
---

**Since 2026-11-26: every commit and push also publishes the playtest build to the restricted page** ("Whenever you commit and push
now, also publish on the playtesting itchio page, but not on the other main page of course"): `tools/release.sh --publish` (not
`--release`) once the push is done, with the tree clean so the build's version is the new commit's hash; then check `butler status`
for the restricted page. If butler needs a login, the user does it.

**Since 2026-10-30: do not publish to the public itch page.** The user said "No need to publish or touch the itchio page yet, i want to work on the game more before i do so." Commit and push to GitHub as asked; leave `tools/release.sh --release --publish` alone until the user says they are ready. Local builds (`tools/release.sh` without --publish) are fine for checking the script.

**Since 2026-11-19 there are two pages and two builds** (docs/itch_release_proposals.md, all five ways built):
- the playtest build, everything in: `tools/release.sh --publish` -> the restricted page "Messengers of Playtesting", `eplogos/messengers-of-playtesting` (butler confirmed it exists). The user asked for it to be published there on 2026-11-19 ("publish the playtesting version in the restricted page"); publish it again only when they ask.
- the release build: `tools/release.sh --release [--allow-stand-ins] --publish` -> the public page `eplogos/messengersoftruth`, channels windows, linux and mac (the old web channel still sits there until the user hides it). Still suspended.
- 2026-11-27: the public build's feature is `public_build` (Godot gives every export its own `release` feature, which had hidden Arena Mode, the demos and the Card Game from the playtest build). Public build contents, the designer's: Play + Arena Mode's first stages (+ saves, Options, Exit) "and anything else i tell you", no art or sound I generated except the plain stand-in for empty slots (`Release.GENERATED_PICTURES`: add every new stand-in picture file). Restricted page: everything, as the designer sees it.

When publishing:
- Butler is at `%APPDATA%\itch\broth\butler\versions\15.31.0\butler.exe` (15.32.0 is out). The user logs in themselves; never handle the credentials. `butler status <target>` says "invalid game" for a page that does not exist and "No channel found" for one with nothing on it yet.
- A build's version reads `<hash>-dirty` when uncommitted files were present.
- Check `butler status` until every channel shows the new build.

Other notes:
- The encounter editor scene (`tools/encounter_editor.tscn`) is the user's scratch space. The repo holds an empty version; this PC's checkout has it `--skip-worktree`, so local edits never show in `git status`. To change the committed version, unset that flag first and set it again afterwards.
- Pushing to GitHub from this PC can wait on a Git Credential Manager sign-in window (2026-10-29); tell the user to sign in rather than waiting silently.
