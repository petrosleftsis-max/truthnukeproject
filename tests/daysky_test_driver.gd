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
	ok(Campaign.weather_today() == Light.weather_of(Campaign.day_number()), "for today alone", Campaign.weather_today())
	Campaign.set_weather("rain", 3)
	var today: int = Campaign.day_number()
	Campaign.advance_clock(0, 2)
	ok(Campaign.weather_today() == "rain", "or for three days")
	Campaign.advance_clock(0, 1)
	ok(Campaign.weather_today() == Light.weather_of(today + 3), "and no longer", Campaign.weather_today())
	Campaign.set_weather("overcast")
	Campaign.set_weather()
	ok(Campaign.weather_today() == Light.weather_of(Campaign.day_number()), "and it can be handed back to the day")
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
	Campaign.set_clock(12)
	await settle()
	Campaign.set_weather("overcast")
	await settle()
	ok(view._clouds.visible, "clouds pass over an overcast day")
	ok(view._sun < 1.0 and view.visible, "and it looks a little less lit, with the rule unchanged", "%.2f" % view._sun)
	ok(m.scene.light.base == Light.Level.BRIGHT, "still Bright")
	Campaign.set_weather("storm")
	await settle()
	ok(view._rain != null and view._rain.emitting, "rain falls in a storm")
	ok(view._day_sound_is == &"rain_falling", "and is heard, if there is a sound in the slot")
	Campaign.set_weather("clear")
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
	LightView.plays_headless = false
	close_map(m)
	await settle()
	Campaign.reset()
	log_line("")
