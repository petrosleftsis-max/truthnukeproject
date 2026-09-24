extends Node
## Every way a combatant can be hurt shows it, and the blow that kills one of
## the player's own frames the screen twice as hard.

var LOG_PATH := HarnessLog.path_for("lethal")

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


func floaters(sprite) -> Array:
	var found = []
	for child in sprite.get_parent().get_children():
		if child is FloatingNumber and not child.is_queued_for_deletion():
			found.append(child)
	return found


## The alpha the vignette settles on at the top of its bloom.
## Watches the vignette every frame and keeps the highest it reached, resetting
## whenever a test zeroes it.
##
## Reading the alpha once, ten frames after the hit, reads a point on the way
## down rather than the flare itself: under load two such readings land at
## different places on their curves and can compare the wrong way round, which
## is exactly how this suite failed once in a full run.
class FlareWatcher extends Node:
	var frame_node: CanvasItem = null
	var peak := 0.0

	func _process(_delta):
		if frame_node == null:
			return
		var alpha = frame_node.modulate.a
		if alpha == 0.0:
			peak = 0.0
		else:
			peak = maxf(peak, alpha)

var _watcher: FlareWatcher = null


func peak_alpha(_vignette) -> float:
	return _watcher.peak if _watcher != null else 0.0


func run_test():
	Campaign.reset()
	Campaign.current_encounter = load("res://encounters/encounter_01_ambush.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	var combat = game.get_node("VisualCombat")
	var vignette = game.get_node("HurtVignette")
	_watcher = FlareWatcher.new()
	_watcher.frame_node = vignette._frame
	add_child(_watcher)
	combat.finish_deployment()
	await get_tree().process_frame

	var hero = null
	var foe = null
	for comb in combat.combatants:
		if comb.side == 0 and hero == null:
			hero = comb
		elif comb.side == 1 and foe == null:
			foe = comb
	hero.max_hp = 200
	hero.resistances = {}

	var poison := EffectDefinition.new()
	poison.type = EffectDefinition.EffectType.DAMAGE_OVER_TIME
	poison.damage_type = Damage.Type.POISON
	poison.min_amount = 5
	poison.max_amount = 5
	poison.duration = 5
	var dart: SkillDefinition = SkillDatabase.skills["poison_dart"]

	log_line("======== a lingering tick is visible at all ========")
	hero.alive = true
	hero.hp = 200
	hero.status_effects.clear()
	hero.sprite.modulate = Color.WHITE
	vignette._frame.modulate.a = 0.0
	var numbers_before = floaters(hero.sprite).size()
	combat.apply_effect(foe, hero, poison, dart, false)
	# The application itself flashes; clear that so the tick is what is measured.
	hero.sprite.modulate = Color.WHITE
	numbers_before = floaters(hero.sprite).size()
	vignette._frame.modulate.a = 0.0
	combat.process_status_effects(hero)
	ok(floaters(hero.sprite).size() > numbers_before, "a poison tick floats a number",
		"%d -> %d" % [numbers_before, floaters(hero.sprite).size()])
	ok(hero.sprite.modulate != Color.WHITE, "and flashes them", "%s" % hero.sprite.modulate)
	for frame in range(0, 10):
		await get_tree().process_frame
	var tick_flare = peak_alpha(vignette)
	ok(tick_flare > 0.0, "and frames the screen", "%s" % tick_flare)
	log_line("")

	log_line("======== an enemy's tick still frames nothing ========")
	foe.max_hp = 200
	foe.alive = true
	foe.hp = 200
	foe.status_effects.clear()
	for frame in range(0, 90):
		await get_tree().process_frame
	vignette._frame.modulate.a = 0.0
	combat.apply_effect(hero, foe, poison, dart, false)
	combat.process_status_effects(foe)
	for frame in range(0, 10):
		await get_tree().process_frame
	ok(peak_alpha(vignette) == 0.0, "hurting an enemy over time leaves the border alone",
		"%s" % peak_alpha(vignette))
	log_line("")

	log_line("======== the killing blow is twice as intense ========")
	var melee: SkillDefinition = SkillDatabase.skills["greatsword_attack"]
	var hit := EffectDefinition.new()
	hit.type = EffectDefinition.EffectType.DAMAGE
	hit.damage_type = Damage.Type.PHYSICAL

	# The same hit, once survivable and once not. Health is what differs, so the
	# share-of-health part of the strength is held equal by using a huge pool
	# both times and only moving the survival line.
	for frame in range(0, 120):
		await get_tree().process_frame
	hero.alive = true
	hero.hp = 200
	hero.status_effects.clear()
	vignette._frame.modulate.a = 0.0
	combat.do_damage(foe, hero, hit, melee, false)
	for frame in range(0, 10):
		await get_tree().process_frame
	var survived = peak_alpha(vignette)
	ok(survived > 0.0, "a survivable hit flares", "%s" % survived)

	for frame in range(0, 120):
		await get_tree().process_frame
	hero.alive = true
	hero.hp = 1
	hero.status_effects.clear()
	vignette._frame.modulate.a = 0.0
	combat.do_damage(foe, hero, hit, melee, false)
	for frame in range(0, 10):
		await get_tree().process_frame
	var killed = peak_alpha(vignette)
	ok(killed > survived, "the blow that kills flares harder", "%s vs %s" % [killed, survived])
	# Not asserted as an exact ratio here: these are samples of a live tween,
	# and hit stop pauses tweens for a length that depends on the damage, so
	# two runs are never the same distance along their curve. The exact
	# doubling is a property of the two constants, checked at the end.
	ok(not hero.alive, "and they did in fact die")
	log_line("")

	log_line("======== a poison tick that kills does it too ========")
	for frame in range(0, 120):
		await get_tree().process_frame
	hero.alive = true
	hero.hp = 200
	hero.status_effects.clear()
	vignette._frame.modulate.a = 0.0
	combat.apply_effect(foe, hero, poison, dart, false)
	combat.process_status_effects(hero)
	for frame in range(0, 10):
		await get_tree().process_frame
	var survivable_tick = peak_alpha(vignette)

	for frame in range(0, 120):
		await get_tree().process_frame
	hero.alive = true
	hero.hp = 200
	hero.status_effects.clear()
	combat.apply_effect(foe, hero, poison, dart, false)
	hero.hp = 1
	vignette._frame.modulate.a = 0.0
	combat.process_status_effects(hero)
	for frame in range(0, 10):
		await get_tree().process_frame
	var lethal_tick = peak_alpha(vignette)
	ok(lethal_tick > survivable_tick, "a lethal poison tick flares harder than a survivable one",
		"%s vs %s" % [lethal_tick, survivable_tick])
	ok(not hero.alive, "and the poison did kill them")
	log_line("")

	log_line("======== ordinary hits are unchanged ========")
	ok(HurtVignette.PEAK_ALPHA == 0.5, "an ordinary flare still uses half the gradient",
		"%s" % HurtVignette.PEAK_ALPHA)
	ok(HurtVignette.LETHAL_PEAK_ALPHA == 2.0 * HurtVignette.PEAK_ALPHA, "and a lethal one exactly twice that",
		"%s vs %s" % [HurtVignette.LETHAL_PEAK_ALPHA, HurtVignette.PEAK_ALPHA])
	# The same strength through both paths, read at the same moment, so the
	# tween is at the same point on its curve for each.
	vignette._frame.modulate.a = 0.0
	vignette.flare(Color.RED, 1.0, false)
	await get_tree().process_frame
	await get_tree().process_frame
	var ordinary = peak_alpha(vignette)
	vignette._frame.modulate.a = 0.0
	vignette.flare(Color.RED, 1.0, true)
	await get_tree().process_frame
	await get_tree().process_frame
	var doubled = peak_alpha(vignette)
	ok(doubled > ordinary, "and a lethal flare really does reach further",
		"%s vs %s" % [doubled, ordinary])
	log_line("")

	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
