# Proposals of 2026-11-05

Light on the maps, the enemy AI, more illusions, and the immunity passive.
Everything here is a PROPOSAL. None of it is built unless it says so, and every number
is a starting point for the designer to change.

## 1. Light on the maps

**Built 2026-11-06:** the proposed Dim, option A, time of day changing during play. A lantern is an item; no map has its ambient set yet.

**What exists now.** Stealth maps have a dark switch, lamps and `dark_sight_tiles` (guards see
2.5 tiles in the dark). In fights, the darkness rule is built but only zones make it dark
(Light Void, Ravenous Dark): whoever stands in one is invisible to anybody who cannot see in the
dark. Cyrus can (Night Eyes), and so can anybody with Clear Sight.

### Three levels on every tile

Every tile is **Bright**, **Dim** or **Dark**, worked out from the map's ambient light and from
whatever is lighting it.

**Ambient**, a dropdown on `MapSetup` and `EncounterDefinition`:

| Ambient | Starts as | Notes |
| --- | --- | --- |
| Outdoors, day | Bright | The sun. Tiles under a roof are Interior |
| Outdoors, dusk or dawn | Dim | |
| Outdoors, night | Dim, or Dark with no moon | A second switch |
| Interior | Dim | Windows make pools of Bright by day |
| Underground | Dark | Only sources and openings light it |

**Sources:**

- **Placed lights:** a `LightSource` node with a Bright radius, a Dim radius beyond it, a colour,
  on or off. Stealth map lamps become these.
- **Things on the map:** `BattleObjectDefinition` gets a light radius (brazier, torch stand, a
  burning barrel). Destroy it and the light goes, so a light can be a target.
- **Openings:** a cave mouth or a hole in the roof lets the sun in by day, and the light fades
  with distance. At night it lets in nothing.
- **Carried:** a lantern as a Baldric item, or a light spell. See "Everybody invisible" below.
- **Spells:** Burner's ground and Wildfire light what they burn. Light Void cancels light inside it.

Walls stop light, by the same sight walk as everything else (`StealthSight`, `_SightGrid`), so a
torch does not light the next room. Light is worked out from positions alone and nothing is
rolled, so it stays safe over a network.

### What each level does

- **Bright:** nothing.
- **Dim (proposed):** no penalty to hit. Cyrus can hide there without cover, and guards' sight is
  shorter (a new `dim_sight_tiles`, about two thirds of normal). The alternative is ranged attacks
  from 5 or more tiles at -10% accuracy, which I would hold back unless Dim feels like nothing.
- **Dark:** invisible to whoever cannot see in the dark. Already built.

### Everybody invisible: the decision this needs

"Anybody in darkness is invisible" meets an existing rule: when nobody on a side is left in sight,
everybody hiding on that side is revealed. In a wholly dark cave both sides are invisible, so
either nobody can aim at anybody, or that rule reveals everyone at once and the dark does nothing.
The options:

- **A. Everybody sees one tile in the dark.** Melee still works and the dark punishes range.
  Simple. *Recommended.*
- **B. The party carries a small light** (Dim, radius 2, on a toggle). Turning it off is how Cyrus
  sneaks. Guards see a lantern from far off. *Recommended alongside A.*
- **C. No rule:** every underground fight is hand-lit so this never comes up.

### Who sees in the dark

Per creature, never by category. A passive already does it (`sees_in_darkness`), so a cave thing
only needs that passive, and a condition does it too (Clear Sight).

### On the screen

The rule has to be exact per tile, and the look should be soft, so these are two layers:

- **Rule layer:** a tint per tile under the figures, drawn like zones: faint normally, strong in
  the danger view (Shift).
- **Mood layer, view only:** `CanvasModulate` for the ambient colour and time of day, `PointLight2D`
  on each source, and shadows from occluders built from the Blocks tiles. It never decides anything.
- **Underground:** what is Dark is nearly black. With Cyrus leading or selected, a grey-blue "night
  eyes" view shows it. Enemies nobody can see are not drawn at all (`unseen_by_party` is built).
- **Sun:** warm tint by day and sprite shadows that lean with the hour, as placeholders behind slots.

