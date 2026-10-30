# How moves could land harder - proposals

Written 2026-10-30, after the placeholder projectiles went in
(`combat/Projectile.gd`).

**Status, 2026-10-31: built, all but moves coming down from above or up from
below.** The designer (2026-10-30): "go ahead and do everything not done and
suggested, except the following 'moves that come down from above (hammers,
suns) or up from below (spikes)'". So the "From above" and "From below" styles
are not built, nor what each of those moves was to do with them (Judgement
Hammer, Judgment, Divine Verdict, Stolen Sun, Ire of Sophia, Rockfall, Water
Spike, Tartarus Flame, Crystalise keep their bolt or arc). Everything else
below is in `combat/MoveFeel.gd` and `combat/Projectile.gd` (CLAUDE.md
"Projectiles"; suite `projectile`), each move's own look set in its skill file
(SkillDefinition's Projectile Look, Hand Look, Impact Look and Ground Mark,
and the Beam / Spray / Back To User styles). It is all placeholder art and
sound, drawn or generated in code behind slots: the designer makes the real
ones. Every timing and size in it is a PROPOSAL value (ledger).

Where each went, in short:

| Proposal | Built as |
|---|---|
| A flash at the hand | `MoveFeel.hand`, by Hand Look (muzzle and a casing for a tracer, glyph, swish, roar, puff) |
| A burst in the element's own way | `MoveFeel.burst`, one particle set per element and a mend's |
| Pushed the way the blow came | `CombatantSprite.recoil(direction, single)`: along the line, further, and `squash` |
| Weight from the numbers | `Combat.hit_stop_for`, `shake_for`, `slow_motion` (`_last_standing`, a boss) |
| A miss that misses | `Projectile.verdict` (MISSED flies on past, GRAZED bursts dimly, IMAGE shatters); `MoveFeel.missed` for a blow |
| The number says what happened | `FloatingNumber.spawn(..., how)`: share, graze, resisted, vulnerable |
| Something left behind | `MoveFeel.mark_ground` (scorch, frost, puddle, pit), two rounds |
| Sound in three | SkillDefinition `sound` (launch), `travel_sound`, `impact_sound`; `PlaceholderSounds` stand-ins; `pitch_for` from the round and who |
| Cause and effect | `MoveFeel.condition_put` (to `combat_ui.condition_point`); `MoveFeel.mended`; `HealthBarMarks.fill` |
| Beam, Spray, Back to the user | ProjectileStyle BEAM, SPRAY (a roar: rings), BACK_TO_USER; a steal or a loot: `MoveFeel.item_flies` |
| Move by move | the looks named below, set on each move (but those from above or below) |
| Readied moves going off | `MoveFeel.readied_line` |
| Reactions | `MoveFeel.exclaim` - a "!" and the face card |
| Declared moves | `MoveFeel.declared` glyphs; a landing's `DECLARED_SHAKE` and `DECLARED_HIT_STOP` |
| Element raised | `Projectile.colour_from`, the flare half way |
| A boss staggered | `BossBars.crack`, `slow_motion` |
| Body parts | `MoveFeel.part_struck` |
| Zones | `Combat.spreading_zones`, `zone_tiles` / `_spread_so_far` |

The rest of this file is the proposals as they were written.

The game already has some of the tools these build on:

- a hit-stop sized by the blow (`Combat.hit_stop`, `hit_stop_for`);
- a camera shake (`shake_camera`, which level 3+ spells use);
- a recoil away from the blast (`CombatantSprite.recoil`);
- the struck combatant tinted in the element's colour, and the damage number in
  it (`Damage.TYPE_COLOURS`);
- a sound per move (`SkillDefinition.sound`), and generated stand-ins
  (`PlaceholderSounds`);
- the new projectile: the orb, its trail and its burst, with a texture or a
  scene slot per move.

Every suggestion is in the same spirit as the projectiles: drawn or generated
in code as a stand-in, behind a slot on the move for real art or sound later.
None of it may roll on `Combat.rng` or change the fight, so a fight played on
two machines stays the same.

## Everywhere: the beat of a move

A blow reads as having weight when it has five beats:

1. wind-up
2. release
3. travel
4. impact
5. aftermath

