# Handoff: Movement/Turn Freeze Bug

## RESOLVED

**Root cause: GDScript lambdas capture local variables by value.** The
`_handle_step_arrival()` timeout wrapper added in fix attempt #5 signalled
completion like this:

```gdscript
var finished = false
_run_step_arrival_and_flag(func(): finished = true)   # writes the lambda's OWN copy
while not finished and elapsed < STEP_ARRIVAL_TIMEOUT:   # ...so this is never true
```

`finished` in the enclosing scope stays `false` forever, so the wait always ran
its full 15 seconds. Since `_processing_step` is only released after that loop,
and `_process()`'s first line is `if _processing_step: return`, **every single
movement step locked all movement for every combatant for 15 seconds.** Godot
names this class of mistake `CONFUSABLE_CAPTURE_REASSIGNMENT`; it's a warning,
not an error, so it never surfaced.

This accounts for every observed symptom: the total freeze, "recovers after 15s",
"everyone only moves one tile per turn" (`ai_move`'s 10s timeout gives up before
the 15s lock clears), the missing preview tiles (`_draw()` is gated on
`_arrived`, which stays `false` mid-path), the freeze not being tied to any
particular combatant/skill/tile, and `check_reactive_skills()` always logging a
clean return - the hang was *after* it, in the wrapper. It also explains why
attempts #6 and #7 produced "exact same result": both changed what
`_handle_step_arrival()` does at the end, while the freeze was in the wrapper
around it either way.

Note this was the *second* freeze in sequence. The first one - `advance_turn()`
being awaited from inside the `_processing_step`-guarded scope, diagnosed in
attempt #6 - was real and is genuinely fixed by the `call_deferred()` in
`_handle_step_arrival()`'s terminal branches. Fixing it just exposed this one.

**Fix:** `_run_step_arrival_with_timeout()` / `_run_step_arrival_and_flag()` now
use the member variable `CController._step_arrival_finished` instead of a
captured local. Only one step arrival is ever in flight at a time
(`_processing_step` guarantees it), so one shared flag is safe.

`CombatantSprite.play_skill_and_wait()` had the identical bug and is fixed the
same way (`_skill_animation_finished` + `_on_skill_animation_finished()`). It
was latent only because no combatant currently has a `skill` animation assigned;
the moment one did, every skill use would have stalled for its full 5s timeout.

Also removed: the per-step `[_handle_step_arrival]` prints and the `[find_path]`
redirect print, which were diagnostics for this bug and fired on every movement
step / every mouse hover. The `push_warning` safety nets are kept - they now
genuinely only fire on a real bug.

## ALSO RESOLVED: Caster / Priest never repositioning

The separate open issue noted at the bottom of this document (Caster and Priest
appearing to stop repositioning even when cover was available).

**Root cause: safety was measured only as line-of-sight cover.** Every
positioning score used `count_players_without_los(tile)` and nothing else. On
open ground with no wall to break line of sight, that term is 0 for *every*
reachable tile, so every tile scored identically - and `find_best_reachable_tile`
keeps the current tile on a tie. Result: they planted themselves next to the
players and never moved. The Ranger escaped this only because its retreat step
scored raw distance (`float(d)`) as well as cover.

It was never about being *next to* cover: `count_players_without_los` does a real
Bresenham line-of-sight check from each player's actual position, so standing
beside a wall that doesn't block anything scores exactly zero.

**Fix:**
- `score_tile_safety(tile)` - the single shared definition of "a safer tile":
  line-of-sight cover (`COVER_WEIGHT`) plus distance from the nearest player,
  capped at `STANDOFF_CAP` so a retreating unit stops caring about distance
  once nothing can reach it, rather than fleeing the map. Distance always
  distinguishes tiles, so there is always a reason to back off.
- `retreat_with_remaining_movement()` - the Ranger's "hit and run" second half,
  extracted so `ai_caster` gets it too. Caster previously had no retreat at all
  and simply stood wherever it fired from.
