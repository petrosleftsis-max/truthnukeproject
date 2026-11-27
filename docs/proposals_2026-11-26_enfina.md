# Enfina: through, not around - proposals, 2026-11-26

## Chosen, and built (2026-11-26)

The designer's answers: "1. All except wood burns / 2. All, Breakthrough should also make the fiery path she leaves behind bigger
(one extra tile on the right and left of her), shoulder through can do a bit of damage. A creature takes this damage only once per
turn. / 3. Do Intercept. For the other, change how grapple works. Make it a secondary action and have it automatically succeed on
allies. If the ally isn't stunned or dead, they don't lower her movement like grapple normally would / 4. For dragon's wake,
increase the burn dot and duration that her path causes on enemies that step on it. Don't do the rest / 5. Don't do flashpoint /
6. Do weak points, not read the line". And: "Yes. Allow me to choose what is breakable and how much hp"; a keg "goes off"; "Take
planted out and let's reconsider her subclasses"; "Anybody can break barrels and whatever has hp, but they have to deplete the hp,
while enfina instantly destroys them no matter what"; all of it "Core".

Built (Combat "Things that break", "Intercept", "Weak Points", "Breakthrough"; suite `enfina`). Numbers and levels PROPOSAL:

| What | How it works now |
|---|---|
| Things with health | The TileSet's new **Health** (custom data, set per tile in the TileSet editor; 0 never breaks). The barrels and crates start at 12. Anybody wears one down with blows and blasts; at nothing it is the floor around it, and walking, sight, cover, the drawing and the light all follow. Battle objects break by their own health, as before. |
| Breaker (1) | Any blow of hers breaks whatever can be broken at once, a keg, a Cracked Wall, a barrel. |
| Burn Through (4) | Burning, she walks straight through anything that breaks; it breaks as she comes to it, and a keg goes off on her. |
| Splinters (16) | What she bursts through hits everybody beside it for 30% of her blow and Exposes them a turn. |
| Breakthrough (16, a skill) | A charge in a straight line as far as she walks: smaller ones of the other side driven aside for half the blow, their guard broken; somebody bigger stops her and takes all of it; burning, the way stays alight three tiles wide. |
| Shoulder Through (24) | Burning, she walks through smaller ones of the other side, shoving each aside for 20% of her blow, each once a turn. |
| Intercept (24) | Burning, Step In reaches an ally two tiles away; she runs to them, and pays a tile of her next walk. |
| Grab | A secondary action; always takes hold of an ally, who costs her nothing to carry unless stunned, and is set down as their own turn begins. (The Barbarian and the Glutton have Grab too, so theirs is a secondary action now as well.) |
| Blazed Path | The other side catches fire for 5 turns at 0.4, was 3 at 0.2. |
| Weak Points (1) | On her turn the board marks what breaks, and in a hotter colour what goes off. On a map, what breaks near the party is outlined while she is with them (there are no hidden Cracked Walls to spot). |
| Outside a fight | She smashes a barrel or a crate with any move she uses at it, as she does a Cracked Wall: floor for good, kept in the flags, heard by guards. Out here it is hers alone, at once. |
| Momentum I and II | Taken out of her kit (and out of `docs/progression.csv`). Standing still is worth nothing more: Sweep Strike planted at 54 is x1.40 (was x1.54), at 64 x1.40 (was x1.61); a planted greatsword blow at 64 x1.0 (was x1.15). |

Not built, as the designer said: Wood Burns, Carry Out (Grab changed instead), Opening, the rest of Dragon's Wake, Afterburn,
Flashpoint, Reads the Line.

## Her paths, chosen and built (2026-11-27)

The designer's answer: "The paths sound good, but i don't want juggernaut to be about her being immovable. ill need to think
about it / do the rest". Built (suites `enfina`, "Firebrand" and "Interceptor", and `paths`). Numbers PROPOSAL:

| Path | What changed |
|---|---|
| Vanguard | **Firebrand** (41) in place of Daunting Roar: whoever her Breakthrough drives aside catches fire (Burn, as Adrenaline gives), and so does anybody of the other side her splinters hit. The name stays Vanguard: "Wildfire" was suggested, but a spell already has that name. |
| Warden of Cover | **Daunting Roar** (41) is the Warden's now (`data/skills/enfina/paths/warden_of_cover/`), beside Hold the Line. **Interceptor** (54) reworked: her Step In reaches an ally 3 tiles away, burning or not, and running to them costs her none of her next walk. It was "50% of any hit on an ally within two tiles of her is taken by her instead". |
| Juggernaut | Unchanged (Chain Hook 24, Hamstring 32, Pin Down 41, Immovable 54, Tremor 64). The designer is thinking about what it is; not "the immovable warrior". |
| Planted | Momentum I and II have no home for now. Their two files are kept out of the game in `docs/set_aside/passives/` (the glossary lists every passive in `data/passives/`, and nobody holds them). |

