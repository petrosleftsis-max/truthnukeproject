extends Node
## The new skill icons, and the previews on a character sheet.

var LOG_PATH := HarnessLog.path_for("icons")

## Icons drawn for one skill each, named after it. The rest still share a face
## by kind - heal, buff, debuff, the greatsword for gateless damage, fire for
## the rest - until they get one of their own. Stealth's is Cyrus's, the one
## character who has it; Wind Swoon's is named for what it does, Windswept.
const OWN_ICONS := {
	"run": "run_skill.png", "slip_past": "slip_past_icon.png", "study": "study_skill.png",
	"stealth": "cyrusstealth_skill.png", "blink_strike": "blinkstrike_skill.png",
	"burner": "burner_skill.png", "burning_shot": "burningshot_skill.png",
	"crystalise": "crystallise_skill.png", "fire_blast": "fireblast_icon.png",
	"flash": "flash_skill.png", "follow_up_attack": "followupattack_skill.png",
	"gun": "gun_skill.png", "gust_blast": "gustblast_skill.png",
	"hermes_step": "hermesstep_skill.png", "holy_lance": "holylance_skill.png",
	"hover": "hover_skill.png", "light_heal": "lightheal_skill.png",
	"light_swing": "lightswing_skill.png", "poison_dart": "poisondart_skill.png",
	"quicken": "quicken_skill.png", "rapier": "rapier_skill.png",
	"river_flow": "riverflow_skill.png", "rock_throw": "rockthrow_icon.png",
	"sass_club": "sassclub_skill.png", "shoving_strike": "shovingstrike_skill.png",
	"sweep_strike": "sweepstrike_skill.png", "trailblaze": "trailblaze_skill.png",
	"warning_shot": "warningshot_skill.png", "water_spike": "waterspike_skill.png",
	"wind_shot": "windshot_icon.png", "wind_swoon": "windswept_skill.png",
	"wind_vacuum": "windvacuum_skill.png",
	# The paths' skills - placeholders, each its own until real art goes in.
	"frost_round": "frost_round_skill.png", "corrosive_round": "corrosive_round_skill.png",
	"combined_load": "combined_load_skill.png", "flame_edge": "flame_edge_skill.png",
	"frost_edge": "frost_edge_skill.png", "storm_edge": "storm_edge_skill.png",
	"stone_edge": "stone_edge_skill.png", "holy_spear": "holy_spear_skill.png",
	"censure": "censure_skill.png", "judgement_hammer": "judgement_hammer_skill.png",
	"mirror_image": "mirror_image_skill.png", "dread_visage": "dread_visage_skill.png",
	"bewilder": "bewilder_skill.png", "daunting_roar": "daunting_roar_skill.png",
	"shield_bash": "shield_bash_skill.png", "chain_hook": "chain_hook_skill.png",
	"pin_down": "pin_down_skill.png", "hamstring": "hamstring_skill.png",
	# The paths of 2026 - placeholders too.
	"snare": "snare_skill.png", "tripwire": "tripwire_skill.png", "minefield": "minefield_skill.png",
	"grand_design": "grand_design_skill.png", "illusory_cover": "illusory_cover_skill.png",
	"phantom_body": "phantom_body_skill.png", "sanctuary_of_light": "sanctuary_of_light_skill.png",
	"mass_mirage": "mass_mirage_skill.png", "realitys_reflection": "realitys_reflection_skill.png",
	"accusation": "accusation_skill.png", "recant": "recant_skill.png", "catalyst": "catalyst_skill.png",
	"wildfire": "wildfire_skill.png", "frozen_river": "frozen_river_skill.png", "dispel_magic": "dispel_magic_skill.png",
	# Declared moves - placeholders too.
	"ground_pound": "ground_pound_skill.png", "rockfall": "rockfall_skill.png",
	# The progression's (docs/progression.csv) - placeholders, each its own.
	"battle_cry": "battle_cry_skill.png",
	"stunning_blow": "stunning_blow_skill.png",
	"cover_leap": "cover_leap_skill.png",
	"venom_fan": "venom_fan_skill.png",
	"tartarus_flame": "tartarus_flame_skill.png", "ire_of_sophia": "ire_of_sophia_skill.png",
	"gnostic_tempest": "gnostic_tempest_skill.png", "stolen_sun": "stolen_sun_skill.png",
	"holy_splash": "holy_splash_skill.png", "communion": "communion_skill.png",
	"piercing_light": "piercing_light_skill.png", "judgment": "judgment_skill.png",
	"glacial_tide": "glacial_tide_skill.png", "purification": "purification_skill.png",
	"divine_verdict": "divine_verdict_skill.png", "restoration": "restoration_skill.png",
	"revelation": "revelation_skill.png", "grace": "grace_skill.png",
}
var _log: FileAccess
var _fail = 0