- `reposition_healer()` + `count_allies_within_heal_reach()` - the Priest's
  version. Ally coverage (`HEAL_COVERAGE_WEIGHT`) dominates safety, so it will
  stand somewhere exposed if that's the price of staying able to reach a distant
  ally, but among tiles covering the same allies it takes the safest. This
  replaced an idle branch that scored "hug my nearest ally, plus cover", which
  on open ground reduced to hugging alone.

Verified headless by driving real enemy turns in the real scene. With the fix,
starting from the scene's default positions, distance to the nearest player:
Ranger 3->5, Caster 3->8, Priest 5->7 (Priest still covering both allies, at 6
and 5 tiles, inside its heal reach of 7). As a causal control, setting
`STANDOFF_CAP = 0` - which reduces the metric to the old cover-only one -
reproduces the bug exactly: Caster and Priest both report `moved=false`.

**Known remaining consequence (balance, not AI):** melee does 6-8 damage while
Caster has 7 max HP and Priest/Ranger have 6. `avoid_needless_opportunity_attacks`
refuses any move whose worst-case reaction damage could kill, so once a player is
*adjacent*, none of these three will ever disengage - one hit can always kill
them, so the check can never pass. The fix above addresses this preventively (they
now keep their distance rather than letting players close), but if you want them
able to escape melee, that's a stats question (raise their HP, or lower
`attack_melee`'s damage), not an AI one.

Everything below is the original handoff, kept for history.

---

Godot 4.7.2 2D tactical RPG. This document summarizes an unresolved, intermittent
freeze in the turn/movement system, everything tried so far, and what's still
unknown. Written for a fresh agent picking this up with tool access (able to
run the project, set breakpoints, etc.) that this conversation did not have.

## Symptom

During combat, movement processing sometimes freezes entirely - not just for
the combatant currently acting, but for *everyone*, including the human
player. Observed symptoms across several rounds of testing:

- A combatant's turn appears to hang indefinitely (originally reported as
  "doesn't end its turn," later confirmed to be a full, unresponsive freeze).
- After adding timeout-based workarounds (below), the game "recovers" but
  every combatant - player and AI alike - can only ever move **one tile**
  per turn before getting stuck again.
- While stuck, the player's movement/skill-range preview (the blue/red tile
  overlay) stops rendering entirely.
- The freeze is intermittent and not tied to one specific combatant, skill,
  or tile - it has been reproduced by multiple different AI archetypes
  (Ranger, Healer/"Goblin 3") doing ordinary movement.

It is NOT caused by (all individually ruled out during investigation):
- Skill/animation systems - the combatant that most reliably triggered it
  (Ranger) has no `sprite_frames`/animation assigned at all.
- The movement-cost or accuracy formulas - unrelated systems, already fixed
  and confirmed working in earlier sessions.
- `Combat.check_reactive_skills()` itself - diagnostic prints placed
  immediately before/after every call to it consistently show it starting
  and returning cleanly, even in runs where the freeze still occurred
  shortly after.

## Relevant files

- **`control/CController.gd`** - grid movement, pathfinding (`AStarGrid2D`),
  the per-frame movement loop (`_process()`), and turn-completion triggering.
  This is where nearly all of the suspected bug lives.
- **`combat/Combat.gd`** - turn-based combat brain: `advance_turn()`,
  `ai_process()`, the AI archetype functions (`ai_ranger`, `ai_healer`,
  `ai_caster`, etc.), and `check_reactive_skills()`.
- **`combat/CombatantSprite.gd`** - animation wrapper; ruled out as the cause,
  but `play_skill_and_wait()` has its own timeout safety net (below) that's
  part of the same defensive pattern applied elsewhere.

Line numbers below will have drifted after further edits - grep for the
function names instead of trusting them.

## Architecture relevant to this bug

