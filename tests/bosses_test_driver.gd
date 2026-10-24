extends Node
## Bosses, and what anybody can have that bosses lean on: immunities (to
## conditions and to being shoved, moved, robbed), more turns a round, an aura.
## A boss's name across the screen, its bars along the top, its phases, its
## stagger bar - filled by damage, by what it shrugs off, faster while it winds
## up, by bells on the map - and the arena: ash falling a round after it is
## marked, ground that hurts. Things on the map take no turns and never keep a
## fight going. The turn queue runs down the right of the screen.

var LOG_PATH := HarnessLog.path_for("bosses")
const WARDEN_FIGHT := "res://data/encounters/boss_ash_warden.tres"
const BELL_FIGHT := "res://data/encounters/boss_bellkeeper.tres"

var _log: FileAccess = null
var _fail = 0
var game: Node = null
var combat = null
var ui = null
var heard: Array = []


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
	get_tree().create_timer(300.0, true, false, true).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	var booted = get_tree().current_scene
	if booted != null:
		booted.queue_free()
		await settle()
	await the_warden_appears()
	await immunities()
	await two_turns_a_round()
	await the_queue_on_the_right()
	await the_aura()
	await the_stagger_bar()
	await the_phases()
	await the_arena()
	await powder_kegs()
	await the_bellkeeper()
	await close_fight()
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


func settle(frames: int = 3):
	for i in frames:
		await get_tree().process_frame


func open_fight(path: String):
	await close_fight()
	Campaign.reset()
	Campaign.current_encounter = load(path)
	game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle(6)
	combat = game.get_node("VisualCombat")
	ui = combat.game_ui
	heard = []
	combat.update_information.connect(func(text): heard.append(text))
	if combat.deployment_active:
		combat.finish_deployment()
		await settle(3)


func close_fight():
	if game != null and is_instance_valid(game):
		game.queue_free()
		await settle(3)
	game = null


func who(key: String) -> Dictionary:
	for comb in combat.combatants:
		if comb.get("combatant_key", "") == key and comb.alive:
			return comb
	return {}


func all_of(key: String) -> Array:
	return combat.combatants.filter(func(c): return c.get("combatant_key", "") == key and c.alive)


func heard_since(mark: int, words: String) -> bool:
	for i in range(mark, heard.size()):
		if words in heard[i]:
			return true
	return false


func cond(key: String) -> ConditionDefinition:
	return load("res://data/conditions/%s.tres" % key)


func has_condition(comb: Dictionary, key: String) -> bool:
	return combat.conditions_of(comb).any(func(c): return c.resource_path.get_file().get_basename() == key)


## An effect putting `key` on somebody, the way a skill would.
func condition_effect(key: String) -> EffectDefinition:
	var effect := EffectDefinition.new()
	effect.type = EffectDefinition.EffectType.CONDITION
	effect.condition = cond(key)
	return effect


## A free tile beside any tile of `comb`'s that `mover` has room on.
func beside(comb: Dictionary, mover: Dictionary) -> Vector2i:
	for tile in combat.tiles_of(comb):
		for way in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var there: Vector2i = tile + way
			if combat.distance_to(comb, there) == 1 and combat.room_for(mover, there):
				return there
	return Vector2i(-99999, -99999)


func sturdy(comb: Dictionary, hp: int = 5000):
	comb.max_hp = hp
	comb.hp = hp


func the_warden_appears():
	log_line("======== a boss appears ========")
	await open_fight(WARDEN_FIGHT)
	var warden := who("ash_warden")
	ok(not warden.is_empty() and combat.is_boss(warden) and warden.size == Sizes.Size.LARGE, "the Ash Warden is a boss, and Large")
	ok(ui.boss_banner_showing() == "Ash Warden | Warden of the Ash Gate", "its name brought up across the screen",
		ui.boss_banner_showing())
	var bars: BossBars = ui._boss_bars
	ok(bars.visible and bars.row_for(warden.id) != null, "its bar along the top")
	var row: Control = bars.row_for(warden.id)
	ok(row.get_node("Stagger").visible and row.get_node("Hint").text.begins_with("Hit it hard"), "with its stagger bar, and how to fill it")
	ok(row.get_node("HealthBar").marks.size() == 2, "and a mark on its health where each phase begins")
	var screen: Vector2 = ui.get_viewport_rect().size
	var bar_box: Rect2 = bars.get_global_rect()
	ok(absf(bar_box.get_center().x - screen.x * 0.5) < 2.0 and bar_box.position.y < 20.0, "at the top, in the middle",
		"%s" % bar_box)
	ok(ui.banner_top() > bar_box.end.y, "and the turn banner moves down under it")
	log_line("")


