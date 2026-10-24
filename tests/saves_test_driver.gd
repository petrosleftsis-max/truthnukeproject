extends Node
## Saving and loading: three slots saved to anywhere on a map but a stealth
## one, three automatic saves made before fights, everything a run has come to
## coming back as it was, and the buttons for it in the pause menu and on the
## title screen.

var LOG_PATH := HarnessLog.path_for("saves")
const CROSSROADS := "res://maps/crossroads_explore.tscn"
const STAGE_MAP := "res://maps/stealth_stages/stealth_1.tscn"
const AMBUSH := "res://data/encounters/encounter_01_ambush.tres"

## What Campaign keeps that is not a run's to save: the fight under way, a
## conversation's answer, a menu's note, the stealth map being watched.
const NOT_SAVED := ["current_encounter", "return_position", "return_to_position", "target_entry",
	"_pending_trigger", "stealth_watch", "stealth_checkpoint", "_encounter_answer", "asks_for_paths",
	"story_dialogue", "story_title", "story_next_scene", "_arena_return", "menu_opens_at", "menu_note",
	# A list read from the enemies folder, not anything the run did.
	"_codex_enemies",
	# How the fight just over went, for the conversation straight after it.
	"last_fight"]
## Saved, but not as they are kept (Campaign.snapshot names them itself).
const SAVED_ITS_OWN_WAY := ["party_order", "dungeon", "current_map"]

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
	get_tree().create_timer(240.0, true, false, true).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	var booted = get_tree().current_scene
	if booted != null:
		booted.queue_free()
		await settle()
	wipe()
	await everything_is_saved()
	await save_and_load()
	await where_it_can_be_saved()
	await automatic_saves()
	await the_buttons()
	wipe()
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


func settle(frames: int = 3):
	for i in frames:
		await get_tree().process_frame


## Every save gone.
func wipe():
	for slot in SaveGame.MANUAL_SLOTS + SaveGame.AUTO_SLOTS:
		if FileAccess.file_exists(SaveGame.path_of(slot)):
			DirAccess.remove_absolute(SaveGame.path_of(slot))


## A map made the current scene, as arriving on it would.
func walk_onto(map: String) -> ExplorationScene:
	var old = get_tree().current_scene
	if old != null and is_instance_valid(old):
		old.queue_free()
		await settle(2)
	Campaign.current_map = map
	var scene: ExplorationScene = load("res://scenes/exploration.tscn").instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await settle(5)
	return scene


## Waits for a load to arrive, and hands back the map it arrived on.
func arrived() -> ExplorationScene:
	for i in 120:
		await get_tree().process_frame
		var scene = get_tree().current_scene
		if scene is ExplorationScene and scene.is_node_ready() and not SceneTransition.is_changing():
			await settle(3)
			return scene
	return null


func everything_is_saved():
	log_line("======== everything a run keeps is in a save ========")
	var kept := []
	for property in Campaign.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			kept.append(property.name)
	var missing := kept.filter(unaccounted_for)
	ok(missing.is_empty(), "nothing Campaign keeps is left out of a save without saying why - add it to Campaign.SAVED, or to NOT_SAVED here",
		"%s" % [missing])
	log_line("")


## Kept by Campaign, and neither saved nor said not to be.
func unaccounted_for(property: String) -> bool:
	return not Campaign.SAVED.has(property) and not NOT_SAVED.has(property) and not SAVED_ITS_OWN_WAY.has(property)


