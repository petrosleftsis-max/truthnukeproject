---
name: bash-tool-eats-backslashes
description: "The Bash tool collapses \"\\\\\" to \"\\\" before a command runs, so perl/sed patterns needing a literal backslash silently fail - use the Edit tool"
metadata:
  node_type: memory
  type: feedback
  originSessionId: daf832bf-a3b0-42bb-854e-4dde88e2fdd6
  modified: 2026-09-27T16:58:29.198Z
---

In this environment's Bash tool, a doubled backslash inside a single-quoted perl or sed pattern reaches the program as a single one (`[\\]` arrived as `[\]`). A `s/...\\n.../` meant to match the two characters `\n` in a GDScript string therefore matches a newline instead, finds nothing, and the substitution does nothing - with no error.

Heredocs with apostrophes inside a `'EOF'` block also broke the command outright once ("unexpected EOF while looking for matching `'`").

**Why:** a multi-hundred-line change to StealthWatch.gd quietly didn't apply, and only a later grep showed it.

**How to apply:** for any edit whose match text contains a backslash (GDScript `"\n"` in log strings, most of them), use the Edit tool. For writing a large block of code containing quotes, write it with the Write tool to the scratchpad and append it with `cat file >> target`. After any perl/sed edit, grep for the change before moving on. Python is not installed (the user offered to install it, but Edit/Write made it unnecessary).
