extends "res://StealthHarness.gd"
## What the weather does, now that some of it is a rule (the designer, 2026-11-07, section 18 of docs/proposals_2026-11-07.md):
## in a fight, the wind on shots and fliers, deep snow, lightning, the rain soaking and putting fire out, heat and cold on Burn and
## Frozen, and thick weather to hide in; on a map, steps heard further or drowned and prints left in the wet and the snow.

const WATCHER := "res://data/encounters/encounter_03_watcher.tres"
const PARTY := ["enfina", "cyrus", "prometheus", "alithia"]
const BURN := preload("res://data/conditions/burn.tres")
const FROZEN := preload("res://data/conditions/frozen.tres")
const NO_TILE := Vector2i(-9999, -9999)
var game = null
var combat: Combat = null
var controller = null


func suite() -> String:
	return "weather"


func time_limit() -> float:
	return 240.0


func run_sections():
	the_model()
	await on_the_figures()
	await indoors_and_out()
	await the_wind()
	await fliers()
	await deep_snow()
	await lightning()
	await rain_heat_and_cold()
	await thick_weather()
	await close_fight()
	await on_a_map()


## Opens a fight at `minute` of the story's first day, under `weather`, out of doors unless `ambient` says.
func open_fight(weather: String, minute: int = 720, ambient: int = Light.Ambient.OUTDOORS):
	await close_fight()
	Campaign.reset()
	Campaign.set_party(PARTY, 32)
	Campaign.calendar_minutes = minute
	Campaign.set_weather(weather, 3)
	Campaign.current_map = "res://maps/crossroads_explore.tscn"
	Campaign.return_to_position = true
	var encounter: EncounterDefinition = load(WATCHER).duplicate()
	encounter.ambient = ambient
	encounter.time_of_day = -1
	encounter.boss_reveal = false
	Campaign.current_encounter = encounter
	game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle(6)
	combat = game.get_node("VisualCombat")
	controller = game.get_node("Controller")
	if combat.deployment_active:
		combat.finish_deployment()
		await settle(2)
	for comb in combat.combatants:
		comb.reaction_used = true
		if comb.has("stats"):
			comb.hp = 900
			comb.max_hp = 900


func close_fight():
	if game != null and is_instance_valid(game):
		game.queue_free()
		await settle(3)
	game = null
	combat = null


func who(key: String) -> Dictionary:
	for comb in combat.combatants:
		if comb.get("combatant_key", "") == key and not comb.get("illusion", false):
			return comb
	return {}


func foes() -> Array:
	return combat.combatants.filter(func(comb): return comb.side == 1 and comb.alive and not comb.has("object") and not comb.get("illusion", false))


func open_tile_near(from: Vector2i, walker: Dictionary) -> Vector2i:
	for gap in range(1, 6):
		for tile in controller.get_reachable_tiles(from, 0, 40, walker):
			if combat.get_position_distance(tile, from) == gap and combat.can_land_on(walker, tile) and combat.get_combatant_at(tile).is_empty():
				return tile
	return from


## Only to look at: what settles on a figure out under the sky, and a pose for the weather that falls back on idle.
func on_the_figures():
	log_line("======== on the figures ========")
	var figure := CombatantSprite.new()
	get_tree().root.add_child(figure)
	var frames := SpriteFrames.new()
	figure.setup(frames, null, false)
	var was_sky = CombatantSprite.under_the_sky
	CombatantSprite.under_the_sky = func(_at): return true
	CombatantSprite.snowing = 1.0
	CombatantSprite.cold_air = 1.0
	figure._weather_on_me(10.0)
	ok(figure.snow_on > 0.0 and figure.cold_on > 0.0, "snow settles on them out under the sky, and the cold shows", "%.2f, %.2f" % [figure.snow_on, figure.cold_on])
	ok(figure.weather_pose == &"shiver", "and they would shiver")
	ok(figure._animated == null or figure._animated.animation == &"idle" or not frames.has_animation(&"shiver"), "with no shiver of their own, they stand idle")
	CombatantSprite.under_the_sky = func(_at): return false
	figure._weather_on_me(120.0)
	ok(figure.snow_on == 0.0 and figure.weather_pose == &"", "under a roof it melts off, and they stand as ever")
	CombatantSprite.snowing = 0.0
	CombatantSprite.cold_air = 0.0
	CombatantSprite.under_the_sky = was_sky
	figure.queue_free()
	await settle()
	log_line("")