func save_and_load():
	log_line("======== saved, changed, loaded back ========")
	Campaign.reset()
	var scene := await walk_onto(CROSSROADS)
	Campaign.set_party(["cyrus", "alithia"], 1)
	Campaign.reach_level(24)
	Campaign.choose_subclass("cyrus", "trapper")
	Campaign.give_gold(321)
	Campaign.give_gear("fencers_rapier")
	Campaign.equip("cyrus", "fencers_rapier")
	Campaign.give_gear("padded_jacket")
	Campaign.set_inventory("alithia", ["medicine", "", "cure_potion"])
	Campaign.set_flag("saves_test_flag", "remembered")
	Campaign.cleared_triggers["saves_test_trigger"] = true
	Campaign.party_state["cyrus"] = {"hp": 17, "max_hp": 86, "alive": true, "frailty": 0.9}
	var standing: Vector2 = scene.party_position()
	ok(SaveGame.why_not(get_tree()) == "", "on a map, it can be saved", SaveGame.why_not(get_tree()))
	ok(SaveGame.save("slot_2", get_tree()), "saved to slot 2")
	ok(SaveGame.exists("slot_2") and not SaveGame.exists("slot_1"), "which is there, and slot 1 still empty")
	var described := SaveGame.describe("slot_2")
	ok(described.contains("Cyrus") and described.contains("level 24") and described.contains("Crossroads"),
		"the list says whose, how far and where", described)
	ok(SaveGame.latest() == "slot_2", "and it is the latest")

	# Everything moved on, and then back.
	Campaign.reach_level(9)
	Campaign.spend_gold(300)
	Campaign.unequip("cyrus", "weapon")
	Campaign.clear_flag("saves_test_flag")
	Campaign.set_inventory("alithia", [])
	ok(SaveGame.load_slot("slot_2"), "loading it")
	scene = await arrived()
	ok(scene != null and scene.map_path() == CROSSROADS, "goes back to the map it was saved on")
	ok(Campaign.party_level == 24 and Campaign.subclass_of("cyrus") == "trapper", "the level and the path as they were",
		"%d %s" % [Campaign.party_level, Campaign.subclass_of("cyrus")])
	ok(Campaign.gold == 321, "the purse", "%d" % Campaign.gold)
	ok(Campaign.equipped_in("cyrus", "weapon") == "fencers_rapier" and Campaign.gear == ["padded_jacket"], "the gear, worn and in the stash")
	ok(Campaign.inventory_of("alithia").slice(0, 3) == ["medicine", "", "cure_potion"], "the bags, slot for slot")
	ok(Campaign.flag_value("saves_test_flag") == "remembered" and Campaign.is_trigger_cleared("saves_test_trigger"),
		"what has been done")
	ok(Campaign.party_state.cyrus.hp == 17 and is_equal_approx(Campaign.party_state.cyrus.frailty, 0.9), "the wounds and the weakening")
	if scene != null:
		ok(scene.party_position().distance_to(standing) < 1.0, "standing where they stood", "%s, saved at %s" % [scene.party_position(), standing])
	log_line("")


func where_it_can_be_saved():
	log_line("======== where it can be saved ========")
	Campaign.reset()
	var scene := await walk_onto(STAGE_MAP)
	ok(SaveGame.why_not(get_tree()) != "" and not SaveGame.save("slot_1", get_tree()), "not on a stealth map",
		SaveGame.why_not(get_tree()))
	scene.queue_free()
	await settle(2)
	Campaign.reset()
	Campaign.current_encounter = load(AMBUSH)
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await settle(6)
	ok(SaveGame.why_not(get_tree()) != "" and not SaveGame.save("slot_1", get_tree()), "not in a fight",
		SaveGame.why_not(get_tree()))
	game.queue_free()
	await settle(2)
	scene = await walk_onto(CROSSROADS)
	scene.begin_blocking_interaction()
	ok(SaveGame.why_not(get_tree()) != "", "nor in the middle of a conversation", SaveGame.why_not(get_tree()))
	scene.end_blocking_interaction()
	ok(not SaveGame.exists("slot_1"), "and nothing was written for any of them")
	log_line("")