func immunities():
	log_line("======== immunities ========")
	var warden := who("ash_warden")
	var cyrus := who("cyrus")
	sturdy(warden)
	var mark := heard.size()
	var before: float = warden.stagger
	combat.apply_effect(cyrus, warden, condition_effect("stunned"))
	ok(not has_condition(warden, "stunned") and heard_since(mark, "immune to stunned"), "a stun does not take, and it says so")
	ok(is_equal_approx(warden.stagger - before, 20.0), "but counts on its stagger bar, as its bar says",
		"%.1f" % (warden.stagger - before))
	combat.apply_effect(cyrus, warden, condition_effect("burn"))
	ok(has_condition(warden, "burn"), "what it is not immune to takes")
	var push := EffectDefinition.new()
	push.type = EffectDefinition.EffectType.PUSH
	push.knockback_distance = 2
	var standing: Vector2i = warden.position
	combat.apply_knockback(cyrus, warden, push, false)
	ok(warden.position == standing and heard_since(mark, "immune to being shoved"), "and it cannot be shoved")
	ok(combat.immune_to(warden, Immunity.Kind.TELEPORTED) and not combat.immune_to(cyrus, Immunity.Kind.TELEPORTED),
		"or moved by somebody else's teleport")
	var golem: Dictionary = combat.create_combatant(CombatantDatabase.combatants.golem, "golem")
	ok(combat.immune_to_condition(golem, cond("poisoned")) and combat.immune_to(golem, Immunity.Kind.SHOVED)
		and not combat.is_boss(golem), "a stone golem, no boss at all, cannot be poisoned or shoved either")
	warden.status_effects = []
	warden.stagger = 0.0
	log_line("")


func two_turns_a_round():
	log_line("======== two turns a round ========")
	var warden := who("ash_warden")
	var index: int = combat.combatants.find(warden)
	var places := []
	for i in combat.turn_queue.size():
		if combat.turn_queue[i] == index:
			places.append(i)
	ok(places.size() == 2, "the Warden is in the order twice", "%s of %d" % [places, combat.turn_queue.size()])
	ok(places.size() == 2 and places[1] - places[0] >= 2, "spread through the round, not back to back")
	var faces: Array = ui._queue_faces_for(warden)
	ok(faces.size() == 2, "with a face in the queue for each turn")
	log_line("")
	log_line("======== a declared move waits for the party ========")
	var cyrus := who("cyrus")
	combat.declare(warden, "ground_pound", cyrus.position)
	combat._turn_begins_for(warden)
	ok(warden.has("declared") and not combat.declared_due(warden), "its own second turn coming round does not land it")
	for comb in combat.combatants:
		if comb.alive and comb.side == 0:
			combat._turn_begins_for(comb)
	ok(combat.declared_due(warden), "every one of the party having had a turn does")
	combat.drop_declared(warden, "test")
	log_line("")


func the_queue_on_the_right():
	log_line("======== the turn queue runs down the right ========")
	await settle(2)
	var box: ScrollContainer = ui.get_node("TurnQueue")
	var screen: Vector2 = ui.get_viewport_rect().size
	var rect := box.get_global_rect()
	ok(absf(rect.end.x - (screen.x - ui.QUEUE_EDGE)) <= 1.0, "against the right-hand edge", "%s" % rect)
	ok(rect.position.y <= ui.QUEUE_TOP + 0.5 and rect.end.y <= ui.queue_floor() + 0.5, "from the top, down to above the log",
		"%.0f to %.0f, log at %.0f" % [rect.position.y, rect.end.y, ui.queue_floor()])
	var faces: Array = ui.get_node("TurnQueue/Queue").get_children()
	var downwards := true
	for i in range(1, faces.size()):
		downwards = downwards and faces[i].position.y > faces[i - 1].position.y and is_equal_approx(faces[i].position.x, faces[0].position.x)
	ok(faces.size() > 1 and downwards, "top to bottom in the order turns come", "%d faces" % faces.size())
	var crowd: Array = []
	for i in 12:
		crowd.append_array(combat.turn_queue)
	ui.update_turn_queue(combat.combatants, crowd)
	await settle(2)
	ok(ui.turn_queue_overflows() and box.get_global_rect().end.y <= ui.queue_floor() + 0.5, "too many to fit, it stops above the log and scrolls")
	box.scroll_vertical = 0
	var wheel := InputEventMouseButton.new()
	wheel.pressed = true
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	ui._on_queue_input(wheel, {})
	ok(box.scroll_vertical > 0, "the wheel rolls it down")
	ui.update_turn_queue(combat.combatants, combat.turn_queue)
	await settle(2)
	ok(not ui.turn_queue_overflows(), "and back to a short queue, it fits")
	var view: Rect2 = ui.map_view_rect()
	ok(view.end.x <= box.get_global_rect().position.x and view.position.y >= ui._boss_bars.get_global_rect().end.y,
		"a pad's cursor is kept off it, and off the boss's bar")
	log_line("")