Movement and turn-advancement are both async (GDScript coroutines via
`await`), and several pieces of mutable state are shared on the single
`CController` node across every combatant's turn (`controlled_node`, `_path`,
`_next_position`, `_position_id`, `_arrived`, `movement`). Key pieces:

- **`_process(delta)`** - every frame, if a combatant is mid-move
  (`_arrived == false`), glides `controlled_node` toward `_next_position`.
  When it arrives at a tile, it calls `_handle_step_arrival()`.
- **`_processing_step`** (bool) - a re-entrancy guard. Set `true` right
  before awaiting `_handle_step_arrival()`, reset `false` after. Exists
  because a reactive skill can trigger *during* a movement step (see below),
  and that resolution can itself take multiple frames (playing an
  animation) - without this guard, Godot would call `_process()` again on
  the next frame and re-enter mid-step. **Critically, `_process()`'s very
  first line is `if _processing_step: return` - so if this flag ever gets
  stuck `true` and never resets, it silently freezes movement for every
  combatant in the game, not just the one whose step set it.** This is the
  leading suspect for the actual freeze mechanism.
- **`_handle_step_arrival()`** - handles one tile of movement: updates
  position/occupancy, calls `await combat.check_reactive_skills(mover,
  old_position, new_position)` (which can itself await a reactive skill's
  animation), then either advances to the next path waypoint or - if this
  was the last step - sets `_arrived = true` and considers whether the turn
  is over.
- **`check_turn_completion()`** - called once a combatant's movement
  finishes; if it's the player's turn and both movement and their one skill
  are spent, calls `combat.advance_turn()`.
- **`Combat.advance_turn()`** - ends the current turn, hands off to the next
  combatant; if that combatant is an enemy, it (after a fix - see below)
  awaits their *entire* AI turn via `ai_process(comb)` before returning.
