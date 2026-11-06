@tool
@icon("res://art/editor_icons/character.svg")
## Marked @tool so the encounter editor can ask a definition what it looks
## like. A resource whose script is not a tool script is a placeholder in the
## editor: its properties can be read but none of its methods exist, which is
## why spawn markers drew nothing the moment portraits started coming from a
## method rather than straight off a field.
extends Resource
class_name CombatantDefinition


@export var name = ""
## Who this is, for the glossary's Character intros. Freeform - write as much or
## as little as you like; a character with nothing written here simply says so.
##
## Kept next to everything else about them rather than in the glossary book, so
## there is one place a character is described.
@export_multiline var glossary_text: String = ""
## How they come into a fight late, or into a Boss Reveal (FightCards.entrance). Stored by
## number: append.
enum EntranceStyle { AUTOMATIC, BURSTS_FROM_GROUND, DROPS_IN, KICKS_DOOR }
@export var entrance_style: EntranceStyle = EntranceStyle.AUTOMATIC
## What they say as they fall, in any fight that has nothing of its own for them. Empty:
## nothing (EncounterDefinition.last_words).
@export_multiline var last_words: String = ""

@export_group("Class")
@export_enum("Melee", "Ranged", "Magic") var class_t = 0
@export_enum("Ground", "Flying", "Mounted") var class_m = 0
@export_group("Stats")
## Health at level 1.
@export_range(1, 2, 1, "or_greater") var max_hp = 1
## Health at the top level, 64 (Stats.MAX_LEVEL) - the name is from when that
## was 20. Every level between climbs the same step from Max Hp to
## this (see hp_at). Zero means the same as level 1 all the way up, so a
## character only ever fought at one strength needs nothing here.
##
## Separate from the attribute curve on purpose: attributes are worked out from
## the level by formula, because they are how developed someone is. How much
## punishment a character can take is a design decision per character - a mage
## who never gets sturdier and a knight who doubles are both reasonable, and
## neither falls out of a formula.
@export_range(0, 2, 1, "or_greater") var max_hp_level_20 = 0
## How much incoming damage they soak at level 1: damage is multiplied by
## 40/(40 + this). Used wherever nobody has said otherwise - a spawn whose own
## Defense is left at 0, a guard caught on a stealth map, a summon, somebody
## coming back. docs/enemy_progression.csv gives the ranges by tier: frail, average
## and tanky enemies.
@export_range(0, 100) var defense: int = 10
## The same at level 64, climbing evenly from Defense the way health climbs
## (see defense_at). Zero means the same as level 1 all the way up.
@export_range(0, 100) var defense_level_64: int = 0
## Defense in steps instead, level -> Defense from that level on: the party's
## armour bands from docs/player_hp_defense_progression.csv ({1: 12, 8: 20,
## 17: 28}). Filled in, it stands in for the two above.
@export var defense_by_level: Dictionary = {}
## How big they are - see Sizes. A Human is one tile; Tiny and Small share a
## tile with their own side; Large and up cover 2 x 2 tiles and more.
@export var size: Sizes.Size = Sizes.Size.HUMAN
## For a Gigantic one: how many tiles a side it covers, 16 or more.
@export_range(16, 64) var gigantic_span: int = 16
@export_range(1, 3, 1, "or_greater") var movement = 3
@export_range(1, 2, 1, "or_greater") var initiative = 1

@export_subgroup("Attributes")
## The two attributes this character is built around. A combatant's level
## decides the numbers - main stat 10 at level 1 climbing to 85 at level 64, secondary
## half that, everything else a flat 10 - so all that is set here is which two
## they are. See Stats.stats_for_level.
##
## Per character, not per AI archetype: two enemies driven by the same AI can
## be built around completely different attributes.
##
## Defense and weapon base are deliberately not here. Both are set per spawn in
## the encounter editor, so the same character can be tougher or better armed
## in one fight than another.
@export var main_stat: Stats.Type = Stats.Type.PHYSICAL
@export var secondary_stat: Stats.Type = Stats.Type.MINDFULNESS
## What every spell of theirs is worked out from - its damage, its heals, its
## side of a contest - whichever spell it is (Combat.scaling_stat_of). A spell
## names no stat of its own; a skill that costs no gate still does. Prometheus's
## is Intellect, Alithia's Mindfulness.
@export var spellcasting_stat: Stats.Type = Stats.Type.INTELLECT
## A half caster: if they cast at all, the gates of a full caster at half their
## level, rounded up (Stats.half_caster_gates) - like a D&D paladin, fewer
## castings and every gate opening later. Off: a full caster's, at their level;
## somebody with no spell has none either way. The Ranger (the designer,
## 2026-10-25).
@export var half_caster: bool = false

