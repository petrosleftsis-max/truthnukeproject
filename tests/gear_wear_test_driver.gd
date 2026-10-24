extends Node
## Equipment: a weapon, armour and a charm for each of the party, kept in a
## stash between times; what is worn standing in for a story fight's own
## numbers; and putting it on from the character sheet.

var LOG_PATH := HarnessLog.path_for("gear_wear")
const AMBUSH := "res://data/encounters/encounter_01_ambush.tres"

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
	get_tree().create_timer(180.0, true, false, true).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	var booted = get_tree().current_scene
	if booted != null:
		booted.queue_free()
		await settle()
	await the_pieces()
	await the_stash()
	await in_a_fight()
	await on_the_sheet()
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


func settle(frames: int = 3):
	for i in frames:
		await get_tree().process_frame


func open_fight() -> Node:
	Campaign.current_encounter = load(AMBUSH)
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle(6)
	var combat = game.get_node("VisualCombat")
	if combat.deployment_active:
		combat.finish_deployment()
		await settle(2)
	return game


func fighter(combat, key: String) -> Dictionary:
	for comb in combat.combatants:
		if comb.get("combatant_key", "") == key:
			return comb
	return {}


func the_pieces():
	log_line("======== the pieces ========")
	var all := EquipmentDefinition.all()
	var slots := {}
	for key in all:
		slots[all[key].slot_key()] = true
	ok(slots.has("weapon") and slots.has("armour") and slots.has("charm"), "weapons, armour and charms", "%d pieces" % all.size())
	var light := 0
	var heavy := 0
	for key in all:
		var piece: EquipmentDefinition = all[key]
		if piece.slot == EquipmentDefinition.Slot.ARMOUR:
			if piece.armour_category == EquipmentDefinition.ArmourCategory.LIGHT:
				light += 1
			else:
				heavy += 1
	ok(light > 0 and heavy > 0, "armour in both categories, light and heavy", "%d light, %d heavy" % [light, heavy])
	var rapier := EquipmentDefinition.named("fencers_rapier")
	ok(rapier.fits("cyrus") and not rapier.fits("enfina"), "a piece made for one of them fits nobody else")
	ok(EquipmentDefinition.named("padded_jacket").fits("enfina"), "and one for anybody fits anybody")
	ok(rapier.price > 0, "everything has a price")
	log_line("")


func the_stash():
	log_line("======== the stash ========")
	Campaign.reset()
	ok(Campaign.give_gear("fencers_rapier") and Campaign.gear == ["fencers_rapier"], "a piece given goes to the stash")
	ok(not Campaign.give_gear("no_such_thing"), "and a piece that does not exist is not given")
	ok(not Campaign.equip("enfina", "fencers_rapier"), "Enfina cannot wield Cyrus's rapier")
	ok(Campaign.equip("cyrus", "fencers_rapier") and Campaign.equipped_in("cyrus", "weapon") == "fencers_rapier"
		and Campaign.gear.is_empty(), "Cyrus can - out of the stash and into his hand")
	Campaign.give_gear("worn_knife")
	ok(Campaign.equip("cyrus", "worn_knife") and Campaign.equipped_in("cyrus", "weapon") == "worn_knife"
		and Campaign.gear == ["fencers_rapier"], "putting another weapon on puts the first back")
	ok(Campaign.gear_for("cyrus", "weapon") == ["fencers_rapier"] and Campaign.gear_for("enfina", "weapon").is_empty(),
		"what the stash has for each slot is only what fits")
	ok(Campaign.unequip("cyrus", "weapon") and Campaign.equipped_in("cyrus", "weapon") == ""
		and Campaign.gear.has("worn_knife"), "taken off, it goes back too")
	Campaign.reset()
	ok(Campaign.gear.is_empty() and Campaign.equipped.is_empty(), "started over, there is none")
	log_line("")


