extends "res://StealthHarness.gd"
## The day going round (Light.sky, Campaign "The day's own sky", LightView; docs/proposals_2026-11-07.md section 14): curves, more marks, the
## shade by the minute, a day's own weather and sunset, the moon, the seasons, a place's own sky, and lights that go by the clock.


func suite() -> String:
	return "daysky"


func time_limit() -> float:
	return 200.0


func run_sections():
	the_curve()
	each_day_its_own()
	await the_story_has_the_last_word()
	the_moon()
	the_seasons()
	the_other_weathers()
	getting_wet()
	await lights_by_the_clock()
	await how_it_looks()


func the_curve():
	log_line("======== smoother ========")
	var outdoors := Light.Ambient.OUTDOORS
	ok(Light.SKY.size() >= 13, "about thirteen marks", "%d" % Light.SKY.size())
	var biggest := 0.0
	var was: Color = Light.tone_at(outdoors, 0)
	for minute in range(1, 1441):
		var now: Color = Light.tone_at(outdoors, minute)
		biggest = maxf(biggest, absf(now.r - was.r) + absf(now.g - was.g) + absf(now.b - was.b))
		was = now
	ok(biggest < 0.05, "no jump from one minute to the next, round the end of the day too", "%.3f" % biggest)
	ok(Light.tone_at(outdoors, 1440).is_equal_approx(Light.tone_at(outdoors, 0)), "midnight is midnight")
	ok(not Light.tone_at(outdoors, 540).is_equal_approx(Light.tone_at(outdoors, 840)), "it doesn't stand still from morning to afternoon")
	ok(not is_equal_approx(Light.shadow_at(outdoors, 600).lean, Light.shadow_at(outdoors, 840).lean), "and nor do the shadows")
	ok(not is_equal_approx(Light.shadow_at(outdoors, 1290).lean, Light.shadow_at(outdoors, 200).lean), "a moon shadow goes round at night")
	var noon: Dictionary = Light.sky(outdoors, 720)
	var evening: Dictionary = Light.sky(outdoors, 1110)
	ok(noon.soft < evening.soft, "shadows are hard at noon and soft at the day's end", "%.2f, %.2f" % [noon.soft, evening.soft])
	ok(absf(noon.lean) < absf(evening.lean), "and short", "%.2f, %.2f" % [noon.lean, evening.lean])
	# How lit it looks goes by the minute: 16:30 already has evening in it, and 17:00 no jump.
	ok(Light.sky(outdoors, 990).amount < noon.amount, "at half past four the evening is coming", "%.2f" % Light.sky(outdoors, 990).amount)
	var before: float = Light.sky(outdoors, 1019).amount
	var after: float = Light.sky(outdoors, 1021).amount
	ok(absf(before - after) < 0.02, "and at five nothing jumps", "%.3f, %.3f" % [before, after])
	ok(Light.sky(Light.Ambient.UNDERGROUND, 720).amount < 0.0, "under a rock the sun has no say")
	log_line("")