## Gates are not set here. How many castings someone has is decided by how far
## along they are - see Stats.GATES_BY_LEVEL - and they only have any at all if
## they carry a spell to cast. A spell can be cast through a higher gate than it
## asks for but never a lower one, and combat spends the cheapest that will do.
@export_group("Visual")
@export var icon: Texture2D
## Used only if sprite_frames below is empty - a single static image on the
## map, exactly how every combatant works today.
@export var map_sprite: Texture2D
## Optional. Set this to animate this combatant on the map instead of using
## a static image - see CombatantSprite.gd for the animation names it looks
## for ("idle", "walk", "skill", "dead") and how to build one. Leave empty
## to keep using map_sprite as a plain static sprite.
@export var sprite_frames: SpriteFrames
## Tints their sprite on the map - white is as drawn. For a creature borrowing
## somebody else's art until it has its own.
@export var tint: Color = Color.WHITE
@export_group("Skills")
@export var skills: Array[String]
## Skills this combatant can additionally use in their secondary slot, on top
## of everything already marked is_secondary. This is the per-character
## exception: Run is a main skill for everyone, but listing it here for Cyrus
## lets him also use it as a secondary - so he can Run twice in one turn.
## A skill listed here doesn't have to leave the main panel; it can appear in
## both.
##
## Prefer a passive for this (PassiveDefinition.secondary_skills): it does the
## same and the character sheet shows it under Passive Skills, where this list
## is shown nowhere. Cyrus's Light Footed is one.
@export var secondary_skills: Array[String]
## Skill key -> the level this one uses it from, in place of the skill's own
## Required Level - an enemy with one of the party's moves, which the party
## grows into later (Sweep Strike, from 54) but this one has from 3.
@export var skill_levels: Dictionary = {}
## What they do without being asked - working all the time, or once their
## moment comes. Never on the action panel; the character sheet lists them
## under Passive Skills. See PassiveDefinition.
@export var passives: Array[PassiveDefinition] = []
## The paths they can choose between at level 5, by key, in the order the
## choice offers them. See SubclassDefinition.
@export var subclasses: Array[String] = []
## Learns their spells rather than growing into them (Campaign "Spellbooks"):
## of the spells in Skills and their path's, they know only Starting Spells and
## those learned since - from a spellbook, or a Gate Nade taken apart. Prometheus.
@export var learns_spells: bool = false
## The spells they know from the start, by key, when they learn their spells.
@export var starting_spells: Array[String] = []
## How many things they can carry into a fight to use: an enemy's pocket. The
## party's is their bag's first slots (Campaign.COMBAT_SLOTS) whatever this says.
@export_range(1, 24, 1) var pocket_size: int = 4
@export_group("Resistances")
## How this combatant stands up to each kind of damage, as a percentage.
## Positive resists - 20 means a fifth of that damage is shrugged off, 100
## means immune. Negative is a vulnerability - -20 means a fifth extra gets
## through. Zero is normal.
##
## Per character, not per AI archetype: two combatants running the same AI can
## have completely different resistances, and changing one never affects how
## they behave.
@export_range(-100, 100, 1, "or_greater", "or_less") var resist_physical: int = 0
@export_range(-100, 100, 1, "or_greater", "or_less") var resist_fire: int = 0
@export_range(-100, 100, 1, "or_greater", "or_less") var resist_water: int = 0
@export_range(-100, 100, 1, "or_greater", "or_less") var resist_wind: int = 0
@export_range(-100, 100, 1, "or_greater", "or_less") var resist_earth: int = 0
@export_range(-100, 100, 1, "or_greater", "or_less") var resist_poison: int = 0
@export_range(-100, 100, 1, "or_greater", "or_less") var resist_psychic: int = 0
## The upgraded elements. An upgraded type is its own element, not a stronger
## version of the one it came from, so resisting Fire does nothing against
## Plasma unless this says so too.
@export_range(-100, 100, 1, "or_greater", "or_less") var resist_plasma: int = 0
@export_range(-100, 100, 1, "or_greater", "or_less") var resist_ice: int = 0
@export_range(-100, 100, 1, "or_greater", "or_less") var resist_lightning: int = 0
@export_range(-100, 100, 1, "or_greater", "or_less") var resist_metal: int = 0
@export_range(-100, 100, 1, "or_greater", "or_less") var resist_acid: int = 0
@export_range(-100, 100, 1, "or_greater", "or_less") var resist_idol: int = 0