func in_a_fight():
	log_line("======== worn in a story fight ========")
	Campaign.reset()
	Campaign.set_party(["cyrus", "enfina"], 1)
	Campaign.current_map = "res://maps/crossroads_explore.tscn"
	Campaign.return_to_position = true
	for key in ["fencers_rapier", "brigandine", "feather_charm", "iron_charm"]:
		Campaign.give_gear(key)
	Campaign.equip("cyrus", "fencers_rapier")
	Campaign.equip("cyrus", "brigandine")
	Campaign.equip("cyrus", "feather_charm")
	var game = await open_fight()
	var combat = game.get_node("VisualCombat")
	var cyrus := fighter(combat, "cyrus")
	var enfina := fighter(combat, "enfina")
	ok(cyrus.weapon_base == 10, "the rapier's weapon base, not the tile's", "%d" % cyrus.weapon_base)
	ok(combat.stat_of(cyrus, Stats.Type.DEFENSE) == 20, "the brigandine's defence", "%d" % combat.stat_of(cyrus, Stats.Type.DEFENSE))
	var plain_movement: int = CombatantDatabase.combatants.cyrus.movement
	ok(combat.get_effective_stat(cyrus, "movement") == plain_movement + 1, "and the charm's step",
		"%d" % combat.get_effective_stat(cyrus, "movement"))
	var spawn: SpawnDefinition = null
	for each in load(AMBUSH).spawns:
		if each.combatant_key == "enfina":
			spawn = each
	# A tile's defence of 0 is her own at her level.
	var tile_defense: int = spawn.defense if spawn.defense > 0 \
		else CombatantDatabase.combatants.enfina.defense_at(enfina.level)
	ok(enfina.weapon_base == spawn.weapon_base and enfina.stats.defense == tile_defense,
		"Enfina, wearing nothing, has the tile's own numbers", "%d / %d" % [enfina.weapon_base, enfina.stats.defense])
	game.queue_free()
	await settle(3)
	Campaign.equip("enfina", "iron_charm")
	game = await open_fight()
	combat = game.get_node("VisualCombat")
	enfina = fighter(combat, "enfina")
	ok(combat.stat_of(enfina, Stats.Type.DEFENSE) == tile_defense + 5, "a charm adding defence adds it", "%d" % combat.stat_of(enfina, Stats.Type.DEFENSE))
	game.queue_free()
	await settle(3)

	log_line("")
	log_line("======== not from the menu ========")
	Campaign.current_map = ""
	Campaign.return_to_position = false
	game = await open_fight()
	combat = game.get_node("VisualCombat")
	cyrus = fighter(combat, "cyrus")
	var cyrus_spawn: SpawnDefinition = null
	for each in load(AMBUSH).spawns:
		if each.combatant_key == "cyrus":
			cyrus_spawn = each
	ok(cyrus.weapon_base == cyrus_spawn.weapon_base, "Battle Select fights with the tile's numbers whatever is worn")
	game.queue_free()
	await settle(3)
	Campaign.reset()
	log_line("")


func on_the_sheet():
	log_line("======== on the character sheet ========")
	Campaign.reset()
	Campaign.set_party(["cyrus"], 1)
	Campaign.give_gear("fencers_rapier")
	Campaign.give_gear("padded_jacket")
	var sheet: CharacterSheet = load("res://ui/character_sheet.gd").new()
	get_tree().root.add_child(sheet)
	await settle(2)
	sheet.open(false)
	await settle(2)
	var weapon_button: Button = sheet.find_child("Gear_weapon", true, false)
	ok(weapon_button != null and weapon_button.text == "Weapon: -", "a button a slot, empty to begin with",
		weapon_button.text if weapon_button != null else "none")
	weapon_button.pressed.emit()
	await settle(2)
	var wear: Button = sheet.find_child("Wear_fencers_rapier", true, false)
	ok(wear != null, "pressed, what fits comes up")
	ok(sheet.find_child("Wear_padded_jacket", true, false) == null, "and nothing that does not")
	wear.pressed.emit()
	await settle(2)
	ok(Campaign.equipped_in("cyrus", "weapon") == "fencers_rapier", "chosen, he wears it")
	weapon_button = sheet.find_child("Gear_weapon", true, false)
	ok(weapon_button.text == "Weapon: Fencer's Rapier", "and the button says so", weapon_button.text)
	var weapon_row: Dictionary = sheet._entries[sheet._index]
	ok(weapon_row.weapon_base == 10, "with the sheet's weapon base his", "%d" % weapon_row.weapon_base)
	sheet.close()
	sheet.queue_free()
	await settle(2)
	Campaign.reset()
	log_line("")
