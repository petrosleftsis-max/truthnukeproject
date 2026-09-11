extends Node
## Autoload. The state that outlives a single battle: which encounter is being
## fought, and what condition the player's party is in.
##
## The party carries damage forward between encounters, so a battle won at
## great cost leaves you weaker for the next one. Nothing here is saved to
## disk - it lasts for the session, and "Reset Party" on the level select
## wipes it back to full strength.


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
	return true


func has_member(key: String) -> bool:
	return party_order.has(key)


## Emitted whenever the roster changes, so anything showing the party (the
## exploration line, the portrait column) can redraw itself without polling.
signal party_changed()


## What the HUD needs to draw the party: one entry per living member, leader
## first. hp comes from what they carried out of the last battle, so the
## portraits show real wear rather than everyone at full health.
func party_members() -> Array:
	var members: Array = []
	for key in living_party():
		var definition: CombatantDefinition = CombatantDatabase.combatants.get(key)
		if definition == null:
			continue
		var hp = definition.max_hp
		var max_hp = definition.max_hp
		if party_state.has(key):
			hp = party_state[key].hp
			# What they were last fielded with, so the bar reads against the
			# health they actually had rather than their level 1 figure.
			max_hp = party_state[key].get("max_hp", definition.max_hp)
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
	current_encounter = encounter
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
func finish_battle_from_exploration(won: bool):
	if won and _pending_trigger != "":
		cleared_triggers[_pending_trigger] = true
	_pending_trigger = ""


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
	# Clamped, because the health carried out of one fight can exceed what this
	# one allows: walking a level 3 survivor into a battle that fields them at
	# level 1 should not start them above full.
	comb.hp = mini(stored.hp, comb.max_hp)
	comb.alive = stored.alive


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
		if comb.side != 0:
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


## Back to full strength: everyone alive, everyone at full health, every
## encounter trigger in the world armed again, and the marching order back to
## however the starting party is configured.
func reset():
	party_state.clear()
	cleared_triggers.clear()
	party_order.clear()
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
