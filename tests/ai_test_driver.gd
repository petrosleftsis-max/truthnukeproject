extends Node
## Headless harness: drives real enemy turns in the real scene and reports
## whether Caster / Priest actually reposition, and how far they end up from
## the nearest player. Scratchpad-only - not part of the game project.
## Logs to a file (Godot's stdout is block-buffered when piped) and force-quits
## on a watchdog so a hang still leaves usable diagnostics behind.

var LOG_PATH := HarnessLog.path_for("ai")
const WATCHDOG_SECONDS = 120.0

var _log: FileAccess = null
var _done = false


func log_line(text: String):
	if _log == null:
		return
	_log.store_line(text)
	_log.flush()


func _ready():
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	log_line("driver ready")
	get_tree().create_timer(WATCHDOG_SECONDS).timeout.connect(_on_watchdog)
	await get_tree().process_frame
	await get_tree().process_frame
	run_test()


func _on_watchdog():
	if _done:
		return
	log_line("WATCHDOG FIRED after %ss - test did not finish" % WATCHDOG_SECONDS)
	get_tree().quit(2)


func find_combat(node: Node):
	if node is Combat:
		return node
	for c in node.get_children():
		var found = find_combat(c)
		if found != null:
			return found
	return null


func describe(combat) -> String:
	var parts = []
	for c in combat.combatants:
		if c.side != 1:
			continue
		if not c.alive:
			parts.append("%s DEAD" % c.name)
			continue
		parts.append("%s[%s] %s d=%d" % [
			c.name, c.ai_function, c.position,
			combat.distance_to_nearest_player(c.position)
		])
	return ", ".join(parts)


func run_test():
	var combat = find_combat(get_tree().root)
	if combat == null:
		log_line("TEST FAIL: no Combat node found")
		_done = true
		get_tree().quit(1)
		return
	log_line("found Combat, %d combatants" % combat.combatants.size())

	# The scene's three enemies are ranger / copycat / healer; retarget the
	# copycat so this run exercises ai_caster too.
	for c in combat.combatants:
		if c.name == "Goblin 2":
			c.ai_function = "ai_caster"

	var players = []
	for c in combat.combatants:
		if c.side == 0:
			players.append("%s %s" % [c.name, c.position])
	log_line("PLAYERS: " + ", ".join(players))
	log_line("BEFORE:  " + describe(combat))

	var start_positions = {}
	for c in combat.combatants:
		if c.side == 1:
			start_positions[c.name] = c.position

	var advances = 0
	while advances < 4 and not combat.combat_over:
		log_line("-> advance_turn() #%d starting (current=%s)" % [advances + 1, combat.get_current_combatant().name])
		await combat.advance_turn()
		advances += 1
		log_line("AFTER %d: %s" % [advances, describe(combat)])

	log_line("---- SUMMARY ----")
	for c in combat.combatants:
		if c.side != 1:
			continue
		var moved = c.position != start_positions[c.name]
		log_line("%-9s %-16s start=%s end=%s moved=%s" % [
			c.name, c.ai_function, start_positions[c.name], c.position, moved
		])
	log_line("DONE")
	# Nothing above asserts anything - this is a trace of what each archetype
	# did with its turn, read by eye. It stays in the sweep because driving the
	# AI through four turns still catches a script error or a hang, which the
	# runner does judge; the line is how the runner tells "ran to the end" from
	# "died halfway". The archetypes suite is where their behaviour is asserted.
	log_line("FAILURES: 0")
	_done = true
	get_tree().quit()

