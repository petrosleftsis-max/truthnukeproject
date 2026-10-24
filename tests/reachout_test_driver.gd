extends Node
## Leaving the reach of two or more at once: every one of them whose reaction is
## unspent gets their swing at the one going, one after another - not only the
## first (the user's, 2026-10-25).

var LOG_PATH := HarnessLog.path_for("reachout")
const WATCHER := "res://data/encounters/encounter_03_watcher.tres"

var _log: FileAccess = null
var _fail = 0
var game: Node = null
var combat = null
var reacted: Array = []


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
	get_tree().create_timer(120.0, true, false, true).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	var booted = get_tree().current_scene
	if booted != null:
		booted.queue_free()
		await settle()
	await open_fight()
	await leaving_two()
	if game != null:
		game.queue_free()
		await settle(3)
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


func settle(frames: int = 3):
	for i in frames:
		await get_tree().process_frame


func open_fight():
	Campaign.reset()
	Campaign.set_party(["cyrus", "enfina", "prometheus", "alithia"], 18)
	Campaign.current_map = "res://maps/crossroads_explore.tscn"
	Campaign.return_to_position = true
	Campaign.current_encounter = load(WATCHER)
	game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle(6)
	combat = game.get_node("VisualCombat")
	if combat.deployment_active:
		combat.finish_deployment()
		await settle(2)
	# Nobody at the keyboard: a reaction is taken without asking.
	combat.reaction_prompt = null
	combat.metric.connect(func(event, data): if event == "action" and data.get("reaction", false): reacted.append(data.who.name))
	for comb in combat.combatants:
		comb.max_hp = 9999
		comb.hp = 9999
		comb.status_effects.append({"stat": "accuracy", "amount": 200, "duration": 99, "source_name": "test"})


func who(key: String) -> Dictionary:
	for comb in combat.combatants:
		if comb.get("combatant_key", "") == key and not comb.get("illusion", false):
			return comb
	return {}


func put(comb: Dictionary, tile: Vector2i):
	var from: Vector2i = comb.position
	comb.position = tile
	if comb.get("sprite") != null:
		comb.sprite.position = combat.controller.tile_map.map_to_local(tile)
	combat.controller.reposition_combatant(from, tile)


func open(tile: Vector2i) -> bool:
	return combat.controller.is_in_bounds(tile) and combat.controller.is_on_map(tile) \
		and combat.get_combatant_at(tile).is_empty() and not combat.controller.is_tile_blocking(tile, 0)


## The nearest tile with open ground two tiles all round it.
func clearing(near: Vector2i) -> Vector2i:
	var region: Rect2i = combat.controller._astargrid.region
	var best := Vector2i(-1, -1)
	var best_gap := 999999
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var there := Vector2i(x, y)
			var gap: int = combat.get_position_distance(near, there)
			if gap >= best_gap:
				continue
			var clear := true
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					if not open(there + Vector2i(dx, dy)):
						clear = false
			if clear:
				best = there
				best_gap = gap
	return best


func leaving_two():
	log_line("======== leaving the reach of two at once ========")
	var enfina := who("enfina")
	var cyrus := who("cyrus")
	var foe: Dictionary = combat.combatants.filter(func(comb): return comb.side == 1 and comb.alive and not comb.has("object"))[0]
	var at := clearing(enfina.position)
	ok(at != Vector2i(-1, -1), "an open patch to measure on")
	put(foe, at)
	put(enfina, at + Vector2i.LEFT)
	put(cyrus, at + Vector2i.UP)
	for comb in [enfina, cyrus]:
		comb.reaction_used = false
	# The foe's own turn, its step out of both their reaches.
	combat.current_combatant = combat.combatants.find(foe)
	var from: Vector2i = foe.position
	put(foe, at + Vector2i.RIGHT + Vector2i.DOWN)
	reacted.clear()
	await combat.check_reactive_skills(foe, from, foe.position)
	await settle(3)
	ok(reacted.has(enfina.name) and reacted.has(cyrus.name), "both of them swing at it as it goes", "%s" % [reacted])
	ok(enfina.reaction_used and cyrus.reaction_used, "  and each spends their own reaction")

	# The other way about: one of the party leaving two of the other side's
	# reaches - the Barbarian's Greatsword Attack and the Priest's Rapier.
	var alithia := who("alithia")
	var barbarian := who("barbarian")
	var priest := who("priest")
	var spot := clearing(alithia.position)
	put(alithia, spot)
	put(barbarian, spot + Vector2i.LEFT)
	put(priest, spot + Vector2i.UP)
	for comb in [barbarian, priest]:
		comb.reaction_used = false
		comb.erase("hidden")
	combat.current_combatant = combat.combatants.find(alithia)
	from = alithia.position
	put(alithia, spot + Vector2i.RIGHT + Vector2i.DOWN)
	reacted.clear()
	await combat.check_reactive_skills(alithia, from, alithia.position)
	await settle(3)
	ok(reacted.has(barbarian.name) and reacted.has(priest.name), "Alithia leaving two of them: both swing at her", "%s" % [reacted])
	log_line("")

	log_line("======== asked, each of them in turn ========")
	combat.reaction_prompt = game.find_child("ReactionPrompt", true, false)
	ok(combat.reaction_prompt != null, "the prompt is there")
	put(foe, at)
	put(enfina, at + Vector2i.LEFT)
	put(cyrus, at + Vector2i.UP)
	for comb in [enfina, cyrus]:
		comb.reaction_used = false
	combat.current_combatant = combat.combatants.find(foe)
	from = foe.position
	put(foe, at + Vector2i.RIGHT + Vector2i.DOWN)
	reacted.clear()
	var done := [false]
	var run := func():
		await combat.check_reactive_skills(foe, from, foe.position)
		done[0] = true
	run.call()
	var asked := 0
	var until := Time.get_ticks_msec() + 15000
	while not done[0] and Time.get_ticks_msec() < until:
		if combat.reaction_prompt._waiting:
			asked += 1
			# Its first button: Use, or the first of what is offered.
			combat.reaction_prompt._choose(0)
		await get_tree().process_frame
	ok(done[0] and asked == 2 and reacted.has(enfina.name) and reacted.has(cyrus.name), "both asked, both say yes, both swing",
		"%d asked, %s" % [asked, reacted])
	log_line("")
