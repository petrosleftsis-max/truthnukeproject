extends RefCounted
class_name SaveGame
## Saving a playthrough to disk and putting it back.
##
## Three slots the player saves to from the pause menu, anywhere on a map that
## is not a stealth map - never in a fight, and never partway through sneaking.
## And three automatic saves, one made just before each fight starts, the
## oldest written over each time (autosave_before_fight): a fight lost, and
## the moment before it is there to go back to.
##
## What is saved is Campaign.snapshot - everything a run has come to, and where
## on which map the party stood - written as Godot's own text format
## (var_to_str), which keeps a Vector2 a Vector2. Loading is Campaign.restore.

const DIR := "user://saves/"
const MANUAL_SLOTS := ["slot_1", "slot_2", "slot_3"]
const AUTO_SLOTS := ["auto_1", "auto_2", "auto_3"]
## Bumped if what a save holds changes in a way an older one cannot be read as.
const VERSION := 1


static func path_of(slot: String) -> String:
	return DIR + slot + ".save"


## Why the game cannot be saved right now, or "" when it can: only on a map
## (not in a fight, not on a menu, not in a story screen), not a stealth one,
## and with nothing else going on.
static func why_not(tree: SceneTree) -> String:
	var scene = tree.current_scene if tree != null else null
	if scene == null or not scene is ExplorationScene:
		return "The game can only be saved on a map, not in a fight."
	if scene.stealth != null:
		return "The game cannot be saved while sneaking."
	if scene.is_holding() or scene.picker != null or scene.store_screen != null:
		return "Finish what is going on first."
	if SceneTransition.is_changing():
		return "Wait until the scene has changed."
	return ""


## Saves to `slot` from wherever the party is standing. False if it cannot be
## saved now (why_not) or could not be written.
static func save(slot: String, tree: SceneTree) -> bool:
	if why_not(tree) != "":
		return false
	var scene: ExplorationScene = tree.current_scene
	return write(slot, Campaign.snapshot(scene.map_path(), scene.party_position()), "manual")


## The moment before a fight starts, into whichever automatic slot is empty or
## oldest. `state` is Campaign.snapshot of where the fight was started from.
static func autosave_before_fight(state: Dictionary) -> String:
	var slot: String = AUTO_SLOTS[0]
	var oldest := INF
	for each in AUTO_SLOTS:
		if not exists(each):
			slot = each
			break
		var when: float = summary(each).get("saved_at", 0.0)
		if when < oldest:
			oldest = when
			slot = each
	return slot if write(slot, state, "auto") else ""


## Writes `state` to `slot`, with what the load list shows about it.
static func write(slot: String, state: Dictionary, kind: String) -> bool:
	DirAccess.make_dir_recursive_absolute(DIR)
	var file := FileAccess.open(path_of(slot), FileAccess.WRITE)
	if file == null:
		push_warning("SaveGame: could not write %s (%s)." % [path_of(slot), error_string(FileAccess.get_open_error())])
		return false
	var data := {"version": VERSION, "meta": _meta_for(state, kind), "state": state}
	file.store_string(var_to_str(data))
	file.close()
	return true


## What a save says about itself, for the list.
static func _meta_for(state: Dictionary, kind: String) -> Dictionary:
	var order: Array = state.get("party_order", [])
	var place := _place_name(state.get("map", ""))
	if state.get("dungeon", "") != "":
		var dungeon = load(state.dungeon)
		if dungeon != null:
			place = "%s - %s" % [dungeon.display_name, place] if place != "" else dungeon.display_name
	return {
		"kind": kind,
		"saved_at": Time.get_unix_time_from_system(),
		"when": Time.get_datetime_string_from_system(false, true),
		"leader": Campaign.display_name_of(order[0]) if not order.is_empty() else "",
		"level": state.get("party_level", 1),
		"gold": state.get("gold", 0),
		"place": place,
	}


## "Laboratory" from "res://maps/laboratory_explore.tscn".
static func _place_name(map: String) -> String:
	if map == "":
		return ""
	return map.get_file().get_basename().trim_suffix("_explore").replace("_", " ").capitalize()


## Everything in `slot`, or {} if there is nothing there it can read.
static func read(slot: String) -> Dictionary:
	if not FileAccess.file_exists(path_of(slot)):
		return {}
	var text := FileAccess.get_file_as_string(path_of(slot))
	var data = str_to_var(text)
	if not data is Dictionary or data.get("version", 0) != VERSION or not data.get("state") is Dictionary:
		return {}
	return data


static func exists(slot: String) -> bool:
	return not read(slot).is_empty()


## What the list shows about `slot`, or {} for an empty one.
static func summary(slot: String) -> Dictionary:
	return read(slot).get("meta", {})


## The most recently written slot of all six, or "" if there are none.
static func latest() -> String:
	var found := ""
	var newest := -1.0
	for slot in AUTO_SLOTS + MANUAL_SLOTS:
		var when: float = summary(slot).get("saved_at", -1.0)
		if when > newest:
			newest = when
			found = slot
	return found


## Puts the playthrough in `slot` back and goes to where it was saved. False if
## there is nothing there to load.
static func load_slot(slot: String) -> bool:
	var data := read(slot)
	if data.is_empty():
		return false
	Campaign.restore(data.state)
	return true


## How a slot reads in a list: "Slot 1 - Cyrus, level 10, Laboratory - 2026-10-08 14:03".
static func describe(slot: String) -> String:
	var title := ("Autosave %s" if slot.begins_with("auto_") else "Slot %s") % slot.get_slice("_", 1)
	var meta := summary(slot)
	if meta.is_empty():
		return "%s - empty" % title
	var bits := ["%s, level %d" % [meta.get("leader", "?"), meta.get("level", 1)]]
	if meta.get("place", "") != "":
		bits.append(meta.place)
	return "%s - %s - %s" % [title, ", ".join(bits), meta.get("when", "")]
