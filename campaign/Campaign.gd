extends Node
## Autoload. The state that outlives a single battle: which encounter is being
## fought, and what condition the player's party is in.
##
## The party carries damage forward between encounters, so a battle won at
## great cost leaves you weaker for the next one. Nothing here is saved to
## disk - it lasts for the session, and "Reset Party" on the level select
## wipes it back to full strength.


## The title screen, which is where the game starts and where to_main_menu()
## sends it back to.
const MAIN_MENU := "res://scenes/main_menu.tscn"

## Set by the level select immediately before it loads scenes/game.tscn.
## GameScene reads it on entering the tree; if it is null (running game.tscn
## directly from the editor) GameScene falls back to its own exported default,
## so a battle scene is still playable on its own.
var current_encounter: EncounterDefinition = null

## combatant_key -> {"hp": int, "alive": bool}. Only player-side combatants
## are recorded. A key that isn't in here has never fought and starts fresh.
var party_state := {}

## --- The party ---
##
## Who is travelling, in marching order: the first entry leads and is the one
## you steer, the rest follow. Keys index CombatantDatabase, the same way
## encounter spawns do.
##
## Seeded from the Starting Party list on scenes/exploration.tscn the first
## time an exploration map loads, so adding a teammate is an inspector edit
## rather than a code change. Add them to CombatantDatabase first.
var party_order: Array[String] = []

## How far along the party is while walking a map, 1 to 3. Set by the map's
## MapSetup; decides the health they carry and what the character sheet
## shows them as. Encounter spawns carry their own levels, so this does not
## decide what they fight at.
var party_level: int = 1


## Puts a named party on the map, replacing whoever was travelling.
##
## Unlike seed_party this is authoritative: a map that declares its own cast is
## stating a fact about that part of the story, not offering a default. Walking
## into such a map through a door therefore changes who you are steering, which
## is the point - the church is Alithia alone whichever way you arrive at it.
func set_party(keys: Array, level: int = 1):
	party_order.clear()
	for key in keys:
		if not CombatantDatabase.combatants.has(key):
			push_warning("A map's party lists '%s', which isn't in CombatantDatabase - skipping it." % key)
			continue
		if not party_order.has(key):
			party_order.append(key)
	# The map's level is the least the party is by now, never a step back: the
	# levels are earned at milestones (reach_level), and walking onto a map
	# written for an earlier point must not take them away again. Raised, it is
	# a milestone like any other - health grows, a subclass may be due - only
	# not said in the log: arriving somewhere is not news.
	if not reach_level(level, true):
		party_changed.emit()


## --- Milestones ---
##
## The party levels up at points in the story rather than through experience:
## a conversation saying so (`do Campaign.reach_level(5)`), or a fight whose
## EncounterDefinition.party_reaches_level is set being won.

## The party's level went up. Carries the new one.
signal party_leveled(level: int)

## Takes the party to `level`, if they are not there already - a milestone
## reached a second time, or one behind them, does nothing. Everyone's health
## grows by as much as their new level adds, so a wounded party stays as
## wounded as it was rather than healing or falling further behind.
func reach_level(level: int, quietly: bool = false) -> bool:
	level = clampi(level, 1, Stats.MAX_LEVEL)
	if level <= party_level:
		return false
	var before := party_level
	party_level = level
	for key in party_state:
		var definition: CombatantDefinition = CombatantDatabase.combatants.get(key)
		if definition == null:
			continue
		var stored: Dictionary = party_state[key]
		var frailty: float = stored.get("frailty", 1.0)
		var gained := Combat.weakened_figure(definition.hp_at(level), frailty) \
			- Combat.weakened_figure(definition.hp_at(before), frailty)
		stored["max_hp"] = stored.get("max_hp", definition.hp_at(before)) + gained
		if stored.get("alive", true):
			stored["hp"] = stored.get("hp", 0) + gained
	if not quietly:
		announce("[color=lightgreen]The party reaches level %d.[/color]\n" % level)
	party_leveled.emit(level)
	party_changed.emit()
	return true


## --- Chapters ---
##
## The story is five chapters, each leveling slower than the one before: the
## party reaches level 18 by the end of Chapter I, 33 by II, 45 by III, 55 -
## ΛΗΘΗ, the forgetting - by IV, and 64 - ΑΛΗΘΕΙΑ, the truth - by the end of V
## (CHAPTER_LEVELS). A dialogue starts the next (`do Campaign.begin_chapter(2)`).
## The character sheet's Levels page shows nothing past 55 until Chapter V has
## begun, and the first time it is opened after, it lifts the veil from the rest
## (levels_unveiled).

## The level each chapter ends at, I to V. The first starts at 1, each other one
## where the last ended.
const CHAPTER_LEVELS := [18, 33, 45, 55, 64]
const CHAPTER_NAMES := ["I", "II", "III", "IV", "V"]
## The levels named on the Levels page, in Greek by the sum of their letters:
## 55 is ΛΗΘΗ (forgetting), 64 ΑΛΗΘΕΙΑ (truth, unforgetting).
const LETHE_LEVEL := 55
const ALETHEIA_LEVEL := 64

## A chapter began. Carries which.
signal chapter_begun(which: int)

## The chapter the story is in, 1 to 5.
var chapter: int = 1
## Whether the Levels page has shown the levels past ΛΗΘΗ being uncovered - the
## first time it is opened in Chapter V.
var levels_unveiled := false


## Starts chapter `which`, 1 to 5. Written for a dialogue:
##
##     do Campaign.begin_chapter(5)
func begin_chapter(which: int):
	which = clampi(which, 1, CHAPTER_LEVELS.size())
	if which == chapter:
		return
	chapter = which
	announce("[color=lightgreen]Chapter %s begins.[/color]\n" % CHAPTER_NAMES[which - 1])
	chapter_begun.emit(which)


## The highest level the Levels page shows: up to ΛΗΘΗ until Chapter V, then all.
func levels_in_view() -> int:
	return Stats.MAX_LEVEL if chapter >= CHAPTER_LEVELS.size() else LETHE_LEVEL


## The chapter `level` is reached in: 1 for 1 to 18, 2 for 19 to 33, and so on.
static func chapter_of_level(level: int) -> int:
	for i in CHAPTER_LEVELS.size():
		if level <= CHAPTER_LEVELS[i]:
			return i + 1
	return CHAPTER_LEVELS.size()


## --- Spellbooks ---
##
## Somebody who Learns Spells (CombatantDefinition.learns_spells - Prometheus)
## does not know a spell of theirs by reaching its level, as Alithia does. They
## know their Starting Spells, and every other spell of theirs once they have
## learned it - from a spellbook (ItemDefinition.teaches) or by taking a Gate
## Nade of it apart (GateNadeDefinition.spell), either of them used up. Only a
## spell that is theirs can be learned at all: in their own Skills, or the
## path's they took - no book teaches Prometheus Communion. Learned is
## learned for good; a spell still needs its level, as anybody's does.
## In a fight walked into from a map they have only what they have learned
## (Combat._deploy_party); a fight opened from Arena Mode knows everything.

## combatant key -> every spell they have learned, by key.
var learned_spells := {}

## Somebody learned a spell. Carries who, and which.
signal spell_learned(key: String, spell: String)


## Whether `key` learns their spells rather than growing into them.
func learns_spells(key: String) -> bool:
	var definition: CombatantDefinition = CombatantDatabase.combatants.get(key)
	return definition != null and definition.learns_spells


## Every spell `key` could ever know: in their own Skills, or their path's.
func learnable_spells(key: String) -> Array:
	var definition: CombatantDefinition = CombatantDatabase.combatants.get(key)
	if definition == null:
		return []
	var keys: Array = Array(definition.skills)
	var path := SubclassDefinition.named(subclass_of(key))
	if path != null:
		for skill_key in path.skills:
			if not keys.has(skill_key):
				keys.append(skill_key)
	return keys.filter(func(skill_key): return Combat.is_spell(SkillDatabase.skills.get(skill_key)))


## Whether `key` knows `spell`: always, for somebody who does not learn spells;
## their Starting Spells and what they have learned, for somebody who does.
func knows_spell(key: String, spell: String) -> bool:
	if not learns_spells(key):
		return true
	# A dungeon can hand them the lot (DungeonDefinition.knows_every_spell).
	if dungeon != null and dungeon.knows_every_spell:
		return true
	var definition: CombatantDefinition = CombatantDatabase.combatants.get(key)
	return definition.starting_spells.has(spell) or learned_spells.get(key, []).has(spell)


## Why `key` cannot learn `spell` now, or "" when they can.
func cannot_learn(key: String, spell: String) -> String:
	var skill: SkillDefinition = SkillDatabase.skills.get(spell)
	var who := display_name_of(key)
	if skill == null:
		return "There is no such spell"
	if not learns_spells(key):
		return "%s learns spells by growing into them, not from books" % who
	if not learnable_spells(key).has(spell):
		return "%s is not a spell %s can learn" % [skill.name, who]
	if knows_spell(key, spell):
		return "%s already knows %s" % [who, skill.name]
	return ""


## The spell `item` teaches, by key - a spellbook's, or a Gate Nade's own - or "".
static func spell_taught_by(item: ItemDefinition) -> String:
	if item == null:
		return ""
	if item.teaches != "":
		return item.teaches
	if item is GateNadeDefinition:
		return item.spell
	return ""


## Everything in the party's bags that would teach `spell`, spellbooks before
## Gate Nades: [{"holder": combatant key, "item": item key}].
func teachers_of(spell: String) -> Array:
	var books := []
	var nades := []
	for holder in party_order:
		for item_key in inventory_of(holder):
			var item: ItemDefinition = ItemDatabase.item(item_key) if item_key != "" else null
			if spell_taught_by(item) != spell:
				continue
			(nades if item is GateNadeDefinition else books).append({"holder": holder, "item": item_key})
	return books + nades


## `key` learns `spell` from the first thing in the party's bags that teaches it,
## which is used up. "" when they have learned it, or why not.
func learn_spell(key: String, spell: String) -> String:
	var why := cannot_learn(key, spell)
	if why != "":
		return why
	var teachers := teachers_of(spell)
	if teachers.is_empty():
		return "Nothing in the party's bags teaches %s" % SkillDatabase.skills[spell].name
	take_item(teachers[0].holder, teachers[0].item)
	learn(key, spell)
	return ""


## `key` knows `spell` from now on, whatever taught it - for the story's own
## teaching too: `do Campaign.learn("prometheus", "fireball")`.
func learn(key: String, spell: String):
	if not learned_spells.has(key):
		learned_spells[key] = []
	if learned_spells[key].has(spell):
		return
	learned_spells[key].append(spell)
	var skill: SkillDefinition = SkillDatabase.skills.get(spell)
	announce("[color=lightgreen]%s learns %s.[/color]\n" % [display_name_of(key), skill.name if skill != null else spell])
	spell_learned.emit(key, spell)


## `comb`'s skill list, played as `key`, without the spells they have not learned.
func forget_unlearned(comb: Dictionary, key: String):
	if not learns_spells(key):
		return
	comb.skill_list = comb.skill_list.filter(func(skill_key):
		return not Combat.is_spell(SkillDatabase.skills.get(skill_key)) or knows_spell(key, skill_key))


## --- Paths ---
##
## At level 24 (Stats.SUBCLASS_LEVEL) each of the party chooses one of their
## paths - SubclassDefinition, three each. Combat puts them on it
## (Combat.take_path); the map asks for the choice (SubclassPicker). Chosen, a
## path can be changed only at a long rest: from one until the party next fights
## (path_change_open), from the character sheet (the designer, 2026-10-25).

## combatant key -> the key of the path they chose.
var subclasses: Dictionary = {}

## Whether paths can be changed now: a long rest has been taken and the party
## has not fought since (Combat._deploy_party closes it).
var path_change_open := false

## Whether a party at level 24 or past it is asked on the map to choose paths at
## all. On in the game. The test harness turns it off (game/asks_for_paths in
## its copy's project settings) so suites about other things are not stopped by
## the choice; the suites about paths turn it back on.
var asks_for_paths: bool = ProjectSettings.get_setting("game/asks_for_paths", true)

## Somebody chose their path.
signal subclass_chosen(key: String, subclass: String)


## The paths as they were before they were remade (2026-10-23), and what each
## became - a save from before keeps its choice. The Carer has no successor, so
## its choice is open again.
const OLD_PATHS := {
	"berserker": "vanguard", "controller": "juggernaut", "guardian": "warden_of_cover",
	"swashbuckler": "skirmisher", "gunner": "saboteur", "bombardier": "trapper",
	"spellsword": "elemental_vanguard", "abjurer": "elemental_tactician", "demolitionist": "elemental_conductor",
	"punisher": "battle_chaplain", "illusionist": "illusory_shepherd", "carer": "",
}


## A save's paths under their names now (OLD_PATHS).
func _carry_old_paths():
	for key in subclasses.keys():
		var path: String = subclasses[key]
		if OLD_PATHS.has(path):
			if OLD_PATHS[path] == "":
				subclasses.erase(key)
			else:
				subclasses[key] = OLD_PATHS[path]


## The path `key` is on, or "".
func subclass_of(key: String) -> String:
	return subclasses.get(key, "")


## Whether `key` has a path to choose now: the party has reached the level for
## one, they have not chosen, and there are paths for them to choose from.
func needs_path(key: String) -> bool:
	return party_level >= Stats.SUBCLASS_LEVEL and subclass_of(key) == "" \
		and not SubclassDefinition.for_character(key).is_empty()


## Everybody in the party with a path still to choose, leader first.
func choosing_paths() -> Array:
	return living_party().filter(needs_path)


