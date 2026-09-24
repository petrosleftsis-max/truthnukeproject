extends Node
## Checks that every skill has an icon that actually loads, and that the
## action buttons pick it up.

var LOG_PATH := HarnessLog.path_for("icon")

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
	get_tree().create_timer(60.0).timeout.connect(func(): log_line("TIMED OUT"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


func run_test():
	log_line("======== every skill has a loadable icon ========")
	var keys = SkillDatabase.skills.keys()
	keys.sort()
	for key in keys:
		var skill: SkillDefinition = SkillDatabase.skills[key]
		var size = "null" if skill.icon == null else "%dx%d" % [skill.icon.get_width(), skill.icon.get_height()]
		ok(skill.icon != null, "%s (%s)" % [key, skill.name], size)
	log_line("")

	log_line("======== the action buttons show them ========")
	Campaign.reset()
	Campaign.current_encounter = load("res://encounters/encounter_01_ambush.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	var combat = game.get_node("VisualCombat")
	combat.finish_deployment()
	await get_tree().process_frame
	await get_tree().process_frame

	# The grid is a fixed set of slots - only the filled ones should have an
	# icon, the spares stay blank.
	var current = combat.get_current_combatant()
	var expected = combat.main_skills_of(current).size()
	var grid = game.get_node("CanvasLayer/UI/Actions/ActionsPanel/ActionsGrid")
	var with_icon = 0
	for button in grid.get_children():
		if button.icon != null:
			with_icon += 1
	ok(expected > 0, "the combatant up has skills to show", "%s: %d" % [current.name, expected])
	ok(with_icon == expected, "every filled slot carries an icon", "%d of %d" % [with_icon, expected])
	log_line("")

	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