func the_aura():
	log_line("======== an aura ========")
	var warden := who("ash_warden")
	var cyrus := who("cyrus")
	var near := beside(warden, cyrus)
	combat.teleport_to(cyrus, near)
	cyrus.status_effects = []
	combat._turn_begins_for(cyrus)
	ok(has_condition(cyrus, "choking_ash"), "starting a turn beside the Warden, Cyrus chokes on its ash")
	cyrus.status_effects = []
	var far := Vector2i(-99999, -99999)
	var region: Rect2i = combat.controller._astargrid.region
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var tile := Vector2i(x, y)
			if combat.room_for(cyrus, tile) and combat.distance_to(warden, tile) > 4 and far.x == -99999:
				far = tile
	combat.teleport_to(cyrus, far)
	combat._turn_begins_for(cyrus)
	ok(not has_condition(cyrus, "choking_ash"), "out of its reach, he does not")
	ok(combat.aura_tiles().any(func(aura): return aura.hostile and aura.tiles.size() > 4), "and its reach is drawn on the board")
	log_line("")


func the_stagger_bar():
	log_line("======== the stagger bar ========")
	var warden := who("ash_warden")
	var cyrus := who("cyrus")
	sturdy(warden)
	warden.stagger = 0.0
	combat.lose_hp(warden, 30, Damage.Type.PHYSICAL)
	ok(is_equal_approx(warden.stagger, 30.0), "a point of stagger for each point of damage", "%.1f" % warden.stagger)
	combat.declare(warden, "ground_pound", warden.position + Vector2i(-1, 0))
	combat.lose_hp(warden, 20, Damage.Type.PHYSICAL)
	ok(is_equal_approx(warden.stagger, 70.0), "twice that while it is winding up a declared move", "%.1f" % warden.stagger)
	var mark := heard.size()
	combat.lose_hp(warden, 30, Damage.Type.PHYSICAL)
	ok(combat.is_staggered(warden), "full, it is staggered")
	ok(not warden.has("declared") and heard_since(mark, "comes to nothing - staggered"), "and what it was winding up comes to nothing")
	ok(ui.boss_banner_showing() == "Ash Warden | Staggered!", "said across the screen", ui.boss_banner_showing())
	ok(warden.stagger == 0.0, "the bar empties")
	combat.lose_hp(warden, 50, Damage.Type.PHYSICAL)
	ok(warden.stagger == 0.0, "and does not fill while it reels")
	var skill: SkillDefinition = SkillDatabase.skills.rapier
	ok(is_equal_approx(combat.damage_dealt_multiplier(cyrus, warden, skill) / combat.path_damage_multiplier(cyrus, skill), 1.5),
		"it is hit half as hard again")
	# Its next turn is lost to it.
	var index: int = combat.combatants.find(warden)
	var p: int = combat.combatants.find(cyrus)
	combat.turn_queue = [p, index, p]
	combat.turn = 0
	combat.current_combatant = p
	mark = heard.size()
	await combat.advance_turn()
	await settle(2)
	ok(heard_since(mark, "is staggered and loses their turn"), "its next turn is lost")
	ok(not combat.is_staggered(warden), "and then it is over")
	ok(combat.damage_taken_multiplier(warden) == 1.0, "and it is hit as hard as ever")
	log_line("")


