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
	await basic_armour()
	await armour_by_character()
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


func settle(frames: int = 3):
	for i in frames:
		await get_tree().process_frame


func open_fight(encounter: EncounterDefinition = null) -> Node:
	Campaign.current_encounter = encounter if encounter != null else load(AMBUSH)
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
	var kinds := {}
	for key in all:
		var piece: EquipmentDefinition = all[key]
		if piece.slot == EquipmentDefinition.Slot.ARMOUR:
			kinds[piece.kind()] = kinds.get(piece.kind(), 0) + 1
	ok(kinds.has("Cloth armour") and kinds.has("Light armour") and kinds.has("Medium armour") and kinds.has("Heavy armour"),
		"armour of all four kinds, cloth, light, medium and heavy", "%s" % [kinds])
	# Its kind in its preview, on the line under its name, and never in the name (the designer, 2026-11-20).
	var said_wrong := []
	for key in all:
		var piece: EquipmentDefinition = all[key]
		var lines: PackedStringArray = piece.reading().split("\n")
		if lines.size() < 2 or lines[0] != piece.name or not lines[1].begins_with(piece.kind()) or piece.name.contains("("):
			said_wrong.append(key)
	ok(said_wrong.is_empty(), "every piece's preview says its kind under its name, and no name carries it", "%s" % [said_wrong])
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
	for key in ["fencers_rapier", "studded_leather", "feather_charm", "iron_charm"]:
		Campaign.give_gear(key)
	Campaign.equip("cyrus", "fencers_rapier")
	Campaign.equip("cyrus", "studded_leather")
	Campaign.equip("cyrus", "feather_charm")
	var game = await open_fight()
	var combat = game.get_node("VisualCombat")
	var cyrus := fighter(combat, "cyrus")
	var enfina := fighter(combat, "enfina")
	ok(cyrus.weapon_base == 10, "the rapier's weapon base, not the tile's", "%d" % cyrus.weapon_base)
	# Light armour, which is all he wears (the designer, 2026-11-20): 20 over his Basic Armour's 12 at level 1.
	ok(combat.stat_of(cyrus, Stats.Type.DEFENSE) == 20, "the studded leather's defence", "%d" % combat.stat_of(cyrus, Stats.Type.DEFENSE))
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