@export_group("Immunities")
## Conditions that never take hold on them - a golem that cannot be poisoned, a
## boss nobody can stun. Drag the condition's file in from data/conditions/. (To
## be immune to a kind of damage, set its resistance above to 100.)
@export var immune_to_conditions: Array[ConditionDefinition] = []
## The other things that cannot be done to them (Immunity).
@export var immune_to: Array[Immunity.Kind] = []
## Nothing touches them: every attack misses, nothing hurts them, nothing takes
## hold of them - though they stand where they stand like anybody, and the
## other side soon stops wasting blows on them. Prometheus's Illusory Dragon.
@export var untouchable: bool = false

@export_group("Summons")
## Who they bring into every fight with them, by key: a summon of theirs, beside
## them from the start, on their turn rather than its own (Combat "Summons").
## The Summoner's Bound Beast.
@export var summon_at_start: String = ""

@export_group("Turns")
## Turns they get each round, spread through it. A boss facing a whole party
## usually wants more than one.
@export_range(1, 4, 1, "or_greater") var turns_per_round: int = 1

@export_group("Boss")
## Makes them a boss, whatever their size: their name across the screen as they
## appear, their own health bar along the top, phases and a stagger bar.
@export var boss: BossDefinition

@export_group("Nerve")
## How much it takes to break them (Combat "Nerve"): what shakes them - their
## leader falling, half their side down, being badly hurt, being alone, being
## afraid, being intimidated - is added up at the start of their turns, and at
## this much or more they break. Immune to Breaking (above) never breaks.
@export_range(0, 300, 1) var nerve: int = 60
## Broken, they run for it - and are gone after a couple of turns - or throw
## down their weapons and are taken.
@export_enum("Flees", "Surrenders") var when_broken: int = 0
## Their side's leader: when they fall, the rest of their side lose heart.
@export var leads: bool = false
## Fled and got away (Combat "Getting away"), what comes of it: nothing more,
## they are gone; they come back (with whoever Brings Back names) Back After
## Rounds later, where they left; or the fight is lost - the messenger who must
## not reach the gate.
@export_enum("Gone", "Comes back", "Fight lost") var when_fled: int = 0
@export_range(1, 10, 1) var back_after_rounds: int = 2
## Coming back: who comes with them, by combatant key.
@export var brings_back: Array[String] = []
## Set when they get away, for a conversation afterwards to know.
@export var fled_flag: String = ""

@export_group("Dealing with them")
## Gold that buys them out of a fight (Bribe, or a parley before it): a
## mercenary's price. 0 for somebody who cannot be bought.
@export_range(0, 9999, 1) var bribe_price: int = 0
## Clues (by key) that give the party something on them - what Intimidate,
## Persuade and Deceive need. Knowing their faction (FactionDefinition, through a
## clue) does as well.
@export var leverage_clues: Array[String] = []
## Taken alive (surrendered or knocked out), what questioning them gives up:
## clues by key...
@export var interrogation_clues: Array[String] = []
## ...gold, from where they stashed their pay...
@export_range(0, 9999, 1) var interrogation_gold: int = 0
## ...and, optionally, a conversation of their own, played instead of the
## plain questioning.
@export var interrogation_dialogue: Resource
@export var interrogation_title: String = "start"

@export_group("Bound")
## Who they are bound to - "the sorcerer", "its master" - for a creature held
## by a binding. Prometheus can hack a bound creature's binding with Rebind
## Hack below, and it fights for the party. Empty: not bound.
@export var bound_to: String = ""
## The binding's sheet: a Rewrite the Rule whose last line is who it answers to.
@export var rebind_hack: HackDefinition
## Turns of its own it fights for the party, rebound. 0 for the rest of the fight.
@export_range(0, 20, 1) var rebind_turns: int = 0

@export_group("Body parts")
## Places on them that can be aimed at and broken (BodyPartDefinition) - legs,
## arms, an armour plate. For somebody bigger than a tile.
@export var parts: Array[BodyPartDefinition] = []

