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
	get_tree().create_timer(420.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


func run_test():
	await styles()
	colours()
	await a_flight()
	await nothing_rolled()
	await slots()
	feel_data()
	await new_styles()
	await every_look()
	await verdicts()
	await every_feel()
	await every_way_in()
	await weight()
	numbers()
	await fills_and_sounds()
	Projectile.plays_headless = false
	MoveFeel.plays_headless = false
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
		if mend == null and skill.projectile_colour.a == 0.0 and skill.all_effects().any(func(effect): return effect != null and effect.type == EffectDefinition.EffectType.HEAL and not effect.applies_to_caster):
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
		MoveFeel.plays_headless = flown
		var combat := await start_fight()
		var shot := await line_up(combat, [SkillDefinition.ProjectileStyle.BOLT, SkillDefinition.ProjectileStyle.ARC])
		if shot.is_empty():
			after.append("")
		else:
			await combat.use_skill(shot.key, shot.user, shot.aim)
			after.append("%s\n%d %d" % [combat.fight_state(), combat.rng.state, combat.rng.randi()])
		await end_fight()
	ok(after[0] != "" and after[0] == after[1], "the same move from the same seed leaves the same fight, and the same rolls to come, flown or not - its looks, numbers and weight too",
		"" if after[0] == after[1] else "\n%s\n  ---\n%s" % [after[0], after[1]])
	MoveFeel.plays_headless = false
	log_line("")


## --- How moves are felt (MoveFeel; docs/move_feel_proposals.md) ---


## The proposals' looks, on the moves they were for.
func feel_data():
	log_line("======== each move's own looks ========")
	var wanted := {
		"gun": {"projectile_look": SkillDefinition.ProjectileLook.TRACER},
		"combined_load": {"projectile_look": SkillDefinition.ProjectileLook.TWIN_TRACER},
		"poison_dart": {"projectile_style": SkillDefinition.ProjectileStyle.ARC, "projectile_look": SkillDefinition.ProjectileLook.DART},
		"warning_shot": {"impact_look": SkillDefinition.ImpactLook.SPARK_BESIDE},
		"minefield": {"impact_look": SkillDefinition.ImpactLook.SETTLE},
		"rapier": {"impact_look": SkillDefinition.ImpactLook.THRUST},
		"greatsword_attack": {"impact_look": SkillDefinition.ImpactLook.HEAVY_SWOOSH},
		"sweep_strike": {"impact_look": SkillDefinition.ImpactLook.HALF_CIRCLE},
		"stunning_blow": {"impact_look": SkillDefinition.ImpactLook.SHIELD_STARS},
		"chain_hook": {"projectile_look": SkillDefinition.ProjectileLook.CHAIN},
		"battle_cry": {"projectile_style": SkillDefinition.ProjectileStyle.SPRAY, "hand_look": SkillDefinition.HandLook.ROAR},
		"fireball": {"projectile_look": SkillDefinition.ProjectileLook.GREAT_ORB},
		"wind_vacuum": {"projectile_look": SkillDefinition.ProjectileLook.VACUUM},
		"gnostic_tempest": {"impact_look": SkillDefinition.ImpactLook.STORM},
		"holy_lance": {"projectile_style": SkillDefinition.ProjectileStyle.BEAM},
		"censure": {"projectile_style": SkillDefinition.ProjectileStyle.SPRAY},
		"sanctuary_of_light": {"impact_look": SkillDefinition.ImpactLook.DOME},
		"accusation": {"impact_look": SkillDefinition.ImpactLook.SEAL},
		"fire_breath": {"projectile_style": SkillDefinition.ProjectileStyle.SPRAY},
		"self_destruct": {"impact_look": SkillDefinition.ImpactLook.WHITE_OUT},
		"savage_bite": {"impact_look": SkillDefinition.ImpactLook.CLAW},
	}
	var wrong := []
	for key in wanted:
		var skill: SkillDefinition = SkillDatabase.skills.get(key)
		for property in wanted[key]:
			if skill == null or skill.get(property) != wanted[key][property]:
				wrong.append("%s %s" % [key, property])
	ok(wrong.is_empty(), "the proposals' looks are on the moves they were for", "%s" % [wrong])
	# Worked out when Automatic: a mend's column, a cleanse's wash, a blow's arc.
	var heal: SkillDefinition = SkillDatabase.skills.get("heal")
	var cleanse: SkillDefinition = SkillDatabase.skills.get("cleanse")
	var swing: SkillDefinition = SkillDatabase.skills.get("light_swing")
	ok(heal != null and MoveFeel.impact_look_of(heal) == SkillDefinition.ImpactLook.COLUMN
		and cleanse != null and MoveFeel.impact_look_of(cleanse) == SkillDefinition.ImpactLook.WASH
		and swing != null and MoveFeel.impact_look_of(swing) == SkillDefinition.ImpactLook.SWOOSH,
		"  and when Automatic: a column of light for a mend, a wash for a cleanse, a swing's arc for a blow")
	log_line("")


## A beam, a spray and one back to its user, flown and waited for.
func new_styles():
	log_line("======== a beam, a spray, and back to its user ========")
	Projectile.plays_headless = true
	MoveFeel.plays_headless = true
	var combat := await start_fight()
	var user := party_member(combat, "cyrus")
	var foe := nearest_foe(combat, user)
	var board: Node = user.sprite.get_parent()
	var aim: Vector2i = user.position + Vector2i(3, 0)
	var base: SkillDefinition = SkillDatabase.skills.get("gun")
	for style in [SkillDefinition.ProjectileStyle.BEAM, SkillDefinition.ProjectileStyle.SPRAY, SkillDefinition.ProjectileStyle.BACK_TO_USER]:
		var skill: SkillDefinition = base.duplicate()
		skill.projectile_style = style
		var tiles := [aim, aim + Vector2i(1, 0), aim + Vector2i(1, 1), aim + Vector2i(1, -1)]
		var done := [false]
		var seen := [null]
		var fly := func():
			await Projectile.fly(combat, user, skill, aim, tiles)
			done[0] = true
		fly.call()
		var waited := 0
		while waited < 300 and not done[0]:
			for child in board.get_children():
				if child is Projectile and seen[0] == null:
					seen[0] = child
			await get_tree().process_frame
			waited += 1
		var flying: Projectile = seen[0]
		var name: String = SkillDefinition.ProjectileStyle.keys()[style].to_lower()
		ok(flying != null and done[0], "a %s flies, and is waited for until the blow lands" % name)
		if flying != null and is_instance_valid(flying) and style == SkillDefinition.ProjectileStyle.BACK_TO_USER:
			ok(flying.from.distance_to(combat.sprite_point({}, aim)) < Grid.TILE_SIZE and flying._end().distance_to(MoveFeel.middle_of(combat, user)) < Grid.TILE_SIZE,
				"  from where it was aimed to its user")
		if flying != null and is_instance_valid(flying) and style == SkillDefinition.ProjectileStyle.SPRAY:
			ok(not flying._bits.is_empty(), "  pouring out what fills its cone", "%d" % flying._bits.size())
		ok(await until(func(): return not is_instance_valid(flying), 3.0), "  and is gone after")
	await end_fight()
	log_line("")


## Every Projectile Look flown: each drawn, landed and gone.
func every_look():
	log_line("======== every look, flown ========")
	Projectile.plays_headless = true
	MoveFeel.plays_headless = true
	var combat := await start_fight()
	var user := party_member(combat, "cyrus")
	var board: Node = user.sprite.get_parent()
	var aim: Vector2i = user.position + Vector2i(3, 0)
	var base: SkillDefinition = SkillDatabase.skills.get("gun")
	var missing := []
	for look in range(1, SkillDefinition.ProjectileLook.size()):
		var skill: SkillDefinition = base.duplicate()
		skill.projectile_look = look
		var done := [false]
		var fly := func():
			await Projectile.fly(combat, user, skill, aim, [aim])
			done[0] = true
		fly.call()
		var flew := false
		var waited := 0
		while waited < 200 and not done[0]:
			flew = flew or board.get_children().any(func(child): return child is Projectile and child.look == look)
			await get_tree().process_frame
			waited += 1
		if not flew or not done[0]:
			missing.append(SkillDefinition.ProjectileLook.keys()[look])
	ok(missing.is_empty(), "every look flies, and lands", "%s" % [missing])
	await until(func(): return not board.get_children().any(func(child): return child is Projectile), 3.0)
	await end_fight()
	log_line("")


## What became of a blow, told as it lands: a miss flies on past, a graze bursts
## dimly, a copy taking it shatters.
func verdicts():
	log_line("======== a miss, a graze, a copy ========")
	Projectile.plays_headless = true
	MoveFeel.plays_headless = true
	var combat := await start_fight()
	var user := party_member(combat, "cyrus")
	var foe := nearest_foe(combat, user)
	var board: Node = user.sprite.get_parent()
	var base: SkillDefinition = SkillDatabase.skills.get("gun")
	for outcome in [Projectile.Verdict.MISSED, Projectile.Verdict.GRAZED, Projectile.Verdict.IMAGE]:
		var bursts_before := _feels(board, &"burst").size()
		var shatters_before := _feels(board, &"shatter").size()
		var told := [false]
		var flying := [null]
		var fly := func():
			await Projectile.fly(combat, user, base, foe.position, [foe.position], foe)
		fly.call()
		await get_tree().process_frame
		for child in board.get_children():
			if child is Projectile and child.target == foe:
				flying[0] = child
		if flying[0] == null:
			ok(false, "a blow flown at one")
			continue
		var shot: Projectile = flying[0]
		ok(shot.judged, "a blow at one alone lands as it went for them")
		shot.landed.connect(func():
			Projectile.verdict(foe, outcome)
			told[0] = true, CONNECT_ONE_SHOT)
		await until(func(): return told[0], 3.0)
		await get_tree().process_frame
		await get_tree().process_frame
		var bursts: Array = _feels(board, &"burst")
		match outcome:
			Projectile.Verdict.MISSED:
				var past: float = shot._trail.back()[0].distance_to(shot.from) if is_instance_valid(shot) else 0.0
				for i in 6:
					await get_tree().process_frame
				var later: float = shot._trail.back()[0].distance_to(shot.from) if is_instance_valid(shot) else 0.0
				ok(bursts.size() == bursts_before and later > past, "a miss bursts nowhere, and flies on past them", "%.0f -> %.0f" % [past, later])
			Projectile.Verdict.GRAZED:
				ok(bursts.size() > bursts_before and bursts.back().strength < 1.0, "a graze bursts, dimly",
					"%.2f" % (bursts.back().strength if bursts.size() > bursts_before else -1.0))
			Projectile.Verdict.IMAGE:
				ok(_feels(board, &"shatter").size() > shatters_before, "a copy taking the blow shatters")
		await until(func(): return not is_instance_valid(shot), 3.0)
	await end_fight()
	log_line("")


func _feels(board: Node, kind: StringName) -> Array:
	return board.get_children().filter(func(child): return child is MoveFeel and child.kind == kind)


## Every look MoveFeel has, made and gone; a burst in every element; a mark on
## the ground going with the rounds; a declared move's glyphs going with it; a
## zone spreading out.
func every_feel():
	log_line("======== every look of a move landing ========")
	MoveFeel.plays_headless = true
	var combat := await start_fight()
	var user := party_member(combat, "cyrus")
	var foe := nearest_foe(combat, user)
	var board := combat.combatant_layer()
	var at := MoveFeel.middle_of(combat, foe)
	var made := []
	for kind in MoveFeel.SECONDS:
		var feel := MoveFeel.spawn(combat, kind, at, {"on": foe, "on_offset": combat.drawing_offset(foe), "points": [Vector2.ZERO, Vector2(Grid.TILE_SIZE, 0)],
			"reach": Grid.TILE_SIZE * 1.5, "toward": Vector2.RIGHT, "text": "casing"})
		if feel != null:
			made.append(feel)
	for element in Damage.Type.size():
		var burst := MoveFeel.spawn(combat, &"burst", at, {"element": element, "colour": Damage.type_colour(element)})
		if burst != null:
			made.append(burst)
	ok(made.size() == MoveFeel.SECONDS.size() + Damage.Type.size(), "every look is made - and a burst in every element",
		"%d of %d" % [made.size(), MoveFeel.SECONDS.size() + Damage.Type.size()])
	ok(await until(func(): return made.all(func(feel): return not is_instance_valid(feel)), 4.0), "  and each is gone once it has played")
	# A mark on the ground: until two rounds have gone by.
	var skill: SkillDefinition = SkillDatabase.skills.get("fireball")
	MoveFeel.mark_ground(combat, user, skill, [foe.position, foe.position + Vector2i(1, 0)])
	# On the ground: among the map's own children, under everybody.
	var marks := _feels(board.get_parent(), &"mark")
	ok(marks.size() == 1, "a fire move scorches the ground it lands on")
	combat.round_number += 1
	await get_tree().process_frame
	ok(marks.all(func(mark): return is_instance_valid(mark)), "  still there a round on")
	combat.round_number += 1
	await get_tree().process_frame
	await get_tree().process_frame
	ok(marks.all(func(mark): return not is_instance_valid(mark)), "  and gone two rounds on")
	combat.round_number -= 2
	# A declared move's glyphs: there while it is.
	user["declared"] = {"skill": "fireball", "tiles": [foe.position], "waiting": [foe.get("id", -1)]}
	MoveFeel.declared(combat, user)
	var glyphs := _feels(board.get_parent(), &"declared")
	await get_tree().process_frame
	ok(glyphs.size() == 1 and is_instance_valid(glyphs[0]), "a declared move's tiles carry its glyphs")
	user.erase("declared")
	await get_tree().process_frame
	await get_tree().process_frame
	ok(glyphs.all(func(glyph): return not is_instance_valid(glyph)), "  gone with it")
	# A zone spreading out from where it landed.
	var tiles := [foe.position, foe.position + Vector2i(1, 0), foe.position + Vector2i(2, 0), foe.position + Vector2i(3, 0)]
	combat.zones.append({"id": 900, "tiles": tiles, "side": 0, "unseen": false})
	MoveFeel.zone_spreads(combat, 900, foe.position, tiles)
	var shown_first: int = combat._spread_so_far(combat.zones.back()).size()
	ok(shown_first < tiles.size(), "a zone laid shows only where it came down at first", "%d of %d" % [shown_first, tiles.size()])
	await until(func(): return not combat.spreading_zones.has(900), 3.0)
	ok(combat._spread_so_far(combat.zones.back()).size() == tiles.size(), "  and the whole of it once it has spread")
	combat.zones.pop_back()
	await end_fight()
	MoveFeel.plays_headless = false
	log_line("")


## Every way the fight calls in (MoveFeel's entry points), once each, with
## everything shown - for any of them that would not run (a script error fails
## the suite) - and all of it gone again after.
func every_way_in():
	log_line("======== every way the fight calls in ========")
	MoveFeel.plays_headless = true
	var combat := await start_fight()
	var user := party_member(combat, "cyrus")
	var mate := party_member(combat, "enfina")
	var foe := nearest_foe(combat, user)
	var gun: SkillDefinition = SkillDatabase.skills.get("gun")
	MoveFeel.hand(combat, user, gun, foe.position)
	for key in ["greatsword_attack", "heal", "stunning_blow", "flash", "sass_club", "disarm", "hover", "intuition", "self_destruct",
			"ground_pound", "hamstring", "bewilder", "accusation", "cleanse", "resuscitate"]:
		var skill: SkillDefinition = SkillDatabase.skills.get(key)
		if skill != null:
			MoveFeel.impact(combat, user, foe, skill, false, key == "sass_club")
	for key in ["sanctuary_of_light", "gnostic_tempest", "river_flow", "glacial_tide", "illusory_dragon", "grand_design", "wildfire",
			"fire_blast", "dispel_magic"]:
		var skill: SkillDefinition = SkillDatabase.skills.get(key)
		if skill != null:
			MoveFeel.over_area(combat, user, skill, foe.position, [foe.position, foe.position + Vector2i(1, 0)])
	MoveFeel.missed(combat, user, foe, gun)
	MoveFeel.mended(combat, mate)
	MoveFeel.readied_line(combat, user, foe)
	MoveFeel.exclaim(combat, foe)
	var condition: ConditionDefinition = null
	for path in ["res://data/conditions/stunned.tres", "res://data/conditions/burning.tres", "res://data/conditions/poisoned.tres"]:
		if condition == null and ResourceLoader.exists(path):
			condition = load(path)
	if condition != null:
		MoveFeel.condition_put(combat, foe, condition, false)
	MoveFeel.item_flies(combat, foe, user, "cure_potion")
	MoveFeel.dust(combat, MoveFeel.middle_of(combat, foe))
	MoveFeel.thud(combat, MoveFeel.middle_of(combat, foe))
	MoveFeel.bound_out(combat, user, mate)
	MoveFeel.thrown(combat, mate, MoveFeel.middle_of(combat, user))
	MoveFeel.part_struck(combat, [foe.position], Color.RED)
	MoveFeel.staggered(combat, foe)
	MoveFeel.screen_flash(combat, Color(1, 1, 1, 0.5), 0.2)
	var made := combat.combatant_layer().get_children().filter(func(child): return child is MoveFeel).size()
	var overlay: Node = combat.get_node_or_null("MoveFeelOverlay")
	ok(made > 20 and overlay != null and overlay.get_child_count() > 0, "the fight's every way in makes its looks, on the board and over the screen",
		"%d on the board" % made)
	ok(await until(func(): return not combat.combatant_layer().get_children().any(func(child): return child is MoveFeel) \
		and overlay.get_child_count() == 0, 4.0), "  and all of them go again")
	await end_fight()
	MoveFeel.plays_headless = false
	log_line("")


## Weight from the numbers: a scratch stops nothing, a heavy blow a beat and a
## shake, a kill the most.
func weight():
	log_line("======== weight from the numbers ========")
	var combat := await start_fight()
	ok(combat.hit_stop_for(5, 100) == 0.0 and combat.shake_for(0.05) == 0.0, "a scratch stops nothing, and shakes nothing")
	ok(combat.hit_stop_for(15, 100) == Combat.HIT_STOP_MINIMUM and combat.shake_for(0.15) == 0.0, "  a fair blow a moment, no shake")
	ok(combat.hit_stop_for(40, 100) >= Combat.HIT_STOP_HEAVY and combat.shake_for(0.4) >= Combat.SHAKE_HEAVY,
		"  a heavy one a beat, and the view shaken", "%.3f %.1f" % [combat.hit_stop_for(40, 100), combat.shake_for(0.4)])
	ok(combat.hit_stop_for(10, 100, true) == Combat.HIT_STOP_KILL and combat.shake_for(0.1, true) == Combat.SHAKE_KILL,
		"  and a kill the longest of all, whatever it took")
	var foes := combat.combatants.filter(func(comb): return comb.get("side", 0) == 1 and comb.get("alive", false) and not comb.has("object"))
	ok(not foes.is_empty() and (foes.size() > 1) != combat._last_standing(foes[0]), "the last of a side standing is known, for the blow that fells it to slow the world",
		"%d standing" % foes.size())
	await end_fight()
	log_line("")


## The number says what happened.
func numbers():
	log_line("======== the number says what happened ========")
	var holder := Node2D.new()
	add_child(holder)
	var plain := FloatingNumber.spawn(holder, Vector2.ZERO, "5", Color.WHITE)
	var big := FloatingNumber.spawn(holder, Vector2.ZERO, "50", Color.WHITE, {"share": 0.8})
	var grazed := FloatingNumber.spawn(holder, Vector2.ZERO, "3", Color.WHITE, {"graze": true})
	var resisted := FloatingNumber.spawn(holder, Vector2.ZERO, "3", Color.WHITE, {"resisted": true})
	var weak := FloatingNumber.spawn(holder, Vector2.ZERO, "9", Color.WHITE, {"vulnerable": true})
	ok(big.scale.x > plain.scale.x, "a blow that took most of somebody's health floats up bigger", "%.2f %.2f" % [plain.scale.x, big.scale.x])
	ok(grazed.get_children().any(func(child): return child is Label and child.text == "Graze"), "  a graze says so under it")
	ok(resisted.get_children().any(func(child): return child is Node2D and not child is Label and not child.star),
		"  one resisted is cracked")
	ok(weak.get_children().any(func(child): return child is Node2D and not child is Label and child.star), "  one they are weak to sits on a jagged star")
	holder.queue_free()
	log_line("")


## A mend's stretch of the bar filling; the stand-in sounds of a move.
func fills_and_sounds():
	log_line("======== a bar filling, and the sounds ========")
	var bar := ProgressBar.new()
	bar.size = Vector2(200, 12)
	add_child(bar)
	await get_tree().process_frame
	HealthBarMarks.fill(bar, 20, 60, 100)
	var strip: Control = bar.get_node_or_null("Fill")
	ok(strip != null, "health coming back fills the bar visibly, the new part brighter")
	bar.queue_free()
	var silent := []
	for called in ["launch_shot", "launch_spell", "launch_throw", "launch_roar", "launch_puff", "travel", "travel_beam",
			"travel_spray", "impact_physical", "impact_fire", "impact_water", "impact_wind", "impact_earth", "impact_poison",
			"impact_psychic", "impact_plasma", "impact_ice", "impact_lightning", "impact_metal", "impact_acid", "impact_idol",
			"impact_mend", "impact_miss", "impact_graze", "impact_shatter", "impact_thud"]:
		var stream := PlaceholderSounds.make(called)
		if stream == null or stream.data.size() < 200 or not PlaceholderSounds.RECIPES.has(called):
			silent.append(called)
	ok(silent.is_empty(), "a move sounds in three - leaving, travelling, landing - each a stand-in while its slot is empty", "%s" % [silent])
	ok(MoveFeel._impact_sound_of(SkillDatabase.skills.get("fireball"), Damage.Type.FIRE, false) == "impact_fire"
		and MoveFeel._impact_sound_of(SkillDatabase.skills.get("heal"), Damage.Type.PHYSICAL, false) == "impact_mend",
		"  landing by its element, or a mend's")
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
