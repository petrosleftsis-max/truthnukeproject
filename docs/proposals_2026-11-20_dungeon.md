# Proposals, 2026-11-20: a dungeon run, and Erysichthon again

The designer asked: "I'd like to next make a dungeon playthrough, with three combats and exploration at the start and between each
combat. I want to make the maps and the encounters myself, but I'd like it if you had suggestions. I want the last fight to be
Erysichton but I want to really redesign it."

Answer per line, as before ("do 1a and 4a", "not this"). Sizes are rough: Small is a day or less, Medium a few days, Large a week
or more. All of it is PROPOSAL, and every number in it is the designer's to set. The maps and the encounters are the designer's to
make; what follows is ideas for them, and the code each idea would need.

## 0. What a dungeon can do already

- **The shape is there.** A `DungeonDefinition` (`data/dungeons/`) is stages in order, each a map walked until its fight or a fight
  gone straight into (`DungeonStage.map`, `encounter`, `replaces`). Exploration at the start and between the fights is three map
  stages: map 1 then fight 1, map 2 then fight 2, map 3 then Erysichthon. Nothing new is needed for that.
- **Between stages:** the dungeon's own rest (short or full: `short_rests`), gates brought back a few times a run
  (`gate_recoveries`), a store (`store`), and the party, its level and its kit set by the dungeon (`party`, `level`, `kit`).
- **On a map:** guards with sight and shifts (`Hours`), Bright, Dim and Dark Areas, lamps and Flares, marks only the dark or a
  light shows, traps known and concealed, ladders and Cyrus climbing (Cat Burglar, from 24), Stay Here and calling over, rest spots
  (a short rest, once a day), clues and the journal's deductions, conversations, things to pick up, doors that open from one side,
  the map screen and what it remembers, the weather and the hours, and the oddities of the Wanderer's Quarter (struck-out words,
  things that remember, the dream-place).
- **In a fight:** body parts that break and grow back, phases, a stagger bar, swallowing and the Belly Hole, eating (food, its own
  dead, itself), arrivals in waves and warnings of them ahead (`warned_by_flag`, `warned_by_reading`), hazards (falling rocks,
  burning ground; a phase can start them), things on the board to Use (the carcass, the keg), talk (Intimidate, Persuade, Deceive
  with leverage), bribes, turning sides, packs, fears, commanders, summons, images.
- **A fight on the map's own ground** (caught on a stealth map, or started on the map) is fought on that map's tiles, and since
  today the party comes back where it stood when it ended, everybody walking over to the leader.

## 1. The run's through-line

### 1a. What the maps do to the last fight (my pick)

Each map has one or two things that, done or found, change Erysichthon's fight: the larder burnt or spoilt in map 2 (fewer
carcasses on his board, so fewer meals), a keeper's ledger read (his waves warned of a turn ahead: `warned_by_reading`, there
already), the keg found and wrapped in meat, Mestra freed (1c), the dryad's acorn found (4c). The last fight becomes the run's exam,
and a careful party can feel it paid off.

Needs: a spawn that is there only with a flag set, or only without it (`SpawnDefinition`), so a burnt larder takes carcasses off the
board. Small. The rest is there.

### 1b. A run that teaches

Fight 1 teaches the Gnawers (a pack that goes in together, afraid of fire); fight 2 teaches swallowing, on something smaller that
cannot kill anybody with it (3b); the last fight asks for both at once. There already, given the creatures.

### 1c. Mestra, his daughter

In the myth Erysichthon sold his daughter Mestra again and again to buy food, and each time she changed her shape and got away. She
could be the run's guide and riddle: in each map she is there in another shape (a mare in a stable, a gull on the granary roof, an
old woman in the market), says a little, and is gone. Recognised in all three (a clue each, and a deduction in the journal), she can
be talked out of the last fight with that as leverage (Persuade) and turn on him (turning sides), or just leave the field.

Small as conversations and clues; Medium if she is on the board, changing her shape between turns.

## 2. The three maps

### 2a. Map 1, the way in: where the food ran out

A quarter of the city gone hungry: empty stalls, a notice board of the missing with names struck out, Gnawers' tracks to a sewer
grate or a granary gate. Guards on shifts at the gate, to slip past at the change or fight. The first Mestra. A keeper's ledger
(the waves of 1a). Fight 1 at its end, at the grate.

### 2b. Map 2, the larder

A granary or a slaughterhouse, dark and close: Dim and Dark Areas and a lamp to carry, Cyrus's dark-only marks to a side room, the
keeper's traps, a ladder up to the lofts, a rest spot halfway. The larder itself, to burn or spoil (1a); the keg and the meat; the
second Mestra. Fight 2 at its end.