@export_group("Holding and eating")
## How many they can keep hold of at once (Grab): a second one grabbed past
## this, the first held is let go. A creature with two heads holds two.
@export_range(1, 4, 1) var holds_at_once: int = 1
## What they eat (Combat "Gluttony"), free, as their turn begins and once they
## have moved: food on the map (BattleObjectDefinition's Edible), the bodies of
## their own side, the bodies of the other side. A body eaten is gone - nobody
## stands it back up.
@export_flags("Food On The Map", "Its Own Fallen", "The Other Side's Fallen") var eats: int = 0
## How near something has to be for them to eat it: tiles between them.
@export_range(1, 4, 1) var eat_reach: int = 1
## What a meal heals them by, as a share of their health - nourishing food or a
## body. Bait (food that is not Nourishing) heals nothing.
@export_range(0.0, 1.0, 0.01) var meal_heals: float = 0.0
## What every meal does to them besides - a hunger fed: stronger, quicker.
## Effects on themselves, as a skill's are.
@export var fed_effects: Array[EffectDefinition] = []
## What being spat out alive leaves on whoever they swallowed (EffectType.SWALLOW):
## covered in bile, say. Empty: nothing.
@export var spat_out_with: ConditionDefinition

@export_group("Party")
## Whether this one actually fights. Turn it off for someone who travels with
## the party but takes no part in battles - a guide, a prisoner, a child - and
## they'll walk in the line on the map and appear in the portrait column, but
## be left out when an encounter deploys the party.
@export var can_fight: bool = true
## Whether they keep the enemy codex: every enemy they study - with Study, or
## any other way - gets its page written (Campaign "The enemy codex"). Enfina
## and Prometheus do.
@export var keeps_codex: bool = false
## Whether any damaging move of theirs knocks down a breakable wall
## (BreakableWall), on a map or in a fight. Anybody's damaging spell or item
## does; only the strong break one with a blade or a fist. Enfina does.
@export var breaks_walls: bool = false
## Can go to stealth mode on a watched map: creeping (Ctrl), they walk unnoticed
## by anybody who cannot see them (StealthWatch.stealthing). Anybody else walking
## near a guard is noticed, walls or no walls - Cyrus alone has this.
@export var stealths: bool = false
## No disguise fools them in a fight (Combat "Disguises"): a nose, say. Whoever wears one is in plain
## sight to them.
@export var sees_through_disguises: bool = false
## What they say when the party changes a turn they foresaw (Intuition) - one
## of these, at random, over their head and in the log. Empty says nothing.
@export var future_changed_lines: Array[String] = []

## Whether consumables that would normally cost the main action can be used as
## a secondary one instead. Cyrus can: quick hands are his, and it is why he
## can drink a potion and still swing in the same turn.
## Prefer a passive for this (PassiveDefinition.items_as_secondary), which the
## sheet shows; Cyrus's Quick Hands is one.
@export var items_as_secondary: bool = false

## The kit this character is written as carrying: what an encounter's spawn
## list is seeded from when you want them to turn up equipped.
##
## Nothing is handed out from here automatically. A bag is filled by something
## that happens in the game - an encounter's spawn saying what its fighter
## brings, or a dialogue giving somebody something - so walking onto a map
## starts everyone empty-handed.
@export var starting_items: Array[String] = []
@export_group("Faction")
## The side they belong to, by key (FactionDefinition) - empty for nobody's.
## Learning about it (ClueDefinition.reveals_factions) opens their sheet in every
## fight and has the party hit them harder.
@export var faction: String = ""

@export_group("AI (enemies only - ignored for player-controlled units)")
## Lies down as its turn ends when nobody could reach it in melee next turn, and
## stays down while it has somebody to hit from there (Combat "Prone"). Off, it only
## gets up from wherever something else put it down.
@export var goes_prone: bool = false
## Which Combat.gd function drives this enemy's turn. Built-in options:
## "ai_melee_rush" (default - rushes the nearest enemy and melees it),
## "ai_hit_and_explode", "ai_ranger", "ai_healer", "ai_caster",
## "ai_copycat". To add your own, write a new "func ai_my_type(comb:
## Dictionary):" in Combat.gd (following the pattern of the existing ones -
## it ends by either using a skill or calling advance_turn() itself) and
## type its name here. An unrecognised name falls back to ai_melee_rush.
@export var ai_function: String = "ai_melee_rush"