## The party's armour instead of Defense bands (the designer, 2026-11-19): a basic armour
## each, worn while nothing better is, keeping up with their level - Enfina's heavy, with
## the old Iron Hide I's 10% in it as in the Brigandine and the Plate Harness.
func basic_armour():
	log_line("======== basic armour, worn while nothing better is ========")
	var heavy := EquipmentDefinition.named("basic_heavy_armour")
	var plain := EquipmentDefinition.named("basic_armour")
	ok(heavy != null and heavy.armour_category == EquipmentDefinition.ArmourCategory.HEAVY and heavy.fits("enfina") and not heavy.fits("cyrus")
		and [heavy.defense_at(1), heavy.defense_at(7), heavy.defense_at(8), heavy.defense_at(16), heavy.defense_at(17), heavy.defense_at(64)] == [18, 18, 27, 27, 36, 36],
		"Enfina's Basic Heavy Armour, hers alone: 18 from level 1, 27 from 8, 36 from 17", heavy.summary() if heavy != null else "none")
	ok(plain != null and [plain.defense_at(1), plain.defense_at(7), plain.defense_at(8), plain.defense_at(17), plain.defense_at(64)] == [12, 12, 20, 28, 28],
		"the others' Basic Armour: 12, 20, 28, the bands as they were", plain.summary() if plain != null else "none")
	ok(EquipmentDefinition.named("brigandine").defense_at(30) == 27, "a piece with one Defense gives it at any level")
	for key in ["cyrus", "alithia"]:
		var who: CombatantDefinition = CombatantDatabase.combatants[key]
		ok(who.basic_armour == "basic_armour" and who.defense_by_level.is_empty() and who.defense_at(8) == 20,
			"%s wears Basic Armour, with no bands of their own" % who.name)
	# Prometheus's is cloth, a step below light (the designer, 2026-11-20: 9, 17, 24).
	var cloth := EquipmentDefinition.named("basic_cloth_armour")
	var prometheus_definition: CombatantDefinition = CombatantDatabase.combatants.prometheus
	ok(cloth != null and cloth.armour_category == EquipmentDefinition.ArmourCategory.CLOTH and cloth.kind() == "Cloth armour"
		and cloth.fits("prometheus") and not cloth.fits("cyrus")
		and [cloth.defense_at(1), cloth.defense_at(7), cloth.defense_at(8), cloth.defense_at(16), cloth.defense_at(17), cloth.defense_at(64)] == [9, 9, 17, 17, 24, 24],
		"Prometheus's Basic Cloth Armour, his alone: 9 from level 1, 17 from 8, 24 from 17", cloth.summary() if cloth != null else "none")
	ok(prometheus_definition.basic_armour == "basic_cloth_armour" and prometheus_definition.defense_by_level.is_empty()
		and prometheus_definition.defense_at(8) == 17, "and he wears it")
	var enfina_definition: CombatantDefinition = CombatantDatabase.combatants.enfina
	ok(enfina_definition.basic_armour == "basic_heavy_armour" and enfina_definition.defense_by_level.is_empty()
		and enfina_definition.defense_at(8) == 27, "Enfina wears hers")

	# A story fight with the armour slot empty: worn and named; armour of his own on instead takes its place.
	Campaign.reset()
	Campaign.set_party(["cyrus", "enfina"], 8)
	Campaign.current_map = "res://maps/crossroads_explore.tscn"
	Campaign.return_to_position = true
	Campaign.give_gear("hardened_leather")
	Campaign.equip("cyrus", "hardened_leather")
	var game = await open_fight()
	var combat = game.get_node("VisualCombat")
	var enfina := fighter(combat, "enfina")
	var cyrus := fighter(combat, "cyrus")
	ok(combat.stat_of(enfina, Stats.Type.DEFENSE) == 27 and enfina.get("gear", []).has("Basic Heavy Armour"),
		"Enfina at 8, nothing on: her Basic Heavy Armour's 27, and named among what she wears",
		"%d, %s" % [combat.stat_of(enfina, Stats.Type.DEFENSE), enfina.get("gear", [])])
	ok(combat.stat_of(cyrus, Stats.Type.DEFENSE) == 28 and cyrus.get("gear", []).has("Hardened Leather")
		and not cyrus.get("gear", []).has("Basic Armour"), "Cyrus in Hardened Leather: its 28, and no Basic Armour under it",
		"%d, %s" % [combat.stat_of(cyrus, Stats.Type.DEFENSE), cyrus.get("gear", [])])
	game.queue_free()
	await settle(3)
	# Arena Mode: the tile's level, their basic armour.
	Campaign.current_map = ""
	Campaign.return_to_position = false
	game = await open_fight()
	combat = game.get_node("VisualCombat")
	enfina = fighter(combat, "enfina")
	ok(combat.stat_of(enfina, Stats.Type.DEFENSE) == enfina_definition.defense_at(enfina.level) and enfina.get("gear", []).has("Basic Heavy Armour"),
		"from the menu too, at the tile's level %d" % enfina.level, "%d" % combat.stat_of(enfina, Stats.Type.DEFENSE))
	game.queue_free()
	await settle(3)

	# On the map: the sheet's Defense is the basic armour's, and the Armour slot names it.
	Campaign.reset()
	Campaign.set_party(["enfina"], 17)
	var sheet: CharacterSheet = load("res://ui/character_sheet.gd").new()
	get_tree().root.add_child(sheet)
	await settle(2)
	sheet.open(false)
	await settle(2)
	var armour_button: Button = sheet.find_child("Gear_armour", true, false)
	ok(armour_button != null and armour_button.text == "Armour: Basic Heavy Armour", "her sheet's Armour slot names it",
		armour_button.text if armour_button != null else "none")
	var row: Dictionary = sheet._entries[sheet._index]
	ok(row.stats.defense == 36, "and its Defense at 17 is hers on the map, as in a fight", "%d" % row.stats.defense)
	sheet.close()
	sheet.queue_free()
	await settle(2)
	Campaign.reset()
	log_line("")