### 2c. Map 3, the grove under the city

The grove of the myth, felled: a ring of stumps round one great stump, roots through the walls, quiet. Things that remember (the
roots whisper what he did), the hours standing still as in the dream-place. The last Mestra, and the acorn (4c). His lair is at the
far end and is fought on this map's own ground, so the fight opens where they stand and, won, they walk out among the stumps.

## 3. Fights 1 and 2

### 3a. Fight 1: the pack

Gnawers in two waves, rung on by a Bellkeeper (a commander: those near it think a level higher, and nothing stuns or moves it). It
teaches that they go in together, that fire keeps them off (Prometheus, Enfina's fire paths), and that the bells must stop first.
There already, given the encounter.

### 3b. Fight 2: something that swallows

The larder's keeper: a bloated thing that swallows one of the party at a time, with its own Belly Hole to tear open and a stagger
that heaves them up, but too weak inside to do much harm. The party learns the rule on something that cannot kill with it. A new
creature from what is there (parts, swallowing, stagger). Medium, with its art.

### 3c. Or fight 2: Limos, Famine herself

In the myth Demeter sent Limos, Famine, to breathe the hunger into him. As fight 2: gaunt and slow, never hitting hard, but
everything near her starves: healing taken goes down (there already: `healing_taken_change`), the food in the party's bags spoils
(new), and she feeds the Gnawers back to full. Beaten, she is not in the last fight; sneaked past, she is there, feeding him. Medium.

## 4. Erysichthon, redesigned

Now: an undead wolf, Enormous, that catches a scent, grabs, swallows, eats carrion, its own dead and at the last itself; Jaws,
Belly Hole and Hind Legs, then a Second Head and Rib Maws; a stagger bar ("feed it what it should not eat"); three waves of Gnawers.
A great deal at once, and much of it hidden. Four directions, which mix:

### 4a. One rule: the Hunger (my pick)

A second bar under his health, Hunger, filling every round and with every blow he takes. Full, he must eat: the nearest thing he
can, a carcass, a Gnawer, one of the party (swallowed), or with nothing in reach, himself (a part torn off, his own health, and the
next phase). Fed, it empties, and he heals and swells (Gorged). Every turn is about it: feed him the keg (staggered), keep food from
him (burn the carcasses, fell the Gnawers before he reaches them), or starve him until he eats himself. The myth's end is the win:
the last phase is him devouring himself, a clock the party has only to live through and push along.

Needs: the Hunger bar (like the stagger bar), and eating when it is full (he eats already). Medium. Its strength: one bar the player
watches, and one question every round, "what will he eat next?"

### 4b. The king who became the beast

Closer to the myth: he starts as the king, Human-sized, at a table among the plates, and every meal makes him bigger (phases already
grow somebody), Large, then Enormous, and at the last the beast with the hole in its belly. Kept from food, he stays small. Needs:
phases that come on meals as well as on health (Small to Medium), and the artist's three sizes.

### 4c. The grove fights back

The dryad's curse, on his side and against him: the felled oak's stump in the middle; blight spreading from him each round, ground
that withers healing (hazards are there; spreading is new, Medium); and the acorn from map 3, planted (Use), a ring of the grove's
favour he cannot cross, or that hurts him. Ties the last map to the fight.

### 4d. The banquet

The board is his hall: from the kitchens, Gnawers carry him a dish each round, and every dish eaten heals and grows him. The party
cuts the line: fells the carriers, poisons the dishes (tainting, there already), tips the tables (Use), bars the kitchen doors.
Needs: carriers that fetch food to him (AI, Medium).

### My pick

4a as the core, with 4b's growing as its phases and 1a's carry-over (fewer carcasses after a burnt larder, Mestra freed, Limos
beaten or not). Keep swallowing and the Belly Hole, parts that grow back when he eats, and the keg. Simplify the scent (one more
hidden rule) and the waves (two, warned of by the ledger).

## 5. Smaller things for the run

- A codex page for each new creature, with Enfina's and Prometheus's lines for studying them (there already, empty).
- Music in layers for each stage (there already).
- The store at the start only; short rests between stages, as in the Dungeon Demo (there already).
- After the last fight, the walk out through the grove (since today).

## 6. Questions

1. What level, and who goes in? (The Dungeon Demo: Cyrus, Alithia and Prometheus at 14; Erysichthon in the story: 22.)
2. Erysichthon a beast, the undead wolf he is now, or the myth's king who becomes one (4b)?
3. Should what the party does in the maps change the last fight (1a)?
4. Short rests between stages, or full ones?
5. Does this run take the Dungeon Demo's place, or stand beside it?