- **`Combat.ai_process(comb)`** - dispatches to the AI archetype function
  named in the combatant's data (e.g. `ai_ranger`) via `await
  call(ai_function, comb)`.
- **`CController.ai_move(target_position)`** - the AI-facing movement
  helper: computes a path, starts the move, and waits for it to finish
  before returning control to the calling archetype function.

The AI archetype functions (`ai_ranger`, `ai_healer`, `ai_caster`, etc.) are
deeply chained coroutines - e.g. `ai_ranger` awaits `move_into_range_of`,
which awaits `ai_move`, which (via the timeout wrapper) awaits
`_handle_step_arrival`, which awaits `check_reactive_skills`, which can await
`use_reactive_skill`, which can await an animation. This nesting depth may
itself be relevant.

## Timeline of fixes attempted (in order, all shipped and tested)

Each of these was independently reasoned to be correct and was tested by the
user. **Every one of them failed to resolve the underlying freeze**, though
several fixed real, independently-confirmable bugs along the way.

1. **Hypothesis: looping skill animation.** Ranger uses two skill-use points
   per turn (self-heal, attack), and a looping "skill" animation would
   `await animation_finished` forever. Ruled out - user confirmed Ranger has
   no animation assigned at all.

2. **Added a timeout safety net to `ai_move()`.** Raced the `finished_move`
   signal against a 10s timeout (`AI_MOVE_TIMEOUT`), via a manually
   `.connect(..., CONNECT_ONE_SHOT)` listener polled each frame. This
   confirmed the hang was real (not just "not using all movement" as
   initially guessed) and started surfacing diagnostic data.

3. **Diagnostic dump showed a genuinely blocked/redirected pathfinding
   case**, and separately, a real bug was found and fixed in
   `find_path()`'s "destination is occupied, redirect to an adjacent tile"
   logic: it used four independent, overwriting `if` checks that only ever
   produced a single cardinal direction, silently redirecting to the wrong
   tile for any diagonal move. Fixed to compute a proper direction vector
   via `sign()`. This was a real, demonstrable bug, but did not fix the
   freeze.

4. **Found and fixed a genuine turn-concurrency bug:** `Combat.advance_turn()`
   called `ai_process(comb)` without `await`, and `ai_process()` itself
   called `call(ai_function, comb)` without `await`. This meant two
   combatants' turns could run *concurrently*, both manipulating the same
   shared `CController` state. Fixed both, and propagated `await` through
   all ~25 call sites of `advance_turn()` across both files (verified via
   script that none were missed). This was a real, serious, pre-existing bug
   (present since the original asset) - but did not fix the freeze; a new
   diagnostic dump afterward showed a *different* hang, with
   `_processing_step` stuck `true` permanently and `_arrived` stuck `false`.

5. **Added a timeout-race wrapper around `_handle_step_arrival()`**
   (`_run_step_arrival_with_timeout()` / `_run_step_arrival_and_flag()`,
   15s `STEP_ARRIVAL_TIMEOUT`) that force-resets `_processing_step` if the
   underlying call never completes. Also added targeted `print()`
   diagnostics immediately before/after the `check_reactive_skills()` call.
   This didn't fix the root cause, but made the game "recover" after 15s
   instead of freezing forever - which is when the "everyone only moves one
   tile" and "no preview tiles" symptoms became observable (previously
   masked by the total freeze). The missing-preview symptom was explained:
   `_draw()`'s preview rendering is gated on `_arrived == true`, which never
   settled while stuck.

6. **Diagnosed (from logs) that the hang was specifically in
   `check_turn_completion()`/`advance_turn()` being awaited from *inside*
   the `_processing_step`-guarded scope** - i.e. the fix in step 4 was
   correct and necessary, but it means `advance_turn()` can now legitimately
   take a long time (awaiting an entire subsequent enemy turn), and holding
   `_processing_step` for that whole duration freezes everything. Fix:
   changed `_handle_step_arrival()`'s two terminal branches to call
   `check_turn_completion()` / `combat.advance_turn()` **without** `await`.
   Reasoning: once `_arrived` is set `true`, this step's own processing is
   finished, so `_processing_step` has nothing left to protect.
   **Tested: "exact same result."** The unawaited call did not behave as
   expected - possibly a GDScript coroutine-nesting subtlety not fully
   understood (calling an unawaited coroutine from inside a function that is
   itself mid-coroutine may not behave like "fire and forget" the way it
   does from a non-coroutine context - this was never confirmed either way).

7. **Most recent round of fixes (also tested, also "exact same result"):**
   - Replaced the unawaited calls from step 6 with **`.call_deferred()`**
     (e.g. `check_turn_completion.call_deferred()`), reasoning that this is
     an unambiguous decoupling mechanism regardless of coroutine-nesting
     semantics.
   - Found and fixed a **second, independent bug**: a different function,
     `CController.ai_process(target_position)` (used by AI archetypes'
     fallback "approach the nearest open tile" logic - not to be confused
     with `Combat.ai_process(comb)`), called `ai_move(candidate)` without
     `await` and returned the raw `finished_move` signal directly,
     completely bypassing `ai_move()`'s own timeout protection for that call
     path. Fixed to `await ai_move(candidate)`.
   - Replaced `ai_move()`'s signal-based completion detection entirely with
     **direct polling of the `_arrived` boolean** (the same flag
     `_process()`/`_handle_step_arrival()` themselves set), removing the
     `finished_move` signal/listener indirection on the theory that
     signal-connection timing could itself be a contributing factor.
   - Made `move_on_path()`'s degenerate (`_path.size() < 2`) branch
     explicitly set `_arrived = true`, for consistency with the new
     poll-based `ai_move()`.

   **User's report after this round: "Exact same result" - no new log was
   captured before the conversation moved to recommending a tool switch.**
   It is NOT confirmed whether this round changed the underlying symptom at
   all, made no difference, or produced a new failure mode that simply
   wasn't captured.

## Current state of the code (as of the last shipped build)

- `_processing_step` guard remains in `_process()`.
- `_handle_step_arrival()` is wrapped in a 15s timeout
  (`_run_step_arrival_with_timeout`) that force-unlocks `_processing_step`
  and logs a `push_warning` if it fires - this is a safety net, not a fix,
  and will mask the real freeze as "movement is just slow" if left in.
- `_handle_step_arrival()`'s two terminal branches use `.call_deferred()`
  for `check_turn_completion()` / `combat.advance_turn()`.
- `ai_move()` polls `_arrived` directly with a 10s `AI_MOVE_TIMEOUT` and no
  longer touches the `finished_move` signal for its own completion.
- `CController.ai_process(target_position)` properly awaits `ai_move()`.
- `find_path()`'s destination-redirect uses a proper `sign()`-based
  direction vector.
- Diagnostic `print()` statements remain in `_handle_step_arrival()` around
  `check_reactive_skills()`, and a detailed `push_warning()` diagnostic
  (dumping `_path`, `_arrived`, `_position_id`, `_next_position`,
  `controlled_node.position`, `_processing_step`) fires in `ai_move()`'s
  timeout branch. These are safe to keep or remove.
- Separately, unrelated diagnostic prints also remain in `ai_caster` and
  `ai_healer` (Combat.gd) for a **different, never-resolved issue**: Caster
  and Priest-type combatants appeared to stop repositioning even when cover
  was available. This was never conclusively diagnosed - no follow-up log
  was captured. Worth revisiting separately once the freeze is solved, or
  in parallel if it turns out to be related.

## What's confirmed vs. still unknown

**Confirmed (via log evidence across multiple rounds):**
- `_processing_step` is the flag that gets stuck, and it can freeze movement
  for every combatant, not just the one that triggered it.
- `check_reactive_skills()` itself is not the hang - it consistently
  completes cleanly per the diagnostic prints.
- The freeze correlates with a movement step completing (`_arrived`
  becoming, or about to become, `true`) and the subsequent turn-advancement
  chain.
- Two rounds of fixes targeting that chain (unawaiting, then
  `call_deferred()`-ing the same calls) did not resolve it.

**Still unknown:**
- Whether the freeze is still mechanically the same one after the latest
  round of fixes, since no fresh diagnostic log was captured afterward.
- Whether there's a second, undiscovered place that sets `_processing_step
  = true` (a grep before the last round found only one set/reset pair; this
  should be re-verified after any further edits).
- Whether the real cause is orthogonal to `_processing_step` entirely - e.g.
  something about Godot's coroutine/signal scheduling when multiple `while
  ... await get_tree().process_frame` polling loops are active
  simultaneously at different nesting depths, or an issue specific to how
  deep the AI await chain now goes.

## Suggested next steps

1. **Get a real stack trace at the moment of freeze**, via Godot's own
   debugger (breakpoint or pause-on-hang) rather than relying on inferred
   state from print statements. This is the single biggest gap in the
   investigation so far - everything above was diagnosed blind, from logs
   handed back after the fact, with no way to inspect the actually-suspended
   call stack.
2. Consider tagging every entry/exit of `_handle_step_arrival`, `ai_move`,
   `advance_turn`, `ai_process`, and `check_turn_completion` with a
   monotonically increasing ID in their log lines, to make it possible to
   see directly from logs whether two invocations are ever overlapping
   (suspected several times, never conclusively proven or disproven).
3. Given four rounds of targeted patches have each failed, it may be more
   productive to **restructure turn/movement sequencing** around a single,
   explicit owner (e.g. one coroutine or state machine that owns "whose turn
   is it and what are they currently doing") rather than continuing to layer
   incremental fixes (signals + polling + timeouts + `call_deferred`) onto
   the existing structure.
4. If it's easy to do, a minimal headless repro (script a fixed sequence of
   moves via `godot --headless` and assert on `_processing_step`/`_arrived`
   after each) would make this bug bisectable without needing the Godot
   editor UI at all.