func each_day_its_own():
	log_line("======== each day its own ========")
	var outdoors := Light.Ambient.OUTDOORS
	ok(Light.weather_of(1) == "clear", "the story's first day is clear")
	var kinds := {}
	for day in range(2, 200):
		kinds[Light.weather_of(day)] = true
	ok(kinds.has("clear") and kinds.has("haze") and kinds.has("overcast") and kinds.has("rain") and kinds.has("fog"), "every kind comes up", "%s" % [kinds.keys()])
	ok(not kinds.has("storm"), "a storm only when a scene says")
	ok(Light.weather_of(37) == Light.weather_of(37) and Light.day_share(12, 2) == Light.day_share(12, 2), "the same day is the same")
	var clear: Dictionary = Light.sky(outdoors, 720, 5, "clear")
	var overcast: Dictionary = Light.sky(outdoors, 720, 5, "overcast")
	var rain: Dictionary = Light.sky(outdoors, 720, 5, "rain")
	var haze: Dictionary = Light.sky(outdoors, 720, 5, "haze")
	var storm: Dictionary = Light.sky(outdoors, 720, 5, "storm")
	ok(overcast.strength < clear.strength * 0.5 and overcast.saturation < clear.saturation, "overcast is flat and grey, with faint shadows", "%.2f" % overcast.strength)
	ok(overcast.clouds > clear.clouds, "and clouds pass over it", "%.2f" % overcast.clouds)
	ok(rain.rain > 0.0 and clear.rain == 0.0, "rain falls")
	ok(rain.sound == &"rain_falling", "and is heard")
	ok(haze.tone.r > haze.tone.b and haze.contrast < clear.contrast, "haze is soft and warm", "%s" % haze.tone)
	ok(storm.amount < rain.amount and rain.amount < clear.amount, "a storm is darker than rain, and rain than a clear day")
	var early: Dictionary = Light.sky(outdoors, 420, 5, "fog")
	var lifted: Dictionary = Light.sky(outdoors, 600, 5, "fog")
	var fog_noon: Dictionary = Light.sky(outdoors, 720, 5, "fog")
	ok(early.mist > 0.8, "a foggy morning", "%.2f" % early.mist)
	ok(lifted.mist < 0.01, "has lifted by ten", "%.2f" % lifted.mist)
	ok(is_equal_approx(fog_noon.amount, Light.sky(outdoors, 720, 5, "").amount) and fog_noon.strength > 0.3, "and the day goes on as if it had never been")
	# Sunset and sunrise vary, within a range.
	var sunsets := {}
	for day in range(2, 40):
		var sunset: Color = Light.sky(outdoors, 1110, day, "clear").tone
		sunsets[sunset.to_html()] = true
		ok(sunset.r > sunset.b, "day %d's sunset is warm" % day) if day == 2 or day == 30 else null
		var morning: Dictionary = Light.sky(outdoors, 420, day, "clear")
		var evening: Dictionary = Light.sky(outdoors, 1090, day, "clear")
		var night: Color = Light.sky(outdoors, 60, day, "clear").tone
		if morning.lean >= 0.0 or evening.lean <= 0.0 or night.b <= night.r:
			ok(false, "the sun rises on the same side and night is blue, whatever the day", "day %d" % day)
	ok(sunsets.size() >= 8, "and no two weeks' are the same", "%d kinds" % sunsets.size())
	var tinted: Color = Light.sky(outdoors, 720, 0, "", Color(0.8, 1.0, 0.8)).tone
	ok(tinted.g > tinted.r and tinted.g > tinted.b, "a place can have its own sky", "%s" % tinted)
	log_line("")


func the_story_has_the_last_word():
	log_line("======== the story has the last word ========")
	Campaign.reset()
	var moved := [0]
	var listen := func(): moved[0] += 1
	Campaign.clock_moved.connect(listen)
	ok(Campaign.weather_today() == "clear", "a clear first day")
	Campaign.set_weather("storm")
	ok(Campaign.weather_today() == "storm", "a scene says storm")
	ok(moved[0] == 1, "and what is drawn hears it")
	ok(Campaign.sky_now().rain > 0.9, "and it rains")
	Campaign.advance_clock(0, 1)
	ok(Campaign.weather_today() == Light.weather_of(Campaign.day_number(), Campaign.days_in_a_year()), "for today alone", Campaign.weather_today())
	Campaign.set_weather("rain", 3)
	var today: int = Campaign.day_number()
	Campaign.advance_clock(0, 2)
	ok(Campaign.weather_today() == "rain", "or for three days")
	Campaign.advance_clock(0, 1)
	ok(Campaign.weather_today() == Light.weather_of(today + 3, Campaign.days_in_a_year()), "and no longer", Campaign.weather_today())
	Campaign.set_weather("overcast")
	Campaign.set_weather()
	ok(Campaign.weather_today() == Light.weather_of(Campaign.day_number(), Campaign.days_in_a_year()), "and it can be handed back to the day")
	Campaign.clock_moved.disconnect(listen)
	# A save keeps it.
	ok(Campaign.SAVED.has("weather_fixed") and Campaign.SAVED.has("moon_fixed") and Campaign.SAVED.has("map_sky_tint"), "in a save")
	Campaign.set_weather("fog", 2)
	Campaign.set_moon("new")
	var kept: Dictionary = Campaign.weather_fixed.duplicate()
	var state: Dictionary = Campaign.snapshot("", Vector2.ZERO) if Campaign.has_method("snapshot") else {}
	ok(state.is_empty() or state.get("weather_fixed", {}) == kept, "with what a scene fixed", "%s" % [state.get("weather_fixed", {})])
	Campaign.reset()
	ok(Campaign.weather_fixed.is_empty() and Campaign.moon_fixed == "", "a new run has none of it")
	log_line("")