## When the AI readies a move ("Ready" - Combat "Readying, for the AI"), if at
## all: only with nothing it could hit this turn, and never with its last
## casting of a gate.
##   Covers The Approach - something ranged watching a cone down the way the
##     party comes (nobody in it yet), so walking up to it costs them; else
##     its reach.
##   Guards Its Post - stays put rather than chase: a cone over the thing on
##     the map beside it (a bell) or the tile it started on, or its own reach.
##   Counters Casters - with somebody who casts in sight and in reach: ready for
##     when they do.
##   Waits For The Hidden - with somebody of the party out of sight: ready for
##     whoever steps into its reach.
##   Protects Its Own - the ally of its in sight most at risk watched: whoever
##     hits them is hit back (appended; the designer's "smarter readies",
##     2026-10-29 - PROPOSAL).
@export_flags("Covers The Approach", "Guards Its Post", "Counters Casters", "Waits For The Hidden", "Protects Its Own") var ai_readies: int = 0

@export_group("Giving Light")
## Gives off light by being what it is, this many tiles of it (Bright for half), real or an illusion:
## a burning thing, an illusion of one (Light). 0: none.
@export_range(0.0, 12.0, 0.5, "suffix:tiles") var light_tiles: float = 0.0
@export var light_colour: Color = Color(1.0, 0.74, 0.42)

@export_group("AI Mind")
## How much this creature thinks (Combat "The AI's mind"). Instinct goes for whoever is nearest, weighs
## no kills and knows nothing below. Trained is the ordinary soldier. Cunning and Mastermind know
## more. All Knowing knows the party's kits as well: what each could do next turn, who has what
## reaction ready, which spells are prepared and what castings are left. Stored by number: append.
enum AiSmarts { INSTINCT, TRAINED, CUNNING, MASTERMIND, ALL_KNOWING }
@export var ai_smarts: AiSmarts = AiSmarts.TRAINED
## What it might know, on top of what its Smarts already give (Also Knows) or taken away from it
## (Never Knows). Stored by number: append.
enum AiKnows { GROUND = 1, TELEGRAPHS = 2, KEEPS_FROM_HAZARDS = 4, SETS_OFF_HAZARDS = 8, SHOVES = 16, TETHERS = 32, WAKES_ALLIES = 64,
	AVOIDS_REACH = 128, SPREADS_OUT = 256, SET_UPS = 512, HEMS = 1024, BLOCKS = 2048, TRIAGE = 4096, GATES = 8192, DARK = 16384, FALLS_BACK = 32768, KITS = 65536 }
@export_flags("Knows The Ground", "Steps Off Telegraphs", "Keeps From Hazards", "Sets Off Hazards", "Uses Shoves", "Goes For Tether Holders", "Wakes Allies", "Avoids The Party's Reach", "Spreads Out", "Sets Things Up", "Hems In", "Blocks The Way", "Triage", "Saves Its Gates", "Searches The Dark", "Falls Back", "Knows The Party's Kits") var ai_also_knows: int = 0
@export_flags("Knows The Ground", "Steps Off Telegraphs", "Keeps From Hazards", "Sets Off Hazards", "Uses Shoves", "Goes For Tether Holders", "Wakes Allies", "Avoids The Party's Reach", "Spreads Out", "Sets Things Up", "Hems In", "Blocks The Way", "Triage", "Saves Its Gates", "Searches The Dark", "Falls Back", "Knows The Party's Kits") var ai_never_knows: int = 0
## How much a blow is worth to it: above 1 it trades safety for blood, below 1 it would rather live.
@export_range(0.0, 3.0, 0.05) var ai_aggression: float = 1.0
## How much it minds bad ground, a hazard, the party's reach and standing bunched up.
@export_range(0.0, 3.0, 0.05) var ai_caution: float = 1.0
## How hard it is drawn to whoever is already hurt, and whoever its side last went for.
@export_range(0.0, 3.0, 0.05) var ai_focus: float = 1.0
## How soon it drinks what it carries, and falls back to a healer.
@export_range(0.0, 3.0, 0.05) var ai_self_preservation: float = 1.0
@export_subgroup("Ways Of Its Own")
## Those of its side within this many tiles think a level higher while it stands and is awake, up to
## Mastermind. Bring it down and they think for themselves again. 0: it commands nobody.
@export_range(0, 30, 1, "suffix:tiles") var ai_commands_tiles: int = 0
## How hard it goes for whoever last hurt it. 0: it holds no grudge.
@export_range(0.0, 3.0, 0.05) var ai_grudge: float = 0.0
## Picks somebody out at its first turn, and goes for nobody else until they fall or it loses sight of them.
@export var ai_hunter: bool = false
## A combatant key, for one in the same fight: it keeps within Guards Within of them, and steps in
## front of a blow at one of them, with its reaction.
@export var ai_guards: String = ""
@export_range(1, 12, 1, "suffix:tiles") var ai_guards_within: int = 3
## Holds back until this many of those with a pack of their own, itself among them, can reach the same
## target. 0: no pack.
@export_range(0, 6) var ai_pack: int = 0
## Elements it will not walk on or beside: ground that burns, somebody burning, a flame on the map.
@export var ai_fears: Array[Damage.Type] = []
## Once an image has shattered in front of it, its whole side stops being fooled by illusions.
@export var ai_learns: bool = false
## Goes for whoever carries the most, and once it has stolen something, leaves with it. It needs a
## Steal in its skills to do the second.
@export var ai_greedy: bool = false



