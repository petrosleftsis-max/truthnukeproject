extends Node
## The clock and the calendar, time going by, and the look of light (Campaign "The clock and the calendar",
## LightView; the designer, 2026-11-07).

const LOG_NAME := "clock"
const WATCHER := "res://data/encounters/encounter_03_watcher.tres"
const PARTY := ["enfina", "cyrus", "prometheus", "alithia"]

var LOG_PATH := HarnessLog.path_for(LOG_NAME)
var _log: FileAccess = null
var _fail := 0


func log_line(text: String):
	if _log:
		_log.store_line(text)
		_log.flush()


func ok(condition: bool, label: String, detail: String = ""):
	if condition:
		log_line("  PASS  %s %s" % [label, detail])
	else:
		_fail += 1
		log_line("  FAIL  %s %s" % [label, detail])


func _ready():
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	get_tree().create_timer(240.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await settle()
	var booted = get_tree().current_scene
	if booted != null:
		booted.queue_free()
		await settle()
	the_clock()
	the_calendar()
	the_sky()
	await time_seen_going_by()
	await phantom_wall_and_light()
	await the_look()
	await the_calendar_panel()
	log_line("FAILURES: %d" % _fail)
	_log.close()
	get_tree().quit(0 if _fail == 0 else 1)


func settle(frames: int = 3):
	for i in frames:
		await get_tree().process_frame


func the_clock():
	log_line("======== the clock ========")
	Campaign.reset()
	ok(Campaign.day_number() == 1 and Campaign.clock_text() == "08:00", "the story begins on day 1, at 08:00", Campaign.clock_text())
	ok(Campaign.time_of_day == Light.Hour.DAY, "which is day")
	Campaign.advance_clock(8.5)
	ok(Campaign.clock_text() == "16:30" and Campaign.time_of_day == Light.Hour.DAY, "eight and a half hours on", Campaign.clock_text())
	var moved := [0]
	var turned := [0]
	var on_moved := func(): moved[0] += 1
	var on_turned := func(): turned[0] += 1
	Campaign.clock_moved.connect(on_moved)
	Campaign.time_of_day_changed.connect(on_turned)
	Campaign.advance_clock(1.0)
	ok(Campaign.time_of_day == Light.Hour.DUSK and moved[0] == 1 and turned[0] == 1, "past five it is dusk, and everybody is told", Campaign.clock_text())
	Campaign.advance_clock(0.25)
	ok(moved[0] == 2 and turned[0] == 1, "a quarter of an hour on is only the clock")
	Campaign.clock_moved.disconnect(on_moved)
	Campaign.time_of_day_changed.disconnect(on_turned)
	Campaign.advance_clock(0, 3)
	ok(Campaign.day_number() == 4 and Campaign.clock_text() == "17:45", "three days on", "day %d %s" % [Campaign.day_number(), Campaign.clock_text()])
	Campaign.set_clock(21, 30)
	ok(Campaign.day_number() == 4 and Campaign.clock_text() == "21:30" and Campaign.time_of_day == Light.Hour.NIGHT, "half past nine the same night")
	Campaign.set_clock(7)
	ok(Campaign.day_number() == 5 and Campaign.clock_text() == "07:00", "seven in the morning is tomorrow", "day %d" % Campaign.day_number())
	Campaign.set_time_of_day("night")
	ok(Campaign.day_number() == 5 and Campaign.clock_text() == "20:00", "night, the next time it comes", Campaign.clock_text())
	Campaign.set_time_of_day("dawn")
	ok(Campaign.day_number() == 6 and Campaign.clock_text() == "05:00", "dawn, the day after", Campaign.clock_text())
	var day := Campaign.day_number()
	Campaign.long_rest()
	ok(Campaign.time_of_day == Light.Hour.DAWN and Campaign.day_number() == day + 1, "a long rest at dawn ends at the next one")
	Campaign.advance_clock(3.0)
	Campaign.long_rest()
	ok(Campaign.day_number() == day + 2 and Campaign.time_of_day == Light.Hour.DAWN, "a long rest ends at the next dawn", "day %d" % Campaign.day_number())
	var before := Campaign.calendar_minutes
	Campaign.short_rest()
	ok(Campaign.calendar_minutes == before + roundi(Campaign.SHORT_REST_HOURS * 60.0), "a short rest takes an hour")
	Campaign.tick_clock(0.4)
	Campaign.tick_clock(0.4)
	var at := Campaign.calendar_minutes
	Campaign.tick_clock(0.4)
	ok(Campaign.calendar_minutes == at + 1, "parts of a minute add up")
	var saved := Campaign.snapshot("", Vector2.ZERO)
	ok(saved.has("calendar_minutes"), "it is kept in a save")
	var kept: int = saved.calendar_minutes
	Campaign.reset()
	Campaign.apply(saved)
	ok(Campaign.calendar_minutes == kept, "and comes back")
	saved.erase("calendar_minutes")
	saved.time_of_day = Light.Hour.NIGHT
	Campaign.apply(saved)
	ok(Campaign.clock_text() == "20:00" and Campaign.day_number() == 1, "a save from before there was a clock: day 1, at that part of it", Campaign.clock_text())
	log_line("")


func the_calendar():
	log_line("======== the calendar ========")
	var calendar: CalendarDefinition = load(Campaign.CALENDAR)
	var first := calendar.date_on(1)
	ok(first.day == 1 and first.month == 0 and first.year == 1, "day 1 is the first of the first")
	var later := calendar.date_on(31)
	ok(later.day == 1 and later.month == 1, "31 days on is the next month", "%s" % [later])
	var year := calendar.date_on(361)
	ok(year.year == 2 and year.month == 0 and year.day == 1, "and a year goes round", "%s" % [year])
	ok(calendar.date_on(8).weekday == 0, "the week goes round")
	ok(calendar.date_text(1) == "First Day, 1 of First Month, year 1", "it reads as a date", calendar.date_text(1))
	log_line("")


func the_sky():
	log_line("======== the sky, by the clock ========")
	ok(Light.hour_at(480) == Light.Hour.DAY and Light.hour_at(1020) == Light.Hour.DUSK and Light.hour_at(1200) == Light.Hour.NIGHT and Light.hour_at(300) == Light.Hour.DAWN, "each part begins when it says")
	ok(Light.hour_at(0) == Light.Hour.NIGHT and Light.hour_at(1439) == Light.Hour.NIGHT, "midnight is night")
	var sum := 0
	for hour in Light.HOUR_STARTS.size():
		sum += Light.hour_length(hour)
	ok(sum == Light.MINUTES_A_DAY, "and they add up to a day")
	var noon := Light.tone_at(Light.Ambient.OUTDOORS, 720)
	ok(noon.is_equal_approx(Color.WHITE), "noon is as drawn")
	var dusk := Light.tone_at(Light.Ambient.OUTDOORS, 1110)
	ok(dusk.r > dusk.b, "dusk is gold", "%s" % dusk)
	var night := Light.tone_at(Light.Ambient.OUTDOORS, 60)
	ok(night.b > night.r, "night is blue", "%s" % night)
	var dawn := Light.tone_at(Light.Ambient.OUTDOORS, 390)
	ok(dawn.r > dawn.b and dawn.b > dusk.b, "dawn is first gold, paler than dusk", "%s" % dawn)
	var between := Light.tone_at(Light.Ambient.OUTDOORS, 1000)
	ok(between.b < noon.b and between.b > dusk.b, "and it eases between them", "%s" % between)
	ok(Light.tone_at(Light.Ambient.UNDERGROUND, 60) == Light.UNDERGROUND_TONE, "underground the hour has no say")
	ok(Light.grade_at(Light.Ambient.OUTDOORS, 60).saturation < 1.0 and Light.grade_at(Light.Ambient.OUTDOORS, 1110).saturation > 1.0, "colours go at night, and glow at dusk")
	var morning := Light.shadow_at(Light.Ambient.OUTDOORS, 400)
	var evening := Light.shadow_at(Light.Ambient.OUTDOORS, 1100)
	ok(morning.lean < 0.0 and evening.lean > 0.0, "shadows go round with the sun")
	log_line("")


func time_seen_going_by():
	log_line("======== time seen going by ========")
	Campaign.reset()
	# Nobody to see it: a cut.
	await Campaign.watch_time_pass(4.0)
	ok(Campaign.clock_text() == "12:00" and not Campaign.time_passing, "with nobody to see it, a cut", Campaign.clock_text())
	LightView.plays_headless = true
	var turned := [0]
	var on_turned := func(): turned[0] += 1
	Campaign.time_of_day_changed.connect(on_turned)
	Campaign.watch_time_pass(10.0, 0, 0.4)
	await settle(3)
	ok(Campaign.time_passing, "seen going by: everybody stands while it does")
	var show = get_tree().root.get_node_or_null("TimePassing")
	ok(show != null, "with a clock on the screen")
	var part_way := Campaign.calendar_minutes
	await get_tree().create_timer(0.6).timeout
	ok(Campaign.calendar_minutes > part_way, "it runs")
	ok(Campaign.clock_text() == "22:00", "and gets to where it was going", Campaign.clock_text())
	ok(not Campaign.time_passing and not is_instance_valid(show), "and it is over")
	ok(turned[0] >= 2, "through dusk and into night, each told", "%d" % turned[0])
	Campaign.time_of_day_changed.disconnect(on_turned)
	var was := Campaign.calendar_minutes
	Campaign.watch_time_pass(0.0, 3, 0.0)
	ok(Campaign.calendar_minutes == was + 3 * Light.MINUTES_A_DAY, "with no seconds to do it in, a cut too")
	LightView.plays_headless = false
	log_line("")


func phantom_wall_and_light():
	log_line("======== illusions and light ========")
	Campaign.reset()
	Campaign.set_party(PARTY, 64)
	Campaign.choose_subclass("alithia", "illusory_shepherd")
	Campaign.current_map = "res://maps/crossroads_explore.tscn"
	Campaign.return_to_position = true
	var encounter: EncounterDefinition = load(WATCHER).duplicate()
	encounter.ambient = Light.Ambient.UNDERGROUND
	Campaign.current_encounter = encounter
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle(6)
	var combat: Combat = game.get_node("VisualCombat")
	var controller = game.get_node("Controller")
	if combat.deployment_active:
		combat.finish_deployment()
		await settle(2)
	var alithia: Dictionary = {}
	for comb in combat.combatants:
		comb.reaction_used = true
		if comb.has("stats"):
			comb.hp = 900
			comb.max_hp = 900
		if comb.get("combatant_key", "") == "alithia":
			alithia = comb
	for gate in alithia.spell_slots.size():
		alithia.spell_slots[gate] = 5
	ok(load("res://data/objects/phantom_wall.tres").illusion_stops_light, "a Phantom Wall stops light")
	# A light on one side of where the wall goes.
	var source_at := Vector2i.ZERO
	var wall_at := Vector2i.ZERO
	var beyond := Vector2i.ZERO
	var found := false
	for tile in controller.get_reachable_tiles(alithia.position, 0, 12, alithia):
		for way in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
			var candidates := [tile + way * 2, tile + way * 3, tile + way]
			if candidates.all(func(each): return controller.is_on_map(each) and not controller.terrain_blocks_sight(each, 0) and combat.get_combatant_at(each).is_empty()) \
					and combat.get_combatant_at(tile).is_empty() and absi(tile.x - alithia.position.x) + absi(tile.y - alithia.position.y) >= 4:
				source_at = tile
				wall_at = tile + way
				beyond = tile + way * 3
				found = true
				break
		if found:
			break
	ok(found, "somewhere to try it")
	combat._placed_lights = [{"tile": source_at, "bright": 2.0, "dim": 6.0, "colour": Color.WHITE, "flickers": false}]
	combat.relight()
	var lit_before: int = combat.light_level(beyond)
	ok(lit_before != Light.Level.DARK, "the light reaches past where the wall will go", "%d" % lit_before)
	combat.current_combatant = combat.combatants.find(alithia)
	alithia.skill_used_this_turn = false
	controller.set_controlled_combatant(alithia)
	await settle()
	for comb in combat.combatants.duplicate():
		if comb.get("alive", false) and comb.has("object") and comb.position == wall_at:
			combat.combatant_die(comb)
	var definition = CombatantDatabase.combatants.get("phantom_wall")
	var wall: Dictionary = combat.create_combatant(definition, "phantom_wall")
	wall["illusion"] = true
	combat.add_combatant(wall, 0, wall_at)
	combat.relight()
	ok(combat.is_wall(wall) and combat._wall_tiles_for_light.has(wall_at), "it counts as a wall for light")
	ok(combat.light_level(beyond) == Light.Level.DARK, "and beyond it, it is dark", "%d" % combat.light_level(beyond))
	# An illusion gives light too.
	combat._placed_lights = []
	combat.relight()
	var dragon_def: CombatantDefinition = CombatantDatabase.combatants.illusory_dragon
	ok(dragon_def.light_tiles > 0.0, "an Illusory Dragon gives light")
	var dragon: Dictionary = combat.create_combatant(dragon_def, "illusory_dragon")
	dragon["illusion"] = true
	combat.add_combatant(dragon, 0, source_at)
	combat.relight()
	ok(combat.light_level(source_at) == Light.Level.BRIGHT, "real light, though it is not", "%d" % combat.light_level(source_at))
	game.queue_free()
	await settle()
	log_line("")


func the_look():
	log_line("======== the look ========")
	LightView.plays_headless = true
	Campaign.reset()
	Campaign.set_party(PARTY, 32)
	Campaign.current_map = "res://maps/crossroads_explore.tscn"
	Campaign.return_to_position = true
	var encounter: EncounterDefinition = load(WATCHER).duplicate()
	encounter.ambient = Light.Ambient.UNDERGROUND
	Campaign.current_encounter = encounter
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle(6)
	var combat: Combat = game.get_node("VisualCombat")
	if combat.deployment_active:
		combat.finish_deployment()
		await settle(2)
	var view: LightView = combat.light_view
	ok(view != null, "it is drawn")
	if view != null:
		var tile: Vector2i = combat.combatants[0].position
		combat._placed_lights = [{"tile": tile, "bright": 2.0, "dim": 5.0, "colour": Color(1, 0.5, 0.2), "flickers": true},
			{"tile": tile + Vector2i(3, 0), "bright": 2.0, "dim": 4.0, "colour": Color.WHITE, "flickers": false, "opening": true}]
		combat.relight()
		await settle()
		var lights := view.get_children().filter(func(node): return node is PointLight2D)
		ok(lights.size() == 2, "a real light on each source", "%d" % lights.size())
		if lights.size() == 2:
			ok(lights[0].color == Color(1, 0.5, 0.2) and lights[0].shadow_enabled, "in its colour, casting shadows")
			ok(lights[0].get_children().any(func(node): return node is CPUParticles2D), "embers round a flame")
			ok(lights[1].get_children().any(func(node): return node is LightView._Shaft), "shafts of light from an opening")
		ok(view.get_node("Occluders").get_child_count() > 0, "walls made into what stops them", "%d" % view.get_node("Occluders").get_child_count())
		ok(not CombatantSprite.light_points.is_empty(), "figures' shadows are told where the lights are")
		ok(view.get_node("Grade").visible, "underground is graded")
		ok(view.get_node("Fog").visible, "fog hangs in the dark")
		view.night_eyes = false
		var strength: float = view.get_node("Fog").material.get_shader_parameter("strength")
		view.night_eyes = true
		ok(view.get_node("Fog").visible and view.get_node("Fog").material.get_shader_parameter("strength") != strength, "and still does for whoever sees in the dark, as they see it")
		view.night_eyes = false
		# A carried light glides; a light gone goes out.
		var first: PointLight2D = lights[0]
		combat._placed_lights[0].tile = tile + Vector2i(1, 0)
		combat.relight()
		await settle()
		ok(view.get_children().filter(func(node): return node is PointLight2D).has(first), "a light moved a tile is the same light")
		combat._placed_lights = []
		combat.relight()
		await settle()
		# Darkness comes on slowly (the designer, 2026-11-12): the shade, the fog over the Dark and the figures' darkness alike.
		ok(view._shade_blend < 1.0 and CombatantSprite.shade_blend < 1.0 and float(view.get_node("Fog").material.get_shader_parameter("blend")) < 1.0,
			"the dark coming on eases in: the shade, the fog and the figures together", "%.2f" % view._shade_blend)
		ok(view._shade_easing != null and view._shade_easing.is_valid(), "over a while")
		await get_tree().create_timer(LightView.EASE_SECONDS + 0.2).timeout
		ok(view.get_children().filter(func(node): return node is PointLight2D).is_empty(), "and they go out, slowly")
		await get_tree().create_timer(LightView.DARKEN_SECONDS).timeout
		ok(is_equal_approx(view._shade_blend, 1.0) and is_equal_approx(CombatantSprite.shade_blend, 1.0), "and gets there")
		# One coming before the last is done goes on from where that had got to.
		combat._placed_lights = [{"tile": tile, "bright": 2.0, "dim": 5.0, "colour": Color.WHITE, "flickers": false}]
		combat.relight()
		await get_tree().create_timer(0.3).timeout
		var halfway: Image = view._shade_shown()
		combat._placed_lights = []
		combat.relight()
		var from_image: Image = (view.get_node("Shade").material.get_shader_parameter("previous") as Texture2D).get_image()
		var at: Vector2i = tile - view._region.position
		ok(from_image != null and halfway != null and absf(from_image.get_pixelv(at).a - halfway.get_pixelv(at).a) < 0.06,
			"a change halfway goes on from halfway, not from where the last was going",
			"%.2f and %.2f" % [from_image.get_pixelv(at).a if from_image != null else -1.0, halfway.get_pixelv(at).a if halfway != null else -1.0])
		await get_tree().create_timer(LightView.DARKEN_SECONDS + 0.2).timeout
		# Figures in the dark.
		var someone: Dictionary = combat.combatants[0]
		someone.sprite.set_in_the_dark(true, true)
		await settle()
		ok(someone.sprite._animated != null or someone.sprite._static != null, "a figure is there")
		ok((someone.sprite._animated if someone.sprite._animated != null else someone.sprite._static).material != null, "with a rim in the dark")
		ok(someone.sprite._eyes != null and someone.sprite._eyes.visible, "and eyes, if they see in it")
		await get_tree().create_timer(CombatantSprite.FADE_SECONDS + 0.1).timeout
		someone.sprite.set_in_the_dark(false, true)
		var drawn_as: Node2D = someone.sprite._animated if someone.sprite._animated != null else someone.sprite._static
		await settle()
		ok(someone.sprite._rim > 0.0 and someone.sprite._rim < 1.0, "the rim eases away, not at once", "%.2f" % someone.sprite._rim)
		await get_tree().create_timer(CombatantSprite.FADE_SECONDS + 0.1).timeout
		ok((drawn_as.material == null or float(drawn_as.material.get_shader_parameter("rim_on")) == 0.0) and not someone.sprite._eyes.visible, "and neither in the light")
		# Fading out of sight into the dark, or hidden: eased too, the rule's own number at once.
		var showing_now: float = someone.sprite._shown_alpha
		var to: float = 0.1 if showing_now > 0.5 else 0.9
		var was_wanted: float = someone.sprite.hidden_alpha
		someone.sprite.set_hidden_alpha(to)
		ok(is_equal_approx(someone.sprite.hidden_alpha, to) and is_equal_approx(someone.sprite._shown_alpha, showing_now),
			"somebody fading into the dark or out of it goes slowly, though the rule has them hidden or seen at once",
			"%.2f to %.2f" % [someone.sprite._shown_alpha, to])
		await get_tree().create_timer(CombatantSprite.FADE_SECONDS + 0.1).timeout
		ok(is_equal_approx(someone.sprite._shown_alpha, to), "and gets there", "%.2f" % someone.sprite._shown_alpha)
		someone.sprite.set_hidden_alpha(was_wanted)
	# Projectiles.
	var fire := SkillDefinition.new()
	fire.deals_damage = true
	fire.damage_type = Damage.Type.FIRE
	ok(Projectile.light_tiles_of(fire) > 0.0, "a fire projectile gives light")
	var rock := SkillDefinition.new()
	rock.deals_damage = true
	rock.damage_type = Damage.Type.EARTH
	ok(Projectile.light_tiles_of(rock) == 0.0, "a rock does not")
	rock.projectile_light_tiles = 2.0
	ok(Projectile.light_tiles_of(rock) == 2.0, "unless it says so")
	ok(Projectile.light_tiles_of(SkillDatabase.skills.light_void) < 0.0, "and what makes darkness takes it away")
	game.queue_free()
	await settle()
	LightView.plays_headless = false
	log_line("")


func the_calendar_panel():
	log_line("======== the calendar, to look at ========")
	# The designer, 2026-11-12: "make it easier for me to see every weather through the sundial, allow me to check a calendar to
	# see dates and weather".
	Campaign.reset()
	Campaign.call_deferred("open_calendar")
	await settle(4)
	var panel = get_tree().root.get_node_or_null("CalendarPanel")
	ok(panel != null, "it comes up")
	if panel == null:
		return
	var days: Array = panel.find_children("Day*", "Button", true, false)
	ok(days.size() == Campaign.calendar().days_in_a_month, "a square for every day of the month", "%d" % days.size())
	var said_today: Array = days[0].find_children("*", "Label", true, false).map(func(label): return label.text)
	ok(said_today.any(func(text): return text.begins_with(Campaign.weather_on(1).capitalize())), "each with its weather", "%s" % [said_today])
	panel._show("weathers")
	await settle()
	var buttons: Array = panel.find_children("Weather_*", "Button", true, false)
	ok(buttons.size() == Light.WEATHERS.size(), "and every weather there is, to have now", "%d" % buttons.size())
	for button in buttons:
		if button.name == "Weather_fog":
			button.pressed.emit()
	ok(Campaign.weather_today() == "fog", "pressed, it is that weather now", Campaign.weather_today())
	Campaign.set_clock(6, 30)
	ok(Campaign.weather_today() == "fog", "and still, the hours gone round past midnight", "day %d: %s" % [Campaign.day_number(), Campaign.weather_today()])
	panel._show("month")
	await settle()
	panel._picked_day = 5
	panel._go_to_picked()
	ok(Campaign.day_number() == 5, "a day to come can be gone to", "day %d" % Campaign.day_number())
	panel._picked_day = 2
	panel._say_about()
	ok(panel._go.disabled, "never one gone by")
	panel._close()
	await settle()
	ok(get_tree().root.get_node_or_null("CalendarPanel") == null, "and it closes")
	# A round of every weather, stopped by a press, and the sky as it was after.
	Campaign.set_weather("snow", 2)
	var was: Dictionary = Campaign.weather_fixed.duplicate()
	Campaign.call_deferred("tour_the_weathers")
	await settle(4)
	var caption = get_tree().root.get_node_or_null("WeatherTour")
	ok(caption != null and Campaign.weather_today() == Light.WEATHERS.keys()[0], "a round of them all begins with the first", Campaign.weather_today())
	if caption != null:
		caption.stopped = true
	await settle(4)
	ok(Campaign.weather_fixed == was and get_tree().root.get_node_or_null("WeatherTour") == null, "stopped, the sky is as it was", "%s" % [Campaign.weather_fixed])
	Campaign.reset()
	log_line("")
