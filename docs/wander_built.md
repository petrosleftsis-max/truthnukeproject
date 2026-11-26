# Exploring, maps and some weirdness: what was built from the proposals of 2026-11-19

The designer, 2026-11-19, on `docs/proposals_2026-11-19.md`: "Proposals: 2. Do all / 3. Do all except the ones kin to Alan wake and
the Sky Slips". Built:
- all nine pieces of section 2;
- six of section 3: the archive that rearranges, things that remember, struck-out words, friendly oddities, a dream-place, and
  Lethe's touch.

Not built: the forgetting dark and pages ahead of time (both kin to Alan Wake), and the sky slips.

**Every number here is a PROPOSAL** until the designer has played with it. All the art and sound made for it is a placeholder behind
a slot (see "Slots" at the end), and every line of writing is a placeholder for the designer's own. The suite is `wander`.

## Where to see all of it: The Wanderer's Quarter

On the title screen, Stealth Stages, the tenth stage (`maps/stealth_stages/wander.tscn`, built by `tools/build_stealth_stages.gd`
`stage_wander`; its dream `dream.tscn`, from `stage_dream`). A quarter of a town, 36 x 24 tiles:
- **The yard:** a fire to rest at, which also leads into the dream; a note on a wall; a stash by the well; a pond that freezes in
  winter.
- **A terrace:** raised ground, with a ledge and a ladder up it.
- **A cracked wall:** light shows through it. Behind it is a dark room, with a mark only Cyrus's Cat Eyes see, and the stash it
  uncovers.
- **The lane:** it floods after rain, and a lamp's light there shows a second mark.
- **The neighbours:** a shop shut at night; a townsman who goes home after dark; a neighbour who forgets the party.
- **The oddities:** a statue, a bin and a lamp post.
- **The field to the east:** a foe on the roam.
- **The archive:** a door barred from the other side; a room that changes while nobody looks; a corridor that loops until its odd
  note is read; at its end, a stash holding the stopped clock and Lethe Water; and a bench, the second rest spot, to travel between.

## 2. Exploring and maps