### Stealth maps

The same levels replace the single dark switch: `dark_sight_tiles` for Dark, `dim_sight_tiles` for
Dim. Lamps and doors bump `_world_version` as they do now. A guard carrying a torch lights the
ground round himself, so Cyrus sees him coming, and a lamp put out is already an oddity to notice.

### Order to build it

1. Levels, ambient, `LightSource`, the rule layer, in fights.
2. Stealth maps on the same levels.
3. Soft lights and shadows.
4. Time of day, carried lights, spells that light.

### Decisions wanted

- What Dim does.
- A, B or C above.
- Whether time of day changes during play or is set per map.

## 2. The enemy AI

**All built, 2026-11-06:** CLAUDE.md "The AI's mind".

**What it does now.** `ai_plan_attack` tries every usable skill from every reachable tile and scores
it by predicted damage, chance to hit, kills, new conditions, hurt targets and focus fire. Prone
already counts, because `predict_hit` includes it. The ideas below are what it does not see yet.
Each would be a per-creature switch or dial.

**Recommended first:**

1. **It knows the ground.** Tile scoring counts what a zone would do: leaves Burner's ground by the
   shortest way, keeps out of a Storm Cloud's reach, and a caster steps out of Silence before casting.
2. **It sets off hazards.** Shoots a Demolition Charge or Gale Urn when the party stands round it,
   and keeps away from one itself. An encounter gets a switch to turn this off, for fights where
   the hazard is the players' mechanic.
3. **It uses shoves.** `foresee_shoves` is built, so the planner can score throwing somebody into a
   wall, a body or a hazard.
4. **It goes for whoever holds a tether.** Damage frays a tether, so while one of its own is held,
   the holder is worth more. A switch lets a creature slap a Mesmerised ally awake with a weak hit.
5. **Personality dials per creature** on `CombatantDefinition`: aggression, caution, focus fire,
   self-preservation. They would sit over today's `AI_*` constants and be tuned in the inspector.

**Later:**

6. **It avoids the party's reach.** `threat_map` from the other side: Rangers and casters prefer
   tiles the fewest of the party can hit next turn, using cover.
7. **It spreads out** once the party has shown an area spell.
8. **Set-ups.** Knocks somebody down only if an ally with melee acts next, and plays conditions
   into each other.
9. **Hemming and blocking.** Scores tiles that hem a target in, and a tank stands in a corridor to
   keep the party's melee off its casters.
10. **Healers triage.** Heals whoever would otherwise fall next round, lifts the most damaging
    condition, and dispels a tether's zone rather than healing through it.
11. **Gate economy.** The cheapest blow that kills, with the big gates kept for two or more targets.
12. **In the dark.** Walks to where somebody was last seen, throws an area there, moves towards light.
13. **Telegraphs.** Steps off marked hazard tiles and declared areas.
14. **Falling back.** The wounded pull back towards a healer, tied to Nerve.

`archetypes` and `lab` would measure each one.

## 3. Illusions

**Built 2026-11-06:** Phantom Noise, Phantom Wall, Seeming, False Ground, Phantom Killer, Fallen Friend,
Phantom Company, Mislead, Weird. Not chosen: Displacement, Mistaken Ally, Project Image.

### So far

| Spell | Who | Gate | Tether | Status |
| --- | --- | --- | --- | --- |
| Four Reflections | Alithia, Illusory Shepherd | Hermes (2) | none | New |
| Illusory Cover | Alithia, Illusory Shepherd | Pandora (3) | none | |
| Phantom Body | Alithia, Illusory Shepherd | Charon (4) | none | |
| Sanctuary of Light | Alithia, Illusory Shepherd | Nemesis (6) | none | |
| Mass Mirage | Alithia, Illusory Shepherd | Ogdoad (8) | none | |
| Reality's Reflection | Alithia, Illusory Shepherd | Yaldabaoth (10) | none | |
| Bewilder (mind trick) | Alithia | Hermes (2) | 200 | |
| Dread Visage (mind trick) | Alithia | Pandora (3) | 200 | |
| Invisibility | Prometheus | Hermes (2) | none | |
| Illusory Dragon | Prometheus | Ogdoad (8) | none | |
| Mirror Image | nobody | World (1) | none | Unused, data still there |