## Puts `key` on `subclass` for good. False - and nothing changes - if it is
## not one of theirs, they have one already, or the party is not far enough
## along yet.
func choose_subclass(key: String, subclass: String) -> bool:
	var path := SubclassDefinition.named(subclass)
	if path == null or not SubclassDefinition.for_character(key).has(subclass) or not needs_path(key):
		return false
	subclasses[key] = subclass
	announce("[color=lightgreen]%s[/color] takes the path of the [color=yellow]%s[/color].\n" % [
		display_name_of(key), path.name])
	subclass_chosen.emit(key, subclass)
	return true


## Whether `key` can change the path they are on now: they have one, and a long
## rest has been taken with no fight since (path_change_open).
func can_change_path(key: String) -> bool:
	return path_change_open and subclass_of(key) != "" and party_level >= Stats.SUBCLASS_LEVEL


## Puts `key` on `subclass` in place of the path they are on. False - and nothing
## changes - outside a long rest's window (can_change_path), or if it is not one
## of theirs or the one they are on. What they have learned stays learned.
func change_path(key: String, subclass: String) -> bool:
	var path := SubclassDefinition.named(subclass)
	if path == null or not can_change_path(key) or not SubclassDefinition.for_character(key).has(subclass) \
			or subclass_of(key) == subclass:
		return false
	subclasses[key] = subclass
	announce("[color=lightgreen]%s[/color] turns to the path of the [color=yellow]%s[/color].\n" % [
		display_name_of(key), path.name])
	subclass_chosen.emit(key, subclass)
	return true


## Fills the roster if it hasn't been set yet. Anything already in it wins, so
## this can't stomp a party the player has since reordered.
func seed_party(keys: Array):
	if not party_order.is_empty():
		return
	for key in keys:
		if CombatantDatabase.combatants.has(key) and not party_order.has(key):
			party_order.append(key)
		elif not CombatantDatabase.combatants.has(key):
			push_warning("Starting party lists '%s', which isn't in CombatantDatabase - skipping it." % key)


## The roster in marching order, leaving out anyone who has died. The leader is
## first. Everything that draws or spawns the party uses this, so the line on
## the map matches who is actually still standing.
func living_party() -> Array:
	var living: Array = []
	for key in party_order:
		if is_alive(key):
			living.append(key)
	return living


## Who is currently being steered, or "" if the whole party has fallen.
func leader() -> String:
	var living = living_party()
	return living[0] if not living.is_empty() else ""


## Moves `key` to the front of the marching order. Ignored for someone who
## isn't in the party, or who is dead - a corpse can't lead.
func set_leader(key: String) -> bool:
	if not party_order.has(key) or not is_alive(key):
		return false
	party_order.erase(key)
	party_order.insert(0, key)
	party_changed.emit()
	return true


## Passes the lead to the next living member, wrapping around. Returns the new
## leader's key, or "" if there was nobody to pass it to.
##
## Rotates the order rather than promoting the second member to the front:
## promoting would swap the front two back and forth for ever and never reach
## the third, so a party of three had only two possible leaders.
func cycle_leader() -> String:
	var living = living_party()
	if living.size() < 2:
		return leader()
	party_order.append(party_order.pop_front())
	# Step over anyone who has died, so the lead always lands on someone
	# standing. Bounded by the roster size, since at least two are alive.
	var guard = party_order.size()
	while guard > 0 and not is_alive(party_order[0]):
		party_order.append(party_order.pop_front())
		guard -= 1
	party_changed.emit()
	return leader()


## The members an encounter will actually deploy: living, and able to fight
## (see CombatantDefinition.can_fight). A guide or a prisoner travelling with
## the party walks the map and shows in the portraits, but is left out here.
func battle_party() -> Array:
	var fighters: Array = []
	for key in living_party():
		var definition: CombatantDefinition = CombatantDatabase.combatants.get(key)
		if definition != null and definition.can_fight:
			fighters.append(key)
	return fighters


