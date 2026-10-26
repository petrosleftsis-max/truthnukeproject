# Moves outside a fight - the plan

The designer's request of 2026-10-26, and their answers to the proposal made
for it. **Phase 1 is built** (2026-10-26, the `outside` suite; CLAUDE.md "Moves
outside a fight"); Phases 2 and 3 wait for the designer's word. A session picking
this up should read this, then `CLAUDE.md` ("Stealth maps", "Find Familiar",
"Gates outside a fight", "Moves outside a fight").

## The request

Outside combat, the player can see all of a character's skills, spells and gates
and use them. The designer marks which moves make noise, and that is shown only
outside combat. A toggle in exploration shows only the out-of-combat spells. A
key hides the UI outside combat, except the dialogue and the text box.

## Decided (designer, 2026-10-26)

1. **Paying.** A spell cast outside a fight pays from the real gates
   (`Campaign.spend_gate_outside`, taken off at the next fight, as Find Familiar
   does). A spell marked out of combat may also pay from the Gates of Iris
   (`Campaign.outside_gates_left` / `spend_outside_gate`; Invisibility's pool).
   *PROPOSAL:* Iris first, then the real gates, with the pips showing both.
2. **Damaging moves outside a fight** do one of two things: used on an unaware
   guard, the fight starts as an ambush with that move as the opener; or they
   break an interactable, such as a breakable wall.
3. **The out-of-combat mark.** The designer marks a spell as out of combat (a
   new `SkillDefinition` field); only a spell that deals no damage may be marked,
   and a test fails on any damaging spell that is. The exploration toggle,
   "Out of combat only", shows only the marked spells.
4. **The hide-UI key** is not Space (Space stays a second interact key). A new
   action, `hide_ui`. *PROPOSAL:* U on the keyboard; holding View for half a
   second on a pad, since every pad button is taken on stealth maps.
5. **What each move does outside** - the table below. *Awaiting the designer.*

## Phase 1 - see and pay (built)

As built, and where it differs from the plan below:

- A heal lands on whoever is worst hurt (an area heal on everybody hurt), and
  Resuscitate on the first fallen - there is no picker (PROPOSAL).
- Hurry is x1.5 for the move's Outside Seconds, else 20 s; Quicken's is 60
  (PROPOSAL test values).
- Spells go deeper than their gate when it is spent, as in a fight; Find
  Familiar pays exactly World, Invisibility Iris only, as before.
- Iris pays a marked spell no deeper than the gate Iris matches (Hermes).
- Nothing is marked Out Of Combat yet; the toggle shows Find Familiar and
  Invisibility by their nature.
- G lists the spells that would do something now (keys and a pad have no
  pointer on a map); skills are on the panel for the mouse.
- Hide UI is U, and Share (Create, Mic, Capture) on a pad - every other pad
  button is taken on a stealth map, and View opens the menus on its press.
- The edge arrows and the familiar's frame stay up with the UI hidden.

The plan as it was:


- **The exploration panel.** `combat_ui.set_exploration_mode` hides the turn
  queue, movement and End Turn and empties the skill grid
  (`set_skill_list([], true)`), leaving a Spells button and an empty grid. Fill
  that grid with the leader's moves (Skills / Secondary / Spells tabs, gate pips
  as in a fight); Tab swaps the leader, so it shows the new one's. A move with no
  outside use yet is greyed with "only in a fight".
- **The toggle** on the panel, kept as left (a per-viewer setting, not saved
  state), shows only spells marked out of combat.
- **Gates.** Pips from `Campaign.gates_left_outside` plus the Iris pool. Fix the
  character sheet's `_pools_of`, which ignores `gates_spent_outside` on the map.
- **Noise marks.** A `SkillDefinition` field `noise` - Unmarked (0), Silent,
  Quiet, Loud, appended in that order - and `noise_tiles`. Quiet: guards within
  the radius turn to look. Loud: they investigate (`Guard.hear`, like a dash or a
  takedown). Unmarked plays as silent, and a test lists the skills still
  unmarked. Shown only outside a fight: a badge on the panel, and on the sheet's
  Moves page while on a map ("Silent", "Loud: 6 tiles").
- **First uses:** Mend (heal a member's carried health in `party_state`), Revive
  (Resuscitate, as at a rest), Burst / Speed (Run, Quicken).
- **Fold in** Invisibility and Find Familiar: G (`StealthBar.outside_spell`,
  `ui/outside_spell_choice.gd`) can stay as a shortcut, or go once the panel
  casts them.
- **Hide the UI** with `hide_ui`, outside a fight only: the party portraits, the
  action panel, the stealth bar and the objectives go; the dialogue balloon
  (layer 30) and the information log stay; guard cones and meters, drawn in the
  world, stay. A conversation starting brings nothing back - the key does. Bind
  it in `project.godot` `[input]` with its pad button and name it through
  `Pad.key`.
- **Tests:** a new suite for the panel, paying (Iris then real), the mark rule,
  the toggle, noise and the hide key; `pages`/`sheet` for the pips fix. Ledger
  rows "Moves outside a fight" are already in `docs/design_status_ledger.csv`;
  update their state as each lands.

## Phase 2 - on guards and the world

- Blind / Scare / Confuse a guard for some seconds; Read a guard (his route
  known); Switch off magic (a sensor or ward, for some seconds).
- **The ambush opener:** a damaging move at an unaware guard starts the fight as
  the ambush (F) does (`build_fight`, `surprised`), with that move used first.
  *OPEN:* whether the opener is the leader's first action or a free one before
  the first turn, and whether it may be aimed at anybody else caught.
- **Breakable walls:** an `Interactable` that a damaging move breaks, opening its
  tiles the way an opened door does (`_shut`, `_world_version`). *OPEN:* whether
  some walls want a minimum damage or a damage type.

## Phase 3 - moving, luring, traps

Blink / Fly (a few tiles through a gap, or over low obstacles for a while), Lure
(a decoy guards go to look at, as a thrown thing), Hiding spot (made where cast),
Trap (catches a guard who walks into it, down as after a takedown).

## What each move does outside (PROPOSAL, for the designer)

The game has to be told what a move does outside a fight: a heal there is
obvious, a Flash at a guard needs a rule. Rather than write each move by hand,
every move gets one of a few shared behaviours, built once.

| Outside use | What it does | Moves |
|---|---|---|
| Mend | heals a member's carried health | Heal, Light Heal, Communion, Restoration, Grace, Purification |
| Revive | brings a fallen member back, as at a rest | Resuscitate |
| Burst / Speed | a dash or a faster pace for some seconds | Run, Quicken |
| Blink / Fly | a step of a few tiles, or over low obstacles for a while | Hermes Step, Mist Step, Cover Leap, Hover, Climb |
| Blind / Scare / Confuse | a guard sees nothing, runs off, or wanders, for some seconds | Flash; Dread Visage, Intimidate; Bewilder |
| Lure | a decoy or a sound guards go to look at | Phantom Body, Mass Mirage, Reality's Reflection, Kindled Hound |
| Hiding spot | makes one where it is cast | Illusory Cover, Stealth |
| Read a guard | his patrol route known | Study, Intuition |
| Switch off magic | a sensor or ward silent for a while | Dispel Magic, InstaHack |
| Trap | catches a guard who walks into it | Snare, Tripwire |
| Ambush / break | the damaging moves (decision 2) | every move that deals damage |
| None | greyed, "only in a fight" | Guard, Growth |

Not placed yet - for the designer: Cleanse, Persuade, Deceive, Steal, Hack,
Catalyst, Trailblaze, Grab, Slip Past, Sanctuary of Light, Recant, Illusory
Dragon, Grand Design. Some already have a stealth-map counterpart (a pocket
picked, a hack on an Interactable, a word in disguise) and could map to it.