func the_model():
	log_line("======== what lies on the ground ========")
	var night_rain := Light.ground(60, "rain", "clear", 0)
	var day_rain := Light.ground(720, "rain", "clear", 0)
	ok(night_rain.wet > 0.0 and day_rain.wet > night_rain.wet and day_rain.wet <= 1.0, "puddles fill over a rainy day", "%.2f, %.2f" % [night_rain.wet, day_rain.wet])
	ok(Light.ground(900, "clear", "rain", 0).wet == 0.0 and Light.ground(120, "clear", "storm", 0).wet > 0.0, "and dry through the next morning")
	ok(Light.ground(720, "snow", "clear", 3).snow >= Light.DEEP_SNOW, "snow lies deep by midday of a snowy day")
	ok(Light.ground(720, "clear", "snow", 3).snow > 0.0 and Light.ground(1300, "clear", "snow", 2).snow == 0.0, "a winter's keeps; an autumn's melts by evening")
	ok(Light.ground(300, "clear", "clear", 3).frost > 0.0 and Light.ground(660, "clear", "clear", 3).frost == 0.0, "frost on a clear winter's night, gone by mid-morning")
	ok(Light.ground(300, "clear", "clear", 1).frost == 0.0, "never in summer")
	ok(Light.ground(600, "ash", "clear", 1).ash > 0.0 and Light.ground(600, "sandstorm", "clear", 1).sand > 0.0, "ash and sand gather over a day of them")
	var walls := func(tile: Vector2i): return tile == Vector2i(0, 0)
	ok(Light.lying_on({"snow": 1.0, "sand": 1.0}, Vector2i(1, 0), Vector2i(1, 0), walls).snow < 1.0, "thinner in the lee of a wall")
	ok(Light.lying_on({"snow": 1.0, "sand": 1.0}, Vector2i(-1, 0), Vector2i(1, 0), walls).sand == 1.0, "sand gathers against it")
	ok(Light.WIND_WAYS.has(Light.wind_way(5)) and Light.wind_way(5) == Light.wind_way(5), "each day's wind blows one way, the same for everybody")
	ok(Light.thick(Light.sky(Light.Ambient.OUTDOORS, 360, 2, "fog")) and not Light.thick(Light.sky(Light.Ambient.OUTDOORS, 720, 2, "clear")), "a fog is thick; a clear day is not")
	log_line("")


func indoors_and_out():
	log_line("======== indoors and out ========")
	await open_fight("rain", 720, Light.Ambient.INTERIOR)
	ok(combat.weather.is_empty() and combat.lying.is_empty() and not combat.raining_on(who("enfina").position), "indoors, no weather at all")
	await open_fight("rain")
	ok(float(combat.weather.get("rain", 0.0)) > 0.0 and combat.raining_on(who("enfina").position), "out of doors, the rain")
	log_line("")


func the_wind():
	log_line("======== the wind ========")
	await open_fight("wind")
	ok(combat.wind != Vector2i.ZERO and combat.wind == Campaign.wind_now(), "a strong wind, today's way", "%s" % combat.wind)
	var cyrus := who("cyrus")
	var gun: SkillDefinition = SkillDatabase.skills.gun
	ok(combat.wind_carries(gun), "the wind carries a shot")
	ok(not combat.wind_carries(SkillDatabase.skills.rapier), "not a blow")
	ok(not combat.wind_carries(SkillDatabase.skills.blink_strike) or SkillDatabase.skills.blink_strike.teleports == SkillDefinition.TeleportWho.NOBODY, "nor a blink")
	var from: Vector2i = cyrus.position
	var along: Vector2i = from + combat.wind * 5
	var across: Vector2i = from + Vector2i(-combat.wind.y, combat.wind.x) * 5 if combat.wind.x == 0 or combat.wind.y == 0 else from + Vector2i(combat.wind.x, -combat.wind.y) * 5
	ok(combat._wind_reach(cyrus, gun, 20, from, along) == 40, "twice as far along it", "%d" % combat._wind_reach(cyrus, gun, 20, from, along))
	ok(combat._wind_reach(cyrus, gun, 20, from, across) == 10, "half as far across it", "%d" % combat._wind_reach(cyrus, gun, 20, from, across))
	ok(combat._wind_reach(cyrus, gun, 3, from, across) == maxi(2, gun.min_range), "never below its least reach")
	var tiles: Array = combat.get_range_tiles(gun, cyrus.position, 0, cyrus)
	var far_across := tiles.filter(func(tile): return combat.wind_share(cyrus.position, tile) < 1.0 and combat.get_position_distance(cyrus.position, tile) > 10)
	ok(far_across.is_empty(), "what he is shown to aim at agrees: nothing across it past ten")
	Campaign.set_weather("clear", 3)
	combat._begin_weather()
	ok(combat.wind == Vector2i.ZERO and combat._wind_reach(cyrus, gun, 20, from, across) == 20, "on a calm day, the shot as it was")
	log_line("")