func the_moon():
	log_line("======== the moon ========")
	Campaign.reset()
	ok(is_equal_approx(Light.moon_phase(1), 0.5), "full on the first day")
	ok(Light.moon_name(Light.moon_phase(1)) == "full moon", "and says so")
	ok(Light.moon_light(Light.moon_phase(16)) < Light.NO_MOON_BELOW, "new a fortnight on")
	ok(Light.moon_name(Light.moon_phase(16)) == "new moon", "and says so")
	var outdoors := Light.Ambient.OUTDOORS
	var full: Dictionary = Light.sky(outdoors, 60, 2, "clear", Color.WHITE, 0.5)
	var thin: Dictionary = Light.sky(outdoors, 60, 2, "clear", Color.WHITE, 0.1)
	ok(full.amount > thin.amount, "a full moon's night is a little brighter", "%.2f, %.2f" % [full.amount, thin.amount])
	ok(full.strength > thin.strength, "with more of a shadow", "%.2f, %.2f" % [full.strength, thin.strength])
	# The rule: a new moon is No Moon.
	ok(not Campaign.no_moon_now(), "the first night has one")
	ok(Light.base_level(outdoors, Light.Hour.NIGHT, Campaign.no_moon_now()) == Light.Level.DIM, "so night is Dim")
	Campaign.advance_clock(0, 15)
	Campaign.set_clock(22)
	ok(Campaign.no_moon_now(), "a new moon's night has none", "day %d, phase %.2f" % [Campaign.day_number(), Campaign.moon_now()])
	ok(Light.base_level(outdoors, Light.Hour.NIGHT, Campaign.no_moon_now()) == Light.Level.DARK, "so it is Dark")
	var before: bool = Campaign.no_moon_now()
	Campaign.set_clock(2)
	ok(Campaign.no_moon_now() == before, "and it doesn't change at midnight, in the middle of the night")
	Campaign.set_moon("full")
	ok(not Campaign.no_moon_now(), "a scene can give it a moon")
	Campaign.set_moon()
	ok(Campaign.no_moon_now() == before, "and hand it back")
	Campaign.reset()
	Campaign.set_moon("new")
	ok(Campaign.no_moon_now(), "or take it away")
	Campaign.reset()
	Campaign.map_no_moon = true
	ok(Campaign.no_moon_now(), "and a map's own No Moon still has its say")
	Campaign.reset()
	log_line("")


func the_seasons():
	log_line("======== the seasons ========")
	Campaign.reset()
	ok(Light.season_shift(1, 360) == 0, "the story begins with neither")
	ok(Light.season_shift(5, 360) == 0, "and it moves in steps")
	ok(Light.season_shift(91, 360) == Light.SEASON_MOST, "an hour longer at one end of the year", "%d" % Light.season_shift(91, 360))
	ok(Light.season_shift(271, 360) == -Light.SEASON_MOST, "and shorter at the other", "%d" % Light.season_shift(271, 360))
	ok(Light.hour_at(1050) == Light.Hour.DUSK, "half past five is dusk in the middle of the year")
	ok(Light.hour_at(1050, 60) == Light.Hour.DAY, "and still day at the height of it")
	ok(Light.hour_at(990, -60) == Light.Hour.DUSK, "half past four is dusk at the depth of it")
	ok(Light.hour_at(1230, 60) == Light.Hour.DUSK and Light.hour_at(1230) == Light.Hour.NIGHT, "night comes later")
	ok(Light.hour_at(260, 60) == Light.Hour.DAWN and Light.hour_at(260) == Light.Hour.NIGHT, "and dawn sooner")
	var sum := 0
	for hour in Light.HOUR_STARTS.size():
		sum += Light.hour_length(hour)
	ok(sum == Light.MINUTES_A_DAY, "and it is still a day")
	var summer: float = Light.sky(Light.Ambient.OUTDOORS, 1140, 91, "clear", Color.WHITE, 0.5, 60).amount
	var midyear: float = Light.sky(Light.Ambient.OUTDOORS, 1140, 91, "clear", Color.WHITE, 0.5, 0).amount
	ok(summer > midyear, "and how it looks goes with it", "%.2f, %.2f" % [summer, midyear])
	# On the clock.
	Campaign.advance_clock(0, 90)
	ok(Campaign.season_shift() == Light.SEASON_MOST, "the calendar says how far on it is", "day %d, %d" % [Campaign.day_number(), Campaign.season_shift()])
	Campaign.set_clock(17, 30)
	ok(Campaign.time_of_day == Light.Hour.DAY, "half past five, still day", Light.TIME_NAMES[Campaign.time_of_day])
	Campaign.set_time_of_day("dusk")
	ok(Campaign.time_of_day == Light.Hour.DUSK and Campaign.minute_of_day() == Light.hour_start(Light.Hour.DUSK, 60), "and asked for dusk, it comes when dusk does", Campaign.clock_text())
	Campaign.reset()
	log_line("")