## Who wears what (the designer, 2026-11-20): Prometheus no armour, Cyrus light only,
## Alithia light and medium, Enfina any (CombatantDefinition.armour_kinds).
func armour_by_character():
	log_line("======== armour by character ========")
	var armour := ["padded_jacket", "studded_leather", "hardened_leather", "mail_shirt", "scale_coat", "brigandine", "plate_harness"]
	var allowed := {
		"cyrus": ["padded_jacket", "studded_leather", "hardened_leather"],
		"alithia": ["padded_jacket", "studded_leather", "hardened_leather", "mail_shirt", "scale_coat"],
		"prometheus": [],
		"enfina": armour,
	}
	for who in allowed:
		var can := armour.filter(func(key): return Campaign.can_use(who, EquipmentDefinition.named(key)))
		ok(can == allowed[who], "%s can wear %s" % [Campaign.display_name_of(who), ", ".join(can) if not can.is_empty() else "none of these"])
	# Cloth (the designer, 2026-11-20): Prometheus's only kind, and Enfina wears any.
	var cloth := EquipmentDefinition.named("basic_cloth_armour")
	var wears_cloth := {}
	for who in allowed:
		wears_cloth[who] = (CombatantDatabase.combatants[who] as CombatantDefinition).wears(cloth)
	ok(wears_cloth == {"cyrus": false, "alithia": false, "prometheus": true, "enfina": true}, "cloth armour: Prometheus's kind, and Enfina's as any is",
		"%s" % [wears_cloth])
	ok(Campaign.can_use("prometheus", cloth) and not Campaign.can_use("enfina", cloth), "his Basic Cloth Armour is his alone, as Enfina's heavy one is hers")
	ok(Campaign.can_use("prometheus", EquipmentDefinition.named("rowan_staff")) and Campaign.can_use("prometheus", EquipmentDefinition.named("iron_charm"))
		and Campaign.can_use("prometheus", EquipmentDefinition.named("satchel")), "Prometheus still takes up his staff, a charm and a backpack")
	Campaign.reset()
	Campaign.set_party(["cyrus", "alithia", "prometheus", "enfina"], 14)
	for key in armour:
		Campaign.give_gear(key)
	ok(not Campaign.equip("cyrus", "brigandine") and not Campaign.equip("cyrus", "mail_shirt") and Campaign.equipped_in("cyrus", "armour") == ""
		and Campaign.gear.has("brigandine") and Campaign.gear.has("mail_shirt"), "Cyrus cannot put on a Brigandine or a Mail Shirt, which stay in the stash")
	ok(Campaign.gear_for("cyrus", "armour") == ["padded_jacket", "studded_leather", "hardened_leather"], "the stash offers him light armour only",
		"%s" % [Campaign.gear_for("cyrus", "armour")])
	ok(Campaign.gear_for("alithia", "armour") == ["padded_jacket", "studded_leather", "hardened_leather", "mail_shirt", "scale_coat"],
		"Alithia light and medium", "%s" % [Campaign.gear_for("alithia", "armour")])
	ok(Campaign.gear_for("prometheus", "armour").is_empty() and not Campaign.equip("prometheus", "padded_jacket"), "Prometheus none")
	ok(Campaign.equip("alithia", "scale_coat") and Campaign.equip("enfina", "plate_harness"), "Alithia in the Scale Coat, Enfina in plate")
	# What a store's preview says of who can wear it.
	var said_for := func(keys: Array) -> String: return "For " + ", ".join(keys.map(func(key): return Campaign.display_name_of(key)))
	ok(StoreScreen.who_can_use(EquipmentDefinition.named("mail_shirt")) == [said_for.call(["alithia", "enfina"])]
		and StoreScreen.who_can_use(EquipmentDefinition.named("studded_leather")) == [said_for.call(["cyrus", "alithia", "enfina"])]
		and StoreScreen.who_can_use(EquipmentDefinition.named("rowan_staff")) == [said_for.call(["prometheus"])]
		and StoreScreen.who_can_use(EquipmentDefinition.named("satchel")).is_empty(),
		"a store says who of the party can wear each piece, and nothing when all of them can",
		"%s" % [StoreScreen.who_can_use(EquipmentDefinition.named("mail_shirt"))])
	# Armour an encounter puts on somebody who cannot wear it is left off.
	var ambush: EncounterDefinition = load(AMBUSH).duplicate(true)
	var worn: Array[String] = ["brigandine", "fencers_rapier"]
	for spawn in ambush.spawns:
		if spawn.combatant_key == "cyrus":
			spawn.equipment = worn
	Campaign.reset()
	Campaign.set_party(["cyrus", "enfina"], 1)
	Campaign.current_map = ""
	Campaign.return_to_position = false
	var game = await open_fight(ambush)
	var combat = game.get_node("VisualCombat")
	var cyrus := fighter(combat, "cyrus")
	ok(not cyrus.get("gear", []).has("Brigandine") and cyrus.get("gear", []).has("Fencer's Rapier") and not cyrus.get("equipment", []).has("brigandine")
		and combat.stat_of(cyrus, Stats.Type.DEFENSE) != 27, "a Brigandine an encounter puts on Cyrus stays off, and his rapier does not",
		"%s, %d" % [cyrus.get("gear", []), combat.stat_of(cyrus, Stats.Type.DEFENSE)])
	game.queue_free()
	await settle(3)
	Campaign.reset()
	log_line("")