func fliers():
	log_line("======== fliers in the wind ========")
	await open_fight("wind")
	var flier: Dictionary = foes()[0]
	flier["base_movement_class"] = 1
	combat.resync_movement_class(flier)
	var downwind: Vector2i = flier.position + combat.wind
	if not combat.can_land_on(flier, downwind):
		combat.teleport_to(flier, open_tile_near(who("enfina").position, flier))
		downwind = flier.position + combat.wind
	var was: Vector2i = flier.position
	combat._blown_by_the_wind(flier)
	ok(not combat.can_land_on(flier, was + combat.wind) or flier.position == was + combat.wind, "blown a tile down it as its turn starts", "%s -> %s" % [was, flier.position])
	ok(combat.land_refusal(flier) == "" and combat.land(flier) and flier.movement_class == 0 and flier.landed, "it can land, for nothing")
	var still: Vector2i = flier.position
	combat._blown_by_the_wind(flier)
	ok(flier.position == still, "landed, the wind leaves it be")
	ok(combat.take_off(flier) and flier.movement_class == 1 and not flier.has("landed"), "and take off again, for nothing")
	combat._ai_consider_landing(flier)
	ok(flier.get("landed", false), "the AI comes down out of the wind as its turn ends")
	var walker := who("enfina")
	ok(combat.land_refusal(walker) != "", "nobody lands who is not flying")
	log_line("")


func deep_snow():
	log_line("======== deep snow ========")
	await open_fight("blizzard", 720)
	ok(not combat._deep_snow.is_empty(), "a blizzard by midday: the snow lies deep", "%d tiles" % combat._deep_snow.size())
	var enfina := who("enfina")
	var deep: Vector2i = combat._deep_snow.keys()[0]
	ok(combat.hem_cost(enfina, deep) == 2, "a step through it costs twice")
	var flier := enfina.duplicate()
	flier["movement_class"] = 1
	ok(combat.hem_cost(flier, deep) == 1, "but not a flier's")
	Campaign.set_weather("clear", 3)
	combat._begin_weather()
	ok(combat._deep_snow.is_empty() and combat.hem_cost(enfina, deep) == 1, "none lying, the step as it was")
	log_line("")


func lightning():
	log_line("======== lightning ========")
	await open_fight("thunderstorm")
	combat._arena_started = false
	combat._hazards_running.clear()
	combat._hazard_marks.clear()
	combat._arena_round_begins()
	ok(combat._hazards_running.any(func(running): return running.hazard == Combat.LIGHTNING_HAZARD), "a thunderstorm brings lightning to the field")
	var strikes: Array = combat._lightning_strikes(3)
	ok(strikes.size() == 3 and strikes.all(func(tile): return combat.light.under_the_sky(tile)), "it comes down out of the open sky", "%s" % [strikes])
	var low := {"level": 1}
	var high := {"level": 64}
	ok(combat._hazard_damage(Combat.LIGHTNING_HAZARD, high) > combat._hazard_damage(Combat.LIGHTNING_HAZARD, low) and combat._hazard_damage(Combat.LIGHTNING_HAZARD, low) > 0,
		"as hard as a blow at the level of whoever it catches", "%d at 1, %d at 64" % [combat._hazard_damage(Combat.LIGHTNING_HAZARD, low), combat._hazard_damage(Combat.LIGHTNING_HAZARD, high)])
	# Whoever draws it, first.
	var rod: Dictionary = foes()[0]
	rod["draws_lightning"] = true
	var on_rod := 0
	var tries := 3000
	for tile in combat._lightning_strikes(tries):
		if combat.tiles_of(rod).has(tile):
			on_rod += 1
	var open_tiles := 0
	var region: Rect2i = controller._astargrid.region
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			if controller.is_on_map(Vector2i(x, y)) and combat.light.under_the_sky(Vector2i(x, y)):
				open_tiles += 1
	ok(float(on_rod) / float(tries) > 2.0 / float(maxi(open_tiles, 1)), "whoever draws it is struck far more often than a tile anywhere", "%d of %d, %d tiles" % [on_rod, tries, open_tiles])
	rod.erase("draws_lightning")
	Campaign.set_weather("clear", 3)
	combat._begin_weather()
	combat._arena_started = false
	combat._hazards_running.clear()
	combat._arena_round_begins()
	ok(not combat._hazards_running.any(func(running): return running.hazard == Combat.LIGHTNING_HAZARD), "no thunderstorm, no lightning")
	log_line("")