## --- Recruiting and losing people ---
##
## These are the story hooks. They can be called from anywhere, including
## straight out of a dialogue file, because Campaign is registered as a state
## autoload shortcut for Dialogue Manager:
##
##     ~ enfina_joins
##     Enfina: I'll come with you.
##     do Campaign.add_member("enfina")
##     => END
##
## Anyone added is at full health unless they've fought before, and lands at
## the back of the marching order so the lead doesn't change under the player.
func add_member(key: String, at_front: bool = false) -> bool:
	if not CombatantDatabase.combatants.has(key):
		push_warning("Campaign.add_member('%s'): no such combatant in CombatantDatabase." % key)
		return false
	if party_order.has(key):
		return false
	if at_front:
		party_order.insert(0, key)
	else:
		party_order.append(key)
	party_changed.emit()
	announce("[color=lightgreen]%s[/color] joins the party.
" % display_name_of(key))
	return true


## Removes someone from the party - they left, or the story took them. Their
## carried health is forgotten too, so rejoining later starts them fresh;
## pass keep_state to remember the state they left in.
func remove_member(key: String, keep_state: bool = false) -> bool:
	if not party_order.has(key):
		return false
	party_order.erase(key)
	if not keep_state:
		party_state.erase(key)
	party_changed.emit()
	announce("[color=red]%s[/color] leaves the party.
" % display_name_of(key))
	return true


func has_member(key: String) -> bool:
	return party_order.has(key)


## Emitted whenever the roster changes, so anything showing the party (the
## exploration line, the portrait column) can redraw itself without polling.
signal party_changed()

## Something worth saying in the log, wherever the log happens to be.
##
## Campaign outlives every scene, so whatever wants to say something - an item
## changing hands, somebody joining or leaving - says it here without having to
## know whether a battle or a map is on screen. The HUD is the same scene in
## both, and it listens.
signal announced(text: String)


## Says `text` in the log. Takes the same BBCode the combat log does.
func announce(text: String):
	announced.emit(text)


## What to call somebody in the log: their proper name, falling back to the key
## so a line is never blank about who it is talking about.
func display_name_of(key: String) -> String:
	var definition: CombatantDefinition = CombatantDatabase.combatants.get(key)
	return definition.name if definition != null and definition.name != "" else key

## Somebody's bag changed - used, given, or handed to somebody else. Carries
## whose it was, so a screen showing several at once can redraw just the one.
signal inventory_changed(combatant_key)


## What the HUD needs to draw the party: one entry per living member, leader
## first. hp comes from what they carried out of the last battle, so the
## portraits show real wear rather than everyone at full health.
func party_members() -> Array:
	var members: Array = []
	for key in living_party():
		var definition: CombatantDefinition = CombatantDatabase.combatants.get(key)
		if definition == null:
			continue
		# What they have at the level this map has them at - a level 3 Alithia
		# walking around with her level 1 health would read as badly wounded.
		var hp = definition.hp_at(party_level)
		var max_hp = hp
		if party_state.has(key):
			hp = party_state[key].hp
			# What they were last fielded with, so the bar reads against the
			# health they actually had rather than their level 1 figure.
			max_hp = party_state[key].get("max_hp", definition.hp_at(party_level))
		members.append({
			"key": key,
			"name": definition.name,
			"icon": definition.portrait(),
			"map_sprite": definition.map_still(),
			# The animation set travels with the still: the party walks the map
			# with the same SpriteFrames it fights with.
			"sprite_frames": definition.sprite_frames,
			"hp": hp,
			"max_hp": max_hp,
			"is_leader": key == leader(),
		})
	return members

## --- Exploration ---
##
## Exploration is the hub: battles are started from inside a map and hand
## control back to it afterwards, so the map and the spot you were standing on
## have to survive a scene change.

## Scene path of the exploration map to load, and where in it to put the party.
## return_position is only used when return_to_position is true - otherwise the
## map's own entry point decides, which is what happens when you walk through a
## door into a new map.
var current_map: String = ""
var return_position := Vector2.ZERO
var return_to_position := false
## Which EntryPoint to arrive at, for a door that names one. Ignored when
## return_to_position is set.
var target_entry := ""
## Ids of encounter triggers already beaten, so a fight doesn't restart every
## time you walk back past where it happened.
var cleared_triggers := {}


## Remembers where the party is standing and starts `encounter`. Call this
## instead of setting current_encounter directly when a battle is launched from
## exploration, so the trigger can be retired and the map restored afterwards.
func begin_battle_from_exploration(encounter: EncounterDefinition, map_path: String, party_position: Vector2, trigger_id: String):
	# The moment before the fight, for an automatic save to go back to.
	SaveGame.autosave_before_fight(snapshot(map_path, party_position))
	# In a dungeon the map is the story's own, but the fight at the end of it
	# is the dungeon's.
	current_encounter = dungeon_fight_for(encounter, map_path)
	current_map = map_path
	return_position = party_position
	return_to_position = true
	_pending_trigger = trigger_id


## Whether a battle is currently one the exploration map is waiting to get
## control back from.
func has_map_to_return_to() -> bool:
	return return_to_position and current_map != ""


## Called when a battle launched from exploration ends. A win retires its
## trigger; a loss leaves it in place so the fight can be tried again.
## `still_coming` is the enemy spawns that had not arrived when it ended (see
## Combat.arriving): on a stealth map, a guard still on the way never fought,
## and is still on watch when the party walks back in.
func finish_battle_from_exploration(won: bool, still_coming: Array = []):
	if won and _pending_trigger != "":
		cleared_triggers[_pending_trigger] = true
	_pending_trigger = ""
	if won and stealth_state.has(current_map):
		var state: Dictionary = stealth_state[current_map]
		var late := still_coming.map(func(spawn): return spawn.get_meta("guard", ""))
		for guard in state.get("fighting", []):
			if not late.has(guard) and not state.defeated.has(guard):
				state.defeated.append(guard)


## Map path -> how its stealth watch stood the moment somebody was caught (see
## StealthWatch.snapshot), so walking back in after the fight carries on from
## there rather than from scratch: whoever was knocked out still down, pockets
## still picked, and the guards who fought and lost gone.
var stealth_state := {}


## The stealth map being played right now, if any - set and cleared by its
## StealthWatch - so a conversation can reach it.
var stealth_watch: Node = null


## Settles the stealth map being played `levels` levels, as far as a found body
## lets it - for a conversation, or anything used:
##
##     do Campaign.settle_alert()
##
## True when it went down at all. Nothing, off a stealth map.
func settle_alert(levels: int = 1) -> bool:
	if stealth_watch == null or not is_instance_valid(stealth_watch):
		return false
	return stealth_watch.settle(levels)


## --- Starting a stealth map over ---
##
## Walking onto a stealth map - not back onto it from a fight - writes down how
## things stood, so the pause menu's Restart Stage can put them back and start
## the map again from where the party came in: another go at a clean run, from
## the map or from the middle of the fight a catch started.

var stealth_checkpoint := {}


func save_stealth_checkpoint(map_path: String, arrived_at: Vector2):
	stealth_checkpoint = {
		"map": map_path,
		"at": arrived_at,
		"party_order": party_order.duplicate(),
		"party_level": party_level,
		"party_state": party_state.duplicate(true),
		"inventories": inventories.duplicate(true),
		"containers": containers.duplicate(true),
		"stacks": stacks.duplicate(true),
		"flags": flags.duplicate(true),
		"cleared_triggers": cleared_triggers.duplicate(),
	}


## Whether Restart Stage has somewhere to go back to: a stealth map being
## played, or the fight it started - and nothing else already on its way in.
## Pressed while the screen faded into the fight a catch started, it used to
## reset everything, have its own change of scene ignored, and let that fight
## load with nothing to fight: the battle scene's fallback, the sewer ambush.
func can_restart_stealth() -> bool:
	if stealth_checkpoint.is_empty() or stealth_checkpoint.map != current_map:
		return false
	return not SceneTransition.is_changing()


## Everything as it was when the party walked onto the map, and the map again.
func restart_stealth():
	if not can_restart_stealth():
		return
	var back: Dictionary = stealth_checkpoint
	party_order.assign(back.party_order)
	party_level = back.party_level
	party_state = back.party_state.duplicate(true)
	inventories = back.inventories.duplicate(true)
	containers = back.get("containers", {}).duplicate(true)
	stacks = back.get("stacks", {}).duplicate(true)
	flags = back.flags.duplicate(true)
	cleared_triggers = back.cleared_triggers.duplicate()
	stealth_state.erase(back.map)
	current_map = back.map
	current_encounter = null
	_pending_trigger = ""
	target_entry = ""
	# Put back where they came in, as if back from a fight: the bags are already
	# as they were, so nothing is handed out again.
	return_position = back.at
	return_to_position = true
	Engine.time_scale = 1.0
	SceneTransition.change_scene("res://scenes/exploration.tscn")


## --- Saving ---
##
## What SaveGame writes to disk and reads back: everything a run has come to,
## and where the party stood. Anything kept on this autoload that lasts beyond
## the moment belongs in here - the `saves` suite fails on one that does not.

## The keys of everything the run is made of, copied as they are.
const SAVED := ["party_level", "party_state", "subclasses", "path_change_open", "inventories", "gear", "equipped",
	"gold", "flags", "cleared_triggers", "stealth_state", "dungeon_stage", "gate_recoveries_left", "gates_spent_outside", "outside_spent",
	"meditated", "free_familiar_used", "parley", "chapter", "levels_unveiled", "learned_spells", "containers", "stacks"]


## Everything to save, standing at `at` on `map` ("" for a dungeon's fight with
## no map before it). On a stealth map, how things stood on walking onto it
## (stealth_checkpoint) - a stealth map is never saved partway through.
func snapshot(map: String, at: Vector2) -> Dictionary:
	var state := {"map": map, "at": at, "party_order": Array(party_order),
		"dungeon": dungeon.resource_path if dungeon != null else ""}
	for key in SAVED:
		var value = get(key)
		state[key] = value.duplicate(true) if value is Dictionary or value is Array else value
	if not stealth_checkpoint.is_empty() and stealth_checkpoint.map == map:
		var back: Dictionary = stealth_checkpoint
		state.at = back.at
		state.party_order = Array(back.party_order)
		for key in ["party_level", "party_state", "inventories", "flags", "cleared_triggers"]:
			state[key] = back[key].duplicate(true) if back[key] is Dictionary else back[key]
		state.stealth_state.erase(map)
	return state


## Puts a saved run back (snapshot) and goes to where it was saved.
func restore(state: Dictionary):
	reset()
	clear_story()
	party_order.assign(state.get("party_order", []))
	for key in SAVED:
		if state.has(key):
			var value = state[key]
			set(key, value.duplicate(true) if value is Dictionary or value is Array else value)
	_carry_old_paths()
	var dungeon_path: String = state.get("dungeon", "")
	dungeon = load(dungeon_path) if dungeon_path != "" else null
	current_encounter = null
	_pending_trigger = ""
	target_entry = ""
	Engine.time_scale = 1.0
	party_changed.emit()
	if state.get("map", "") == "":
		# A dungeon's fight with no map before it: straight back into it.
		if dungeon != null:
			_go_to_dungeon_stage(false)
		else:
			to_main_menu()
		return
	current_map = state.map
	return_position = state.get("at", Vector2.ZERO)
	return_to_position = true
	SceneTransition.change_scene(EXPLORATION_SCENE)


func is_trigger_cleared(trigger_id: String) -> bool:
	return trigger_id != "" and cleared_triggers.has(trigger_id)


## Sends the party through a door: a different map, arriving at the named
## entry point rather than at remembered coordinates.
func travel_to_map(map_path: String, entry_name: String):
	current_map = map_path
	target_entry = entry_name
	return_to_position = false


var _pending_trigger := ""


## Applies whatever condition `key` was left in by earlier battles to a
## freshly-created combatant dictionary. No stored state means untouched.
func apply_carried_state(comb: Dictionary, key: String):
	if not party_state.has(key):
		return
	var stored = party_state[key]
	# Brought back from falling, and weaker for it until a long rest (Combat.weaken) -
	# before their health is set, so it is set against what they can have now.
	if stored.get("frailty", 1.0) < 1.0:
		comb["frailty"] = stored.frailty
		Combat.apply_frailty(comb)
	# Clamped, because the health carried out of one fight can exceed what this
	# one allows: walking a level 3 survivor into a battle that fields them at
	# level 1 should not start them above full.
	comb.hp = mini(stored.hp, comb.max_hp)
	comb.alive = stored.alive
	# In a dungeon the gates spent stay spent, fight to fight - only the rest's
	# Recover Gates brings them back. Elsewhere every fight opens them all.
	if in_dungeon() and stored.has("spell_slots"):
		var slots: Array = comb.get("spell_slots", []).duplicate()
		for gate in mini(slots.size(), stored.spell_slots.size()):
			slots[gate] = mini(stored.spell_slots[gate], slots[gate])
		comb.spell_slots = slots
	# And so do the uses spent until a rest (Combat.SPENT_UNTIL_REST) - only a
	# short or long rest brings them back. Elsewhere every fight has them all.
	if in_dungeon() and stored.has("spent_until_rest"):
		var spent: Dictionary = stored.spent_until_rest
		for what in spent:
			comb[what] = spent[what].duplicate(true) if spent[what] is Dictionary or spent[what] is Array else spent[what]


## Gates `key` opened outside a fight - for a hack's hint (Hacking) - stay
## spent into the next fight, and are cleared once it has them.
func take_gates_spent_outside(comb: Dictionary, key: String):
	if not gates_spent_outside.has(key):
		return
	var spent: Array = gates_spent_outside[key]
	var slots: Array = comb.get("spell_slots", []).duplicate()
	for gate in mini(slots.size(), spent.size()):
		slots[gate] = maxi(slots[gate] - spent[gate], 0)
	comb.spell_slots = slots
	gates_spent_outside.erase(key)


## --- Gates outside a fight ---
##
## A fight opens every gate afresh (bar a dungeon's, which stay spent fight to
## fight). Something spending one outside a fight - a hack's hint - would cost
## nothing that way, so what is spent is written here and taken off the next
## fight's gates (take_gates_spent_outside). In a dungeon it comes straight off
## the gates carried between its fights.

## combatant key -> castings spent through each gate, indexed by gate.
var gates_spent_outside := {}


## How many castings `key` has through each gate right now, outside a fight.
func gates_left_outside(key: String) -> Array:
	if in_dungeon():
		return gates_left(key)
	var left := gates_most(key)
	var spent: Array = gates_spent_outside.get(key, [])
	for gate in mini(left.size(), spent.size()):
		left[gate] = maxi(left[gate] - spent[gate], 0)
	return left


## Spends one of `key`'s castings through `gate`, outside a fight. False, and
## nothing spent, with none left.
func spend_gate_outside(key: String, gate: int) -> bool:
	var left := gates_left_outside(key)
	if gate <= 0 or gate >= left.size() or left[gate] <= 0:
		return false
	if in_dungeon():
		if not party_state.has(key):
			party_state[key] = {"hp": _full_health(key), "max_hp": _full_health(key), "alive": true}
		left[gate] -= 1
		party_state[key]["spell_slots"] = left
		party_state[key]["max_spell_slots"] = gates_most(key)
		return true
	var spent: Array = gates_spent_outside.get(key, Stats.no_gates()).duplicate()
	while spent.size() <= gate:
		spent.append(0)
	spent[gate] += 1
	gates_spent_outside[key] = spent
	return true


## Takes `amount` of `key`'s health outside a fight - the strain of a hack -
## never the last point of it.
func strain(key: String, amount: int):
	if amount <= 0:
		return
	if not party_state.has(key):
		party_state[key] = {"hp": _full_health(key), "max_hp": _full_health(key), "alive": true}
	party_state[key].hp = maxi(party_state[key].hp - amount, 1)


## Gives `key` back `amount` of their health outside a fight - a heal cast on a
## map (OutsideMoves) - never past their most. What it mended.
func mend(key: String, amount: int) -> int:
	if amount <= 0 or not party_state.has(key) or not party_state[key].get("alive", true):
		return 0
	var state: Dictionary = party_state[key]
	var most: int = state.get("max_hp", _full_health(key))
	var before: int = state.hp
	state.hp = mini(state.hp + amount, most)
	return state.hp - before


## Who of the party has fallen and is still down, in marching order.
func fallen_members() -> Array:
	var down := []
	for key in party_order:
		if not is_alive(key):
			down.append(key)
	return down


## Stands `fallen` back up outside a fight, by `revive` (a REVIVE effect) - with
## its share of their health, and weaker for it until a long rest, as in a fight.
## False, and nothing changed, for somebody who is not down.
func revive_outside(fallen: String, revive: EffectDefinition) -> bool:
	var state: Dictionary = party_state.get(fallen, {})
	if state.is_empty() or state.get("alive", true) or revive == null:
		return false
	_bring_back(state, revive)
	party_changed.emit()
	return true


## Up again, by `revive`: weaker by its Weakening, with its share of the health
## that leaves them.
func _bring_back(state: Dictionary, revive: EffectDefinition):
	if not state.has("unweakened_max_hp"):
		state["unweakened_max_hp"] = state.get("max_hp", 1)
	state["frailty"] = state.get("frailty", 1.0) * (1.0 - revive.revive_weakening)
	state["max_hp"] = maxi(1, roundi(state.get("max_hp", 1) * (1.0 - revive.revive_weakening)))
	state["hp"] = maxi(1, roundi(state.max_hp * revive.revive_health))
	state["alive"] = true


## --- Gates opened only outside a fight ---
##
## Iris (Stats.OUTSIDE_GATES) has castings of its own, for the spells cast on a
## map (SkillDefinition.outside_gate), so sneaking never costs a fight's gates.
## They come back when a fight's own gates do: at the start of every fight
## (Combat._deploy_party clears this), but in a dungeon only through a rest's
## recovery (recover_gates), at the price of the gate each matches.

## combatant key -> castings spent through each outside gate, indexed by gate.
var outside_spent := {}


## The spells `key` can cast outside a fight, by skill key: their own and their
## path's that go through an outside gate - learned, and through a gate the
## party's level has opened. The rest stay on the character sheet.
func outside_spells(key: String) -> Array:
	var definition: CombatantDefinition = CombatantDatabase.combatants.get(key)
	if definition == null:
		return []
	var known: Array = []
	known.append_array(definition.skills)
	known.append_array(definition.secondary_skills)
	var path := SubclassDefinition.named(subclass_of(key))
	if path != null:
		known.append_array(path.skills)
	var opened := Stats.outside_gates_for_level(party_level)
	var found := []
	for skill_key in known:
		var skill: SkillDefinition = SkillDatabase.skills.get(skill_key)
		if skill == null or skill.outside_gate <= 0 or found.has(skill_key):
			continue
		if skill.required_level > party_level or skill.outside_gate >= opened.size() or opened[skill.outside_gate] <= 0:
			continue
		found.append(skill_key)
	return found


## The most castings `key` has through each outside gate: as many as the ladder
## gate it matches has at the party's level, for a gate they know a spell of,
## and none through the rest.
func outside_gates_most(key: String) -> Array:
	var most := Stats.outside_gates_for_level(party_level)
	var opened := {}
	for skill_key in outside_spells(key):
		opened[SkillDatabase.skills[skill_key].outside_gate] = true
	# And a gate a spell marked Out Of Combat may be paid through (OutsideMoves).
	for skill_key in OutsideMoves.moves_of(key):
		var gate := OutsideMoves.iris_gate_for(SkillDatabase.skills[skill_key])
		if gate > 0:
			opened[gate] = true
	for gate in most.size():
		if not opened.has(gate):
			most[gate] = 0
	return most


## How many castings `key` has left through each outside gate.
func outside_gates_left(key: String) -> Array:
	var left := outside_gates_most(key)
	var spent: Array = outside_spent.get(key, [])
	for gate in mini(left.size(), spent.size()):
		left[gate] = maxi(left[gate] - spent[gate], 0)
	return left


## Spends `count` of `key`'s castings through outside gate `gate`. False, and
## nothing spent, without that many left.
func spend_outside_gate(key: String, gate: int, count: int = 1) -> bool:
	var left := outside_gates_left(key)
	if gate <= 0 or gate >= left.size() or count <= 0 or left[gate] < count:
		return false
	var spent: Array = outside_spent.get(key, []).duplicate()
	while spent.size() <= gate:
		spent.append(0)
	spent[gate] += count
	outside_spent[key] = spent
	return true


## Health of `key` at full, at the party's level.
func _full_health(key: String) -> int:
	var definition: CombatantDefinition = CombatantDatabase.combatants.get(key)
	return definition.hp_at(party_level) if definition != null else 1


## Whether `key` is still standing - false only once they have actually died
## in an earlier encounter. The level select uses this to warn about a wiped
## party, and the spawner uses it to leave the dead out of later battles.
func is_alive(key: String) -> bool:
	if not party_state.has(key):
		return true
	return party_state[key].alive


## Records how the party came out of a battle. Called by Combat when the fight
## ends, for every player-side combatant, win or lose.
func record_party(combatants: Array):
	for comb in combatants:
		# Somebody bought or rebound fought beside them, but is not one of them;
		# nor is anything summoned, which goes with the fight.
		if comb.side != 0 or comb.has("turncoat") or comb.has("summoner"):
			continue
		var key = comb.get("combatant_key", "")
		if key == "":
			continue
		party_state[key] = {
			"hp": maxi(comb.hp, 0),
			# The health they fought at, which is their level's rather than their
			# level 1 figure - without it the level select would show a level 3
			# survivor as 25/10 once per-level health entered the picture.
			"max_hp": comb.max_hp,
			"alive": comb.alive,
		}
		if comb.get("frailty", 1.0) < 1.0:
			party_state[key]["frailty"] = comb.frailty
			# What a long rest gives them back (_lift_weakening).
			if comb.has("unweakened"):
				party_state[key]["unweakened_max_hp"] = comb.unweakened.max_hp
		if in_dungeon():
			party_state[key]["spell_slots"] = comb.get("spell_slots", []).duplicate()
			party_state[key]["max_spell_slots"] = comb.get("max_spell_slots", []).duplicate()
			party_state[key]["spent_until_rest"] = Combat.spent_until_rest(comb)


## Back to full strength: everyone alive, everyone at full health, every
## encounter trigger in the world armed again, and the marching order back to
## however the starting party is configured.
## What a conversation standing in front of a fight decided.
##
## A dialogue answers with a `do` line on the branch that means it:
##
##     - We're ready
##         do Campaign.accept_encounter()
##     - Let's look around a bit more first
##         do Campaign.decline_encounter()
##
## Saying nothing counts as declining. Closing the balloon must not be a way of
## slipping past a fight you were asked about - the trigger is standing in the
## party's path, and the answer decides whether they walk into it or back out
## of it, never whether they get to walk through it.
enum EncounterAnswer { UNANSWERED, ACCEPTED, DECLINED }

var _encounter_answer := EncounterAnswer.UNANSWERED


## Walk into the fight this conversation is about, once it has finished.
func accept_encounter():
	_encounter_answer = EncounterAnswer.ACCEPTED


## Back away from it instead. The party is walked out of the trigger's reach
## when the conversation ends, so they can come back when they are ready.
func decline_encounter():
	_encounter_answer = EncounterAnswer.DECLINED


## Clears any answer left over, so a conversation begins with nothing assumed.
func forget_encounter_answer():
	_encounter_answer = EncounterAnswer.UNANSWERED


## Reads the answer and clears it in one go, so it can never be acted on twice.
func take_encounter_answer() -> EncounterAnswer:
	var answer = _encounter_answer
	_encounter_answer = EncounterAnswer.UNANSWERED
	return answer


func reset():
	_arena_return = {}
	dungeon = null
	dungeon_stage = 0
	gate_recoveries_left = 0
	gates_spent_outside.clear()
	outside_spent.clear()
	meditated.clear()
	free_familiar_used = false
	parley = {}
	_encounter_answer = EncounterAnswer.UNANSWERED
	party_state.clear()
	cleared_triggers.clear()
	stealth_state.clear()
	stealth_checkpoint = {}
	party_order.clear()
	party_level = 1
	chapter = 1
	levels_unveiled = false
	learned_spells.clear()
	subclasses.clear()
	path_change_open = false
	gear.clear()
	gold = 0
	equipped.clear()
	inventories.clear()
	containers.clear()
	stacks.clear()
	# Starting over starts over: what the last playthrough had read, pulled and
	# opened is not true of this one.
	flags.clear()


## One-line summary of the party's condition for the level select, e.g.
## "Enfina 16/16, Cyrus 4/10, Prometheus (dead)". Empty string before the
## first battle, when nobody has taken a scratch yet.
func describe_party() -> String:
	if party_state.is_empty():
		return ""
	var parts = []
	for key in party_state:
		var stored = party_state[key]
		var definition: CombatantDefinition = CombatantDatabase.combatants.get(key)
		var display = definition.name if definition != null else key
		if not stored.alive:
			parts.append("%s (dead)" % display)
		else:
			# The health they were last fielded with, for the same reason the party
			# panel uses it: "12/10" reads as a bug rather than as a veteran.
			var max_hp = stored.get("max_hp", definition.max_hp if definition != null else stored.hp)
			parts.append("%s %d/%d" % [display, stored.hp, max_hp])
	return ", ".join(parts)


## Whether every party member recorded so far is dead - the point at which no
## encounter can be started without resetting first.
func is_party_wiped() -> bool:
	if party_state.is_empty():
		return false
	for key in party_state:
		if party_state[key].alive:
			return false
	return true


## --- Flags ---
##
## Named facts about this playthrough: what has been read, pulled, opened,
## agreed to. Kept here because this is the one thing that survives walking to
## another map and fighting a battle, which is exactly the span a flag has to
## last for to be worth anything.
##
## Dialogue reads and writes them directly, since Campaign is a Dialogue
## Manager state autoload:
##
##     if Campaign.flag("read_the_notice")
##         Guard: So you have seen it.
##     else
##         Guard: There is a notice by the gate.
##     do Campaign.set_flag("spoke_to_guard")
##
## Interactables set and require them without any code at all - see the Flags
## group on Interactable, which is how a button opens a door.

## name -> value. Usually true, but anything can be stored: a count of how many
## times something was asked, which of three endings was taken.
var flags := {}


## Sets `flag_name`. The value is true unless you say otherwise, because
## "this happened" is what almost every flag means.
func set_flag(flag_name: String, value = true):
	if flag_name == "":
		return
	flags[flag_name] = value


## Whether `flag_name` is set and not switched off. false for one never set, so
## a condition can be written before the thing that sets it exists.
func flag(flag_name: String) -> bool:
	if not flags.has(flag_name):
		return false
	var value = flags[flag_name]
	# An explicit false, 0 or "" reads as not set, so a flag can be turned off
	# either by clearing it or by setting it false, and a condition written
	# against it means the same thing either way.
	#
	# Tested by type rather than by comparing the value against false, 0 and ""
	# in turn: comparing a bool against a String is an error at runtime, not a
	# false, and it takes the whole expression - and the flag - down with it.
	match typeof(value):
		TYPE_NIL:
			return false
		TYPE_BOOL:
			return value
		TYPE_INT, TYPE_FLOAT:
			return value != 0
		TYPE_STRING, TYPE_STRING_NAME:
			return value != ""
	return true


## What was stored under `flag_name`, for the flags carrying more than yes or
## no - a count, a name, a choice.
func flag_value(flag_name: String, fallback = null):
	return flags.get(flag_name, fallback)


## Forgets `flag_name` entirely, so flag() reads false and flag_value() gives
## its fallback again.
func clear_flag(flag_name: String):
	flags.erase(flag_name)


## --- Story screens ---
##
## A conversation played over a black screen, with somewhere to go afterwards.
## Set here rather than passed in because changing scene cannot carry arguments,
## and this is already the thing that survives the change.

var story_dialogue := ""
var story_title := "start"
var story_next_scene := ""


## Queues `dialogue` to play over black, then `next_scene` - or the menu, when
## the story has nowhere to be yet.
func begin_story(dialogue: String, title: String = "start", next_scene: String = ""):
	story_dialogue = dialogue
	story_title = title
	story_next_scene = next_scene


func clear_story():
	story_dialogue = ""
	story_title = "start"
	story_next_scene = ""


## --- Leaving ---


## Back to the title screen, from wherever the game currently is.
##
## Written to be called from a dialogue: Campaign is one of the autoloads the
## Dialogue Manager exposes to `do` lines (see state_autoload_shortcuts in
## project.godot), so the last line of a story scene can be
##
##     do Campaign.to_main_menu()
##
## and the conversation ends by handing the player back to the menu.
##
## Clears the run on the way out. Whatever the player picks next starts from
## the menu's own idea of a beginning, and a half-finished party left lying
## around would be inherited by it.
## Where Arena Mode was opened from, so leaving it hands you back rather than
## only ever offering the title screen.
##
## Arena Mode is reachable mid-run - from a fight, or from the middle of the
## sewers - and it used to be a one-way door: the only way out was the main
## menu, which threw the run away. It holds copies rather than relying on the
## live fields, because opening a fight from the arena overwrites those.
##
## Empty when the arena was opened from the title screen, where going back to
## the title screen is the right thing and there is nothing else to go back to.
var _arena_return := {}


func enter_arena_from(scene_path: String, standing_at = null):
	_arena_return = {
		"scene": scene_path,
		"map": current_map,
		"encounter": current_encounter,
		"position": standing_at if standing_at != null else return_position,
		# Only a map remembers where you were standing. A battle is re-entered
		# from its encounter, and the title screen from nothing at all.
		"to_position": standing_at != null,
	}


func can_leave_arena() -> bool:
	return not _arena_return.is_empty()


## Hands the player back wherever they opened the arena from.
func leave_arena():
	if _arena_return.is_empty():
		to_main_menu()
		return
	var back = _arena_return
	_arena_return = {}
	current_map = back.map
	current_encounter = back.encounter
	return_position = back.position
	return_to_position = back.to_position
	SceneTransition.change_scene(back.scene)


## What the title screen opens on, and a line for it to show there, when
## whatever sent the player back has more to say than "the title screen": a
## stealth stage's exit goes back to the list of stages, saying how it went.
## MainMenu reads them once and clears them.
var menu_opens_at := ""
var menu_note := ""


## Back to the title screen - opened at `opens_at` (one of MainMenu's panels)
## with `note` shown on it, when given.
func to_main_menu(opens_at: String = "", note: String = ""):
	_arena_return = {}
	# The title screen plays nothing of its own, and a battle's music carrying
	# on underneath it belongs to a fight that is over. Only here: Arena Mode and
	# the maps set their own, so those keep playing until something says otherwise.
	Music.stop()
	reset()
	clear_story()
	current_map = ""
	current_encounter = null
	return_to_position = false
	menu_opens_at = opens_at
	menu_note = note
	SceneTransition.change_scene(MAIN_MENU)


## --- A dungeon (see DungeonDefinition) ---
##
## A run of fights with rests between: start_dungeon puts the party together
## and sends them to the first stage; the result screen rests them after each
## win and calls next_dungeon_stage, until the last is won.

const EXPLORATION_SCENE := "res://scenes/exploration.tscn"
const BATTLE_SCENE := "res://scenes/game.tscn"

## The dungeon being played, or null.
var dungeon: DungeonDefinition = null
## Which of its stages the party is on.
var dungeon_stage := 0
## How many more rests may still bring gates back.
var gate_recoveries_left := 0


## Starts `which` from the top: its party at its level, carrying nothing, on
## its first stage.
func start_dungeon(which: DungeonDefinition):
	reset()
	clear_story()
	dungeon = which
	dungeon_stage = 0
	gate_recoveries_left = which.gate_recoveries
	set_party(which.party, which.level)
	for key in party_order:
		empty_inventory(key)
		for item_id in which.kit.get(key, []):
			if stow_item(key, str(item_id)) < 0:
				push_warning("%s: no room in %s's bag for %s." % [which.display_name, key, item_id])
	_go_to_dungeon_stage()


func in_dungeon() -> bool:
	return dungeon != null


## The stage the party is on, or null.
func current_dungeon_stage() -> DungeonStage:
	if dungeon == null or dungeon_stage < 0 or dungeon_stage >= dungeon.stages.size():
		return null
	return dungeon.stages[dungeon_stage]


## Whether the stage the party is on is the dungeon's last.
func on_last_dungeon_stage() -> bool:
	return dungeon != null and dungeon_stage >= dungeon.stages.size() - 1


## The fight to have when `map` starts `encounter`: in a dungeon, the stage's
## own fight in its place; anywhere else, `encounter`.
func dungeon_fight_for(encounter: EncounterDefinition, map: String) -> EncounterDefinition:
	if dungeon == null or encounter == null:
		return encounter
	var stage := dungeon.stage_for(map, encounter)
	return stage.encounter if stage != null and stage.encounter != null else encounter


## On to the next stage - or, after the last, back to the title screen with
## the dungeon done.
func next_dungeon_stage():
	if dungeon == null:
		return
	dungeon_stage += 1
	if dungeon_stage >= dungeon.stages.size():
		to_main_menu("", "%s cleared." % dungeon.display_name)
		return
	_go_to_dungeon_stage()


func _go_to_dungeon_stage(autosave: bool = true):
	var stage := current_dungeon_stage()
	if stage == null:
		return
	current_encounter = null
	var scene := EXPLORATION_SCENE
	if stage.map != "":
		travel_to_map(stage.map, "")
	else:
		# Straight into a fight: the moment before it, for an automatic save -
		# unless this is a save being loaded, which is that moment already.
		if autosave:
			SaveGame.autosave_before_fight(snapshot("", Vector2.ZERO))
		current_map = ""
		return_to_position = false
		current_encounter = stage.encounter
		scene = BATTLE_SCENE
	# A change still fading in drops any other asked for meanwhile, and the
	# stage would be counted gone to without being gone to.
	while SceneTransition.is_changing():
		await get_tree().process_frame
	SceneTransition.change_scene(scene)


## --- Resting, between a dungeon's fights ---


## The rest between a dungeon's stages. A dungeon of short rests
## (DungeonDefinition.short_rests) takes a short one; any other, everyone back
## to full health - and, if the dungeon says so, back on their feet - with
## what is spent until a rest back too. What they carry is left as it is.
func rest_party():
	if dungeon != null and dungeon.short_rests:
		short_rest()
		return
	for key in party_order:
		if not party_state.has(key):
			continue
		var state: Dictionary = party_state[key]
		if not state.alive and (dungeon == null or not dungeon.rest_revives):
			continue
		state.hp = state.get("max_hp", state.hp)
		state.alive = true
	short_rest()


## --- Short and long rests ---
##
## What each brings back (the designer, 2026-10-24 and 25). Either is taken
## whenever something calls for it - a conversation (`do Campaign.short_rest()`),
## or a dungeon of short rests between its fights (the Dungeon Demo, the lab);
## a segment has 2-3 short rests on average, 2-4 late in the game, which nothing
## counts.
##
## A short rest brings back everything spent until one (Combat.SPENT_UNTIL_REST)
## - a skill's uses a short rest, a free amplification, a Conduit, the Trapper's
## bomb - but of spare castings (Devotion) only so many, and to everybody
## standing Short Rest Mends of what they have lost; nobody fallen gets up by
## themselves, and no gates come back - but Meditate may bring some, and
## Resuscitate somebody fallen (below).
##
## A long rest brings back everything: everybody up and at full health, the
## weakening of being brought back lifted, every gate (those opened outside a
## fight too - Iris), every spare casting, and Meditate.

## Of what everybody standing has lost, what a short rest gives back - a
## PROPOSAL test value (docs/healing_and_rest_proposal.md).
const SHORT_REST_MENDS := 0.5


func short_rest():
	for key in party_state:
		var state: Dictionary = party_state[key]
		var spare: int = state.get("spent_until_rest", {}).get("spare_spent", 0)
		state.erase("spent_until_rest")
		spare = maxi(spare - spares_back_at_short_rest(key), 0)
		if spare > 0:
			state["spent_until_rest"] = {"spare_spent": spare}
		if state.get("alive", false):
			_mend_for_short_rest(state)


## Short Rest Mends of what `state` has lost.
func _mend_for_short_rest(state: Dictionary):
	var most: int = state.get("max_hp", state.hp)
	state.hp = mini(most, state.hp + roundi(maxi(most - state.hp, 0) * SHORT_REST_MENDS))


## How many spare castings (PassiveDefinition.spare_castings) a short rest gives
## `key` back, from their passives working at the party's level.
func spares_back_at_short_rest(key: String) -> int:
	var definition: CombatantDefinition = CombatantDatabase.combatants.get(key)
	var back := 0
	for passive in definition.passives if definition != null else []:
		if passive != null and party_level >= passive.required_level:
			back += passive.spare_castings_a_short_rest
	return back


func long_rest():
	for key in party_state:
		var state: Dictionary = party_state[key]
		state.erase("spent_until_rest")
		_lift_weakening(state)
		state["alive"] = true
		state["hp"] = state.get("max_hp", state.get("hp", 1))
		if state.has("max_spell_slots"):
			state["spell_slots"] = state.max_spell_slots.duplicate()
		else:
			state.erase("spell_slots")
	outside_spent.clear()
	gates_spent_outside.clear()
	meditated.clear()
	free_familiar_used = false
	# And the paths open to change until the next fight (path_change_open).
	path_change_open = true
	if living_party().any(func(key): return subclass_of(key) != ""):
		announce("[color=yellow]Rested[/color]: paths can be changed from the character sheet until the next fight.\n")


## Brought back from falling, and weaker for it (Combat.weaken): no longer - back
## to the health they had before any of it.
func _lift_weakening(state: Dictionary):
	if state.get("frailty", 1.0) >= 1.0:
		return
	var frailty: float = state.frailty
	state["max_hp"] = state.get("unweakened_max_hp", roundi(state.get("max_hp", 1) / frailty))
	state.erase("frailty")
	state.erase("unweakened_max_hp")


## --- Resuscitate at a rest ---
##
## Somebody fallen in a dungeon of short rests stays down - unless somebody
## standing who knows Resuscitate spends a casting of it on them at the rest:
## through the shallowest gate deep enough that they have one left, the fallen
## back up with the spell's Revive Health of their health, and weakened as in a
## fight (Revive Weakening, Combat.weaken) until a long rest - and then rested
## like everybody else, Short Rest Mends of what they are still missing. The
## designer, 2026-10-25.

const RESUSCITATE := "resuscitate"


## Who of the party can cast Resuscitate at a rest now, or "".
func resuscitator() -> String:
	for key in party_order:
		if rest_gate_for(key) > 0:
			return key
	return ""


## The gate `key` would cast Resuscitate through at a rest, or 0 when they
## cannot: fallen, not knowing it, or nothing left deep enough.
func rest_gate_for(key: String) -> int:
	var skill: SkillDefinition = SkillDatabase.skills.get(RESUSCITATE)
	var definition: CombatantDefinition = CombatantDatabase.combatants.get(key)
	if skill == null or definition == null or not party_state.get(key, {}).get("alive", true):
		return 0
	if not definition.skills.has(RESUSCITATE) or party_level < skill.required_level or not knows_spell(key, RESUSCITATE):
		return 0
	var left := gates_left(key)
	for gate in range(skill.spell_slot_level, left.size()):
		if int(left[gate]) > 0:
			return gate
	return 0


## What Resuscitate does to whoever it brings back (its REVIVE effect), or null.
func resuscitate_revive() -> EffectDefinition:
	var skill: SkillDefinition = SkillDatabase.skills.get(RESUSCITATE)
	for effect in skill.all_effects() if skill != null else []:
		if effect != null and effect.type == EffectDefinition.EffectType.REVIVE:
			return effect
	return null


## `caster` brings `fallen` back at the rest (see above). False, and nothing
## spent, when they cannot.
func resuscitate_at_rest(caster: String, fallen: String) -> bool:
	var state: Dictionary = party_state.get(fallen, {})
	var gate := rest_gate_for(caster)
	if state.is_empty() or state.get("alive", true) or gate <= 0 or not party_state.has(caster):
		return false
	var revive := resuscitate_revive()
	if revive == null:
		return false
	var left := gates_left(caster)
	left[gate] = int(left[gate]) - 1
	party_state[caster]["spell_slots"] = left
	party_state[caster]["max_spell_slots"] = gates_most(caster)
	_bring_back(state, revive)
	# And the rest everybody else has had.
	_mend_for_short_rest(state)
	announce("[color=yellow]%s[/color] casts Resuscitate: [color=lightgreen]%s[/color] is back up and rested, with %d health - and %d%% weaker until a long rest.\n" % [
		display_name_of(caster), display_name_of(fallen), state.hp, roundi(revive.revive_weakening * 100.0)])
	return true


## --- Meditate ---
##
## At a short rest, once until the next long rest, somebody with a passive's
## Meditates (Prometheus) brings back castings they spent: Meditation Points of
## them - a point every MEDITATE_LEVELS levels, rounded up - each casting
## costing its gate's depth (World 1, Hermes 2, Pandora 3), and none through a
## gate deeper than the shallower half of the gates they have open, rounded up.
## Option A of docs/healing_and_rest_proposal.md, section 4 (the designer,
## 2026-10-25: "put in meditate"; its numbers are PROPOSAL test values). The
## gates opened only outside a fight (Iris) are not among them - a long rest
## brings those back. Offered on the RestPanel.

## A point to spend every so many levels, rounded up - a PROPOSAL test value.
const MEDITATE_LEVELS := 6

## Who has meditated since the last long rest.
var meditated: Array = []

## Whether Find Familiar's free casting has been had since the last long rest
## (FamiliarKeeper.pay - the designer, 2026-10-29).
var free_familiar_used := false


## Whether `key` meditates at all, at the party's level.
func meditates(key: String) -> bool:
	var definition: CombatantDefinition = CombatantDatabase.combatants.get(key)
	for passive in definition.passives if definition != null else []:
		if passive != null and passive.meditates and party_level >= passive.required_level:
			return true
	return false


## What `key`'s meditation has to spend.
func meditation_points(_key: String) -> int:
	return ceili(party_level / float(MEDITATE_LEVELS))


## The deepest gate `key`'s meditation reaches: the shallower half of the gates
## they have open, rounded up.
func meditation_deepest(key: String) -> int:
	var most := gates_most(key)
	var open := 0
	for gate in range(1, most.size()):
		if most[gate] > 0:
			open += 1
	return ceili(open / 2.0)


## What one casting through `gate` costs `key` to bring back by meditating - 0
## for a gate too deep.
func meditation_cost(key: String, gate: int) -> int:
	return gate if gate >= 1 and gate <= meditation_deepest(key) else 0


## Whether `key` can meditate now: they meditate, are standing, have not since
## the last long rest, and have spent something it could bring back.
func can_meditate(key: String) -> bool:
	if not meditates(key) or meditated.has(key) or not party_order.has(key):
		return false
	if not party_state.get(key, {}).get("alive", true):
		return false
	var left := gates_left(key)
	var most := gates_most(key)
	for gate in range(1, mini(most.size(), meditation_deepest(key) + 1)):
		if left[gate] < most[gate] and meditation_cost(key, gate) <= meditation_points(key):
			return true
	return false


## `key` meditates, bringing back `counts` of their castings, one count per
## gate. Refused, and nothing changed, if they cannot, it costs more than they
## have to spend or nothing, reaches too deep, or brings back more than was spent.
func meditate(key: String, counts: Array) -> bool:
	if not can_meditate(key):
		return false
	var left := gates_left(key)
	var most := gates_most(key)
	var cost := 0
	for gate in counts.size():
		var count: int = counts[gate]
		if count < 0 or (count > 0 and (gate >= left.size() or meditation_cost(key, gate) <= 0 or left[gate] + count > most[gate])):
			return false
		cost += count * meditation_cost(key, gate)
	if cost <= 0 or cost > meditation_points(key):
		return false
	for gate in counts.size():
		left[gate] += counts[gate]
	party_state[key]["spell_slots"] = left
	party_state[key]["max_spell_slots"] = most
	meditated.append(key)
	announce("[color=yellow]%s[/color] meditates, and has back what they spent.\n" % display_name_of(key))
	return true


## Whether a rest can bring `key`'s gates back now: the dungeon offers it for
## them, there is a recovery left to use, and something has been spent.
func can_recover_gates(key: String) -> bool:
	if dungeon == null or gate_recoveries_left <= 0 or not dungeon.gate_recovery_for.has(key):
		return false
	if not party_order.has(key):
		return false
	if party_state.has(key) and party_state[key].has("spell_slots"):
		var left := gates_left(key)
		var most := gates_most(key)
		for gate in range(1, most.size()):
			if dungeon.gate_cost(gate) > 0 and left[gate] < most[gate]:
				return true
	# Iris and the like: brought back the same way, at the price of the gate
	# each matches.
	var outside_left := outside_gates_left(key)
	var outside_most := outside_gates_most(key)
	for gate in range(1, outside_most.size()):
		if outside_gate_cost(gate) > 0 and outside_left[gate] < outside_most[gate]:
			return true
	return false


## What bringing back one casting through outside gate `gate` costs at a rest:
## the price of the ladder gate it matches.
func outside_gate_cost(gate: int) -> int:
	if dungeon == null or gate < 1 or gate >= Stats.OUTSIDE_GATES.size():
		return 0
	return dungeon.gate_cost(Stats.OUTSIDE_GATES[gate].matches)


## How many castings `key` has left through each gate, indexed by gate.
func gates_left(key: String) -> Array:
	var state: Dictionary = party_state.get(key, {})
	return state.get("spell_slots", gates_most(key)).duplicate()


## How many `key` has through each gate when none are spent.
func gates_most(key: String) -> Array:
	var state: Dictionary = party_state.get(key, {})
	if state.has("max_spell_slots"):
		return state.max_spell_slots.duplicate()
	var definition: CombatantDefinition = CombatantDatabase.combatants.get(key)
	return definition.gates_at(party_level) if definition != null else Stats.no_gates()


## What bringing back `counts` castings - one count per gate - costs, and
## `outside` through the gates opened only outside a fight (Iris), by gate.
func gate_recovery_cost(counts: Array, outside: Array = []) -> int:
	var cost := 0
	for gate in counts.size():
		cost += maxi(counts[gate], 0) * (dungeon.gate_cost(gate) if dungeon != null else 0)
	for gate in outside.size():
		cost += maxi(outside[gate], 0) * outside_gate_cost(gate)
	return cost


## Brings back `counts` of `key`'s castings, one count per gate - and `outside`
## through Iris and the like - spending one of the run's recoveries. Refused,
## and nothing changed, if it costs more than a recovery has to spend, brings
## back more than was spent, or none is left.
func recover_gates(key: String, counts: Array, outside: Array = []) -> bool:
	if not can_recover_gates(key):
		return false
	var cost := gate_recovery_cost(counts, outside)
	if cost <= 0 or cost > dungeon.gate_recovery_points:
		return false
	var left := gates_left(key)
	var most := gates_most(key)
	for gate in counts.size():
		if counts[gate] < 0 or (counts[gate] > 0 and (gate >= left.size() or left[gate] + counts[gate] > most[gate])):
			return false
	var outside_left := outside_gates_left(key)
	var outside_most := outside_gates_most(key)
	for gate in outside.size():
		if outside[gate] < 0 or (outside[gate] > 0 and (gate >= outside_left.size() or outside_left[gate] + outside[gate] > outside_most[gate])):
			return false
	if counts.any(func(count): return count > 0):
		for gate in counts.size():
			if counts[gate] > 0:
				left[gate] += counts[gate]
		party_state[key]["spell_slots"] = left
	var spent: Array = outside_spent.get(key, []).duplicate()
	for gate in mini(outside.size(), spent.size()):
		spent[gate] = maxi(spent[gate] - maxi(outside[gate], 0), 0)
	if not spent.is_empty():
		outside_spent[key] = spent
	gate_recoveries_left -= 1
	return true


## --- Inventories ---
##
## A bag per character rather than one shared pool, so who is carrying the last
## potion is a real question. Everyone in the party can reach everyone else's
## outside a fight (see the inventory screen on I); in a battle a character has
## only what is in their belt.
##
## The bag is the containers they wear (see "Containers") end to end - the
## belt's slots first, then the pouch's, then the backpack's - so the front of
## the bag is what they fight with.


## What everybody carries to start: the starting belt's slots and the starting
## backpack's. What somebody carries now is bag_size.
const INVENTORY_SIZE := 24

## The starting belt's slots - what comes into a fight unless somebody wears a
## bigger one. What somebody fights from now is combat_slots_of.
const COMBAT_SLOTS := 4

## combatant_key -> Array[String] of exactly bag_size entries, "" where the slot
## is empty. Empty slots are kept rather than compacted away so an item stays
## where it was put.
var inventories: Dictionary = {}
## combatant_key -> {slot index: how many}, for the slots holding more than one
## of a bomb (EquipmentDefinition.bombs_per_slot). One is not written down.
var stacks: Dictionary = {}


## Somebody's bag, made if they have never had one.
func inventory_of(key: String) -> Array:
	var size := bag_size(key)
	if not inventories.has(key):
		var slots: Array = []
		slots.resize(size)
		slots.fill("")
		# Empty. A bag is filled by something that happens - an encounter's
		# spawn list handing one out in Arena Mode, or a dialogue giving
		# somebody something - never by simply existing. Walking onto a map
		# used to grant a character their database kit, which meant every
		# exploration started with a satchel nobody had been given.
		inventories[key] = slots
	elif inventories[key].size() != size:
		# A bag saved before its containers were as they are now.
		_fit_bag(key, size)
	return inventories[key]


## `key`'s bag made `size` slots long, keeping what is in it in order. What will
## not fit in a smaller one is gone, and said.
func _fit_bag(key: String, size: int):
	var kept: Array = []
	var counts: Dictionary = {}
	var was: Array = inventories[key]
	for i in was.size():
		if was[i] == "":
			continue
		if kept.size() < size:
			counts[kept.size()] = count_in(key, i)
			kept.append(was[i])
		else:
			push_warning("%s's bag is smaller now: %s is lost." % [key, was[i]])
	var slots: Array = []
	slots.resize(size)
	slots.fill("")
	stacks.erase(key)
	inventories[key] = slots
	# Laid out from the front, as many in a slot as were.
	for i in kept.size():
		slots[i] = kept[i]
		_set_count(key, i, counts[i])


## Replaces somebody's bag outright, in the order given.
##
## Used when a battle is opened straight from the menu: what each character is
## carrying is the encounter's to decide there, rather than whatever their
## database entry lists or they happened to be holding on some map.
func set_inventory(key: String, items: Array):
	var size := bag_size(key)
	var slots: Array = []
	slots.resize(size)
	slots.fill("")
	stacks.erase(key)
	for i in mini(items.size(), size):
		if items[i] == "":
			continue
		if ItemDatabase.items.has(items[i]):
			slots[i] = items[i]
		else:
			push_warning("A spawn hands '%s' to %s, which is not in ItemDatabase." % [items[i], key])
	inventories[key] = slots
	inventory_changed.emit(key)


## Puts `item_id` in `key`'s first free slot. False if there is no such item or
## nowhere to put it - a full bag refuses rather than silently dropping it.
##
## Written to be called from a dialogue:
##
##     do Campaign.give_item("cyrus", "cure_potion")
##
## Campaign is one of the autoloads the Dialogue Manager exposes to `do` lines
## (see state_autoload_shortcuts in project.godot).
func give_item(key: String, item_id: String) -> bool:
	if not ItemDatabase.items.has(item_id):
		push_warning("Campaign.give_item('%s', '%s'): no such item." % [key, item_id])
		return false
	if not CombatantDatabase.combatants.has(key):
		push_warning("Campaign.give_item('%s', '%s'): no such character." % [key, item_id])
		return false
	if stow_item(key, item_id) < 0:
		push_warning("Campaign.give_item('%s', '%s'): their bag is full." % [key, item_id])
		return false
	var item: ItemDefinition = ItemDatabase.item(item_id)
	announce("[color=lightgreen]%s[/color] receives [color=yellow]%s[/color].\n" % [
		display_name_of(key), item.name if item != null else item_id])
	return true


## Puts `item_id` in `key`'s first free slot without a word said, and answers
## which slot - -1 when the bag is full. A bomb goes onto another of its kind
## first, where its container lets them stack. The belt comes first, so
## something put away in a fight is to hand at once if there is room: a Steal
## (Combat.steal) does its own telling. `kind` keeps it to one container.
func stow_item(key: String, item_id: String, kind: String = "") -> int:
	var slots = inventory_of(key)
	var item: ItemDefinition = ItemDatabase.item(item_id) if item_id != "" else null
	var span := _span_of(key, kind)
	if item != null and item.bomb:
		for i in range(span.x, span.y):
			if slots[i] == item_id and count_in(key, i) < holds_at(key, i, item_id):
				_set_count(key, i, count_in(key, i) + 1)
				inventory_changed.emit(key)
				return i
	for i in range(span.x, span.y):
		if slots[i] == "":
			slots[i] = item_id
			inventory_changed.emit(key)
			return i
	return -1


## Takes one `item_id` off `key`, preferring the belt so that using one in a
## fight spends the one that was to hand - or out of the container `kind` only.
## False if they had none there.
func take_item(key: String, item_id: String, kind: String = "") -> bool:
	var slots = inventory_of(key)
	var span := _span_of(key, kind)
	for i in range(span.x, span.y):
		if slots[i] == item_id:
			var count := count_in(key, i)
			if count > 1:
				_set_count(key, i, count - 1)
			else:
				slots[i] = ""
				_set_count(key, i, 0)
			inventory_changed.emit(key)
			return true
	return false


## How many are in `key`'s slot `slot`: 0 for an empty one, 1 for most, more for
## a stack of bombs.
func count_in(key: String, slot: int) -> int:
	var slots: Array = inventories.get(key, [])
	if slot < 0 or slot >= slots.size() or slots[slot] == "":
		return 0
	return stacks.get(key, {}).get(slot, 1)


func _set_count(key: String, slot: int, count: int):
	if count > 1:
		if not stacks.has(key):
			stacks[key] = {}
		stacks[key][slot] = count
	elif stacks.has(key):
		stacks[key].erase(slot)


## How many of `item_id` `key`'s slot `slot` can hold: a container's Bombs Per
## Slot for a bomb, one of anything else.
func holds_at(key: String, slot: int, item_id: String) -> int:
	var item: ItemDefinition = ItemDatabase.item(item_id) if item_id != "" else null
	if item == null or not item.bomb:
		return 1
	var piece := EquipmentDefinition.named(container_in(key, container_at(key, slot)))
	return piece.bombs_per_slot if piece != null else 1


## Moves whatever is in one slot to another, swapping if the destination is
## taken. The two slots can belong to different people, which is how the party
## hands things round: both bags are open on the same screen. A bomb onto a stack
## of its kind with room joins it; a stack into a slot that holds fewer moves
## what fits and leaves the rest, if that slot is empty, and is refused if not.
func move_item(from_key: String, from_slot: int, to_key: String, to_slot: int) -> bool:
	var from_slots = inventory_of(from_key)
	var to_slots = inventory_of(to_key)
	if from_slot < 0 or from_slot >= from_slots.size():
		return false
	if to_slot < 0 or to_slot >= to_slots.size():
		return false
	if from_key == to_key and from_slot == to_slot:
		return false
	var moving: String = from_slots[from_slot]
	var moving_count := count_in(from_key, from_slot)
	var there: String = to_slots[to_slot]
	var there_count := count_in(to_key, to_slot)
	if moving != "" and moving == there and holds_at(to_key, to_slot, moving) > 1:
		# Onto more of the same, where they stack: as many as there is room for.
		var room := holds_at(to_key, to_slot, moving) - there_count
		if room <= 0:
			return false
		var going := mini(room, moving_count)
		_set_count(to_key, to_slot, there_count + going)
		if going >= moving_count:
			from_slots[from_slot] = ""
			_set_count(from_key, from_slot, 0)
		else:
			_set_count(from_key, from_slot, moving_count - going)
	elif there == "" and moving_count > holds_at(to_key, to_slot, moving):
		# More than the slot takes: what fits goes, the rest stays.
		var going := holds_at(to_key, to_slot, moving)
		to_slots[to_slot] = moving
		_set_count(to_key, to_slot, going)
		_set_count(from_key, from_slot, moving_count - going)
	else:
		if moving_count > holds_at(to_key, to_slot, moving) or there_count > holds_at(from_key, from_slot, there):
			return false
		from_slots[from_slot] = there
		to_slots[to_slot] = moving
		_set_count(from_key, from_slot, there_count)
		_set_count(to_key, to_slot, moving_count)
	inventory_changed.emit(from_key)
	if to_key != from_key:
		inventory_changed.emit(to_key)
	return true


## What `key` can actually reach in a fight: the item ids in their belt, in
## order - one for each of a stack - with the empties left out.
func combat_items_of(key: String) -> Array:
	var found: Array = []
	var slots = inventory_of(key)
	for i in mini(combat_slots_of(key), slots.size()):
		if slots[i] == "":
			continue
		# A disguise is worn on a stealth map, not thrown at anybody, and a
		# pebble thrown there to draw a guard off does nothing in a fight.
		var item: ItemDefinition = ItemDatabase.item(slots[i])
		if item != null and item.stealth_only():
			continue
		for each in count_in(key, i):
			found.append(slots[i])
	return found


## The disguises `key` is carrying, each once, in the order they sit in the bag.
func disguises_of(key: String) -> Array:
	var found: Array = []
	for slot in inventory_of(key):
		var item: ItemDefinition = ItemDatabase.item(slot) if slot != "" else null
		if item != null and item.is_disguise() and not found.has(slot):
			found.append(slot)
	return found


## The things to throw `key` is carrying, each once, in bag order.
func distractions_of(key: String) -> Array:
	var found: Array = []
	for slot in inventory_of(key):
		var item: ItemDefinition = ItemDatabase.item(slot) if slot != "" else null
		if item != null and item.is_distraction() and not found.has(slot):
			found.append(slot)
	return found


## The darts `key` is carrying - poisons to throw - each once, in bag order.
func darts_of(key: String) -> Array:
	var found: Array = []
	for slot in inventory_of(key):
		var item: ItemDefinition = ItemDatabase.item(slot) if slot != "" else null
		if item != null and item.is_poison() and item.poison_shootable and not found.has(slot):
			found.append(slot)
	return found


## The first poison `key` is carrying that goes into food rather than a dart,
## or "".
func food_poison_of(key: String) -> String:
	for slot in inventory_of(key):
		var item: ItemDefinition = ItemDatabase.item(slot) if slot != "" else null
		if item != null and item.is_poison() and not item.poison_shootable:
			return slot
	return ""


## How many of `item_id` somebody is carrying, anywhere in their bag.
func count_of(key: String, item_id: String) -> int:
	var total = 0
	var slots = inventory_of(key)
	for i in slots.size():
		if slots[i] == item_id:
			total += count_in(key, i)
	return total


## Gives somebody an empty bag, and stops their starting kit filling it later.
##
## For a map that opens before anybody has been given anything: the crossroads
## is Cyrus at the very beginning, and the potions he is written as owning
## belong to a later part of the story. Making the bag here rather than leaving
## it unmade is the point - inventory_of() seeds an unmade one from the
## database, so "empty" has to be a bag that exists and is empty.
func empty_inventory(key: String):
	var slots: Array = []
	slots.resize(bag_size(key))
	slots.fill("")
	inventories[key] = slots
	stacks.erase(key)
	inventory_changed.emit(key)


## --- Containers ---
##
## What somebody carries things in: a backpack, which everybody has, and a pouch
## and a belt besides, if they wear them. The belt is what they fight from -
## what is in it comes into a battle; the pouch and the backpack keep the rest.
## Each is a piece of gear (EquipmentDefinition, slot Belt, Pouch or Backpack)
## with so many Slots, bought, looted and kept in the stash like any other. The
## bag (inventory_of) is the three end to end, belt first.
##
## A container worn holds what is in it; one in the stash holds nothing.
## Putting on another (wear_container) moves the contents over, or is refused
## if they will not fit. Taking a pouch or a belt off (take_off_container) moves
## what was in it into the others' free slots, backpack first, or is refused;
## the backpack can only be changed for another. Two of the party swap the
## containers of a kind, contents and all (swap_containers). A container with
## Bombs Per Slot above one holds that many of the same bomb to a slot, counted
## in `stacks`.

## The containers, in the order the bag lays them end to end.
const CONTAINER_SLOTS := ["belt", "pouch", "backpack"]
## What everybody starts out wearing.
const STARTING_BELT := "simple_belt"
const STARTING_BACKPACK := "travellers_pack"

## combatant key -> {"belt": key, "pouch": key, "backpack": key}, "" for none.
var containers: Dictionary = {}


## What `key` wears to carry things in, made if they have never had any: the
## starting belt and backpack, and no pouch.
func containers_of(key: String) -> Dictionary:
	if not containers.has(key):
		containers[key] = {"belt": STARTING_BELT, "pouch": "", "backpack": STARTING_BACKPACK}
	return containers[key]


## The container `key` wears as their `kind` ("belt", "pouch", "backpack"), or "".
func container_in(key: String, kind: String) -> String:
	return containers_of(key).get(kind, "")


## How many slots `key`'s `kind` has - 0 with none worn.
func slots_in(key: String, kind: String) -> int:
	var piece := EquipmentDefinition.named(container_in(key, kind))
	return piece.slots if piece != null else 0


## How many slots `key`'s bag has, every container's together.
func bag_size(key: String) -> int:
	var total := 0
	for kind in CONTAINER_SLOTS:
		total += slots_in(key, kind)
	return total


## How many things `key` can have to hand in a fight: their belt's slots.
func combat_slots_of(key: String) -> int:
	return slots_in(key, "belt")


## Where `kind` starts in `key`'s bag.
func container_start(key: String, kind: String) -> int:
	var start := 0
	for each in CONTAINER_SLOTS:
		if each == kind:
			return start
		start += slots_in(key, each)
	return start


## Which container `key`'s bag slot `slot` is in.
func container_at(key: String, slot: int) -> String:
	var start := 0
	for kind in CONTAINER_SLOTS:
		start += slots_in(key, kind)
		if slot < start:
			return kind
	return ""


## The slots of `kind` in `key`'s bag, as Vector2i(first, past the last) - the
## whole bag for "".
func _span_of(key: String, kind: String) -> Vector2i:
	if kind == "":
		return Vector2i(0, inventory_of(key).size())
	var start := container_start(key, kind)
	return Vector2i(start, start + slots_in(key, kind))


## What is in `key`'s `kind`, one item key for each thing - a stack of two bombs
## twice - in slot order.
func contents_of(key: String, kind: String) -> Array:
	var found: Array = []
	var slots = inventory_of(key)
	var span := _span_of(key, kind)
	for i in range(span.x, span.y):
		for each in count_in(key, i):
			found.append(slots[i])
	return found


## Whether `key`'s `kind` has an empty slot.
func has_room_in(key: String, kind: String) -> bool:
	var slots = inventory_of(key)
	var span := _span_of(key, kind)
	for i in range(span.x, span.y):
		if slots[i] == "":
			return true
	return false


## Each container's slots in `key`'s bag as [item, count], by kind.
func _segments(key: String) -> Dictionary:
	var slots = inventory_of(key)
	var found := {}
	for kind in CONTAINER_SLOTS:
		var span := _span_of(key, kind)
		var each: Array = []
		for i in range(span.x, span.y):
			each.append([slots[i], count_in(key, i)])
		found[kind] = each
	return found


## `key`'s bag laid out again from `segments` (kind -> [item, count] per slot),
## for the containers they wear now.
func _lay_out(key: String, segments: Dictionary):
	var slots: Array = []
	stacks.erase(key)
	for kind in CONTAINER_SLOTS:
		var size := slots_in(key, kind)
		var each: Array = segments.get(kind, [])
		for i in size:
			var entry: Array = each[i] if i < each.size() else ["", 0]
			slots.append(entry[0])
			if entry[0] != "":
				_set_count(key, slots.size() - 1, entry[1])
	inventories[key] = slots
	inventory_changed.emit(key)


## `entries` ([item, count] per slot) packed into `piece`: the empties dropped,
## and bombs put together as far as its Bombs Per Slot goes. Null if it all will
## not go in its slots.
func _packed(entries: Array, piece: EquipmentDefinition):
	var out: Array = []
	for entry in entries:
		if entry[0] == "":
			continue
		var item: ItemDefinition = ItemDatabase.item(entry[0])
		var most: int = piece.bombs_per_slot if item != null and item.bomb else 1
		var left: int = entry[1]
		# Onto a stack of the same with room first.
		for packed in out:
			if left <= 0:
				break
			if packed[0] == entry[0] and packed[1] < most:
				var going := mini(most - packed[1], left)
				packed[1] += going
				left -= going
		while left > 0:
			var going := mini(most, left)
			out.append([entry[0], going])
			left -= going
	if out.size() > piece.slots:
		return null
	return out


## `key` puts on `container_key`, from the stash, in place of whatever they wear
## of its kind - which goes to the stash, its contents moved over. "" when done,
## or why not.
func wear_container(key: String, container_key: String) -> String:
	var piece := EquipmentDefinition.named(container_key)
	if piece == null or not piece.is_container():
		return "That is nothing to carry things in"
	if not gear.has(container_key):
		return "%s is not in the stash" % piece.name
	if not piece.fits(key):
		return "%s is not for %s" % [piece.name, display_name_of(key)]
	var kind := piece.slot_key()
	var old := container_in(key, kind)
	var segments := _segments(key)
	var packed = _packed(segments[kind], piece)
	if packed == null:
		var was := EquipmentDefinition.named(old)
		return "%s will not hold everything in %s's %s" % [piece.name, display_name_of(key), was.name.to_lower() if was != null else kind]
	segments[kind] = packed
	gear.erase(container_key)
	if old != "":
		gear.append(old)
	containers_of(key)[kind] = container_key
	_lay_out(key, segments)
	gear_changed.emit()
	return ""


## `key` takes off their pouch or belt, back to the stash, what was in it moved
## into their other containers' free slots - the backpack's first. "" when done,
## or why not. The backpack stays: it can only be changed for another.
func take_off_container(key: String, kind: String) -> String:
	if kind == "backpack":
		return "Everybody keeps a backpack - change it for another instead"
	var old := container_in(key, kind)
	if old == "":
		return "%s wears no %s" % [display_name_of(key), kind]
	var segments := _segments(key)
	var moving: Array = segments[kind]
	segments[kind] = []
	for entry in moving:
		if entry[0] == "":
			continue
		var placed := false
		for other in ["backpack", "pouch", "belt"]:
			if other == kind or placed:
				continue
			for slot in segments[other]:
				if slot[0] == "":
					slot[0] = entry[0]
					slot[1] = entry[1]
					placed = true
					break
		if not placed:
			return "There is no room elsewhere for what is in %s's %s" % [display_name_of(key), kind]
	containers_of(key)[kind] = ""
	gear.append(old)
	_lay_out(key, segments)
	gear_changed.emit()
	return ""


## `one` and `other` swap the containers they wear as `kind`, contents and all -
## or one hands theirs to the other, who wears none. "" when done, or why not.
func swap_containers(one: String, other: String, kind: String) -> String:
	if one == other:
		return ""
	if container_in(one, kind) == "" and container_in(other, kind) == "":
		return "Neither of them wears a %s" % kind
	if kind == "backpack" and (container_in(one, kind) == "" or container_in(other, kind) == ""):
		return "Everybody keeps a backpack"
	var first := _segments(one)
	var second := _segments(other)
	var was: String = containers_of(one)[kind]
	containers_of(one)[kind] = containers_of(other)[kind]
	containers_of(other)[kind] = was
	var moving: Array = first[kind]
	first[kind] = second[kind]
	second[kind] = moving
	_lay_out(one, first)
	_lay_out(other, second)
	return ""


## --- Gear ---
##
## Weapons, armour and charms (EquipmentDefinition): one of each per character,
## worn, and the rest kept in a stash the whole party shares. Spent on nothing
## and never used up, unlike what is in the bags.

## Pieces owned and not being worn, by key - the same key twice for two of them.
var gear: Array = []
## combatant key -> {"weapon": key, "armour": key, "charm": key}, "" for empty.
var equipped: Dictionary = {}

## Somebody's gear, or the stash, changed.
signal gear_changed


## Puts `key` in the stash. Written to be called from a dialogue:
##
##     do Campaign.give_gear("fencers_rapier")
func give_gear(key: String) -> bool:
	var piece := EquipmentDefinition.named(key)
	if piece == null:
		push_warning("Campaign.give_gear('%s'): no such piece." % key)
		return false
	gear.append(key)
	announce("The party receives [color=yellow]%s[/color].\n" % piece.name)
	gear_changed.emit()
	return true


## What `character` has in `slot` ("weapon", "armour", "charm"), or "".
func equipped_in(character: String, slot: String) -> String:
	return equipped.get(character, {}).get(slot, "")


## Puts `key`, from the stash, on `character` - whatever was in that slot goes
## back to the stash. False if it is not in the stash or not theirs to use.
func equip(character: String, key: String) -> bool:
	var piece := EquipmentDefinition.named(key)
	if piece == null or not gear.has(key) or not piece.fits(character):
		return false
	# Something to carry things in, with what is in it (see "Containers").
	if piece.is_container():
		return wear_container(character, key) == ""
	if not equipped.has(character):
		equipped[character] = {}
	var slot := piece.slot_key()
	var was: String = equipped[character].get(slot, "")
	gear.erase(key)
	if was != "":
		gear.append(was)
	equipped[character][slot] = key
	gear_changed.emit()
	return true


## Takes off whatever `character` has in `slot`, back to the stash.
func unequip(character: String, slot: String) -> bool:
	if slot in CONTAINER_SLOTS:
		return take_off_container(character, slot) == ""
	var was := equipped_in(character, slot)
	if was == "":
		return false
	equipped[character][slot] = ""
	gear.append(was)
	gear_changed.emit()
	return true


## What in the stash `character` could put in `slot`, each once, in stash order.
func gear_for(character: String, slot: String) -> Array:
	var found := []
	for key in gear:
		var piece := EquipmentDefinition.named(key)
		if piece != null and piece.slot_key() == slot and piece.fits(character) and not found.has(key):
			found.append(key)
	return found


## --- Gold ---
##
## What the party has to spend, all of it in one purse. Earned from fights won
## in the story (EncounterDefinition.gold_reward) and from whatever hands it
## out (`do Campaign.give_gold(30)`), and spent in stores (StoreDefinition).

var gold: int = 0

## The purse changed. Carries how much is in it now.
signal gold_changed(gold: int)

## A store was asked for (open_store) - the map puts it up once nothing else is
## going on.
signal store_requested(store: String)


## Adds `amount` to the purse, and says so.
func give_gold(amount: int):
	if amount <= 0:
		return
	gold += amount
	announce("The party receives [color=gold]%d gold[/color].\n" % amount)
	gold_changed.emit(gold)


## Takes `amount` out of the purse. False, and nothing taken, if there is not
## that much in it.
func spend_gold(amount: int) -> bool:
	if amount < 0 or amount > gold:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true


## Asks for `store` to be opened. Written to be called from a conversation:
##
##     do Campaign.open_store("travelling_merchant")
func open_store(store: String):
	if StoreDefinition.named(store) == null:
		push_warning("Campaign.open_store('%s'): no such store." % store)
		return
	store_requested.emit(store)


## What `key` costs - an item or a piece of gear - or 0 for something no store
## deals in.
func price_of(key: String) -> int:
	var item: ItemDefinition = ItemDatabase.item(key) if ItemDatabase.is_item(key) else null
	if item != null:
		return item.price
	var piece := EquipmentDefinition.named(key)
	return piece.price if piece != null else 0


## What selling `key` to `store` gets: its price at the store's rate, rounded
## down. 0 when the store does not buy, or the thing is worth nothing.
func sell_price(store: StoreDefinition, key: String) -> int:
	if store == null or not store.buys_back:
		return 0
	return int(floor(price_of(key) * store.sell_rate))


## Why `key` cannot be bought from `store` right now, or "" when it can. An item
## needs somebody in the party with room in their bag.
func cannot_buy(store: StoreDefinition, key: String) -> String:
	if store == null or not store.stock.has(key):
		return "Not sold here"
	var price := price_of(key)
	if price <= 0:
		return "Not for sale"
	if price > gold:
		return "Not enough gold"
	if ItemDatabase.is_item(key) and _who_has_room() == "":
		return "Nobody has room for it"
	return ""


## Buys `key` from `store`: gold out, and the thing into the bag of the first
## of the party with room (leader first) - or the gear stash. "" when it went
## through, or why not.
func buy(store: StoreDefinition, key: String) -> String:
	var refusal := cannot_buy(store, key)
	if refusal != "":
		return refusal
	spend_gold(price_of(key))
	if ItemDatabase.is_item(key):
		var who := _who_has_room()
		stow_item(who, key)
		var item: ItemDefinition = ItemDatabase.item(key)
		announce("[color=lightgreen]%s[/color] buys [color=yellow]%s[/color].\n" % [display_name_of(who), item.name])
	else:
		gear.append(key)
		gear_changed.emit()
		announce("The party buys [color=yellow]%s[/color].\n" % EquipmentDefinition.named(key).name)
	return ""


## Sells one `key` out of `character`'s bag to `store`. False if they have none,
## or the store will not have it.
func sell_item(store: StoreDefinition, character: String, key: String) -> bool:
	var paid := sell_price(store, key)
	if paid <= 0 or count_of(character, key) == 0:
		return false
	take_item(character, key)
	gold += paid
	gold_changed.emit(gold)
	return true


## Sells one `key` out of the gear stash to `store`. What is being worn is not in
## the stash, so it cannot be sold from under somebody.
func sell_gear(store: StoreDefinition, key: String) -> bool:
	var paid := sell_price(store, key)
	if paid <= 0 or not gear.has(key):
		return false
	gear.erase(key)
	gold += paid
	gear_changed.emit()
	gold_changed.emit(gold)
	return true


## The first of the living party, leader first, with a free slot - or "".
func _who_has_room() -> String:
	for key in living_party():
		if inventory_of(key).has(""):
			return key
	return ""


## --- Clues ---
##
## What the party has found out, kept in the journal (J). Stored as flags -
## "clue:ledger_count", holding the order it was learned in - so they last
## exactly as long as every other fact about the playthrough: across maps and
## fights, back to where they were on Restart Stage, gone on a fresh start.
## Dialogue can ask `if Campaign.knows_clue("ledger_count")`.

## Learned a clue: `deduced` when it was worked out in the journal rather than
## found.
signal clue_learned(key: String, deduced: bool)

const CLUE_PREFIX := "clue:"


## Learns the clue `key` (see ClueDefinition), setting its flag. False if there
## is no such clue or it was known already.
func learn_clue(key: String) -> bool:
	var clue: ClueDefinition = ClueBook.clue(key)
	if clue == null:
		push_warning("Campaign.learn_clue('%s'): there is no such clue in %s." % [key, ClueBook.FOLDER])
		return false
	if knows_clue(key):
		return false
	flags[CLUE_PREFIX + key] = known_clues().size() + 1
	if clue.sets_flag != "":
		set_flag(clue.sets_flag)
	clue_learned.emit(key, clue.is_deduction())
	return true


func knows_clue(key: String) -> bool:
	return flag(CLUE_PREFIX + key)


## Every clue learned, in the order it was.
func known_clues() -> Array:
	var found: Array = []
	for flag_name in flags:
		if String(flag_name).begins_with(CLUE_PREFIX) and flag(flag_name):
			found.append(String(flag_name).trim_prefix(CLUE_PREFIX))
	found.sort_custom(func(a, b): return int(flags[CLUE_PREFIX + a]) < int(flags[CLUE_PREFIX + b]))
	return found


## Connects two clues the way the journal's Connect does: the deduction they
## make, learned if it was not already, or "" for two that make nothing.
func connect_clues(a: String, b: String) -> String:
	if not knows_clue(a) or not knows_clue(b):
		return ""
	var deduced = ClueBook.deduced_from(a, b)
	if deduced != "":
		learn_clue(deduced)
	return deduced


## Whether something known opens `combatant_key`'s sheet from the start of a
## fight (ClueDefinition.reveals_combatants).
func clue_reveals(combatant_key: String) -> bool:
	for key in known_clues():
		var clue: ClueDefinition = ClueBook.clue(key)
		if clue != null and clue.reveals_combatants.has(combatant_key):
			return true
	return false


## Whether something known tells the party about `faction` (FactionDefinition,
## ClueDefinition.reveals_factions) - or one of them told them, questioned
## (learn_faction).
func knows_faction(faction: String) -> bool:
	if faction == "":
		return false
	if flag(FACTION_PREFIX + faction):
		return true
	for key in known_clues():
		var clue: ClueDefinition = ClueBook.clue(key)
		if clue != null and clue.reveals_factions.has(faction):
			return true
	return false


## --- What has been looked at ---
##
## Which hotspots in which pictures have been clicked, so a picture can say how
## much of it has been gone over and mark what has. Flags again, for the same
## reasons as clues: "seen:" and the hotspot's place.

const SEEN_PREFIX := "seen:"


func mark_examined(id: String):
	if id != "":
		flags[SEEN_PREFIX + id] = true


func was_examined(id: String) -> bool:
	return flag(SEEN_PREFIX + id)


## --- Putting things together ---


## The item `a` and `b` make together (ItemDefinition.made_from), either way
## round, or "".
func combination_of(a: String, b: String) -> String:
	for key in ItemDatabase.items:
		var item: ItemDefinition = ItemDatabase.items[key]
		if item == null or item.made_from.size() != 2:
			continue
		var wanted: Array = item.made_from.duplicate()
		if wanted.has(a):
			wanted.erase(a)
			if wanted.has(b):
				return key
	return ""


## Who in the party is carrying `item_id`, or "".
func carrier_of(item_id: String) -> String:
	for key in living_party():
		if count_of(key, item_id) > 0:
			return key
	return ""


## Puts `a` and `b` together, wherever in the party they are: both used up and
## what they make handed to whoever carried `b`. The item made, or "" if they
## make nothing or the party does not have both.
func combine_items(a: String, b: String) -> String:
	var made = combination_of(a, b)
	if made == "":
		return ""
	var has_a = carrier_of(a)
	if has_a == "":
		return ""
	take_item(has_a, a)
	var has_b = carrier_of(b)
	if has_b == "":
		give_item(has_a, a)
		return ""
	take_item(has_b, b)
	give_item(has_b, made)
	return made


## The same from two bag slots (the inventory, I): both emptied, and what they
## make put in the second. "" - and nothing moved - if they make nothing.
func combine_slots(from_key: String, from_slot: int, to_key: String, to_slot: int) -> String:
	var from_slots = inventory_of(from_key)
	var to_slots = inventory_of(to_key)
	if from_slot < 0 or from_slot >= from_slots.size() or to_slot < 0 or to_slot >= to_slots.size():
		return ""
	if from_key == to_key and from_slot == to_slot:
		return ""
	var made = combination_of(from_slots[from_slot], to_slots[to_slot])
	# One of a stack makes one thing: the stack it went onto would have to go
	# all at once, so that is not done.
	if made == "" or count_in(to_key, to_slot) > 1:
		return ""
	if count_in(from_key, from_slot) > 1:
		_set_count(from_key, from_slot, count_in(from_key, from_slot) - 1)
	else:
		from_slots[from_slot] = ""
	to_slots[to_slot] = made
	inventory_changed.emit(from_key)
	if to_key != from_key:
		inventory_changed.emit(to_key)
	var item: ItemDefinition = ItemDatabase.item(made)
	announce("[color=lightgreen]%s[/color] makes [color=yellow]%s[/color].\n" % [
		display_name_of(to_key), item.name if item != null else made])
	return made


## Somebody in the party with room for one more, for something picked up: the
## leader first. "" if every bag is full.
func room_for_one() -> String:
	var order: Array = living_party()
	var first = leader()
	if order.has(first):
		order.erase(first)
		order.push_front(first)
	for key in order:
		if inventory_of(key).has(""):
			return key
	return ""


## --- Dealing with enemies ---
##
## What a conversation in front of a fight agreed (parley), and what the party
## has learned that can be used against them.
##
## A parley is a dialogue on an EncounterInteractable whose branches say what
## was agreed before accepting the fight - or calling it off:
##
##     - "We know who pays you." [if Campaign.knows_clue("ledger") /]
##         do Campaign.parley_remove("barbarian", 2)
##         do Campaign.accept_encounter()
##     - Pay the archers off [if Campaign.can_afford_bribe("ranger") /]
##         do Campaign.bribe("ranger")
##         do Campaign.accept_encounter()
##     - "Walk away. Nobody needs to die."
##         do Campaign.parley_call_off()
##
## The agreement is applied as the next fight is laid out (Combat._ready takes
## it), and dropped if the party backs away from the fight instead.

## What was agreed for the next fight: "removed" (key -> how many stay out of
## it), "switched" (key -> how many fight for the party), "surprised", and
## "called_off".
var parley: Dictionary = {}

## Paying somebody to change sides costs this many times their price.
const SWITCH_PRICE := 2
## Flags: a faction learned by questioning, and leverage on a kind of enemy.
const FACTION_PREFIX := "faction_known:"
const LEVERAGE_PREFIX := "leverage:"


## The fight is called off: the trigger is cleared as if it had been won.
func parley_call_off():
	parley["called_off"] = true


## `count` of the `key` enemies stay out of the next fight.
func parley_remove(key: String, count: int = 1):
	var removed: Dictionary = parley.get("removed", {})
	removed[key] = removed.get(key, 0) + count
	parley["removed"] = removed


## The next fight starts with every enemy caught off guard.
func parley_surprise():
	parley["surprised"] = true


## What buying one `key` enemy costs: out of the fight, or onto the party's side.
## 0 for somebody who cannot be bought.
func bribe_price_of(key: String, switching: bool = false) -> int:
	var definition: CombatantDefinition = CombatantDatabase.combatants.get(key)
	if definition == null or definition.bribe_price <= 0:
		return 0
	return definition.bribe_price * (SWITCH_PRICE if switching else 1)


func can_afford_bribe(key: String, switching: bool = false) -> bool:
	var price := bribe_price_of(key, switching)
	return price > 0 and gold >= price


## Buys one `key` enemy out of the next fight - or, `switching`, onto the
## party's side for it. False, and nothing paid, without the gold.
func bribe(key: String, switching: bool = false) -> bool:
	var price := bribe_price_of(key, switching)
	if price <= 0 or not spend_gold(price):
		return false
	if switching:
		var switched: Dictionary = parley.get("switched", {})
		switched[key] = switched.get(key, 0) + 1
		parley["switched"] = switched
	else:
		parley_remove(key)
	announce("The party pays [color=gold]%d gold[/color].\n" % price)
	return true


## What was agreed, cleared as it is read so it is only ever applied once.
func take_parley() -> Dictionary:
	var agreed := parley
	parley = {}
	return agreed


## Whether the party has something on `key` enemies to use against them: their
## faction known, one of them questioned, or one of `clues` learned.
func has_leverage_on(key: String, faction: String = "", clues: Array = []) -> bool:
	if knows_faction(faction) or flag(LEVERAGE_PREFIX + key):
		return true
	for clue in clues:
		if knows_clue(clue):
			return true
	return false


## The party knows who `faction` are, having been told.
func learn_faction(faction: String):
	if faction != "":
		set_flag(FACTION_PREFIX + faction)


## Questions a prisoner of kind `key`: whatever clues and gold they give up,
## who they answer to, and enough about their kind to use against the next of
## them. What was learned, a line each.
func interrogate(key: String) -> Array:
	var learned := []
	var definition: CombatantDefinition = CombatantDatabase.combatants.get(key)
	if definition == null:
		return learned
	for clue_key in definition.interrogation_clues:
		if learn_clue(clue_key):
			var clue: ClueDefinition = ClueBook.clue(clue_key)
			learned.append("A clue: %s" % (clue.title if clue != null else clue_key))
	if definition.faction != "" and not knows_faction(definition.faction):
		learn_faction(definition.faction)
		var faction: FactionDefinition = FactionDefinition.named(definition.faction)
		learned.append("Who they answer to: %s" % (faction.name if faction != null else definition.faction.capitalize()))
	if definition.interrogation_gold > 0 and not flag("stash_told:" + key):
		set_flag("stash_told:" + key)
		give_gold(definition.interrogation_gold)
		learned.append("Where they stashed their pay: %d gold" % definition.interrogation_gold)
	if not flag(LEVERAGE_PREFIX + key):
		set_flag(LEVERAGE_PREFIX + key)
		learned.append("Enough about their kind to use against the next of them")
	return learned


## What becomes of a questioned prisoner: let go, or handed over to the watch.
## Counted, for conversations to read: prisoners_released, prisoners_handed_over.
func release_prisoner(key: String, handed_over: bool = false, how_many: int = 1):
	var counter := "prisoners_handed_over" if handed_over else "prisoners_released"
	flags[counter] = int(flags.get(counter, 0)) + how_many
	set_flag(("handed_over:" if handed_over else "released:") + key)


## --- The last fight ---
##
## How the fight just over went, for the conversation after it (an encounter's
## Victory Dialogue - with Dialogue Decides Prisoners ticked, it is that
## conversation that decides what becomes of them). Written by Combat as the
## fight ends; never saved, since nothing can come between the two.
##
##     if Campaign.taken_alive("sellsword") > 0
##     - Ask who paid them [if not Campaign.questioned("sellsword") /]
##         do Campaign.question("sellsword")
##     - Let them go
##         do Campaign.let_go()
##     - Hand them to the watch
##         do Campaign.hand_over()
##
## Every key is a combatant key; "" means everybody.

## {"taken": {key: count}, "got_away": {...}, "fell": {...}, "questioned": {key: true}}.
var last_fight: Dictionary = {}


## Writes down how the fight went from everybody who was in it (Combat).
func record_last_fight(fighters: Array):
	var taken := {}
	var got_away := {}
	var fell := {}
	for comb in fighters:
		if comb.has("object") or comb.get("illusion", false) or comb.has("turncoat"):
			continue
		var key: String = comb.get("combatant_key", "")
		var how: String = comb.get("taken", "")
		if how in ["surrendered", "knocked_out"]:
			taken[key] = taken.get(key, 0) + 1
		elif how == "fled":
			got_away[key] = got_away.get(key, 0) + 1
		elif not comb.get("alive", true) and how == "":
			fell[key] = fell.get(key, 0) + 1
	last_fight = {"taken": taken, "got_away": got_away, "fell": fell, "questioned": {}}


static func _count(table: Dictionary, key: String) -> int:
	if key != "":
		return int(table.get(key, 0))
	var total := 0
	for each in table:
		total += int(table[each])
	return total


## How many of `key` were taken alive in the last fight - surrendered or
## knocked out - and are still the party's to deal with.
func taken_alive(key: String = "") -> int:
	return _count(last_fight.get("taken", {}), key)


## How many of `key` got away from the last fight.
func got_away(key: String = "") -> int:
	return _count(last_fight.get("got_away", {}), key)


## How many of `key` fell in the last fight and were not taken alive - the
## party's own included.
func fell(key: String = "") -> int:
	return _count(last_fight.get("fell", {}), key)


## Whether one of `key` has been questioned since the last fight.
func questioned(key: String) -> bool:
	return last_fight.get("questioned", {}).has(key)


## Questions one of `key` taken in the last fight (interrogate): whatever they
## give up is said in the corner, as the questioning panel would show it. True
## when there was one to question and they gave something up.
func question(key: String) -> bool:
	if taken_alive(key) <= 0:
		return false
	last_fight.get("questioned", {})[key] = true
	var learned := interrogate(key)
	for line in learned:
		announce("[color=yellow]%s[/color]\n" % line)
	return not learned.is_empty()


## Lets `how_many` of `key` taken in the last fight go (-1: all of them; "":
## every kind), as release_prisoner counts it.
func let_go(key: String = "", how_many: int = -1):
	_deal_with(key, how_many, false)


## Hands `how_many` of `key` taken in the last fight to the watch (-1: all of
## them; "": every kind), as release_prisoner counts it.
func hand_over(key: String = "", how_many: int = -1):
	_deal_with(key, how_many, true)


func _deal_with(key: String, how_many: int, handed_over: bool):
	var taken: Dictionary = last_fight.get("taken", {})
	# How many are still to be dealt with, all kinds together: -1 for no limit.
	var left := how_many
	for each in (taken.keys() if key == "" else [key]):
		var there: int = int(taken.get(each, 0))
		var dealt: int = there if left < 0 else mini(left, there)
		if dealt <= 0:
			continue
		release_prisoner(each, handed_over, dealt)
		taken[each] = there - dealt
		if left > 0:
			left -= dealt
			if left == 0:
				break


## --- The enemy codex ---
##
## A page for every enemy (res://data/enemies/), written when somebody who keeps
## it (CombatantDefinition.keeps_codex - Enfina and Prometheus) studies one;
## a boss has a second page, written when one of them studies it again once it
## is past its first phase (or, with no phases, while it is staggered). How many
## pages are written is a flag, codex:<key>, so the codex rides along with every
## save. The Journal shows it (its Codex tab), the pages worked out by CodexPage.

const CODEX_PREFIX := "codex:"

## A page of the codex was written.
signal codex_written(key: String, page: int)

var _codex_enemies: Array = []


## Every enemy the codex has a page for, by key, in the order of their names.
func codex_enemies() -> Array:
	if _codex_enemies.is_empty():
		var found := DataFolder.read(DataFolder.ENEMIES, CombatantDefinition)
		_codex_enemies = found.keys()
		_codex_enemies.sort_custom(func(a, b): return String(found[a].name).naturalnocasecmp_to(found[b].name) < 0)
	return _codex_enemies


## How many of `key`'s pages are written: 0, 1 or 2.
func codex_pages(key: String) -> int:
	return int(flags.get(CODEX_PREFIX + key, 0))


## Writes `key`'s page `page` - the first, or a boss's second once the first is
## written. False when it already was, or cannot be yet.
func write_codex(key: String, page: int) -> bool:
	if not codex_enemies().has(key) or page != codex_pages(key) + 1:
		return false
	var definition: CombatantDefinition = CombatantDatabase.combatants.get(key)
	if definition == null or page > CodexPage.pages_of(definition):
		return false
	flags[CODEX_PREFIX + key] = page
	codex_written.emit(key, page)
	announce("[color=yellow]The codex: %s%s.[/color]\n" % [definition.name, ", a second page" if page == 2 else " written up"])
	return true


## Whether questioning one of `key`'s kind would give anything up now: a
## conversation of their own, a clue or a stash not yet had, who they answer to
## not yet known, or leverage on their kind not yet gained.
func has_something_to_tell(key: String) -> bool:
	var definition: CombatantDefinition = CombatantDatabase.combatants.get(key)
	if definition == null:
		return false
	if definition.interrogation_dialogue != null or not flag(LEVERAGE_PREFIX + key):
		return true
	if definition.interrogation_gold > 0 and not flag("stash_told:" + key):
		return true
	if definition.faction != "" and not knows_faction(definition.faction):
		return true
	for clue_key in definition.interrogation_clues:
		if not knows_clue(clue_key):
			return true
	return false