Also: Grab is a secondary action for the other side too (the designer, 2026-11-27: "Yes make grab for enemies also secondary";
"Keep vanguard as the name for now"). The Barbarian grabs after its main action, from where it stands, when it wins the
contest; the Glutton grabs its scented prey with its secondary and bites with its main action (that turn it catches no new
scent). Both used to spend their main action on it, a grab or a hit, never both.

## Her paths, reconsidered (the suggestions of 2026-11-26)

With the moving vanguard her core now, the Vanguard path says what every Enfina already is. The three paths could instead be three
answers to the question her story asks - what kind of strength is hers:

1. **Juggernaut: Theron's way, the strength she thinks she needs.** The immovable warrior: keep Immovable (54), Tremor (64), Chain
   Hook (24), Hamstring (32), Pin Down (41), and give it **Planted** (Momentum I and II's +10% and +15% on a turn she has not
   walked, at 32 and 64). The stand lives on here, as a choice.
2. **Vanguard, renamed "Wildfire" (or kept): momentum, more of it.** Keep Adrenaline (24), Leading Charge (32), Unstoppable (54),
   Rampage (64). Swap Daunting Roar (41) for **Firebrand**: whoever Breakthrough drives aside catches fire, and her splinters burn.
3. **Warden of Cover: reaching people, the strength that turns out to be hers.** Keep Shield Bash (24), Covering Stance (32), Hold
   the Line (41), Last Wall (64); take **Daunting Roar** (41) from the Vanguard (a roar that stops them coming closer protects);
   and rework **Interceptor** (54), now that Intercept is core: her Step In reaches three tiles, burning or not, and costs her no
   walk.

Questions: 1. Planted to the Juggernaut? 2. Rename the Vanguard? 3. Interceptor reworked, or kept as "50% of any hit on an ally
within two tiles"? 4. The levels above for the new core pieces?

The designer, 2026-11-26: "I'd like to have objects like the barrels have hp and give Enfina an easier time breaking through them.
For example, give her a passive where while she is burned, she can walk through any breakable object and instantly destroy it.
Some stuff like walls will still be unbreakable. Suggest more stuff we can give her", with their notes on her as a **mobile
vanguard**: Trailblaze as the foundation, momentum and opportunity, "Cyrus gets around obstacles by finding ways around them.
Enfina gets around obstacles by moving straight through them", and her strength being that she reaches people.

Nothing here is built. Sizes are relative (**S** small, **M** a good piece, **L** the biggest here); every number is PROPOSAL.

## What she has already (more of the notes is there than it seems)

| Their idea | What exists | Where |
|---|---|---|
| Trailblaze | Burns herself 5 turns (Burn: +2 movement, a small burn) | `data/skills/enfina/trailblaze.tres`, `data/conditions/burn.tres` |
| A. Dragon's Wake | **Blazed Path** (8): her burning walk stays alight; her side walks it for 1 a tile, +1 movement starting on it; the other side catches fire stepping on it | `blazed_path.tres`, `Combat.blaze_where_they_walk` |
| Spending the fire | **Flashover** (16, blast, stronger the more Burn is left), **Cauterise** (24, heal), **Share the Fire** (32, an ally burns for speed, the hurt lands on her) | her skills |
| C. Intercept | **Step In** (Drills II, 24), **Iron Hide II** (41), Warden's **Interceptor** (54) and **Last Wall** (64) | passives, `warden_of_cover.tres` |
| The charge | Vanguard path: **Adrenaline** (burning: +30%, sets them alight), **Leading Charge** (+20% after 3 tiles), **Unstoppable**, **Rampage** | `data/subclasses/vanguard.tres` |
| Breaking things | **Breaks Walls**: only she (or a spell, a bomb) hurts a Cracked Wall, on a map and in a fight | `CombatantDefinition.breaks_walls`, `Combat.breaks_wall` |
| Shoves | Shoving Strike, Battle Cry, Hurl, Throw a Friend, Anything Is a Weapon, Juggernaut's Tremor | her skills and passives |

**One thing pulls the other way:** her core **Momentum I/II** (32, 64) reward a turn she has *not* walked ("Planted"). That fights
the moving vanguard. See question 3.

Barrels and crates today are scenery: tiles that Stand, block walking and sight, give cover, and are climbed. They have no health.
What breaks in a fight are battle objects (Powder Keg 20, Brazier 20, Tar Cauldron 40, Demolition Charge 60, Cracked Wall 30).

---

## 1. Things with health (the designer's idea, built out)