func rain_heat_and_cold():
	log_line("======== rain, heat and cold ========")
	await open_fight("rain")
	var enfina := who("enfina")
	enfina.status_effects.clear()
	var dry := combat.resisted_damage(enfina, Damage.Type.ICE, 100)
	combat._rain_on(enfina)
	ok(combat.conditions_of(enfina).has(Combat.SOAKED), "under the rain as her turn starts: soaked")
	var wet := combat.resisted_damage(enfina, Damage.Type.ICE, 100)
	ok(wet > dry, "ice hurts her more", "%d against %d" % [wet, dry])
	ok(combat.resisted_damage(enfina, Damage.Type.FIRE, 100) == combat.resisted_damage({"resistances": enfina.get("resistances", {}), "status_effects": []}, Damage.Type.FIRE, 100), "fire no more than it did")
	ok(combat._weather_lengthens(enfina, FROZEN) >= 1, "and Frozen would hold on her a turn longer")
	# Fire on the ground, in the rain.
	var fire := EffectDefinition.new()
	fire.type = EffectDefinition.EffectType.ZONE
	fire.zone_condition = BURN
	fire.zone_turns = 4
	combat.lay_zone(enfina, fire, [enfina.position], null)
	var zone: Dictionary = combat.zones.back()
	combat._zones_at_turn_start(enfina)
	ok(zone.turns == 2 or not combat.zones.has(zone), "fire on the ground burns out twice as fast", "%d turns left" % zone.turns)
	combat.zones.erase(zone)
	# Heat.
	await open_fight("heat", 720)
	enfina = who("enfina")
	ok(Light.hot(combat.weather) and combat._weather_lengthens(enfina, BURN) == 1, "in the heat of the day Burn lasts a turn longer")
	ok(combat._weather_lengthens(enfina, FROZEN) == 0, "and Frozen no longer")
	await open_fight("snow", 720)
	enfina = who("enfina")
	ok(Light.cold(combat.weather, combat.lying) and combat._weather_lengthens(enfina, FROZEN) == 1, "in the snow Frozen lasts a turn longer")
	ok(combat._weather_lengthens(enfina, BURN) == 0, "and Burn no longer")
	log_line("")


func thick_weather():
	log_line("======== thick weather ========")
	await open_fight("fog", 360)
	var cyrus := who("cyrus")
	ok(combat.thick_weather(), "a fog at dawn")
	ok(combat._hides_in_dim(cyrus), "Cyrus can hide in it, past a few tiles, even in the light")
	ok(not combat._hides_in_dim(who("enfina")), "Enfina cannot")
	# Too close, and he is seen all the same (the designer, 2026-11-12): within DIM_SPOT_TILES.
	var them := foes()
	var watcher: Dictionary = them[0]
	for foe in them:
		if foe != watcher:
			combat.teleport_to(foe, Vector2i(-50, -50))
			foe.alive = false
	var near := NO_TILE
	var far := NO_TILE
	for tile in controller.get_reachable_tiles(cyrus.position, 0, 40, watcher):
		if not combat.can_land_on(watcher, tile) or not combat.get_combatant_at(tile).is_empty() or not combat.has_line_of_sight(tile, cyrus.position, 0):
			continue
		var gap: int = combat.get_position_distance(tile, cyrus.position)
		if gap == 2 and near == NO_TILE:
			near = tile
		elif gap == Combat.DIM_SPOT_TILES + 3 and far == NO_TILE:
			far = tile
	if near != NO_TILE and far != NO_TILE:
		combat.teleport_to(watcher, far)
		ok(not combat.is_seen_by_opponents(cyrus), "past %d tiles in the fog, nobody makes him out" % Combat.DIM_SPOT_TILES)
		combat.teleport_to(watcher, near)
		ok(combat.is_seen_by_opponents(cyrus), "two tiles off, he is seen all the same")
	else:
		log_line("  (no open tiles in sight two and %d off)" % (Combat.DIM_SPOT_TILES + 3))
	await open_fight("clear", 720)
	ok(not combat.thick_weather() and not combat._hides_in_dim(who("cyrus")), "on a clear day, nobody")
	log_line("")


