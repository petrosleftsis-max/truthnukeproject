extends Node
## Gear typed into an encounter, and gear typed onto a marker, both surviving
## the encounter editor's Save - and every other field a spawn has with them.

var LOG_PATH := HarnessLog.path_for("gear")
const ENCOUNTER = "res://data/encounters/encounter_01_ambush.tres"

var _log: FileAccess = null
var _fail = 0


func log_line(t: String):
	if _log:
		_log.store_line(t)
		_log.flush()


func ok(condition: bool, label: String, detail: String = ""):
	if condition:
		log_line("  PASS  %s %s" % [label, detail])
	else:
		_fail += 1
		log_line("  FAIL  %s %s" % [label, detail])


func _ready():
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	get_tree().create_timer(120.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


## An editor with the encounter open and its markers built, as if the scene had
## just been opened in the editor.
func open_editor(encounter: EncounterDefinition) -> EncounterEditor:
	var editor = EncounterEditor.new()
	get_tree().root.add_child(editor)
	await get_tree().process_frame
	editor.encounter = encounter
	editor.rebuild()
	return editor


## The editor's half-second housekeeping tick, which is where it notices the
## encounter has been edited underneath it.
func tick(editor: EncounterEditor):
	editor._sync_if_encounter_changed()
	editor._refresh_status()


func from_disk() -> EncounterDefinition:
	return ResourceLoader.load(ENCOUNTER, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)


func spawn_named(encounter: EncounterDefinition, key: String) -> SpawnDefinition:
	for spawn in encounter.spawns:
		if spawn.combatant_key == key:
			return spawn
	return null


func run_test():
	# The suites in a run share one copy of the project, and everything here is
	# saved into a real encounter - put back at the end, so a late arrival
	# written here is not still arriving late in whichever suite comes next.
	var original := FileAccess.get_file_as_string(ENCOUNTER)
	log_line("======== gear typed onto a marker survives Save ========")
	var editor = await open_editor(load(ENCOUNTER))
	var marker = editor.markers()[0]
	var key = marker.combatant_key
	log_line("  NOTE  %s starts at wb=%d def=%d lv=%d" % [key, marker.weapon_base, marker.defense, marker.level])
	marker.weapon_base = 21
	marker.defense = 37
	marker.level = 2
	tick(editor)
	editor.save_to_encounter()
	var saved = spawn_named(from_disk(), key)
	ok(saved != null, "the spawn is still there")
	ok(saved.weapon_base == 21, "weapon_base was written", "%d" % saved.weapon_base)
	ok(saved.defense == 37, "defense was written", "%d" % saved.defense)
	ok(saved.level == 2, "level was written", "%d" % saved.level)
	editor.free()
	log_line("")

	log_line("======== gear typed into the encounter is not overwritten ========")
	# The editor scene sits open in its tab while the encounter's own spawn list
	# is edited in the inspector. Saving used to write the markers - built
	# before the edit - straight over it, putting the gear back to its defaults.
	var encounter = load(ENCOUNTER)
	editor = await open_editor(encounter)
	spawn_named(encounter, key).weapon_base = 44
	spawn_named(encounter, key).defense = 55
	tick(editor)
	ok(editor.markers()[0].weapon_base == 44,
		"the editor picked the edit up rather than sitting on its old copy",
		"marker says %d" % editor.markers()[0].weapon_base)
	editor.save_to_encounter()
	saved = spawn_named(from_disk(), key)
	ok(saved.weapon_base == 44, "and Save kept it", "%d" % saved.weapon_base)
	ok(saved.defense == 55, "both halves of it", "%d" % saved.defense)
	editor.free()
	log_line("")

	log_line("======== an edit on each side is refused rather than guessed at ========")
	encounter = load(ENCOUNTER)
	editor = await open_editor(encounter)
	editor.markers()[0].defense = 60          # changed here
	spawn_named(encounter, key).weapon_base = 70   # and changed there
	tick(editor)
	ok("edited since these markers were built" in editor.status,
		"the status line says which way to go", editor.status.replace("\n", " / "))
	editor.save_to_encounter()
	saved = spawn_named(from_disk(), key)
	# The refusal means nothing at all was written, so the file still reads as it
	# did after the last good save - neither the marker's 60 nor the unsaved 70.
	ok(saved.weapon_base == 44 and saved.defense == 55, "so the file was left exactly as it was",
		"wb=%d def=%d" % [saved.weapon_base, saved.defense])
	log_line("")

	log_line("======== Reload takes the encounter's side ========")
	editor.rebuild()
	tick(editor)
	ok(editor.markers()[0].weapon_base == 70, "the markers now say what the encounter does",
		"%d" % editor.markers()[0].weapon_base)
	ok(not ("edited since these markers were built" in editor.status), "and Save is unblocked",
		editor.status.replace("\n", " / "))
	editor.save_to_encounter()
	saved = spawn_named(from_disk(), key)
	ok(saved.weapon_base == 70, "which then saves cleanly", "%d" % saved.weapon_base)
	editor.free()
	log_line("")

	log_line("======== the fight uses the gear that was saved ========")
	Campaign.reset()
	Campaign.current_encounter = from_disk()
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	var combat = game.get_node("VisualCombat")
	combat.finish_deployment()
	await get_tree().process_frame
	var fighter = null
	for c in combat.combatants:
		if c.get("key") == key or c.get("combatant_key") == key:
			fighter = c
	ok(fighter != null, "the combatant is on the field", key)
	if fighter != null:
		ok(fighter.get("weapon_base") == 70, "swinging the weapon_base that was saved",
			"%s" % fighter.get("weapon_base"))
		ok(fighter["stats"]["defense"] == saved.defense, "and soaking with the saved defense",
			"%s" % fighter["stats"]["defense"])
	log_line("")

	game.queue_free()
	await get_tree().process_frame
	await every_field_survives_save()
	await encounter_edits_are_noticed()

	var put_back := FileAccess.open(ENCOUNTER, FileAccess.WRITE)
	put_back.store_string(original)
	put_back.close()
	ok(FileAccess.get_file_as_string(ENCOUNTER) == original, "(the encounter put back as it was)")

	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


## The spawn in `encounter` called `called`, or null.
func spawn_called(encounter: EncounterDefinition, called: String) -> SpawnDefinition:
	for spawn in encounter.spawns:
		if spawn.display_name == called:
			return spawn
	return null


func marker_called(editor: EncounterEditor, called: String) -> SpawnMarker:
	for marker in editor.markers():
		if marker.display_name == called:
			return marker
	return null


## Every field a spawn stores, by name.
func spawn_fields() -> Array:
	var fields := []
	for property in SpawnDefinition.new().get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and property.usage & PROPERTY_USAGE_STORAGE:
			fields.append(property.name)
	return fields


func every_field_survives_save():
	log_line("======== every field a spawn has survives Save ========")
	# Each one set away from its default, so a field Save drops comes back
	# different. The editor once rebuilt every spawn without its arrival round
	# or whether it was caught off guard, and a Save put both back.
	var encounter: EncounterDefinition = load(ENCOUNTER)
	var late: SpawnDefinition = null
	for spawn in encounter.spawns:
		if spawn.side == 1:
			late = spawn
	late.display_name = "Late One"
	late.level = 2
	late.weapon_base = 33
	late.defense = 44
	late.starting_items.assign(["medicine", "tiny_bomb"])
	late.arrives_on_round = 3
	late.surprised = true
	late.subclass = "gunner"
	var fresh := SpawnDefinition.new()
	var unset := spawn_fields().filter(func(field): return "%s" % [late.get(field)] == "%s" % [fresh.get(field)])
	ok(unset.is_empty(), "(this test sets every field a spawn has - a new one needs setting here too)", "%s" % [unset])
	var wanted := {}
	for field in spawn_fields():
		wanted[field] = "%s" % [late.get(field)]

	var editor = await open_editor(encounter)
	var marker := marker_called(editor, "Late One")
	ok(marker != null and marker.arrives_on_round == 3 and marker.surprised,
		"the marker holds when they arrive and whether they are caught off guard")
	editor.save_to_encounter()
	var back := spawn_called(from_disk(), "Late One")
	var lost := []
	for field in spawn_fields():
		var now = "%s" % [back.get(field)] if back != null else "gone"
		if now != wanted[field]:
			lost.append("%s %s -> %s" % [field, wanted[field], now])
	ok(back != null and lost.is_empty(), "every one of them is still there after Save", "%s" % [lost])
	editor.free()
	log_line("")


func encounter_edits_are_noticed():
	log_line("======== an arrival or a bag changed in the encounter is noticed ========")
	var encounter: EncounterDefinition = load(ENCOUNTER)
	var editor = await open_editor(encounter)
	spawn_called(encounter, "Late One").arrives_on_round = 5
	tick(editor)
	var marker := marker_called(editor, "Late One")
	ok(marker != null and marker.arrives_on_round == 5, "a new arrival round is picked up rather than saved over",
		"%s" % [marker.arrives_on_round if marker != null else "no marker"])
	spawn_called(encounter, "Late One").starting_items.assign(["big_bomb"])
	tick(editor)
	marker = marker_called(editor, "Late One")
	ok(marker != null and marker.starting_items == ["big_bomb"], "and so is a new bag",
		"%s" % [marker.starting_items if marker != null else "no marker"])
	editor.save_to_encounter()
	var back := spawn_called(from_disk(), "Late One")
	ok(back != null and back.arrives_on_round == 5 and back.starting_items == ["big_bomb"], "which Save then keeps")
	editor.free()
	log_line("")
