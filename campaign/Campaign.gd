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
	comb.hp = stored.hp
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
			"alive": comb.alive,
		}


## Back to full strength: everyone alive, everyone at full health, and every
## encounter trigger in the world armed again.
func reset():
	party_state.clear()
	cleared_triggers.clear()


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
			var max_hp = definition.max_hp if definition != null else stored.hp
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
