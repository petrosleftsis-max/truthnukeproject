extends Node
## Gear typed into an encounter, and gear typed onto a marker, both surviving
## the encounter editor's Save.

var LOG_PATH := HarnessLog.path_for("gear")
const ENCOUNTER = "res://encounters/encounter_01_ambush.tres"

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

	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