func the_phases():
	log_line("======== phases ========")
	var warden := who("ash_warden")
	var most: int = combat.get_effective_stat(warden, "max_hp")
	warden.hp = roundi(most * 0.7)
	var imps_before := all_of("imp").size()
	combat.lose_hp(warden, roundi(most * 0.05))
	ok(warden.phase == 1 and warden.phase_name == "The Ash Rises", "below two thirds, its second phase begins", warden.phase_name)
	ok(ui.boss_banner_showing() == "Ash Warden | The Ash Rises", "named across the screen", ui.boss_banner_showing())
	ok(warden.skill_list.has("rockfall") and combat._hazards_running.size() == 1, "it learns Rockfall, and the ash begins to fall")
	ok(ui._boss_bars.row_for(warden.id).get_node("Top/Phase").text == "The Ash Rises", "the bar says which phase")
	ok(combat.immune_to_condition(warden, cond("stunned")), "still unstunnable")
	# Crossed by a lingering wound ticking as its turn opens, with more on it
	# than the phase leaves behind: the list shrinks under the ticks.
	# The older one harmless, so it leaves the new phase's stagger bar as it began.
	var wound := func(amount: int): return {"stat": "dot", "duration": 3, "min_amount": amount, "max_amount": amount,
		"damage_type": Damage.Type.PHYSICAL, "source_name": "test"}
	warden.status_effects = [wound.call(0),
		{"stat": "condition", "condition": cond("burn"), "duration": 3, "source_name": "test"},
		{"stat": "condition", "condition": cond("burn"), "duration": 2, "source_name": "test"},
		wound.call(40)]
	warden.hp = int(most * 0.33) + 2
	var mark := heard.size()
	combat.start_of_turn_effects(warden)
	var ticks := 0
	for i in range(mark, heard.size()):
		if "from a lingering effect" in heard[i]:
			ticks += 1
	ok(ticks == 2 and warden.status_effects.size() == 2,
		"a tick that brings on a phase shedding conditions: the turn's effects still all go through, once each",
		"%d ticks, %d left on it" % [ticks, warden.status_effects.size()])
	ok(warden.phase == 2 and warden.phase_name == "Cinders and Fury", "below a third, the last")
	ok(warden.stagger_def.drain_per_round > 0.0 and warden.stagger == 0.0, "its bar now the burst kind, and empty")
	ok(not combat.immune_to_condition(warden, cond("stunned")), "its armour cracked, a stun takes now")
	ok(not has_condition(warden, "burn"), "it shook off what was on it")
	warden.status_effects = []
	ok(all_of("imp").size() == imps_before + 2, "and called two imps to its side", "%d" % all_of("imp").size())
	warden.stagger = 60.0
	combat._drain_stagger_bars()
	ok(is_equal_approx(warden.stagger, 15.0), "the burst bar drains at the top of every round", "%.1f" % warden.stagger)
	log_line("")


func the_arena():
	log_line("======== the arena ========")
	var cyrus := who("cyrus")
	var warden := who("ash_warden")
	sturdy(cyrus)
	cyrus.status_effects = []
	combat._hazards_running.clear()
	combat._hazard_marks.clear()
	var falling := HazardDefinition.new()
	falling.display_name = "Test rocks"
	falling.aim = HazardDefinition.Aim.THESE_TILES
	falling.tiles = Array([cyrus.position, warden.position], TYPE_VECTOR2I, "", null)
	falling.radius = 0
	falling.damage = 30
	falling.condition = cond("choking_ash")
	falling.stagger = 15.0
	combat._hazards_running.append({"hazard": falling, "from": combat.round_number + 1})
	combat.round_number += 1
	combat._arena_round_begins()
	ok(combat.hazard_warning_tiles().has(cyrus.position), "rocks are marked where they will fall")
	var hp_before: int = cyrus.hp
	ok(cyrus.hp == hp_before, "and nothing has fallen yet")
	warden.stagger = 0.0
	combat._hazards_running.clear()
	combat.round_number += 1
	combat._arena_round_begins()
	ok(cyrus.hp < hp_before and has_condition(cyrus, "choking_ash"), "a round later they come down on whoever is there",
		"%d -> %d" % [hp_before, cyrus.hp])
	ok(warden.stagger >= 15.0 or combat.is_staggered(warden), "and the boss caught under them is staggered by them",
		"%.1f" % warden.stagger)
	ok(combat.hazard_warning_tiles().is_empty(), "and the marks are gone")
	var ground := HazardDefinition.new()
	ground.display_name = "Test fire"
	ground.kind = HazardDefinition.Kind.GROUND
	ground.aim = HazardDefinition.Aim.THESE_TILES
	ground.tiles = Array([cyrus.position], TYPE_VECTOR2I, "", null)
	ground.radius = 0
	ground.damage = 20
	ground.lasts_rounds = 2
	combat._hazards_running.append({"hazard": ground, "from": combat.round_number + 1})
	combat.round_number += 1
	combat._arena_round_begins()
	combat._hazards_running.clear()
	hp_before = cyrus.hp
	combat._turn_begins_for(cyrus)
	ok(cyrus.hp == hp_before and combat.hazard_warning_tiles().has(cyrus.position), "bad ground is marked a round before it hurts")
	combat.round_number += 1
	combat._arena_round_begins()
	combat._turn_begins_for(cyrus)
	ok(cyrus.hp < hp_before and combat.bad_ground_tiles().has(cyrus.position), "then whoever starts a turn on it is hurt")
	combat.round_number += 2
	combat._arena_round_begins()
	ok(combat.bad_ground_tiles().is_empty(), "until its time is up")
	log_line("")