func on_a_map():
	log_line("======== on a map ========")
	Campaign.return_to_position = false
	var m = await open_map()
	Campaign.calendar_minutes = 720
	Campaign.map_ambient = Light.Ambient.OUTDOORS
	var guard_tile: Vector2i = m.post
	var guard := add_guard(m, "Wet Guard", guard_tile)
	var watch := await watch_it(m, out_of_sight_of(m, [guard_tile]))
	var here: Vector2 = at(m, guard_tile)
	Campaign.set_weather("rain", 3)
	ok(is_equal_approx(watch._rain_hearing(here), StealthWatch.RAIN_CARRIES), "a light rain: steps are heard further")
	Campaign.set_weather("storm", 3)
	ok(is_equal_approx(watch._rain_hearing(here), StealthWatch.RAIN_DROWNS), "a storm drowns them")
	Campaign.set_weather("clear", 3)
	ok(is_equal_approx(watch._rain_hearing(here), 1.0), "dry, as ever")
	var someone := {"key": m.leader, "tile": guard_tile + Vector2i(10, 0), "hiding": false}
	watch._walking_now[m.leader] = true
	var creeping: bool = watch.stealthing(m.leader)
	ok(creeping or not watch.notices_walking(guard, someone), "dry, ten tiles off, walking is not heard")
	Campaign.set_weather("rain", 3)
	ok(creeping or watch.notices_walking(guard, someone), "in a light rain it is")
	Campaign.set_weather("storm", 3)
	someone.tile = guard_tile + Vector2i(5, 0)
	ok(creeping or not watch.notices_walking(guard, someone), "in a storm, five tiles off, drowned")
	watch._walking_now.erase(m.leader)
	# Prints in the mud.
	Campaign.set_weather("rain", 3)
	var print_at: Vector2 = at(m, guard_tile + Vector2i(2, 0))
	watch._since_print = 0.0
	watch.step_taken(print_at, Vector2(Grid.tiles(2.0), 0))
	ok(watch._prints.size() == 1 and watch._oddities.any(func(odd): return odd.what == "prints"), "a step in the wet leaves a print")
	settle_guard(watch, guard, 0.0)
	var alert_before: float = watch.alert
	await settle()
	var looked = await until(func(): return guard.mood == Guard.Mood.INVESTIGATING or guard.mood == Guard.Mood.SEARCHING, 1.5)
	var odd: Array = watch._oddities.filter(func(each): return each.what == "prints")
	ok(looked, "a guard sees it, and goes to look", "%s, %d prints noticed" % [Guard.Mood.keys()[guard.mood], odd.filter(func(each): return each.by != null).size()])
	ok(is_equal_approx(watch.alert, alert_before), "and the map is not put up for a print", "%.2f" % watch.alert)
	for print_left in watch._prints.duplicate():
		watch._forget_print(print_left)
	watch._prints.clear()
	Campaign.set_weather("clear", 3)
	watch._since_print = 0.0
	watch.step_taken(print_at, Vector2(Grid.tiles(2.0), 0))
	ok(watch._prints.is_empty(), "on dry ground, none")
	# Thick weather: past his Dim sight, nothing.
	settle_guard(watch, guard, 0.0)
	Campaign.calendar_minutes = 360
	Campaign.set_weather("fog", 3)
	ok(watch._thick_now(), "a fog at dawn")
	watch._seen_key.erase(guard)
	watch._refresh_seen(guard)
	var far: Array = watch._seen.get(guard, {}).keys().filter(func(tile): return gap(tile, guard_tile) > m.setup.dim_sight_tiles + 0.01)
	ok(far.is_empty(), "in it he sees nothing past his Dim sight", "%d tiles further" % far.size())
	var close_by: Array = watch._seen.get(guard, {}).keys().filter(func(tile): return gap(tile, guard_tile) <= m.setup.dim_sight_tiles)
	ok(not close_by.is_empty(), "but whoever is close by he still sees (the designer, 2026-11-12)", "%d tiles within %.0f" % [close_by.size(), m.setup.dim_sight_tiles])
	await close_map(m)
