extends Node
## Everything that makes a skill read as having landed: hit flashes, floating
## numbers, recoil, hit stop, the hurt vignette, death, and camera shake.

var LOG_PATH := HarnessLog.path_for("impact")

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
		if child is FloatingNumber:
			found.append(child)
	return found


func run_test():
	log_line("======== damage types have their own colour ========")
	ok(Damage.TYPE_COLOURS.size() == Damage.TYPE_NAMES.size(), "one colour per type",
		"%d colours, %d types" % [Damage.TYPE_COLOURS.size(), Damage.TYPE_NAMES.size()])
	ok(Damage.type_colour(Damage.Type.FIRE) != Damage.type_colour(Damage.Type.WATER), "fire and water differ")
	ok(Damage.type_colour(999) == Color.WHITE, "an unknown type falls back to white")
	log_line("")

	Campaign.reset()
	Campaign.current_encounter = load("res://encounters/encounter_01_ambush.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	var combat = game.get_node("VisualCombat")
	var camera = game.get_node("Camera2D")
	var vignette = game.get_node("HurtVignette")
	combat.finish_deployment()
	await get_tree().process_frame

	var hero = null
	var foe = null
	for comb in combat.combatants:
		if comb.side == 0 and hero == null:
			hero = comb
		elif comb.side == 1 and foe == null:
			foe = comb

	var fire := EffectDefinition.new()
	fire.type = EffectDefinition.EffectType.DAMAGE
	fire.damage_type = Damage.Type.FIRE
	var melee: SkillDefinition = SkillDatabase.skills["greatsword_attack"]

	log_line("======== hit flash ========")
	hero.sprite.modulate = Color.WHITE
	hero.sprite.flash_hit(true)
	ok(hero.sprite.modulate.r > hero.sprite.modulate.g, "an enemy skill turns them red", "%s" % hero.sprite.modulate)
	hero.sprite.flash_hit(false)
	ok(hero.sprite.modulate.g > hero.sprite.modulate.r, "an allied one turns them green", "%s" % hero.sprite.modulate)
	hero.sprite.flash_hit(true, Damage.type_colour(Damage.Type.FIRE))
	ok(hero.sprite.modulate.is_equal_approx(Damage.type_colour(Damage.Type.FIRE)),
		"a fire hit starts in the fire colour", "%s" % hero.sprite.modulate)
	for frame in range(0, 60):
		await get_tree().process_frame
	ok(hero.sprite.modulate.is_equal_approx(Color.WHITE), "and it all settles back", "%s" % hero.sprite.modulate)
	log_line("")

	log_line("======== floating numbers ========")
	var before = floaters(hero.sprite).size()
	combat.float_number(hero, "12", Color.RED)
	var after = floaters(hero.sprite).size()
	ok(after == before + 1, "a number appears", "%d -> %d" % [before, after])
	var floater = floaters(hero.sprite)[0]
	ok(floater.position == hero.sprite.position, "over the combatant it belongs to", "%s" % floater.position)
	ok(floater.z_index > 20 and not floater.z_as_relative, "and above every combatant", "z=%d" % floater.z_index)
	var started_at = floater.position.y
	for frame in range(0, 30):
		await get_tree().process_frame
	ok(floater.position.y < started_at, "it rises", "%s -> %s" % [started_at, floater.position.y])
	for frame in range(0, 120):
		await get_tree().process_frame
	ok(not is_instance_valid(floater) or floater.is_queued_for_deletion(), "and cleans itself up")
	log_line("")

	log_line("======== a real hit does all of it ========")
	hero.hp = combat.get_effective_stat(hero, "max_hp")
	var numbers_before = floaters(hero.sprite).size()
	combat.apply_effect(foe, hero, fire, melee, false)
	ok(floaters(hero.sprite).size() > numbers_before, "damage floats a number")
	ok(hero.hp < combat.get_effective_stat(hero, "max_hp"), "and actually hurts", "hp %d" % hero.hp)
	log_line("")

	log_line("======== recoil moves the drawing, never the tile ========")
	var tile_before = foe.position
	var node_before = foe.sprite.position
	foe.sprite.recoil(Vector2(1, 0))
	await get_tree().process_frame
	await get_tree().process_frame
	ok(foe.position == tile_before, "the combatant is on the same tile", "%s" % foe.position)
	ok(foe.sprite.position == node_before, "and the sprite node has not moved", "%s" % foe.sprite.position)
	var drawn = foe.sprite._drawn()
	ok(drawn != null and drawn.position != Vector2.ZERO, "but the drawn sprite is shoved aside",
		"%s" % (drawn.position if drawn else "no sprite"))
	for frame in range(0, 90):
		await get_tree().process_frame
	ok(drawn.position.length() < 1.0, "and springs back", "%s" % drawn.position)
	log_line("")

	log_line("======== hit stop ========")
	ok(combat.hit_stop_for(0, 10) == 0.0, "no damage, no freeze")
	ok(combat.hit_stop_for(1, 100) < combat.hit_stop_for(50, 100), "a bigger share freezes longer",
		"%s vs %s" % [combat.hit_stop_for(1, 100), combat.hit_stop_for(50, 100)])
	ok(combat.hit_stop_for(500, 10) <= Combat.HIT_STOP_MAXIMUM, "and it is capped",
		"%s" % combat.hit_stop_for(500, 10))
	Engine.time_scale = 1.0
	combat.hit_stop(0.05)
	ok(Engine.time_scale == 0.0, "time stops", "%s" % Engine.time_scale)
	for frame in range(0, 40):
		await get_tree().process_frame
	ok(Engine.time_scale == 1.0, "and starts again", "%s" % Engine.time_scale)
	# Two overlapping freezes: the first release must not end both.
	combat.hit_stop(0.02)
	combat.hit_stop(0.40)
	for frame in range(0, 8):
		await get_tree().process_frame
	ok(Engine.time_scale == 0.0, "overlapping freezes hold until the last ends", "%s" % Engine.time_scale)
	for frame in range(0, 120):
		await get_tree().process_frame
	ok(Engine.time_scale == 1.0, "then time resumes", "%s" % Engine.time_scale)
	log_line("")

	log_line("======== the hurt vignette ========")
	ok(combat.hurt_vignette == vignette, "combat can reach it")
	ok(vignette._frame != null and vignette._frame.get_child_count() == 4, "it has four edges",
		"%d" % (vignette._frame.get_child_count() if vignette._frame else -1))
	# Opacity alone is not evidence: the first version of this faded in and out
	# perfectly while two of its four strips sat entirely off the screen.
	var screen = get_viewport().get_visible_rect().size
	var covered = [false, false, false, false]
	for strip in vignette._edges:
		var rect = Rect2(strip.position, strip.size)
		ok(rect.size.x > 0 and rect.size.y > 0, "a strip has real size", "%s" % rect)
		ok(Rect2(Vector2.ZERO, screen).intersects(rect), "and is on the screen", "%s in %s" % [rect, screen])
		if rect.position.y <= 0.5: covered[0] = true
		if rect.end.y >= screen.y - 0.5: covered[1] = true
		if rect.position.x <= 0.5: covered[2] = true
		if rect.end.x >= screen.x - 0.5: covered[3] = true
	ok(covered[0] and covered[1] and covered[2] and covered[3],
		"all four edges of the screen are reached", "%s" % [covered])
	ok(vignette._frame.modulate.a == 0.0, "invisible at rest", "%s" % vignette._frame.modulate.a)
	vignette.flare(Damage.type_colour(Damage.Type.POISON), 1.0)
	for frame in range(0, 12):
		await get_tree().process_frame
	ok(vignette._frame.modulate.a > 0.0, "flaring shows it", "%s" % vignette._frame.modulate.a)
	ok(vignette._frame.modulate.g > vignette._frame.modulate.r, "in the poison colour",
		"%s" % vignette._frame.modulate)
	for frame in range(0, 150):
		await get_tree().process_frame
	ok(vignette._frame.modulate.a < 0.01, "and it fades away", "%s" % vignette._frame.modulate.a)

	vignette._frame.modulate.a = 0.0
	foe.hp = combat.get_effective_stat(foe, "max_hp")
	combat.apply_effect(hero, foe, fire, melee, false)
	for frame in range(0, 12):
		await get_tree().process_frame
	ok(vignette._frame.modulate.a == 0.0, "hurting an enemy does not flash the border",
		"%s" % vignette._frame.modulate.a)
	log_line("")

	log_line("======== death ========")
	foe.hp = 1
	combat.combatant_die(foe)
	for frame in range(0, 90):
		await get_tree().process_frame
	ok(foe.sprite.modulate.a < 1.0, "a corpse fades", "alpha %s" % foe.sprite.modulate.a)
	ok(foe.sprite.modulate.a > 0.0, "but is still visible", "alpha %s" % foe.sprite.modulate.a)
	var victim_drawn = foe.sprite._drawn()
	ok(victim_drawn == null or victim_drawn.position.y > 0.0, "and sinks",
		"%s" % (victim_drawn.position if victim_drawn else "no sprite"))
	log_line("")

	log_line("======== camera shake ========")
	camera.offset = Vector2.ZERO
	camera._shake = 0.0
	var settled = camera.position
	camera.shake(20.0)
	# One ordinary frame's step, taken by hand: waiting on real frames failed
	# now and then, when a slow one (over 1/SHAKE_DECAY of a second) decayed
	# the whole shake away before it could be looked at.
	camera._shake_step(1.0 / 60.0)
	ok(camera.offset != Vector2.ZERO, "shaking moves the view", "%s" % camera.offset)
	await get_tree().process_frame
	ok(camera.position == settled, "without moving the camera itself", "%s" % camera.position)
	for frame in range(0, 180):
		await get_tree().process_frame
	ok(camera.offset == Vector2.ZERO, "and it settles back", "%s" % camera.offset)
	log_line("")

	log_line("FAILURES: %d" % _fail)
	Engine.time_scale = 1.0
	get_tree().quit(0 if _fail == 0 else 1)
