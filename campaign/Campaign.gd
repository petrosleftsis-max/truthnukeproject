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


## --- Paths ---
##
## At level 5 (Stats.SUBCLASS_LEVEL) each of the party chooses one of their
## paths - SubclassDefinition, three each - once and for good. Combat puts them
## on it (Combat.take_path); the map asks for the choice (SubclassPicker).

## combatant key -> the key of the path they chose.
var subclasses: Dictionary = {}

## Whether a party at level 5 or past it is asked on the map to choose paths at
## all. On in the game. The test harness turns it off (game/asks_for_paths in
## its copy's project settings) so suites about other things are not stopped by
## the choice; the suites about paths turn it back on.
var asks_for_paths: bool = ProjectSettings.get_setting("game/asks_for_paths", true)

## Somebody chose their path.
signal subclass_chosen(key: String, subclass: String)


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
const SAVED := ["party_level", "party_state", "subclasses", "inventories", "gear", "equipped",
	"gold", "flags", "cleared_triggers", "stealth_state", "dungeon_stage", "gate_recoveries_left", "gates_spent_outside",
	"parley"]


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
	# Brought back from falling, and weaker for it for good (Combat.weaken) -
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
	var spent: Array = gates_spent_outside.get(key, [0, 0, 0, 0]).duplicate()
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
		# Somebody bought or rebound fought beside them, but is not one of them.
		if comb.side != 0 or comb.has("turncoat"):
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
		if in_dungeon():
			party_state[key]["spell_slots"] = comb.get("spell_slots", []).duplicate()
			party_state[key]["max_spell_slots"] = comb.get("max_spell_slots", []).duplicate()


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
	parley = {}
	_encounter_answer = EncounterAnswer.UNANSWERED
	party_state.clear()
	cleared_triggers.clear()
	stealth_state.clear()
	stealth_checkpoint = {}
	party_order.clear()
	party_level = 1
	subclasses.clear()
	gear.clear()
	gold = 0
	equipped.clear()
	inventories.clear()
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


## Everyone back to full health - and, if the dungeon says so, back on their
## feet. What they carry is left as it is.
func rest_party():
	for key in party_order:
		if not party_state.has(key):
			continue
		var state: Dictionary = party_state[key]
		if not state.alive and (dungeon == null or not dungeon.rest_revives):
			continue
		state.hp = state.get("max_hp", state.hp)
		state.alive = true


## Whether a rest can bring `key`'s gates back now: the dungeon offers it for
## them, there is a recovery left to use, and something has been spent.
func can_recover_gates(key: String) -> bool:
	if dungeon == null or gate_recoveries_left <= 0 or not dungeon.gate_recovery_for.has(key):
		return false
	if not party_order.has(key) or not party_state.has(key) or not party_state[key].has("spell_slots"):
		return false
	var left := gates_left(key)
	var most := gates_most(key)
	for gate in range(1, most.size()):
		if dungeon.gate_cost(gate) > 0 and left[gate] < most[gate]:
			return true
	return false


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
	return definition.gates_at(party_level) if definition != null else [0, 0, 0, 0]


## What bringing back `counts` castings - one count per gate - costs.
func gate_recovery_cost(counts: Array) -> int:
	var cost := 0
	for gate in counts.size():
		cost += maxi(counts[gate], 0) * (dungeon.gate_cost(gate) if dungeon != null else 0)
	return cost


## Brings back `counts` of `key`'s castings, one count per gate, spending one
## of the run's recoveries. Refused, and nothing changed, if it costs more than
## a recovery has to spend, brings back more than was spent, or none is left.
func recover_gates(key: String, counts: Array) -> bool:
	if not can_recover_gates(key):
		return false
	var cost := gate_recovery_cost(counts)
	if cost <= 0 or cost > dungeon.gate_recovery_points:
		return false
	var left := gates_left(key)
	var most := gates_most(key)
	for gate in counts.size():
		if counts[gate] < 0 or (counts[gate] > 0 and (gate >= left.size() or left[gate] + counts[gate] > most[gate])):
			return false
	for gate in counts.size():
		if counts[gate] > 0:
			left[gate] += counts[gate]
	party_state[key]["spell_slots"] = left
	gate_recoveries_left -= 1
	return true