1. **Barrels and crates break.** A TileSet mark ("Health", 0 for never) gives every barrel and crate tile its health, so every
   map has them at once with no placing. A blow aimed at one, or a blast over it, hurts it; at nothing it is floor with a little
   debris, and the cover and sight it gave are gone (the fight changes shape). Plain walls, rock and raised ground never break.
   Barrel 12, crate 16 to start. **M**
2. **Wood burns.** Fire landing on a barrel or crate sets it alight: it burns a few turns and breaks, leaving a patch of fire.
   Her Blazed Path and Flashover spread through a room of crates. **S**
3. **Burn Through** (the designer's passive). While she burns, a breakable thing in her way is no obstacle: she walks into its
   tile as if it were floor (no extra cost) and it is destroyed as she passes. That covers barrels, crates, battle objects that
   break and Cracked Walls. Plain walls, raised ground and anything unbreakable still stop her. Something that goes off goes off as
   she passes: a Powder Keg blasts, and she is in it (Through the Fire stops fire on the ground, not a blast). Her risk to judge.
   **M** (pathfinding has to let her through them).
4. **Splinters.** What she bursts through throws splinters: everyone beside it takes a little (x0.3) and is Exposed a turn. The
   room becomes her weapon. **S**
5. **Outside a fight.** On a map she smashes barrels, crates, boarded doors and rubble the way she brings down Cracked Walls now:
   new ways through, things inside crates, and noise a guard hears on a stealth map. **M**

## 2. Through people (Breakthrough)

6. **Breakthrough** (a skill). She charges in a straight line up to her movement. Everyone of her size or smaller in it is shoved
   aside to a free tile beside the line and hit x0.5; whoever is bigger stops her and takes the full blow. A Guard it meets is
   broken. While she burns the line becomes Blazed Path. **M**
7. **Shoulder Through** (a passive, Vanguard). While she burns she walks through enemies smaller than her, shoving each a tile
   aside as she passes, with no blow. Plain movement becomes disruption. **M**

## 3. Reaching people (Intercept, further)

8. **Intercept.** Step In from further away: while she burns, a single blow about to land on an ally within two tiles brings her
   running to them, and it lands on her. Her reaction, and a tile less movement next turn. **S** (Step In's rules, longer reach).
9. **Carry Out** (a skill). She takes an ally beside her along as she moves, both ending side by side. A rescue, and "reaching
   people" in the plainest way. **M**

## 4. Openings (her strength making others stronger)

10. **Opening** (a passive). Whoever she shoves, drags or passes through is Off Balance until the round ends: the next blow of an
    ally on them has +25% and ignores their Guard. **S**
11. **Dragon's Wake** (Blazed Path, more). The other side's AI will not stop on her path if it can help it, so the trail is a
    barrier as well as a road. An ally starting a turn on it also acts a little sooner next round. **S**
12. **Afterburn** (a passive). When her Burn ends (run out, Flashover, Cauterise) she gets +1 movement and +5% on her next blow for
    every 3 tiles she walked while it burned (at most +3 and +15%). It rewards a planned route over "light up, hit the nearest".
    **S**

## 5. Interrupting (Flashpoint)

13. **Flashpoint** (a passive). While she burns, her first blow each round on somebody with a declared move drops it, as a stun
    does (`Combat.drop_declared`, "knocked out of it"). On a boss it fills the stagger bar instead. It rewards reading their
    telegraphs. **S**

## 6. Her Intellect (reading the field, not people)

14. **Reads the Line.** She sees whom each enemy means to strike next: a faint line on the board from each to its mark, so
    Intercept and Breakthrough can be planned. Further, the higher her Intellect. **M**
15. **Weak Points.** Selected, she shows what breaks and what is set to go off. On a map she spots a hidden Cracked Wall from
    further. **S**

---

## My pick: one loop, not a pile

**Ignite → run → break → open → spend.** Trailblaze (+2 movement) → **Burn Through** (3) and **Things with health** (1, 2): her
walk goes through the room, leaving Blazed Path → **Breakthrough** (6), where **Flashpoint** (13) drops what they were about to do
→ **Opening** (10) for the party → spend the fire on Flashover or Cauterise, with **Afterburn** (12) paying for the distance.
Intercept (8) is the defensive half, for the Warden. Everything else can wait.

## Questions

1. **What breaks?** Barrels and crates in fights and on maps? Doors, rubble? On stealth maps too, where they are hiding spots?
2. **A keg in her way:** does it go off on her as she passes (risk), or does she pass safely?
3. **Momentum:** keep "Planted" in her core, or move it to the Juggernaut path (the immovable one) and make her core momentum
   about moving (Afterburn)?
4. **Can anybody break barrels** with enough damage (her only easier), or only her?
5. **Core or path:** which of these are every Enfina's, and which belong to Vanguard, Warden of Cover or Juggernaut? At what level?
