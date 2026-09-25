extends Node
## The big portrait beside the skill panel has to keep up with the fight.
##
## It belongs to whoever is acting. It was written only on a turn change, so
## anything that moved their health during their own turn - drinking a potion,
## healing themselves, taking a reaction on the way out - left it showing the
## health they started the turn with, while the party portraits two inches away
## showed the truth.

var LOG_PATH := HarnessLog.path_for("portrait")
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
	get_tree().create_timer(200.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


func run_test():
	Campaign.reset()
	Campaign.current_encounter = load("res://encounters/encounter_02_sappers.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	for i in 6:
		await get_tree().process_frame
	var combat = game.get_node("VisualCombat")
	var ui = combat.game_ui
	log_line("======== the HUD during deployment ========")
	if combat.deployment_active:
		var kept := []
		var showing := []
		for child in ui.get_node("Actions").get_children():
			if child.visible:
				showing.append(child.name)
		ok(showing.has("EndTurnButton"), "Begin Battle is there to press", "%s" % [showing])
		ok(showing.has("SelectTargetMessage"), "and the instruction banner")
		for unwanted in ["ActionsPanel", "SkillPanelTabs", "SkillPanelLabel", "Movement",
				"Information", "LogToggle", "SpellSlots", "StatusIcon"]:
			if not showing.has(unwanted):
				kept.append(unwanted)
		ok(kept.size() == 8, "and nothing else is on screen", "hidden: %s, showing: %s" % [kept.size(), showing])
		# A refresh from anywhere must not hand the skills back mid-placement.
		ui.refresh_action_buttons()
		await get_tree().process_frame
		var leaked := []
		for child in ui.get_node("Actions").get_children():
			if child.visible and not child.name in ["EndTurnButton", "SelectTargetMessage"]:
				leaked.append(child.name)
		ok(leaked.is_empty(), "a refresh does not bring them back", "%s" % [leaked])
		var pressable := []
		for action in ui.get_node("Actions/ActionsPanel/ActionsGrid").get_children():
			if not action.disabled:
				pressable.append(action.name)
		ok(pressable.is_empty(), "and no skill button is pressable", "%s" % [pressable])
		combat.finish_deployment()
		await get_tree().process_frame
		var back := []
		for wanted in ["ActionsPanel", "SkillPanelTabs", "Movement", "Information", "LogToggle"]:
			if ui.get_node("Actions").get_node(wanted).visible:
				back.append(wanted)
		ok(back.size() == 5, "and beginning the battle gives the HUD back", "%s" % [back])
	log_line("")


	var acting = null
	for comb in combat.combatants:
		if comb.side == 0 and comb.alive:
			acting = comb
			break
	ok(acting != null, "somebody of the party to act")
	if acting == null:
		log_line("FAILURES: %d" % _fail)
		get_tree().quit(1)
		return

	# Hand them the turn the way the turn loop does.
	for i in combat.combatants.size():
		if is_same(combat.combatants[i], acting):
			combat.current_combatant = i
	ui.show_combatant_status_main(acting)
	await get_tree().process_frame

	var big = ui.get_node("Actions/StatusIcon/Layout/HealthText")
	var max_hp = combat.get_effective_stat(acting, "max_hp")
	ok(big.text == "%d/%d" % [acting.hp, max_hp],
		"it opens the turn showing their health", big.text)

	log_line("======== hurt during their own turn ========")
	acting.hp = maxi(1, acting.hp - 25)
	combat.update_combatants.emit(combat.combatants)
	await get_tree().process_frame
	ok(big.text == "%d/%d" % [acting.hp, max_hp],
		"the portrait beside the skills follows", "shows %s, they have %d" % [big.text, acting.hp])

	log_line("======== and healed again, without the turn changing ========")
	var hurt_at = acting.hp
	acting.hp = mini(max_hp, acting.hp + 15)
	combat.update_combatants.emit(combat.combatants)
	await get_tree().process_frame
	ok(big.text == "%d/%d" % [acting.hp, max_hp],
		"it follows the heal too", "%d -> %s" % [hurt_at, big.text])

	# What the player was comparing it against.
	var column = null
	for child in ui.get_node("Status").get_children():
		if child.get_meta("combatant_id", -2) == acting.get("id", 0):
			column = child
	if column != null:
		ok(column.get_node("Layout/HealthText").text == big.text,
			"and agrees with the party portrait next to it",
			"%s vs %s" % [column.get_node("Layout/HealthText").text, big.text])
	log_line("")

	log_line("======== an enemy's health does not steal the portrait ========")
	var enemy = null
	for comb in combat.combatants:
		if comb.side == 1 and comb.alive:
			enemy = comb
			break
	if enemy != null:
		var before = big.text
		enemy.hp = maxi(1, enemy.hp - 30)
		combat.update_combatants.emit(combat.combatants)
		await get_tree().process_frame
		ok(big.text == before, "it still shows the acting character", "%s" % big.text)
	log_line("")

	log_line("======== folding the log away ========")
	var panel = ui.get_node("Actions/Information")
	var toggle = ui.get_node("Actions/LogToggle")
	ok(panel.visible, "the log starts open")
	ok(toggle.visible and toggle.text == "-", "with a button to fold it", toggle.text)
	# Placed by hand in the scene, so check it really lands on the panel.
	var panel_rect = panel.get_global_rect()
	var toggle_rect = toggle.get_global_rect()
	ok(panel_rect.has_point(toggle_rect.get_center()),
		"the button sits on the log itself", "button %s, log %s" % [toggle_rect, panel_rect])
	ok(toggle_rect.end.x <= panel_rect.end.x + 1.0
		and toggle_rect.position.y >= panel_rect.position.y - 1.0
		and toggle_rect.position.y < panel_rect.get_center().y,
		"in its top right corner", "%s" % toggle_rect)
	ok(ui.get_viewport_rect().encloses(toggle_rect),
		"and on screen", "screen %s" % ui.get_viewport_rect())
	ui.toggle_log()
	await get_tree().process_frame
	ok(not panel.visible, "pressing it folds the log away")
	ok(toggle.visible, "and the button stays, to get it back")
	ok(toggle.text == "+", "reading the other way now", toggle.text)
	# Aiming a skill hides the whole cluster and puts it back afterwards.
	ui._set_aiming(true)
	await get_tree().process_frame
	ui._set_aiming(false)
	await get_tree().process_frame
	ok(not panel.visible, "and aiming a skill does not unfold it behind their back")
	ui.toggle_log()
	await get_tree().process_frame
	ok(panel.visible, "pressing it again brings the log back")
	ok(toggle.text == "-", "and the button reads as it started", toggle.text)
	log_line("")

	game.queue_free()
	await get_tree().process_frame
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