## --- Inventories ---
##
## A bag per character rather than one shared pool, so who is carrying the last
## potion is a real question. Everyone in the party can reach everyone else's
## outside a fight (see the inventory screen on I); in a battle a character has
## only what is in their own first four slots.


## How much anybody can carry. Slots rather than a growing list so a bag has a
## shape on screen and "full" means something.
const INVENTORY_SIZE := 12

## The slots that come with you into a fight. They are the front of the same
## bag rather than a separate pocket, so packing for a battle is a decision
## made with the inventory screen before walking into one.
const COMBAT_SLOTS := 4

## combatant_key -> Array[String] of exactly INVENTORY_SIZE entries, "" where
## the slot is empty. Empty slots are kept rather than compacted away so an
## item stays where it was put.
var inventories: Dictionary = {}


## Somebody's bag, made if they have never had one.
func inventory_of(key: String) -> Array:
	if not inventories.has(key):
		var slots: Array = []
		slots.resize(INVENTORY_SIZE)
		slots.fill("")
		# Empty. A bag is filled by something that happens - an encounter's
		# spawn list handing one out in Arena Mode, or a dialogue giving
		# somebody something - never by simply existing. Walking onto a map
		# used to grant a character their database kit, which meant every
		# exploration started with a satchel nobody had been given.
		inventories[key] = slots
	return inventories[key]


## Replaces somebody's bag outright, in the order given.
##
## Used when a battle is opened straight from the menu: what each character is
## carrying is the encounter's to decide there, rather than whatever their
## database entry lists or they happened to be holding on some map.
func set_inventory(key: String, items: Array):
	var slots: Array = []
	slots.resize(INVENTORY_SIZE)
	slots.fill("")
	for i in mini(items.size(), INVENTORY_SIZE):
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
	announce("[color=lightgreen]%s[/color] receives [color=yellow]%s[/color].
" % [
		display_name_of(key), item.name if item != null else item_id])
	return true


## Puts `item_id` in `key`'s first free slot without a word said, and answers
## which slot - -1 when the bag is full. The front slots come first, so
## something put away in a fight is to hand at once if there is room: a Steal
## (Combat.steal) does its own telling.
func stow_item(key: String, item_id: String) -> int:
	var slots = inventory_of(key)
	for i in slots.size():
		if slots[i] == "":
			slots[i] = item_id
			inventory_changed.emit(key)
			return i
	return -1


## Takes one `item_id` off `key`, preferring the combat slots so that using one
## in a fight spends the one that was to hand. False if they had none.
func take_item(key: String, item_id: String) -> bool:
	var slots = inventory_of(key)
	for i in slots.size():
		if slots[i] == item_id:
			slots[i] = ""
			inventory_changed.emit(key)
			return true
	return false


## Moves whatever is in one slot to another, swapping if the destination is
## taken. The two slots can belong to different people, which is how the party
## hands things round: both bags are open on the same screen.
func move_item(from_key: String, from_slot: int, to_key: String, to_slot: int) -> bool:
	var from_slots = inventory_of(from_key)
	var to_slots = inventory_of(to_key)
	if from_slot < 0 or from_slot >= from_slots.size():
		return false
	if to_slot < 0 or to_slot >= to_slots.size():
		return false
	if from_key == to_key and from_slot == to_slot:
		return false
	var moving = from_slots[from_slot]
	from_slots[from_slot] = to_slots[to_slot]
	to_slots[to_slot] = moving
	inventory_changed.emit(from_key)
	if to_key != from_key:
		inventory_changed.emit(to_key)
	return true


## What `key` can actually reach in a fight: the item ids in their first
## COMBAT_SLOTS slots, in order, with the empties left out.
func combat_items_of(key: String) -> Array:
	var found: Array = []
	var slots = inventory_of(key)
	for i in mini(COMBAT_SLOTS, slots.size()):
		if slots[i] == "":
			continue
		# A disguise is worn on a stealth map, not thrown at anybody, and a
		# pebble thrown there to draw a guard off does nothing in a fight.
		var item: ItemDefinition = ItemDatabase.item(slots[i])
		if item != null and item.stealth_only():
			continue
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
	for slot in inventory_of(key):
		if slot == item_id:
			total += 1
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
	slots.resize(INVENTORY_SIZE)
	slots.fill("")
	inventories[key] = slots
	inventory_changed.emit(key)


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
	if made == "":
		return ""
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