Passives on the Illusory Shepherd's path: Veil of Mercy I to III, Guiding Phantasm, Illusory Guardian.

### New ideas

Gates and tethers are suggestions. Most stand on systems already built.

| Idea | Gate | Tether | What it does | Rests on |
| --- | --- | --- | --- | --- |
| Displacement | World | none | For 3 turns, the first single blow each round at them misses | `evades_hits` |
| Phantom Noise | World | none | A sound at a tile: a guard goes to look, or in a fight an enemy turns aside | Lure, `make_noise` |
| Phantom Wall | Hermes | 100 | A wall only the other side believes in. Stops their sight and walking; the party shoots through | `illusion`, `believes_illusion` |
| Seeming | Hermes | none | On a map, looks like a guard. In a fight, unnoticed until they act | Disguises, invisibility |
| False Ground | Pandora | 200 | Ground the enemy believes is deadly. They walk round it | `zone_unseen`, AI ground from section 2 |
| Mistaken Ally | Pandora | 200 | Contested: they take the nearest of their own for an enemy | Deceived |
| Phantom Killer | Pandora | 200 | Contested: a psychic wound they believe in, each turn until they win the contest | Tethered DoT |
| Fallen Friend | Charon | 200 | An ally looks dead, and enemies ignore them until they act | `believes_illusion` |
| Phantom Company | Charon | 200 | Two or three images of soldiers that draw attacks and shake Nerve | `summon_decoy`, Nerve |
| Mislead | Nemesis | 200 | Invisible, with a double that a secondary action moves | Invisibility, images |
| Project Image | Ogdoad | 400 | Casts from an image's tile instead of her own | Images, range origin |
| Weird | Yaldabaoth | 400 | Everybody in an area contested: Fear and a psychic DoT | Terror's flee, DoT |

### If you also meant enchantment and divination

- **Enchantment:**
  - Charm (will not attack her unless hurt).
  - Sleep (an area of Stunned that ends when hurt, for the weakest).
  - Dominate (you play their next turn; `switch_sides`, tether 400).
  - Suggestion on a map (a guard walks off; `send_away`).
- **Divination:**
  - Augury (shows where reinforcements will come; the warning tiles are built).
  - Detect Magic (shows sensors and traps on a map).
  - Scry (a look at another room without a familiar).
  - Foresight (the first blow each round misses).

## 4. The immunity passive

The switch is built: a passive's Immune To Conditions and Required Level. It is tested but no
passive uses it yet. The levels below follow `docs/progression.csv`'s tiers.

**The harmful conditions, by kind:**

- **Mind:** Accused, Compelled, Confused, Deceived, Fear, Hesitating, Recanted, Caught Off Guard
- **Senses:** Blind, Choking Ash, Deafened
- **Body and holds:** Crippled, Crystallised, Dazed, Disarmed, Exposed, Frozen, Grappled, Prone,
  Silenced, Snared, Stunned, Windswept
- **Sickness:** Bile-Soaked, Burn, Corroded, Deeply Corroded, Poisoned
- **The Glutton's and boss states:** Scented, Staggered, Swallowed

**Boons and states, not worth immunity:** Blessed, Blurred, Braced, Bulwarked, Burden Shared,
Clear-Sighted, Clinging, Composed, Fortified, Grand Design, In Darkness, Mirage, Phantom Body,
Reflected, Reflections, Riding, Sanctified, Sheltered, Soothed, Unafraid, Veiled.

**A ladder to react to:**

| Level | Immune to |
| --- | --- |
| 8 | Fear |
| 16 | Hesitating, Deceived |
| 24 | Confused, Recanted |
| 32 | Compelled, Accused |
| 41 | Blind, Deafened |
| 54 | Dazed, Choking Ash |
| 64 | Stunned |

**Two that will not work with it:** Staggered and Swallowed are put on directly, past any immunity.
Everything else on the harmful list honours it. Immunity to Scented would stop the Glutton tracking
her, so check that is wanted before choosing it.