### A map you can open
- **What it shows.** N (the `map` action; on a pad, it is in the menus' round with the journal and the bags) opens `MapScreen`
  (`ui/map_screen.gd`). It is drawn from the map's own tiles: floor, raised ground, walls, water and doors, but only what the party
  has seen.
- **What it remembers.** `MapMemory` (`exploration/MapMemory.gd`, one per map, made by `ExplorationScene`) fills it in as the leader
  walks, `SEEN_TILES` 6 round them. It keeps it in `Campaign.exploration`, saved, so a map remembers between visits.
- **Marked on it:** the party, the rest spots found, place names (`MapLabel`) and the goal's star.
- **Pins.** A click puts a pin down or takes one up (`MOST_PINS` 3; a fourth takes the oldest's place).
- **The count.** The corner says how much of the map has been seen and how many of its secrets have been found.

### The way, at the screen's edge
`WayArrow` (`ui/way_arrow.gd`): while the newest pin is off the screen, an arrow at the edge points the way to it, in the pins'
colour, as a ping's arrow does. With no pin, it points to a stealth map's goal. It is hidden with the HUD and while a menu holds the
game.

### Secrets worth finding
Every secret joins the group `secrets` and answers `is_found()`. The map screen counts them.
- **Interactables.** Any Interactable can be one: tick `secret`. Using it for the first time finds it (flag `found:`, the sound
  `secret_found`).
- **Notes on walls.** `WallNote` is read by pointing at it (within 0.6 of a tile) or with E. It goes into the log like anything
  examined. Its sets-flag can unlock something.
- **Stashes.** `Stash` is searched once (prompt Search): its items go into the leader's bags and its gold into the purse.
- **Cracked walls.** A `BreakableWall` shows a warm line of light along its crack (`light_through`). With `secret` ticked, breaking
  it counts as finding it.

### Light that finds things
`HiddenMark` shows its words, and uncovers what it Reveals (an Interactable kept out of sight and out of use until then), in one of
two ways:
- **In The Dark:** while its tile is Dark and whoever leads, within `seen_from_tiles` (4), sees in the dark: only through Cyrus's
  eyes (Cat Eyes), when he leads, not whenever he is in the party (the designer, 2026-11-19: it showed to everyone).
- **In The Light:** while any light the rules make reaches its tile: a lamp, a Flare, a carried light (`LightMap.glow`). The day's
  light does not count.

Seen for the first time, it is a secret found (flag `seen:`). The lighthouse lens (below) shows every mark near it.

### Climbing and shortcuts
- **Raised ground, by a ladder or by Cyrus alone** (the designer, 2026-11-19: "Have them climbable only when Cyrus gets his
  passive that allows him to climb and only him. The party stays behind"). Raised ground (Blocks HIGH, Lift 0 or more, not a thing
  standing) is climbed onto from the floor only where a `Ladder` stands, by anybody, or anywhere by whoever climbs anywhere
  (`Campaign.climbs_anywhere`: Cyrus, from Cat Burglar at 24). He goes up alone: whoever follows him stays below where they stand,
  as if told to Stay Here (`_climbs_alone`). He goes up only after pushing against the edge for 0.35 s (`CLIMB_PUSH_SECONDS`), so
  brushing an edge in passing splits nobody off. Once up, raised ground is walked like any other, and dropping down is allowed
  anywhere. `ExplorationScene.may_cross` decides, and the sound `climb` plays. Walls and things that stand still stop everybody, and
  guards keep their routes as before. A `Ledge` is only how a sheer edge looks now. Neither it nor the ladder has a picture yet.
- **Called over.** Whoever waits can be called to the leader once a way to him exists: C (`call_party`), the moves panel's Call
  (shown only then), or Stay Here when the leader has nobody else in his line, which is a pad's only way. They walk to him by
  `walking_route`, the shortest and safest way the party knows:
  - only over ground it has seen (`MapMemory`);
  - up raised ground only by a ladder, and down anywhere;
  - never onto a trap it knows of (`MagicTrap.known_to_party`);
  - dearer near a guard or a roamer it can see where they stand (4 tiles round, 3 a tile nearer).

  They fall in behind on reaching him. What they don't know of, they walk into: a trap on ground they haven't seen, or a hidden one
  (`MagicTrap.concealed`, a new switch: not drawn until it goes off), goes off as it would for anybody. If he has walked on meanwhile,
  they set off after him again. Coming back to them himself still picks them up, but only from ground they could step straight onto.
- **Doors barred from the other side.** `StealthDoor.opens_only_from` (North, South, East or West; None is any side). From the wrong
  side the log says "It's barred from the other side." Once opened from its side, it opens from both (flag `unbarred:`). The
  archive's door opens from the east, so the archive loops back to the lane.

### The hours and the weather change the map
- **The hours.** `Hours`, put under a node, says which parts of the day it is there: by day, at dusk, at night, at dawn.
  - **Away with nowhere to be:** out of sight and out of use. The shopkeeper is like this, so the shop is shut at night.
  - **With Elsewhere set:** it stands there instead. The townsman stands at his door after dark.
  - **Under a guard:** a shift, which changes while you watch (the designer, 2026-11-19: "Change while I watch"; `StealthWatch`
    "Shifts").
    - **Off duty.** Off his shift a guard is kept off the map (`off_shift`): he sees nothing, nobody sees him, and no fight has him.
    - **Changing over.** As the hour turns, the one going off walks to his Hours' Elsewhere, where the shift changes, once his beat
      leaves him free (`Guard.Mood.LEAVING_SHIFT`). From there he is gone, and the one coming on walks in from it to his beat. The
      check runs every second (`SHIFT_CHECK_SECONDS`).
    - **Still on watch.** Going off, he is still a guard: whatever catches his eye on the way draws him off it, and he goes again
      after.
    - **No Elsewhere.** He fades out, and in, where he stands (0.8 s).
    - **Where to watch it:** the Light stage has a post. A day watch and a night watch stand by the hall's north wall and change over
      at the cellar door (sign "SignShifts"); run the sundial on to dusk or dawn.
- **Floods.** `FloodPatch` water lies over its ground and shuts it while the ground is wet after rain (`floods_from` 0.6 of
  `Campaign.ground_now().wet`), and drains when it dries.
- **Frozen water.** A `WaterPatch` with `freezes` is ice to walk on in winter, or with frost or snow lying (0.5 or more). `deep`
  water can be crossed only while it is frozen.
- **Tracks in snow that guards follow** were there already (the prints).

### Foes that roam
`Roamer` is a placed fight that walks:
- **Wandering:** within `wander_tiles` (4) of where it was put, at `walk_speed` (1.4 tiles a second), resting now and then.
- **Seeing and chasing:** it sees the party within `sight_tiles` (5) along a line no wall cuts, and chases at `chase_speed` (2.8).
- **Giving up:** after `gives_up_seconds` (3) out of sight it goes back.
- **The fight.** Coming within `meets_within` (0.75) starts its fight, as any placed fight does, so an ambush from afar opens it too.
  Beaten, it is gone.
- **How it looks:** it is drawn as its encounter's first foe, and the sound `roamer_sees` marks the moment it spots the party.
- **Dice:** nothing in it rolls on a fight's dice.

### Rest and travel
`RestSpot` (a placeholder fire ring) is found by coming within 3 tiles and kept in `Campaign.rest_spots`. Used, its menu offers:
- **Rest an hour, once a day at each spot** (the designer, 2026-11-19: "Have the resting stops only give a short rest and can only
  be used once per day. Long rest will occur from story and dialogue"). `Campaign.short_rest` mends half of what was lost, gives
  back the uses per short rest and one Devotion casting, and an hour passes. The day is kept in the flag `rested_on:<spot>`, and the
  button reads "Rested here today" until the next day. Then, if anybody can **Meditate** or somebody fallen could be brought back
  with **Resuscitate**, the rest's own panel comes up, the one shown between a dungeon's fights (`RestPanel.on_a_map`: a short rest's
  words, the whole party named, Done, no way to the title screen).
- **No preparing of spells:** only a long rest brings that (the designer: "Spells can only be prepared in a long rest").
- **Travel by Iris's rainbow** to any other rest spot found, on any map. A sweep of the rainbow's colours, and the party arrives
  a tile below that spot. It is free, and no time passes (the designer: "For now no, rainbow travel shouldn't cost time").
- **Sleep, and dream:** where the spot has a Dream Map (the yard's fire). No rest is needed for it (the designer).

### Sound by place
`SoundArea` is a rectangle of a map:
- **Its ambience:** wind, a city's murmur, drips or the dream. It plays quietly and looping while the party is inside, faded in and
  out (-16 dB, 1.5 s).
- **Its surface:** stone, wood or grass, which the steps take (`Footsteps`: `step_<surface>`; wet ground still splashes).

## 3. The weirdness

### The archive that rearranges
- **A room that changes.** `ShiftingRoom` has its layouts as hidden TileMap children. While the whole of it is out of view and
  nobody is in it, it takes the next layout (walls, doors and all), no more often than every 4 seconds. The map is then read again:
  walking, light, depth. Near it, the sound `shift` is heard faintly. The archive's room has three layouts.
- **A corridor that loops.** `LoopingCorridor`: walking past its far end puts the party back at its start, with the view, as if
  nothing had happened. It stops once Breaks On Flag is set. In the stage that is the out-of-place note in it (`corridor_noticed`).

### Things that remember
Keepsakes, kept out of fights, used from the Items tab outside one by whoever carries them, and never used up (`Memento`;
`OutsideMoves` Stop Time, Look Back, Find the Way):
- **The stopped clock:** every guard within 5 tiles stands blind and still for 4 seconds, and every roamer stands still too. It is
  in the stash at the archive's end.
- **The lighthouse lens:** every hidden mark within 7 tiles shows for 10 seconds, whatever the light. It is in the dark room's
  stash.
- **The child's shoe:** small glowing prints, one every 0.8 of a tile and 12 tiles long, from the party towards the newest pin, or
  the goal. The bin gives it for the shiny button (see the oddities below).

All four borrow Study's icon until their own are drawn.

### Struck-out words
- **In a clue's text,** `[struck=flag]words[/struck]` shows as blocks (█) until that flag is set, and then as the words
  (`ClueBook.shown_text`, in the Journal). Nothing in the story uses it yet; the suite does.
- **A gate that speaks.** `GateVoice`: the first time in a game that one of the party casts through each gate, a cold, official line
  is typed across the top of the screen in spaced capitals, with a low tone (`gate_voice`). It shows once per gate (flag
  `gate_voice:<gate>`). The ten lines are placeholders, in `GateVoice.LINES`, for the designer's own.

### Friendly oddities
`TalkingThing` (Kind Statue, Bin or Lamp Post), talked to with `dialogue/oddities.dialogue`, and passing remarks in a bubble within
3 tiles, at most one every 14 seconds:
- **The statue** reviews the last fight (`Campaign.fight_review`).
- **The bin** has opinions, and an errand: the shiny button from the well's stash, for the child's shoe (`Campaign.hand_over_item`).
- **The lamp post** remembers each visit (`count_visit`, `remembered_line`).

### A dream-place
- **Getting there.** Sleep at the yard's fire: the dream lies over the world (`DreamPlace`), with colours drifting, edges soft and
  the ground breathing, and its own bed of sound.
- **Zones.** Within a `DreamZone` the party is drawn bigger (1.7) or smaller (0.6), or carried along as if the ground were tilted
  (2 tiles a second).
- **The lamps.** Three `DreamLamp`s are a puzzle: lit out of order, they all go out.
- **The rehearsal.** Solving the lamps opens the `Rehearsal`: a run of fights (encounters 01 and 02 for now). A blessing drawn at
  random lies on the whole party for the run (`Campaign.run_blessing`): Blessing of the Swift (+1 movement), Blessing of Iron (10%
  Damage Mitigation), or Blessing of the Patient (+15% Output Efficiency on a turn they have not moved). After the last fight it is
  gone, and the next run draws again. Nothing of the campaign is set aside for it. The glossary lists the blessings among the
  passives (`Rehearsal.BLESSINGS`, where a new blessing goes too).
- **The echoes.** The party's echoes in the dream talk.
- **Waking.** `DreamWake` wakes the party at the rest spot they slept at.

### Lethe's touch
- **People who forget.** A conversation's Interactable with `forgets_flags` forgets those flags each time the map loads, so the
  neighbour meets the party afresh every visit.
- **Fading names.** A `MapLabel` with `fades_after_days` wears away on the map screen with the days since the party was last near
  it, and coming near writes it back.
- **Lost clues.** `do Campaign.lose_clue("key")` takes a clue out of the Journal, which says "Something you knew is gone.", until
  `find_clue`. Nothing in the story uses it yet.
- **A move forgotten.** Lethe Water, a thrown item, puts Forgotten on whoever it breaks over. One of their own moves, chosen by the
  fight's dice, is gone from them for two turns (`ConditionDefinition.forgets_a_move`; `Combat.forgotten_moves`). The AI, the HUD
  and `wasted_on` all ask. Its mark reads FM (the designer, 2026-11-19), since Fortified's is Fo. It has no price yet; it is only
  found.

## Not built, or built narrower

- Section 3's forgetting dark, pages ahead of time and the sky slips, as the designer said.
- The ambience beds and the new steps are stand-ins until there are sounds.
- Those called over are seen by the guards where they stand, as anybody waiting is, but their footsteps are not listened for as
  the line's are.

## Slots

- **Sounds** (SoundBank, group "Wandering"; a `PlaceholderSounds` stand-in meanwhile): `secret_found`, `mark_seen`, `rest`,
  `rainbow`, `roamer_sees`, `climb`, `shift`, `dream`, `lethe`, `gate_voice`, `ambience_wind`, `ambience_city`, `ambience_drips`,
  `ambience_dream`, `step_stone`, `step_wood`, `step_grass`.
- **Pictures:** a Texture or Picture on `WallNote`, `Stash`, `HiddenMark`, `Ladder`, `FloodPatch`, `RestSpot`, `TalkingThing`,
  `DreamLamp`, `Rehearsal` and `DreamWake`; each is drawn in code until it has one. Icons for the four keepsakes.

## The suite

`wander` plays The Wanderer's Quarter and its dream: the map and its pins, the arrow, every secret, both kinds of mark, climbing (a
ladder, Cyrus alone, the rest called over round a known trap and over a hidden one) and the barred door, the water and the flood,
the hours, the roamer, resting (once a day, no preparing, Meditate's and Resuscitate's panel) and travel,
sound by place, the oddities, the archive, the mementos, the struck-out words, the lost clue, Lethe Water and the dream; and, on the
Light stage, a shift changing over at dusk and back at dawn.
