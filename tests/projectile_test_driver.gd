extends Node
## Projectiles (combat/Projectile.gd; the designer, 2026-10-30): a move seen
## going from its user to where it was aimed, so that it is clear on the board
## who does what.
##
## - how a move goes, worked out from it, for every move there is: nothing for a
##   melee blow or one at its user's own tile, or one that moves somebody; a
##   streak for a line, a fan for a cone, a straight bolt for one that needs a
##   clear line and an arc for one that goes over what is in the way - and a
##   move's own Projectile Style over all of that
## - its colour: its element's, a mend's green, or its own Projectile Colour
## - one flown in a fight: it is on the board while the move resolves, a trail
##   behind it, and the blow lands only once it has arrived; then it bursts and
##   is gone. An arc goes up over the straight line between, and a cone fans out
##   in three
## - nothing in it rolls: the same move from the same seed leaves the same
##   fight, and the same rolls to come, flown or not
## - its slots: a texture flies in place of the orb, a scene in place of all

var LOG_PATH := HarnessLog.path_for("projectile")

var _log: FileAccess = null
var _fail = 0
var _game: Node = null
var _used := false

const SOURCE := "res://data/encounters/encounter_02_sappers.tres"
const CAST := [["cyrus", 0], ["enfina", 0], ["barbarian", 1], ["ranger", 1]]
const SEED := 31337


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
	get_tree().create_timer(280.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


func run_test():
	await styles()
	colours()
	await a_flight()
	await nothing_rolled()
	await slots()
	Projectile.plays_headless = false
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


## --- How a move goes ---


func styles():
	log_line("======== how a move goes, worked out from it ========")
	var combat := await start_fight()
	var user := party_member(combat, "cyrus")
	var aim := Vector2i(user.position.x + 4, user.position.y)
	var counts := {}
	var wrong := []
	for key in SkillDatabase.skills:
		var skill: SkillDefinition = SkillDatabase.skills[key]
		if skill.projectile_style != SkillDefinition.ProjectileStyle.AUTOMATIC:
			continue
		var style := Projectile.style_for(combat, user, skill, aim)
		var wanted: int
		if Combat.is_melee(skill) or skill.max_range <= 0 or skill.teleports != SkillDefinition.TeleportWho.NOBODY:
			wanted = SkillDefinition.ProjectileStyle.NONE
		elif skill.aoe_shape == SkillDefinition.AoEShape.LINE:
			wanted = SkillDefinition.ProjectileStyle.STREAK
		elif skill.aoe_shape == SkillDefinition.AoEShape.CONE:
			wanted = SkillDefinition.ProjectileStyle.FAN
		else:
			wanted = SkillDefinition.ProjectileStyle.BOLT if skill.respects_blocking else SkillDefinition.ProjectileStyle.ARC
		counts[style] = counts.get(style, 0) + 1
		if style != wanted:
			wrong.append("%s %d not %d" % [key, style, wanted])
		if Projectile.style_for(combat, user, skill, user.position) != SkillDefinition.ProjectileStyle.NONE:
			wrong.append("%s at its user's own tile" % key)
	var names := SkillDefinition.ProjectileStyle.keys()
	var said := []
	for style in counts:
		said.append("%s %d" % [names[style], counts[style]])
	ok(wrong.is_empty(), "every move goes by the rule: nothing for melee, the user's tile or a move that moves somebody; a streak for a line, a fan for a cone, a bolt or an arc",
		"%s %s" % [", ".join(said), wrong.slice(0, 8)])
	for style in [SkillDefinition.ProjectileStyle.BOLT, SkillDefinition.ProjectileStyle.ARC, SkillDefinition.ProjectileStyle.STREAK,
			SkillDefinition.ProjectileStyle.FAN, SkillDefinition.ProjectileStyle.NONE]:
		ok(counts.get(style, 0) > 0, "  and there are moves that go as %s" % names[style].to_lower())
	var melee: SkillDefinition = null
	for key in SkillDatabase.skills:
		if Combat.is_melee(SkillDatabase.skills[key]):
			melee = SkillDatabase.skills[key]
			break
	var own: SkillDefinition = melee.duplicate()
	own.projectile_style = SkillDefinition.ProjectileStyle.ARC
	ok(Projectile.style_for(combat, user, own, aim) == SkillDefinition.ProjectileStyle.ARC,
		"a move's own Projectile Style stands over what would be worked out")
	await end_fight()
	log_line("")


func colours():
	log_line("======== the colour it flies in ========")
	var fire: SkillDefinition = null
	var mend: SkillDefinition = null
	for key in SkillDatabase.skills:
		var skill: SkillDefinition = SkillDatabase.skills[key]
		if fire == null and skill.deals_damage and skill.damage_type == Damage.Type.FIRE and skill.projectile_colour.a == 0.0:
			fire = skill
		if mend == null and skill.projectile_colour.a == 0.0 and skill.all_effects().any(func(effect): return effect != null and effect.type == EffectDefinition.EffectType.HEAL):
			mend = skill
	ok(fire != null and Projectile.colour_for(fire) == Damage.type_colour(Damage.Type.FIRE), "a fire move flies in fire's colour, the one its damage floats up in",
		fire.name if fire != null else "")
	ok(fire != null and Projectile.colour_for(fire, Damage.Type.PLASMA) == Damage.type_colour(Damage.Type.PLASMA), "  and raised to plasma, in plasma's")
	ok(mend != null and Projectile.colour_for(mend) == Projectile.MEND, "a mend in a mend's green", mend.name if mend != null else "")
	var own: SkillDefinition = fire.duplicate() if fire != null else SkillDefinition.new()
	own.projectile_colour = Color("123456")
	ok(Projectile.colour_for(own) == Color("123456"), "and a move's own Projectile Colour over either")
	log_line("")


## --- One flown ---


func a_flight():
	log_line("======== one flown in a fight ========")
	Projectile.plays_headless = true
	var combat := await start_fight()
	var shot := await line_up(combat, [SkillDefinition.ProjectileStyle.BOLT, SkillDefinition.ProjectileStyle.ARC])
	if shot.is_empty():
		ok(false, "a ranged move to try")
		await end_fight()
		return
	var user: Dictionary = shot.user
	var foe: Dictionary = shot.foe
	var board: Node = user.sprite.get_parent()
	var hp_before: int = foe.hp
	var heard := []
	combat.update_information.connect(func(text: String): heard.append(text))
	use_it(combat, shot)
	var flying: Projectile = null
	var waited := 0
	while flying == null and waited < 600:
		await get_tree().process_frame
		waited += 1
		for child in board.get_children():
			if child is Projectile:
				flying = child
	ok(flying != null, "%s's %s: a projectile goes from them across the board" % [user.name, shot.skill.name],
		"%s" % SkillDefinition.ProjectileStyle.keys()[shot.style])
	if flying == null:
		await end_fight()
		return
	ok(foe.hp == hp_before and not heard.any(func(line): return line.contains(" missed ")), "  and while it flies, nothing has landed")
	var highest := INF
	var straight_y := 0.0
	var trail_most := 0
	while is_instance_valid(flying) and not flying._arrived:
		trail_most = maxi(trail_most, flying._trail.size())
		var head: Vector2 = flying._trail.back()[0]
		var t := minf(flying._clock / flying._seconds, 1.0)
		if t > 0.3 and t < 0.7:
			highest = minf(highest, head.y)
			straight_y = flying.from.lerp(flying._end(), t).y
		await get_tree().process_frame
	ok(trail_most > 3, "  a trail behind it as it goes", "%d points" % trail_most)
	if shot.style == SkillDefinition.ProjectileStyle.ARC:
		ok(highest < straight_y - Grid.TILE_SIZE * 0.2, "  going up over the line between, thrown", "%.0f over %.0f" % [highest, straight_y])
	await get_tree().process_frame
	await get_tree().process_frame
	ok(foe.hp < hp_before or heard.any(func(line): return line.contains(" missed ")), "arrived, the blow lands - or misses",
		"%d -> %d" % [hp_before, foe.hp])
	ok(is_instance_valid(flying), "  and it bursts where it landed")
	await until(func(): return not is_instance_valid(flying), 3.0)
	ok(not is_instance_valid(flying), "  and is gone")
	await until(func(): return _used, 5.0)
	await end_fight()

	# A cone, in three: flown straight from Projectile, whoever's cone it is.
	combat = await start_fight()
	await until(func(): return combat.controller.player_turn and combat.plays_for_party(combat.get_current_combatant()), 30.0)
	user = combat.get_current_combatant()
	var cone: SkillDefinition = null
	for key in SkillDatabase.skills:
		var skill: SkillDefinition = SkillDatabase.skills[key]
		if skill.aoe_shape == SkillDefinition.AoEShape.CONE and skill.projectile_style == SkillDefinition.ProjectileStyle.AUTOMATIC \
				and not Combat.is_melee(skill) and skill.max_range > 0 and skill.teleports == SkillDefinition.TeleportWho.NOBODY:
			cone = skill
			break
	if cone == null:
		ok(false, "a cone to try")
	else:
		board = user.sprite.get_parent()
		var aim := Vector2i(user.position.x + 3, user.position.y)
		var tiles: Array = combat.get_impact_tiles(cone, combat.nearest_tile_of(user, aim), aim, combat.terrain_class(user),
			user.get("size", Sizes.Size.HUMAN), user)
		var flying_done := [false]
		var fly := func():
			await Projectile.fly(combat, user, cone, aim, tiles)
			flying_done[0] = true
		fly.call()
		var most := 0
		waited = 0
		while waited < 600 and not flying_done[0]:
			most = maxi(most, board.get_children().filter(func(child): return child is Projectile).size())
			await get_tree().process_frame
			waited += 1
		ok(most == 3 and flying_done[0], "%s, a cone, fans out in three - and is waited for until they land" % cone.name, "%d" % most)
	await end_fight()
	log_line("")


## --- Nothing rolled ---


func nothing_rolled():
	log_line("======== nothing in it rolls ========")
	var after := []
	for flown in [false, true]:
		Projectile.plays_headless = flown
		var combat := await start_fight()
		var shot := await line_up(combat, [SkillDefinition.ProjectileStyle.BOLT, SkillDefinition.ProjectileStyle.ARC])
		if shot.is_empty():
			after.append("")
		else:
			await combat.use_skill(shot.key, shot.user, shot.aim)
			after.append("%s\n%d %d" % [combat.fight_state(), combat.rng.state, combat.rng.randi()])
		await end_fight()
	ok(after[0] != "" and after[0] == after[1], "the same move from the same seed leaves the same fight, and the same rolls to come, flown or not",
		"" if after[0] == after[1] else "\n%s\n  ---\n%s" % [after[0], after[1]])
	log_line("")


## --- Slots ---


func slots():
	log_line("======== slots to fill ========")
	Projectile.plays_headless = true
	var combat := await start_fight()
	var shot := await line_up(combat, [SkillDefinition.ProjectileStyle.BOLT, SkillDefinition.ProjectileStyle.ARC])
	if shot.is_empty():
		ok(false, "a ranged move to try")
		await end_fight()
		return
	var skill: SkillDefinition = shot.skill
	var picture := PlaceholderTexture2D.new()
	picture.size = Vector2(12, 6)
	var scene := PackedScene.new()
	var thing := Node2D.new()
	thing.name = "Bolt"
	scene.pack(thing)
	thing.free()
	skill.projectile_texture = picture
	var seen := await first_flying(combat, shot)
	ok(seen != null and seen.texture == picture, "a move's Projectile Texture flies in place of the orb")
	await until(func(): return _used, 5.0)
	await end_fight()
	skill.projectile_texture = null
	skill.projectile_scene = scene
	combat = await start_fight()
	shot = await line_up(combat, [SkillDefinition.ProjectileStyle.BOLT, SkillDefinition.ProjectileStyle.ARC])
	seen = await first_flying(combat, shot)
	ok(seen != null and seen.art != null and seen.art.name == "Bolt" and seen.art.get_parent() == seen,
		"  and its Projectile Scene in place of all of it")
	await until(func(): return _used, 5.0)
	skill.projectile_scene = null
	await end_fight()
	log_line("")


## The first projectile `shot` puts on the board, used now.
func first_flying(combat: Combat, shot: Dictionary) -> Projectile:
	if shot.is_empty():
		return null
	var board: Node = shot.user.sprite.get_parent()
	use_it(combat, shot)
	for i in 600:
		await get_tree().process_frame
		for child in board.get_children():
			if child is Projectile:
				return child
	return null


## --- A fight ---


func start_fight() -> Combat:
	var source: EncounterDefinition = load(SOURCE)
	var encounter := EncounterDefinition.new()
	encounter.display_name = "Projectiles"
	encounter.terrain_scene = source.terrain_scene
	encounter.skip_deployment = true
	var spawns: Array[SpawnDefinition] = []
	var used := []
	for wanted in CAST:
		for spawn in source.spawns:
			if spawn.combatant_key == wanted[0] and spawn.side == wanted[1] and not used.has(spawn):
				used.append(spawn)
				spawns.append(spawn.duplicate())
				break
	encounter.spawns = spawns
	encounter.set_meta("seed", SEED)
	Campaign.reset()
	Campaign.current_encounter = encounter
	GameSettings._enemy_speed = GameSettings.ENEMY_SPEEDS.size() - 1
	_game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(_game)
	for i in 4:
		await get_tree().process_frame
	var combat: Combat = _game.get_node("VisualCombat")
	combat.reaction_prompt = null
	return combat


func end_fight():
	if _game != null:
		_game.queue_free()
		_game = null
	await get_tree().process_frame
	await get_tree().process_frame


## Waits for one of the party's turns, and lines up a move of theirs of one of
## `styles` at the nearest of the other side - brought into reach, a few tiles
## off in a clear line, if none reaches. {user, foe, key, skill, aim, style},
## or {} for none.
func line_up(combat: Combat, styles: Array) -> Dictionary:
	await until(func(): return combat.combat_over or (combat.controller.player_turn and combat.controller.is_idle()
		and combat.plays_for_party(combat.get_current_combatant())), 30.0)
	if combat.combat_over:
		return {}
	var user: Dictionary = combat.get_current_combatant()
	var foe := nearest_foe(combat, user)
	if foe.is_empty():
		return {}
	for gap in [3, 4, 2, 5]:
		for step in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var tile: Vector2i = user.position + step * gap
			if not combat.controller.is_in_bounds(tile) or not combat.room_for(foe, tile, false):
				continue
			if not combat.sees_tile(user, tile, foe):
				continue
			var was: Vector2i = foe.position
			foe.position = tile
			foe.sprite.position = combat.sprite_point(foe)
			combat.controller.reposition_combatant(was, tile)
			for key in combat._ai_main_keys(user) + Array(user.get("skill_list", [])):
				var skill: SkillDefinition = SkillDatabase.skills.get(key)
				if skill == null or not combat._hostile(skill) or combat.wasted_on(user, skill) != "" \
						or not combat.meets_level_for(user, skill) or not combat.can_afford_skill(user, skill):
					continue
				if gap < skill.min_range or gap > combat.effective_max_range(user, skill):
					continue
				if combat.refusal_for(user, skill, tile) != "":
					continue
				var style := Projectile.style_for(combat, user, skill, tile)
				if styles.has(style):
					return {"user": user, "foe": foe, "key": key, "skill": skill, "aim": tile, "style": style}
			foe.position = was
			foe.sprite.position = combat.sprite_point(foe)
			combat.controller.reposition_combatant(tile, was)
	return {}


## `shot` used, not waited for: _used says once it is done.
func use_it(combat: Combat, shot: Dictionary):
	_used = false
	_use(combat, shot)


func _use(combat: Combat, shot: Dictionary):
	await combat.use_skill(shot.key, shot.user, shot.aim, false)
	_used = true


func party_member(combat: Combat, key: String) -> Dictionary:
	for comb in combat.combatants:
		if comb.get("combatant_key", "") == key and comb.get("side", 1) == 0:
			return comb
	return {}


func nearest_foe(combat: Combat, comb: Dictionary) -> Dictionary:
	var best := {}
	var best_gap := 1 << 30
	for other in combat.combatants:
		if not other.get("alive", false) or other.get("side", 0) == comb.side \
				or other.has("object") or other.get("illusion", false):
			continue
		var gap: int = combat.distance_to(comb, combat.nearest_tile_of(other, comb.position))
		if gap < best_gap:
			best_gap = gap
			best = other
	return best


func until(condition: Callable, seconds: float) -> bool:
	var waited := 0.0
	while not condition.call():
		if waited >= seconds:
			return false
		await get_tree().process_frame
		waited += get_process_delta_time()
	return true