func automatic_saves():
	log_line("======== saved before every fight ========")
	wipe()
	Campaign.reset()
	Campaign.set_party(["cyrus"], 1)
	var encounter: EncounterDefinition = load(AMBUSH)
	Campaign.give_gold(10)
	Campaign.begin_battle_from_exploration(encounter, CROSSROADS, Vector2(100, 100), "")
	ok(SaveGame.exists("auto_1") and SaveGame.summary("auto_1").kind == "auto", "a fight begun from a map saves the moment before it")
	ok(SaveGame.read("auto_1").state.at == Vector2(100, 100), "where the party stood when it began")
	ok(SaveGame.read("auto_1").state.gold == 10, "as things were then", "%d" % SaveGame.read("auto_1").state.gold)
	Campaign.give_gold(10)
	Campaign.begin_battle_from_exploration(encounter, CROSSROADS, Vector2(200, 100), "")
	Campaign.give_gold(10)
	Campaign.begin_battle_from_exploration(encounter, CROSSROADS, Vector2(300, 100), "")
	ok(SaveGame.AUTO_SLOTS.all(func(slot): return SaveGame.exists(slot)), "three fights, three automatic saves")
	var oldest := ""
	var when := INF
	for slot in SaveGame.AUTO_SLOTS:
		if SaveGame.summary(slot).saved_at < when:
			when = SaveGame.summary(slot).saved_at
			oldest = slot
	Campaign.give_gold(10)
	var written := SaveGame.autosave_before_fight(Campaign.snapshot(CROSSROADS, Vector2(400, 100)))
	ok(written == oldest, "a fourth writes over the oldest", "%s, oldest %s" % [written, oldest])
	ok(SaveGame.MANUAL_SLOTS.all(func(slot): return not SaveGame.exists(slot)), "never over the player's own")
	ok(SaveGame.latest() == written and SaveGame.read(written).state.gold == 40, "and is the latest")

	log_line("")
	log_line("======== a fight begun on a stealth map ========")
	Campaign.reset()
	Campaign.set_party(["cyrus"], 10)
	Campaign.give_gold(5)
	Campaign.save_stealth_checkpoint(STAGE_MAP, Vector2(64, 64))
	Campaign.give_gold(50)
	Campaign.set_flag("saves_test_sneaking", true)
	Campaign.stealth_state[STAGE_MAP] = {"alert": 2}
	var state := Campaign.snapshot(STAGE_MAP, Vector2(900, 900))
	ok(state.at == Vector2(64, 64) and not state.flags.has("saves_test_sneaking") and not state.stealth_state.has(STAGE_MAP),
		"is saved as it stood on walking in - never partway through sneaking", "%s" % state.at)
	ok(state.gold == 55, "with what the stealth checkpoint does not keep as it is now")
	Campaign.reset()
	log_line("")


func the_buttons():
	log_line("======== the buttons ========")
	wipe()
	Campaign.reset()
	var scene := await walk_onto(CROSSROADS)
	var pause = scene.find_child("PauseUI", true, false)
	if pause == null:
		for node in scene.find_children("*", "CanvasLayer", true, false):
			if node.has_method("_open_saves"):
				pause = node
	ok(pause != null, "the map has a pause menu")
	if pause != null:
		pause._show_panel(pause.get_node("PausePanel"), pause._pause_buttons)
		ok(pause._save_button.visible and not pause._load_button.visible, "on a map: Save, and no Load until there is a save")
		pause._save_button.pressed.emit()
		await settle(2)
		var list: SaveLoadPanel = pause.saves_panel.get_child(0) if pause.saves_panel != null else null
		ok(list != null and list.saving and list.find_child("Slot_slot_1", true, false) != null
			and list.find_child("Slot_auto_1", true, false) == null, "Save offers the three slots and not the automatic ones")
		list.find_child("Slot_slot_3", true, false).pressed.emit()
		await settle(2)
		ok(SaveGame.exists("slot_3"), "pressing an empty one saves to it")
		list.find_child("Slot_slot_3", true, false).pressed.emit()
		await settle(1)
		ok(list.pending == "slot_3", "pressing a full one asks before writing over it")
		list.find_child("No", true, false).pressed.emit()
		list.find_child("Back", true, false).pressed.emit()
		await settle(2)
		ok(pause.saves_panel == null and pause.get_node("PausePanel").visible and pause._load_button.visible,
			"Back to Pause, which now offers Load")
		pause._close()
		await settle(2)
	scene.queue_free()
	await settle(2)

	log_line("")
	log_line("======== the title screen ========")
	var menu = load("res://scenes/main_menu.tscn").instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	await settle(3)
	var resume: Button = menu.find_child("Continue", true, false)
	ok(resume != null and resume.visible, "with a save, the title screen offers Continue")
	ok(menu.find_child("LoadGame", true, false).visible, "and Load Game")
	Campaign.reset()
	resume.pressed.emit()
	scene = await arrived()
	ok(scene != null and scene.map_path() == CROSSROADS, "Continue carries on from the latest save")
	if scene != null:
		scene.queue_free()
	await settle(2)
	wipe()
	menu = load("res://scenes/main_menu.tscn").instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	await settle(3)
	ok(not menu.find_child("Continue", true, false).visible, "without one, it does not")
	menu.queue_free()
	await settle(2)
	Campaign.reset()
	log_line("")