## Health at `level`: Max Hp at level 1, Max Hp Level 20 at the top level, and the
## same step every level between, rounded.
func hp_at(level: int) -> int:
	if max_hp_level_20 <= 0:
		return max_hp
	return roundi(lerpf(max_hp, max_hp_level_20, Stats.level_progress(level)))


## Their own Defense at `level`: the step it has reached (Defense By Level), or
## Defense at 1 climbing to Defense Level 64 at the top.
func defense_at(level: int) -> int:
	if not defense_by_level.is_empty():
		var reached := -1
		var value := defense
		for from in defense_by_level:
			if int(from) <= level and int(from) > reached:
				reached = int(from)
				value = int(defense_by_level[from])
		return value
	if defense_level_64 <= 0:
		return defense
	return roundi(lerpf(defense, defense_level_64, Stats.level_progress(level)))


## What this combatant may cast at `level`: their level's allowance if they have
## a spell at all, and nothing if they have not. A swordsman does not walk
## around with two unused castings of a gate he cannot open.
func gates_at(level: int) -> Array:
	if not casts_spells():
		return Stats.no_gates()
	return Stats.half_caster_gates(level) if half_caster else Stats.gates_for_level(level)


## Whether anything they know is cast through a gate.
func casts_spells() -> bool:
	# SkillDatabase is an autoload, so it is not there while the editor is just
	# laying a map out. Nothing casts anything in the editor either.
	if Engine.is_editor_hint():
		return false
	for key in skills + secondary_skills:
		var skill: SkillDefinition = SkillDatabase.skills.get(key)
		if skill != null and skill.spell_slot_level > 0:
			return true
	return false


## The resistances above, keyed by Damage.Type, so combat can look one up by
## the type of damage being dealt rather than knowing the field names. Copied
## onto each combatant when they're created.
func resistance_table() -> Dictionary:
	return {
		Damage.Type.PHYSICAL: resist_physical,
		Damage.Type.FIRE: resist_fire,
		Damage.Type.WATER: resist_water,
		Damage.Type.WIND: resist_wind,
		Damage.Type.EARTH: resist_earth,
		Damage.Type.POISON: resist_poison,
		Damage.Type.PSYCHIC: resist_psychic,
		Damage.Type.PLASMA: resist_plasma,
		Damage.Type.ICE: resist_ice,
		Damage.Type.LIGHTNING: resist_lightning,
		Damage.Type.METAL: resist_metal,
		Damage.Type.ACID: resist_acid,
		Damage.Type.IDOL: resist_idol,
	}


## --- What this combatant looks like ---
##
## Icon and MapSprite are optional. Left empty they are taken from the first
## frame of the animation set, so a character with art never wears somebody
## else's face for want of a second field kept in step with the first - which is
## exactly what happened when the enemies were given their own animations and
## their portraits stayed pointing at Cyrus.


## The still that stands for them in the turn queue, the party panel and the
## battle selector.
func portrait() -> Texture2D:
	return icon if icon != null else first_frame()


## The still used on the map for anyone with no animation set at all.
func map_still() -> Texture2D:
	return map_sprite if map_sprite != null else first_frame()


## The first frame of their idle, or of whatever animation they do have. Null
## for a combatant with no animation set, which is what an empty portrait means.
func first_frame() -> Texture2D:
	if sprite_frames == null:
		return null
	var names = sprite_frames.get_animation_names()
	var wanted = "idle" if sprite_frames.has_animation("idle") else (names[0] if names.size() > 0 else "")
	if wanted == "" or sprite_frames.get_frame_count(wanted) == 0:
		return null
	return sprite_frames.get_frame_texture(wanted, 0)


## Faction as a dropdown of the factions there are, blank first for none.
func _validate_property(property: Dictionary):
	if property.name == "faction" and Engine.is_editor_hint():
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = "," + ",".join(FactionDefinition.all().keys())