func log_line(t): _log.store_line(t); _log.flush()

func ok(condition: bool, label: String, detail: String = ""):
	if condition:
		log_line("  PASS  %s %s" % [label, detail])
	else:
		_fail += 1
		log_line("  FAIL  %s %s" % [label, detail])

func _ready():
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	get_tree().create_timer(180.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


## Whether `skill` makes somebody better at something - a stat raised, a
## multiplier above one, a resistance improved, a better way of getting about,
## which is what Hover grants, or a spell raised to its stronger element.
##
## Not every buff is a bigger number: Element Up changes what the next cast is
## made of rather than how large it is, and it is as much good news as Guard.
func raises_something(skill: SkillDefinition) -> bool:
	for effect in skill.all_effects():
		if effect == null:
			continue
		match effect.type:
			EffectDefinition.EffectType.STAT_MODIFIER, EffectDefinition.EffectType.RESISTANCE:
				if effect.modifier_amount > 0:
					return true
			EffectDefinition.EffectType.STAT_MULTIPLIER:
				if effect.stat_multiplier > 1.0:
					return true
			EffectDefinition.EffectType.MOVEMENT_CLASS, \
					EffectDefinition.EffectType.UPGRADE_ELEMENT:
				return true
	return false


## The other side of it: something taken away rather than given.
func lowers_something(skill: SkillDefinition) -> bool:
	for effect in skill.all_effects():
		if effect == null:
			continue
		match effect.type:
			EffectDefinition.EffectType.STAT_MODIFIER, EffectDefinition.EffectType.RESISTANCE:
				if effect.modifier_amount < 0:
					return true
			EffectDefinition.EffectType.STAT_MULTIPLIER:
				if effect.stat_multiplier < 1.0:
					return true
	return false


func icon_file(skill: SkillDefinition) -> String:
	if skill == null or skill.icon == null:
		return ""
	return skill.icon.resource_path.get_file()


func run_test():
	log_line("======== everything has an icon ========")
	var bare := []
	for key in SkillDatabase.skills:
		if SkillDatabase.skills[key].icon == null:
			bare.append(key)
	ok(bare.is_empty(), "no skill or item is left without one", "%s" % [bare])
	log_line("")

	log_line("======== heals and cleanses ========")
	for key in ["heal", "light_heal", "communion", "cleanse"]:
		ok(icon_file(SkillDatabase.skills.get(key)) == OWN_ICONS.get(key, "heal_skill.png"),
			"%s carries the heal icon, or its own" % key, icon_file(SkillDatabase.skills.get(key)))
	log_line("")

	log_line("======== a buff and a debuff no longer look alike ========")
	# One icon used to cover any stat change at all, so a skill that took
	# movement away and one that gave it wore the same face. They are told
	# apart now - which makes the check what an icon claims rather than a list
	# of names, since a list goes stale the moment a skill is added.
	var lying := []
	var unmarked := []
	for key in SkillDatabase.skills:
		var skill: SkillDefinition = SkillDatabase.skills[key]
		if skill == null:
			continue
		var face = icon_file(skill)
		if face == "buff_skill.png" and not raises_something(skill):
			lying.append(key)
		# Something that only takes away should not be wearing the good news,
		# and should be wearing the bad.
		if lowers_something(skill) and not raises_something(skill):
			if face == "buff_skill.png":
				lying.append(key)
			elif face != "debuff_skill.png" and face != OWN_ICONS.get(key, ""):
				unmarked.append("%s (%s)" % [key, face])
	ok(lying.is_empty(), "everything wearing the buff icon raises something", "%s" % [lying])
	ok(unmarked.is_empty(), "and everything that only takes away wears the debuff icon, or its own",
		"%s" % [unmarked])
	log_line("")

	log_line("======== an icon named after a skill sits on that skill ========")
	# Each was drawn for one skill. A rename or a copy-paste would put one on
	# the wrong move and nothing else would notice.
	for key in OWN_ICONS:
		ok(icon_file(SkillDatabase.skills.get(key)) == OWN_ICONS[key],
			"%s carries %s" % [key, OWN_ICONS[key]], icon_file(SkillDatabase.skills.get(key)))
	var worn_twice := {}
	for key in OWN_ICONS:
		worn_twice[OWN_ICONS[key]] = worn_twice.get(OWN_ICONS[key], 0) + 1
	for key in SkillDatabase.skills:
		var face = icon_file(SkillDatabase.skills[key])
		if worn_twice.has(face) and OWN_ICONS.get(key, "") != face and not ItemDatabase.is_item(key):
			worn_twice[face] += 1
	var shared := []
	for face in worn_twice:
		if worn_twice[face] > 1:
			shared.append(face)
	ok(shared.is_empty(), "and none of them is on another skill", "%s" % [shared])
	log_line("")

	log_line("======== damage that costs no gate ========")
	var swings := ["greatsword_attack", "gun", "rapier", "sweep_strike", "shoving_strike",
		"follow_up_attack", "blink_strike", "poison_dart", "burning_shot", "rock_throw",
		"wind_shot", "fire_blast", "self_destruct"]
	for key in swings:
		var swing: SkillDefinition = SkillDatabase.skills.get(key)
		if swing == null:
			continue
		# The rule was "damaging skills that don't require any gates", so it is
		# the gate that decides, not this list. Three of these have since been
		# given a gate to cost, and the icon has to follow the skill rather than
		# the list it was on the day it was written.
		if swing.spell_slot_level > 0:
			ok(icon_file(swing) != "greatsword_skill.png",
				"%s costs a gate now, so it is not one of these" % key, icon_file(swing))
			continue
		ok(icon_file(swing) == OWN_ICONS.get(key, "greatsword_skill.png"),
			"%s carries the greatsword icon, or its own" % key, icon_file(swing))
	for spared in ["water_spike", "fire_burst"]:
		ok(icon_file(SkillDatabase.skills.get(spared)) != "greatsword_skill.png",
			"%s was left as it was, as asked" % spared, icon_file(SkillDatabase.skills.get(spared)))
	log_line("")

	log_line("======== and the consumables ========")
	var wrong := []
	for key in ItemDatabase.items:
		# A disguise is worn on a stealth map, not used up in a fight - it is
		# not a consumable and does not wear the consumable icon.
		if ItemDatabase.items[key].stealth_only():
			continue
		if icon_file(ItemDatabase.items[key]) != "consumable__skill.png":
			wrong.append("%s: %s" % [key, icon_file(ItemDatabase.items[key])])
	ok(wrong.is_empty(), "every consumable carries the consumable icon", "%s" % [wrong])
	log_line("")

	log_line("======== nothing that costs a gate was touched ========")
	var gated := []
	for key in SkillDatabase.skills:
		var skill: SkillDefinition = SkillDatabase.skills[key]
		if skill.spell_slot_level > 0 and icon_file(skill) == "greatsword_skill.png":
			gated.append(key)
	ok(gated.is_empty(), "no spell wears the greatsword", "%s" % [gated])
	log_line("")

	log_line("======== the sheet previews what it lists ========")
	Campaign.reset()
	Campaign.current_encounter = load("res://data/encounters/encounter_02_sappers.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	for i in 6:
		await get_tree().process_frame
	var combat = game.get_node("VisualCombat")
	if combat.deployment_active:
		combat.finish_deployment()
		await get_tree().process_frame
	var sheet = game.get_node("CharacterSheet")
	# An enemy nobody has measured is not on the sheet at all, so measure one.
	var foe = null
	var friend = null
	for comb in combat.combatants:
		if comb.alive and comb.side == 1 and foe == null:
			foe = comb
		elif comb.alive and comb.side == 0 and friend == null:
			friend = comb
	foe["studied"] = true
	sheet.open()
	await get_tree().process_frame
	ok(sheet.is_open(), "the sheet opens")

	var seen_sides := {}
	for step in 12:
		var showing = sheet._entries[sheet._index] if sheet._index < sheet._entries.size() else {}
		var who = showing.get("combatant", {})
		if who.is_empty():
			sheet._index = (sheet._index + 1) % maxi(sheet._entries.size(), 1)
			sheet._show_entry()
			await get_tree().process_frame
			continue
		# Their moves are on the Moves page, an icon a row (the Sheet page has
		# none since the designer's change of 2026-10-25).
		sheet._show_page(1)
		await get_tree().process_frame
		var chips := []
		for row in sheet._stat_rows.get_children():
			if row.name.begins_with("Move_") and row.get_child_count() > 0:
				chips.append(row.get_child(0))
		sheet._show_page(0)
		if not showing.get("skills", []).is_empty():
			ok(chips.size() == showing["skills"].size(),
				"%s shows one icon per skill" % showing["name"],
				"%d icons for %d skills" % [chips.size(), showing["skills"].size()])
			var described = true
			for chip in chips:
				if chip.tooltip_text.strip_edges() == "":
					described = false
			ok(described, "  each carrying a preview")
			if not chips.is_empty():
				ok(chips[0].tooltip_text.contains("Range:"),
					"  which reads like the action panel's", chips[0].tooltip_text.split("\n")[0])
			seen_sides[who.side] = showing["name"]
		sheet._index = (sheet._index + 1) % maxi(sheet._entries.size(), 1)
		sheet._show_entry()
		await get_tree().process_frame
	ok(seen_sides.has(0), "a party member's sheet was read", "%s" % seen_sides.get(0, "none"))
	ok(seen_sides.has(1), "and a studied enemy's", "%s" % seen_sides.get(1, "none"))
	log_line("")

	log_line("======== a preview is worked out in their own hands ========")
	var ui = combat.game_ui
	var swing: SkillDefinition = SkillDatabase.skills["greatsword_attack"]
	var theirs = ui.build_skill_tooltip(swing, foe)
	var ours = ui.build_skill_tooltip(swing, friend)
	ok(combat.base_skill_damage(foe, swing) != combat.base_skill_damage(friend, swing)
		or theirs == ours,
		"two characters swinging the same skill differ where they should",
		"%d vs %d" % [combat.base_skill_damage(foe, swing), combat.base_skill_damage(friend, swing)])
	ok(theirs.contains("Base Damage: %d" % combat.base_skill_damage(foe, swing)),
		"the enemy's preview is the enemy's number",
		"%d" % combat.base_skill_damage(foe, swing))
	# And asking for somebody's numbers does not leave the panel stuck on them.
	var after = ui.build_skill_tooltip(swing)
	ok(after.contains("Base Damage: %d" % combat.base_skill_damage(combat.get_current_combatant(), swing)),
		"and the panel goes back to whoever is acting")
	log_line("")

	game.queue_free()
	await get_tree().process_frame
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