func lights_by_the_clock():
	log_line("======== lights by the clock ========")
	ok(Light.lamp_lit_at(23 * 60, 3), "lit at night")
	ok(not Light.lamp_lit_at(12 * 60, 3), "out by day")
	var apart := 0
	for minute in range(17 * 60, 20 * 60):
		if Light.lamp_lit_at(minute, 3) != Light.lamp_lit_at(minute, 40):
			apart += 1
	ok(apart > 10, "and each at its own minute", "%d" % apart)
	Campaign.reset()
	var m := await open_map()
	var lamp := LightSource.new()
	lamp.by_the_clock = true
	m.map.add_child(lamp)
	lamp.global_position = at(m, Vector2i(4, 4))
	var noon: Dictionary = lamp.source_now(m.tile_map, Light.Hour.DAY, 12 * 60)
	var night: Dictionary = lamp.source_now(m.tile_map, Light.Hour.NIGHT, 23 * 60)
	ok(noon.is_empty(), "a light that goes by the clock gives nothing at noon")
	ok(not night.is_empty(), "and it lights the night")
	ok(not lamp.source_now(m.tile_map, Light.Hour.DAY).is_empty(), "with no minute to go by, it is as it stands")
	lamp.by_the_clock = false
	ok(not lamp.source_now(m.tile_map, Light.Hour.DAY, 12 * 60).is_empty(), "a light that doesn't go by it isn't bothered")
	lamp.queue_free()
	close_map(m)
	await settle()
	m = await open_map()
	m.scene.begin_stealth()
	await settle()
	var watch = m.scene.stealth
	var post := Lamp.new()
	post.by_the_clock = true
	post.starts_lit = false
	m.map.add_child(post)
	post.global_position = at(m, Vector2i(3, 3))
	watch._lamps.append(post)
	Campaign.set_clock(23)
	watch.keep_lamps_by_the_clock()
	ok(post.lit, "a lamp marked for it comes on")
	post.set_lit(false)
	watch.keep_lamps_by_the_clock()
	ok(not post.lit, "somebody put it out, and it stays out")
	Campaign.set_clock(12)
	watch.keep_lamps_by_the_clock()
	ok(not post.lit, "and it is out by day")
	Campaign.set_clock(23)
	watch.keep_lamps_by_the_clock()
	ok(post.lit, "and the next night it is lit again")
	close_map(m)
	await settle()
	Campaign.reset()
	log_line("")