Today the wind-up (the move's animation) and the impact (the number) are
there. The travel is now there too. These would fill in the rest.

1. **A flash at the hand.** A short burst at the user as the move leaves them:
   - a muzzle flash for a shot;
   - a glyph for a spell;
   - a swish for a throw.

   It says who did it before the projectile has gone anywhere. *Cheap; the
   best value of anything here.*
2. **A burst in the element's own way.** The landing ring is the same shape for
   every element now. Each element could get a small particle set of its own:

   | Element | Burst |
   |---|---|
   | Fire | embers rising |
   | Water | droplets falling |
   | Wind | swirl lines |
   | Earth | chunks of grit |
   | Poison | bubbles |
   | Psychic | ripples |
   | Plasma | a hot white core |
   | Ice | shards |
   | Lightning | forks |
   | Metal | sparks |
   | Acid | drips that hiss |
   | Idol (Alithia's holy) | gold motes |

   *Cheap, and it makes the elements tell apart at a glance.*
3. **Pushed the way the blow came.** The recoil now pushes away from the blast
   centre. A single-target hit could nudge the target along the projectile's
   line instead, with a squash as it lands.
4. **Weight from the numbers.** Hit-stop and shake could follow the share of
   health taken:
   - a scratch: none;
   - a quarter or more: a beat;
   - a kill: the longest of all.

   The blow that downs the last enemy, or a boss, could also play a short
   slow-motion (about 0.3 s at 40%).
5. **A miss that misses.** The orb could fly past the target and fade, with a
   whiff, instead of landing on them. A graze could land with a dimmer burst.
   An image taking the blow (`_evades`) could shatter as the orb arrives.
6. **The number says what happened.** The floating number could vary:
   - larger for a big share of health;
   - a "Graze" tag;
   - a cracked look for "Resisted";
   - a jagged, brighter one for "Vulnerable".
7. **Something left behind.** A mark on the ground that fades over two turns:
   - fire scorches;
   - ice frosts;
   - water leaves a puddle;
   - acid leaves a smoking pit.

   Purely to look at.
8. **Sound in three.** Three sounds instead of one:
   - launch, at the hand;
   - travel, a whoosh under the projectile;
   - impact, as it lands.

   Each would be its own slot on the move, filled by `PlaceholderSounds` when
   empty. Any pitch variation would be worked out from something both
   machines share (the turn, the target), never rolled.
9. **Cause and effect.** When a move puts a condition on someone, the
   condition's icon could pop over the target and fly into their condition
   strip. A heal could raise motes and let the health bar fill visibly, its
   new part brighter for a moment.

## New ways for a projectile to go

The styles now are bolt, arc, streak, fan and none. Four more would fit the
moves the game has:

- **From above:** it comes down onto the tile instead of across, for
  hammers, suns and rocks falling. For Judgement Hammer, Judgment, Divine
  Verdict, Stolen Sun, Ire of Sophia and Rockfall.
- **From below:** it rises out of the ground under the target. For Water
  Spike, Tartarus Flame and Crystalise.
- **Beam:** a line that holds for a moment and fades, instead of an orb. For
  Holy Lance, Holy Spear, Piercing Light and Lightning Bolt.
- **Spray:** a dense stream of particles filling a cone for half a second,
  instead of three orbs. For the breaths (Fire, Frost, Lightning, Acid,
  Venom, Dread), Battle Cry and Daunting Roar.
- **Back to the user:** it travels from the target to the user. For Steal
  (the item flying to Cyrus), Loot, and anything that drains.

## Move by move

### Cyrus

- **Gun.** A tracer instead of an orb: thin, fast, a muzzle flash, a casing
  flicking out. *(texture slot: a tracer)*
- **Burning Shot, Frost Round, Corrosive Round.** The Gun's tracer leaving a
  trail of embers, frost or green drips. On landing, a scorch, a patch of
  frost or a hiss.
- **Combined Load.** Two tracers twisting round each other, in the two loads'
  colours.
- **Poison Dart, Venomous Shot.** A small dart on a slow arc, and a green puff
  where it lands.
- **Warning Shot.** It lands beside the target: a spark off the ground, and
  the target flinching.
- **Venom Fan.** Three darts fanning out (the fan does this now). Each would
  leave a little puff.
- **Minefield, Snare, Tripwire.** Lobbed, then settling into the ground with a
  click and a faint glint that stays.
- **Rapier.** A thin thrust line and a pin-prick flash.
- **Steal.** Back to the user: the stolen item's icon flies from the target to
  Cyrus's hand.

### Enfina

- **Greatsword Attack, Light Swing.** A swing arc drawn as a wide swoosh
  across the target, with a heavy hit-stop for the greatsword and a light one
  for the swing.
- **Sweep Strike.** A half-circle swoosh along its line.
- **Shield Bash, Stunning Blow.** A flash in the shield's shape, then stars
  turning over the stunned head.
- **Shoving Strike, and Tremor's shoves.** Dust at every tile slid, and a thud
  with a shake against a wall (for Dazed).
- **Grab, Hurl.** The thrown body on an arc with its shadow, a thud and a ring
  of dust where it lands.
- **Chain Hook.** A chain line out to the target, and a yank back.
- **Hamstring, Pin Down.** A low slash and the target dipping; a stake-like
  slam.
- **Battle Cry, Daunting Roar.** A shockwave rippling through the cone, the
  screen pulsing once.
- **Disarm.** The weapon icon popping off the target and spinning to the
  ground.

### Prometheus

- **Fireball.** A bigger orb with a flickering core, a big burst, and a scorch
  left behind.
- **Burner, Fire Blast.** A short jet of flame; a ring going out.
- **Wildfire.** The burst lighting the tiles around it one after another.
- **Tartarus Flame.** From below: dark red flames rising out of the ground.
- **Stolen Sun.** From above: a small sun falling onto the tile.
- **Rock Throw, Caucasus Shard.** A rock on an arc, breaking into pieces as it
  lands.
- **Gust Blast, Wind Shot, Zephyr Dart, Wind Swoon.** Swirl lines along the
  way instead of an orb.
- **Wind Vacuum.** The same lines, pulled in.
- **Ire of Sophia.** From above: a forked bolt, with a white flash.
- **Gnostic Tempest.** A plasma storm turning over the area for a moment.
- **Crystalise.** From below: crystal closing round the target, and shattering
  when it ends.
- **Hermes Step, Mist Step.** A puff where he vanishes, and another where he
  arrives.
- **Hover, Quicken, Invisibility.** A lift with a shadow under it; speed lines;
  a shimmer as he fades.
- **Hack, InstaHack, Dispel Magic.** A green glyph of code flying; a white
  ring that cuts through glyphs.
- **Flame, Frost, Stone and Storm Edge.** The blade glowing in its element,
  and the swing's swoosh in that colour.
- **Grand Design.** A great glyph circle drawing itself on the board.
- **Kindled Hound, Illusory Dragon.** The summon bounding out of him; a
  ghostly wing sweeping across.

### Alithia

- **Holy Spear, Holy Lance, Piercing Light.** A beam of gold light that holds
  a moment and fades, with a lens flare at her end.
- **Judgement Hammer, Judgment, Divine Verdict.** From above: a hammer of
  light coming down on the target, with a shake.
- **Holy Splash, Votive Flame, Revelation.** Golden droplets; a drifting
  candle flame; rays of light.
- **Censure.** Rays fanning through the cone (spray).
- **Water Spike, River Flow, Frozen River, Glacial Tide.** From below: a spike
  of water out of the ground; a stream sweeping over the tiles; ice spreading.
- **Heal, Light Heal, Restoration, Communion, Grace.** A soft column of light
  and rising motes on whoever is mended.
- **Cleanse, Purification.** A wash of light, with the conditions' icons
  dissolving.
- **Resuscitate.** A column of light, and the fallen sprite lifting back up.
- **Flash.** A white flash over the target.
- **Bewilder, Dread Visage.** Psychic ripples, the target's sprite wobbling.
- **Illusory Cover, Mass Mirage, Phantom Body, Reality's Reflection.**
  Mirror shards gathering into the image.
- **Sanctuary of Light.** A dome of light settling over the area.
- **Accusation, Recant.** A gold line from her to the target, and a seal
  stamping on them.
- **Persuade.** A small speech bubble with a pair of scales.
- **Sass Club.** A cartoon bonk, with a star.
- **Intuition.** An eye glyph, and the read future drawn faintly as a path.

### Enemies

- **The breaths.** Spray instead of three orbs.
- **Ground Pound, Self Destruct.** A shockwave ring and a strong shake; for
  Self Destruct, a white-out flash first.
- **Rockfall.** From above, a few rocks onto the tiles.
- **Nail Projectile, Flammable Limb.** A spinning nail; a burning limb thrown
  on an arc.
- **Bites and claws.** A quick red slash mark over the target.

## The game's own mechanics

- **Readied moves going off.** A quick line from whoever readied it to whoever
  set it off, just before it fires - so it is plain who reacted to whom.
- **Reactions.** A "!" over the reactor, and their face at the side of the
  screen for a moment.
- **Declared moves.** A glyph on the marked tiles, pulsing faster as its turn
  comes, and a heavier impact when it lands.
- **Element raised (Plasma and the rest).** The projectile flaring mid-flight
  from its first colour into the raised one, so the upgrade is seen.
- **A boss staggered.** A crack across the stagger bar and a slow-motion beat.
- **Body parts.** The struck part's outline flashing.
- **Zones.** The zone spreading out from where its projectile landed rather
  than appearing all at once.

## What to try first (most effect for least work)

1. A burst in each element's own way.
2. A flash at the hand.
3. Hit-stop and shake from the share of health taken, and slow motion for the
   last blow.
4. Pushed the way the blow came.
5. From above and from below - hammers, suns, rocks, spikes.
6. Beams for the lances and lightning.
7. Sound in three, behind slots.
8. Marks left on the ground.
9. Numbers that say what happened.
10. Back to the user, for Steal and Loot.
