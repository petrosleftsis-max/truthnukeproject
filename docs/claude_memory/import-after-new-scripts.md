---
name: import-after-new-scripts
description: "the designer runs the game from the Project Manager's Run, which scans nothing; after adding class_name scripts or pictures, import the real project and commit the .uid files"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 322dee5d-0ec4-44ab-8eeb-9bb32627375c
  modified: 2026-11-07T14:52:36.116Z
---

After adding a `class_name` script or any new picture, run `godot --headless --path . --import` in the real project folder before finishing, provided no editor has that project open (check the Godot window title: "Project Manager" is fine), and commit the `.uid` files and any `project.godot` change it makes (the Dialogue Manager adds new `.dialogue` files to the translation list).

**Why:** on 2026-11-07 the designer pressed Run in the Project Manager after my round of work. Nothing had scanned the new classes (SpeechBubbles, SoftAreas, CombatLines and others) or imported the new icons, so the game stopped on parse errors at a black screen, while every test passed because the harness imports its own copy.

**How to apply:** make it the last step before the final commit of any work that adds scripts or art. If an editor is open on the project, tell the designer to let it finish scanning before running instead. See [[autoloads-need-editor-reload]].