## The weathers that were not in at first (the designer, 2026-11-07: "Add the not included weathers as well").
func the_other_weathers():
	log_line("======== the other weathers ========")
	var want := {"snow": ["snow", 720], "sleet": ["hail", 720], "thunderstorm": ["lightning", 720], "wind": ["wind", 720], "sandstorm": ["sand", 720],
		"blizzard": ["snow", 720], "heat": ["shimmer", 780], "ash": ["ash", 720], "aurora": ["aurora", 1380], "rainbow": ["rainbow", 960], "eclipse": ["eclipse", 720]}
	for kind in want:
		ok(Light.WEATHERS.has(kind), "%s is a weather" % kind)
		var sky: Dictionary = Light.sky(Light.Ambient.OUTDOORS, want[kind][1], 5, kind)
		ok(float(sky.get(want[kind][0], 0.0)) > 0.3, "  with its %s" % want[kind][0], "%.2f" % float(sky.get(want[kind][0], 0.0)))
	ok(Light.sky(Light.Ambient.OUTDOORS, 720, 5, "aurora").aurora < 0.05, "an aurora only by night")
	ok(Light.sky(Light.Ambient.OUTDOORS, 1380, 5, "rainbow").rainbow < 0.05, "a rainbow only by day")
	ok(Light.sky(Light.Ambient.OUTDOORS, 720, 5, "eclipse").amount < Light.sky(Light.Ambient.OUTDOORS, 720, 5, "clear").amount * 0.6, "an eclipse darkens noon")
	ok(Light.sky(Light.Ambient.OUTDOORS, 720, 5, "blizzard").wind > 0.5 and Light.sky(Light.Ambient.OUTDOORS, 720, 5, "blizzard").sound == &"wind_blowing", "a blizzard blows, and is heard")
	ok(Light.sky(Light.Ambient.UNDERGROUND, 720, 5, "snow").snow == 0.0, "nothing falls underground")
	for extra in Light.SKY_EXTRAS:
		ok(Light.sky(Light.Ambient.INTERIOR, 720).has(extra) and Light.sky(Light.Ambient.OUTDOORS, 720).has(extra), "every sky says how much %s" % extra)
	# The seasons: what a day may have goes by the time of year.
	var year := 360
	ok(Light.season_of(1, year) == 0 and Light.season_of(91, year) == 1 and Light.season_of(181, year) == 2 and Light.season_of(271, year) == 3, "spring, summer, autumn, winter")
	var seen := {}
	for day in range(2, 721):
		var kind: String = Light.weather_of(day, year)
		var season: int = Light.season_of(day, year)
		seen["%s %d" % [kind, season]] = true
		if Light.SCENE_WEATHERS.has(kind):
			seen["scene"] = true
	ok(not seen.has("scene"), "storms, sandstorms, blizzards, ash and eclipses come only when a scene says")
	ok(seen.has("snow 3") and not seen.has("snow 1"), "snow in winter, never in summer")
	ok(seen.has("heat 1") and not seen.has("heat 3"), "heat in summer, never in winter")
	ok(seen.has("thunderstorm 1"), "summer has its thunderstorms")
	log_line("")


## Wet in the rain, dry out of it (the designer, 2026-11-07: "make them seem slowly getting wet when it rains").
func getting_wet():
	log_line("======== getting wet ========")
	var figure := CombatantSprite.new()
	add_child(figure)
	var was_soaking: float = CombatantSprite.soaking
	var was_under: Callable = CombatantSprite.under_the_sky
	CombatantSprite.soaking = 1.0
	CombatantSprite.under_the_sky = func(_at): return true
	figure._soak(5.0)
	ok(figure.wetness > 0.1 and figure.wetness < 0.5, "five seconds of rain: getting wet", "%.2f" % figure.wetness)
	figure._soak(60.0)
	ok(is_equal_approx(figure.wetness, 1.0), "a minute: soaked", "%.2f" % figure.wetness)
	CombatantSprite.under_the_sky = func(_at): return false
	figure._soak(5.0)
	ok(figure.wetness > 0.9, "under a roof, drying, slowly", "%.2f" % figure.wetness)
	figure._soak(200.0)
	ok(figure.wetness == 0.0, "and dry in the end")
	CombatantSprite.soaking = was_soaking
	CombatantSprite.under_the_sky = was_under
	figure.queue_free()
	# Somebody's shine mask is a drawing of their own, beside each frame.
	ok(CombatantSprite.shine_path_for("res://art/characters/alithia/idle/alithia_idle_color0003.png") == "res://art/characters/alithia/idle/alithia_idle_shine0003.png",
		"a shine mask sits beside the frame, _shine for _color")
	ok(CombatantSprite.shine_path_for("res://art/things/barrel.png") == "res://art/things/barrel_shine.png", "or _shine on the end")
	ok(GameSettings.figure_shapes(), "figures are lit as shapes unless Options say not")
	log_line("")