func powder_kegs():
	log_line("======== things on the map ========")
	await open_fight(WARDEN_FIGHT)
	var kegs := all_of("powder_keg")
	var warden := who("ash_warden")
	var cyrus := who("cyrus")
	sturdy(cyrus)
	sturdy(warden)
	ok(kegs.size() == 2, "two powder kegs on the map")
	var keg_index: int = combat.combatants.find(kegs[0])
	ok(not combat.turn_queue.has(keg_index) and not combat.groups[1].has(keg_index), "on nobody's side, with no turns")
	ok(cyrus.skill_list.has("use"), "the party can Use them")
	var near := beside(kegs[0], cyrus)
	combat.teleport_to(cyrus, near)
	await settle(1)
	combat.current_combatant = combat.combatants.find(cyrus)
	cyrus.skill_used_this_turn = false
	var empty := Vector2i(-99999, -99999)
	for way in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		if combat.get_combatant_at(cyrus.position + way).is_empty():
			empty = cyrus.position + way
	await combat.use_skill("use", cyrus, empty, false)
	ok(not cyrus.skill_used_this_turn and heard.back().contains("nothing there"), "Used on nothing, it is refused and costs nothing")
	warden.stagger = 0.0
	var hp_before: int = cyrus.hp
	await combat.use_skill("use", cyrus, kegs[0].position, false)
	await settle(3)
	ok(not kegs[0].alive, "Used, the keg goes up and is gone")
	ok(cyrus.hp < hp_before, "burning whoever was beside it - Cyrus included")
	ok(warden.stagger >= 25.0 or combat.is_staggered(warden), "and staggering the Warden by it", "%.1f" % warden.stagger)
	warden.stagger = 0.0
	var rapier: SkillDefinition = SkillDatabase.skills.rapier
	var hit := EffectDefinition.new()
	hit.type = EffectDefinition.EffectType.DAMAGE
	for i in 30:
		if not kegs[1].alive:
			break
		combat.do_damage(cyrus, kegs[1], hit, rapier)
	ok(not kegs[1].alive and warden.stagger >= 25.0, "the other, broken, goes up just the same")
	log_line("")
	log_line("======== they never keep a fight going ========")
	await open_fight(WARDEN_FIGHT)
	ok(all_of("powder_keg").size() == 2, "both kegs standing")
	for comb in combat.combatants.duplicate():
		if comb.alive and comb.side == 1 and not comb.has("object"):
			comb.hp = 0
			combat.combatant_die(comb)
	await settle(2)
	ok(combat.combat_over, "every enemy down is a win, whatever is still standing on the map")
	log_line("")


func the_bellkeeper():
	log_line("======== a small boss, staggered by its bells ========")
	await open_fight(BELL_FIGHT)
	var keeper := who("bellkeeper")
	var bells := all_of("bell")
	var cyrus := who("cyrus")
	sturdy(keeper)
	sturdy(cyrus)
	ok(keeper.size == Sizes.Size.SMALL and combat.is_boss(keeper), "the Bellkeeper is a boss half a tile wide")
	ok(ui._boss_bars.row_for(keeper.id) != null, "with its bar along the top all the same")
	ok(bells.size() == 3, "three bells on the map")
	combat.lose_hp(keeper, 80)
	ok(keeper.stagger == 0.0, "nothing done to it fills its bar")
	var hit := EffectDefinition.new()
	hit.type = EffectDefinition.EffectType.DAMAGE
	var mark := heard.size()
	combat.do_damage(cyrus, bells[0], hit, SkillDatabase.skills.rapier)
	ok(bells[0].alive and heard_since(mark, "takes no harm"), "and a bell cannot be broken")
	combat.current_combatant = combat.combatants.find(cyrus)
	for bell in bells:
		combat.teleport_to(cyrus, beside(bell, cyrus))
		await settle(1)
		cyrus.skill_used_this_turn = false
		await combat.use_skill("use", cyrus, bell.position, false)
		await settle(2)
	ok(bells.all(func(bell): return not bell.alive), "each rings once")
	ok(combat.is_staggered(keeper), "and the three of them stagger it", "%.1f" % keeper.stagger)
	var lost: int = 0
	for effect in keeper.status_effects:
		if effect.get("condition") == combat.STAGGERED:
			lost = effect.duration
	ok(lost == 2, "for two of its turns, as its bar says")
	log_line("")
