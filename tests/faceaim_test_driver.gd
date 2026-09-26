extends Node
## Aiming at a face: while a skill is aimed, clicking somebody's portrait in the
## party column or their face in the turn queue uses it on them - by the same
## rules as clicking them on the map, reach included - and anything it could not
## be used on refuses, says why, and leaves the aim where it was.

var LOG_PATH := HarnessLog.path_for("faceaim")

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
	get_tree().create_timer(150.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


func settle():
	for i in 3:
		await get_tree().process_frame


## Waits out a skill going off - its animation holds the action lock.
func until_done(controller):
	for i in 600:
		if not controller.action_locked:
			break
		await get_tree().process_frame
	await settle()


func click(button: MouseButton, down: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = down
	return event


## A left click on a face, as the face itself receives it.
func click_face(face: Control):
	face.gui_input.emit(click(MOUSE_BUTTON_LEFT, true))
	face.gui_input.emit(click(MOUSE_BUTTON_LEFT, false))
	await settle()


func aim(controller, skill: String, as_secondary: bool = false):
	controller.set_selected_skill(skill, as_secondary)
	controller.begin_target_selection()
	await settle()


func run_test():
	Campaign.reset()
	Campaign.current_encounter = load("res://encounters/encounter_02_sappers.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	for i in 4:
		await get_tree().process_frame
	var combat: Combat = game.get_node("VisualCombat")
	var controller = game.get_node("Controller")
	var ui = game.get_node("CanvasLayer/UI")
	combat.finish_deployment()
	await settle()
	var cyrus = combat.get_current_combatant()
	var prometheus = {}
	var mark = {}
	for comb in combat.combatants:
		if comb.name == "Prometheus":
			prometheus = comb
		if comb.side == 1 and comb.alive and mark.is_empty():
			mark = comb
	# Nobody answers back: a reaction would muddy what the click did.
	for comb in combat.combatants:
		comb.reaction_used = true
	ok(cyrus.name == "Cyrus" and not prometheus.is_empty() and not mark.is_empty(),
		"Cyrus acting, Prometheus beside him, an enemy to aim at", "%s / %s" % [cyrus.name, mark.get("name", "?")])
	var column = ui.get_node("Status")
	var queue = ui.get_node("TurnQueue/Queue")
	var cyrus_portrait: Control = ui._icon_for(column, cyrus)
	var prometheus_portrait: Control = ui._icon_for(column, prometheus)
	var cyrus_face: Control = ui._icon_for(queue, cyrus)
	var mark_face: Control = ui._icon_for(queue, mark)
	ok(cyrus_portrait != null and prometheus_portrait != null and cyrus_face != null and mark_face != null,
		"their portraits and queue faces are on the HUD")

	log_line("======== Run, which is only ever for himself ========")
	await aim(controller, "run", true)
	ok(controller.is_skill_selected(), "Run is being aimed")
	var tip: String = prometheus_portrait.get_tooltip(Vector2.ZERO)
	ok(tip.contains("Run can only be used on Cyrus"), "Prometheus's portrait says why not", tip.replace("\n", " / "))
	ui._point_out(prometheus)
	ok(controller._blocked_target_position == controller.tile_map.map_to_local(prometheus.position)
		and controller._ally_target_position == null,
		"hovering it marks him on the map as somebody it cannot be used on")
	ui._stop_pointing()
	ok(controller._blocked_target_position == null, "and leaving it takes the mark away")
	await click_face(prometheus_portrait)
	ok(controller.is_skill_selected() and not cyrus.secondary_used_this_turn,
		"clicking him does nothing, and Cyrus is still aiming")
	ok(not ui.is_viewing_other(), "nor does it turn the HUD over to Prometheus, as it would when not aiming")
	await click_face(mark_face)
	ok(controller.is_skill_selected() and not cyrus.secondary_used_this_turn,
		"nor does clicking an enemy's face in the queue")
	ok(mark_face.get_tooltip(Vector2.ZERO).contains("only be used on Cyrus"), "which says why too")
	ok(cyrus_portrait.get_tooltip(Vector2.ZERO) == "",
		"his own portrait has nothing against it - the prompt beside the cursor does the talking")
	ui._point_out(cyrus)
	ok(controller._ally_target_position == controller.tile_map.map_to_local(cyrus.position),
		"hovering it marks him as the one it goes on")
	await click_face(cyrus_portrait)
	await until_done(controller)
	ui._stop_pointing()
	ok(cyrus.secondary_used_this_turn and not controller.is_skill_selected(),
		"clicking it runs - his secondary action spent, the aim put away")
	ok(prometheus_portrait.get_tooltip(Vector2.ZERO).contains("see their side of the HUD"),
		"and with nothing aimed the portraits say what they always did")
	log_line("")

	log_line("======== Gun, and how far it reaches ========")
	var gun: SkillDefinition = SkillDatabase.skills["gun"]
	# Next to him: closer than Gun can be fired.
	var beside = Vector2i(-99999, -99999)
	for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if beside.x == -99999 and combat.can_land_on(mark, cyrus.position + step):
			beside = cyrus.position + step
	ok(beside.x > -99999, "a free tile beside Cyrus", "%s" % beside)
	combat.teleport_to(mark, beside)
	await aim(controller, "gun")
	ok(ui._icon_for(queue, mark).get_tooltip(Vector2.ZERO).contains("Out of reach"),
		"the enemy beside him is too close for Gun, and their face says so")
	var hp_before = mark.hp
	await click_face(mark_face)
	ok(controller.is_skill_selected() and not cyrus.skill_used_this_turn and mark.hp == hp_before,
		"so clicking it refuses - nothing fired, still aiming")
	ok(prometheus_portrait.get_tooltip(Vector2.ZERO).contains("Gun is only for enemies"),
		"and a teammate's portrait says Gun is not for him")
	await click_face(prometheus_portrait)
	ok(controller.is_skill_selected() and not cyrus.skill_used_this_turn, "and refuses the same way")
	# Hidden, their face stays in the queue but gives nothing away.
	mark.hidden = true
	ui._point_out(mark)
	ok(controller._blocked_target_position == null and controller._attack_target_position == null,
		"somebody hidden is not marked on the map from their face")
	ok(ui._icon_for(queue, mark).get_tooltip(Vector2.ZERO).contains("Hidden"), "their face only says they are hidden")
	ui._stop_pointing()
	mark.hidden = false
	# Right-clicking a face puts the aim away, as right-clicking the map does.
	mark_face.gui_input.emit(click(MOUSE_BUTTON_RIGHT, true))
	mark_face.gui_input.emit(click(MOUSE_BUTTON_RIGHT, false))
	await settle()
	ok(not controller.is_skill_selected(), "right-clicking a face puts the aim away")
	log_line("")

	log_line("======== only looking ========")
	# Somewhere Gun can reach and see.
	var spot = Vector2i(-99999, -99999)
	for tile in combat.get_range_tiles(gun, cyrus.position, cyrus.movement_class, cyrus):
		if spot.x == -99999 and combat.get_position_distance(cyrus.position, tile) >= 4 and combat.can_land_on(mark, tile):
			spot = tile
	ok(spot.x > -99999, "somewhere Gun can reach", "%s" % spot)
	combat.teleport_to(mark, spot)
	hp_before = mark.hp
	controller.begin_look("gun", cyrus)
	await settle()
	ok(mark_face.get_tooltip(Vector2.ZERO) == "", "in reach now, the face has nothing against it")
	ui._point_out(mark)
	ok(controller._attack_target_position == controller.tile_map.map_to_local(mark.position),
		"hovering it marks them on the map, even only looking")
	var prompt = ui._hit_preview
	ok(prompt != null and prompt.visible, "and says what it would do to them")
	await click_face(mark_face)
	ok(controller.is_look_only() and not cyrus.skill_used_this_turn and mark.hp == hp_before,
		"but a click on them only looks - nothing fired")
	ui._stop_pointing()
	ok(prompt == null or not prompt.visible, "and the prompt goes when the cursor does")
	controller.cancel_skill_selection()
	await settle()
	log_line("")

	log_line("======== the map refuses the same way ========")
	combat.teleport_to(mark, beside)
	hp_before = mark.hp
	await aim(controller, "gun")
	ok(not controller.aim_click(beside), "clicking them on the map, too close for Gun, is refused")
	ok(controller.is_skill_selected() and not cyrus.skill_used_this_turn and mark.hp == hp_before,
		"and Cyrus is still aiming, nothing fired - it used to put the aim away")
	controller._preview_hits(beside)
	ok(ui._hit_preview == null or not ui._hit_preview.visible, "nor is anything promised there")
	var far = Vector2i(-99999, -99999)
	for tile in controller.get_reachable_tiles(cyrus.position, cyrus.movement_class, 99):
		if far.x == -99999 and combat.get_position_distance(cyrus.position, tile) > gun.max_range \
				and combat.can_land_on(mark, tile):
			far = tile
	if far.x > -99999:
		combat.teleport_to(mark, far)
		ok(not controller.aim_click(far) and controller.is_skill_selected() and not cyrus.skill_used_this_turn,
			"nor on somebody past the end of its reach", "%s" % far)
	else:
		log_line("  (this map has nowhere past Gun's reach to try)")
	ok(not controller.aim_click(cyrus.position) and controller.is_skill_selected(),
		"nor on Cyrus himself")
	combat.teleport_to(mark, spot)
	controller.cancel_skill_selection()
	await settle()
	log_line("")

	log_line("======== fired from the queue ========")
	await aim(controller, "gun")
	var camera_before = combat.camera.position
	await click_face(mark_face)
	await until_done(controller)
	ok(cyrus.skill_used_this_turn, "in reach, clicking their face fires Gun at them")
	ok(combat.camera.position == camera_before or combat.camera.is_following(),
		"instead of taking the view to them, as the same click does when nothing is aimed")
	log_line("")

	game.queue_free()
	await get_tree().process_frame
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