func how_it_looks():
	log_line("======== how it looks ========")
	LightView.plays_headless = true
	Campaign.reset()
	var m := await open_map()
	var view: LightView = m.scene.light_view
	ok(view != null, "a view of the light")
	if view == null:
		LightView.plays_headless = false
		close_map(m)
		await settle()
		return
	# A change eases in (the designer, 2026-11-07: "Some weather and lighting changes are a bit too abrupt").
	Campaign.set_clock(12)
	await settle()
	Campaign.set_weather("storm")
	await settle()
	# Steps splash, louder, where it rains (the designer, 2026-11-07).
	Footsteps._last_at = -100000
	Footsteps.step(m.party.leader.global_position)
	ok(not Footsteps.last.wet and is_equal_approx(Footsteps.last.db, Footsteps.DRY_DB), "a step before the rain has come on is dry", "%s" % [Footsteps.last])
	ok(view._sky_wanted.rain > 0.9 and view._sky_shown.rain < 0.5, "a storm comes on over a few seconds, not at once",
		"%.2f of %.2f" % [view._sky_shown.rain, view._sky_wanted.rain])
	Engine.time_scale = 10.0
	await until(func(): return not view._sky_easing, 40.0)
	Engine.time_scale = 1.0
	ok(is_equal_approx(view._sky_shown.rain, view._sky_wanted.rain), "and gets there", "%.2f" % view._sky_shown.rain)
	var under: bool = view._under_the_sky(m.party.leader.global_position)
	Footsteps._last_at = -100000
	Footsteps.step(m.party.leader.global_position)
	ok(not under or (Footsteps.last.wet and Footsteps.last.db > Footsteps.DRY_DB), "in the rain, under the sky, a step splashes, louder", "%s, under the sky %s" % [Footsteps.last, under])
	ok(CombatantSprite.soaking > 0.9, "and the rain soaks whoever is out in it")
	# The rest at once, to look at each.
	LightView.sky_ease_seconds = 0.0
	Campaign.set_weather("overcast")
	await settle()
	ok(view._clouds.visible, "clouds pass over an overcast day")
	ok(view._sun < 1.0 and view.visible, "and it looks a little less lit, with the rule unchanged", "%.2f" % view._sun)
	ok(m.scene.light.base == Light.Level.BRIGHT, "still Bright")
	Campaign.set_weather("storm")
	await settle()
	ok(view._rain != null and view._rain.emitting, "rain falls in a storm")
	# Only under the open sky (the designer, 2026-11-12: "outdoor effects like rain shouldn't appear indoor").
	await settle()
	ok(view._air_material != null and view._rain.material == view._air_material, "what falls is drawn through the sky's mask")
	if view._air_material != null:
		var mask_size: Vector2 = view._air_material.get_shader_parameter("mask_size")
		ok(mask_size.x > 0.0 and view._air_material.get_shader_parameter("screen_extent") != Vector2.ZERO,
			"laid over the map, and told where on it the screen is", "%s" % mask_size)
	var region: Rect2i = view._region
	var agrees: bool = view._sky_mask_bytes.size() == region.size.x * region.size.y
	if agrees:
		for y in region.size.y:
			for x in region.size.x:
				if (view._sky_mask_bytes[y * region.size.x + x] > 127) != view.light.under_the_sky(region.position + Vector2i(x, y)):
					agrees = false
	ok(agrees, "open where the sky is and shut under a roof, tile by tile", "%d bytes for %s" % [view._sky_mask_bytes.size(), region.size])
	ok(view._clouds.material.get_shader_parameter("sky_mask") != null and view._mist.material.get_shader_parameter("sky_mask") != null,
		"and the clouds' shadows and the mist read it too")
	ok(is_equal_approx(float(view._flash.material.get_shader_parameter("indoors")), LightView.FLASH_INDOORS), "a flash of lightning shows a little indoors, as at a window")
	ok(view._day_sound_is == &"rain_falling", "and is heard, if there is a sound in the slot")
	# Clear for the days that follow too: a day of its own may have wind, which has no birds or dawn mist.
	Campaign.set_weather("clear", 3)
	await settle()
	ok(not view._rain.emitting, "and stops")
	ok(view._life_is == "dust", "dust hangs at noon", view._life_is)
	Campaign.set_clock(18, 30)
	await settle()
	ok(view._life_is == "insects", "insects at dusk", view._life_is)
	ok(view._sun < 0.8, "and it has got darker with the sun", "%.2f" % view._sun)
	ok(view._opening_colour.r > view._opening_colour.b, "what comes in at a window is gold", "%s" % view._opening_colour)
	Campaign.set_clock(6, 30)
	await settle()
	ok(view._mist.visible, "mist lies low at dawn")
	ok(view._day_sound_is == &"birds_at_dawn", "with the birds' slot")
	Campaign.set_clock(23)
	await settle()
	ok(view._day_sound_is == &"crickets_at_night", "and crickets' at night")
	# A place's own sky.
	Campaign.map_sky_tint = Color(0.7, 1.0, 0.7)
	Campaign.set_clock(12)
	await settle()
	ok(Campaign.sky_now().tone.g > Campaign.sky_now().tone.r, "a place's own sky colours the day")
	LightView.sky_ease_seconds = 2.5
	LightView.plays_headless = false
	close_map(m)
	await settle()
	Campaign.reset()
	log_line("")
