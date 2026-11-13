extends "res://StealthHarness.gd"
## More to look at (LightView; the designer, 2026-11-13, proposals 21: "I like all the new suggestions you can do them"): what each
## wants of the sky - leaves and petals on the wind, birds' shadows, the low mist, far lightning, the night's darker edges - and each
## drawn when it should be on the Light stage's yard: its pond, lights mirrored in the wet, glowing after dark, smoke and cloth in the
## wind, a flock going over, a far flash, the sky's pixels showing for a moment.

const STAGE := "res://maps/stealth_stages/stealth_9.tscn"


func suite() -> String:
	return "atmos"


func time_limit() -> float:
	return 180.0


func run_sections():
	what_each_wants()
	await on_the_stage()


## On to the middle of the next `season`, at `hour`:`minute`.
func go_to(season: String, hour: int, minute: int = 0):
	var year := Campaign.days_in_a_year()
	var days := []
	for day in range(Campaign.day_number() + 1, Campaign.day_number() + year * 2):
		if Light.SEASON_NAMES[Light.season_of(day, year)] == season:
			days.append(day)
		elif not days.is_empty():
			break
	Campaign.calendar_minutes = (int(days[int(days.size() / 2.0)]) - 1) * Light.MINUTES_A_DAY
	Campaign.set_clock(hour, minute)


func what_each_wants():
	log_line("======== what each wants of the sky ========")
	Campaign.reset()
	var view := LightView.new()
	var day := {"amount": 1.0, "clouds": 0.0, "wind": 0.0}
	var night := {"amount": 0.46, "clouds": 0.0, "wind": 0.0}
	# Leaves and petals on the wind.
	go_to("autumn", 12)
	var autumn: Dictionary = view._leaves_wanted({"amount": 1.0, "wind": 0.5})
	ok(autumn.what == "leaves" and autumn.amount > 0.6, "autumn: leaves on the wind", "%s" % [autumn])
	ok(view._leaves_wanted({"amount": 1.0, "wind": 0.0}).amount < autumn.amount, "fewer in still air")
	ok(view._leaves_wanted({"amount": -1.0, "wind": 0.5}).what == "", "none where there is no sky")
	ok(view._leaves_wanted({"amount": 1.0, "wind": 0.5, "snow": 0.4}).what == "", "nor in snow")
	go_to("spring", 12)
	ok(view._leaves_wanted({"amount": 1.0, "wind": 0.4}).what == "petals", "spring: blossom")
	go_to("summer", 12)
	ok(view._leaves_wanted({"amount": 1.0, "wind": 0.2}).what == "" and view._leaves_wanted({"amount": 1.0, "wind": 0.8}).what == "green",
		"summer: only a gale tears green ones off")
	go_to("winter", 12)
	ok(view._leaves_wanted({"amount": 1.0, "wind": 0.8}).what == "", "winter: nothing left to blow")
	# Birds' shadows.
	ok(view._birds_wanted(day) > 0.9, "birds' shadows by day under a clear sky", "%.2f" % view._birds_wanted(day))
	ok(view._birds_wanted({"amount": 1.0, "clouds": 0.8}) < 0.5 and view._birds_wanted({"amount": 1.0, "clouds": 0.8}) > 0.0, "fainter under cloud")
	ok(view._birds_wanted({"amount": 1.0, "rain": 0.6}) == 0.0 and view._birds_wanted({"amount": 1.0, "mist": 0.8}) == 0.0, "none in rain or fog")
	Campaign.set_clock(23)
	ok(view._birds_wanted(night) == 0.0, "none at night")
	# The low mist.
	ok(view._ground_mist_wanted(night) > 0.5, "low mist lies at night", "%.2f" % view._ground_mist_wanted(night))
	ok(view._ground_mist_wanted({"amount": 0.46, "wind": 0.8}) < 0.05, "but not in a wind")
	ok(view._ground_mist_wanted({"amount": 0.46, "sand": 0.5}) == 0.0 and view._ground_mist_wanted({"amount": -1.0}) == 0.0, "nor in sand, nor under no sky")
	Campaign.set_clock(7, 30)
	var morning := view._ground_mist_wanted(day)
	Campaign.set_clock(9, 0)
	var later := view._ground_mist_wanted(day)
	ok(morning > later and later > 0.0, "thinning as the sun climbs", "%.2f at half past seven, %.2f at nine" % [morning, later])
	Campaign.set_clock(12)
	ok(view._ground_mist_wanted(day) == 0.0, "and gone by noon")
	# Far lightning.
	go_to("summer", 23)
	Campaign.weather_fixed = {"name": "storm", "from_day": Campaign.day_number() + 1, "until_day": Campaign.day_number() + 1}
	ok(view._far_lightning_wanted(night) == 1.0, "far lightning on a summer night before a storm")
	ok(view._far_lightning_wanted({"amount": 0.46, "lightning": 0.8}) == 0.0, "not in the storm itself")
	ok(view._far_lightning_wanted({"amount": 0.46, "rain": 0.5}) == 0.0, "nor in rain")
	Campaign.set_clock(12)
	ok(view._far_lightning_wanted(day) == 0.0, "nor by day")
	Campaign.weather_fixed = {}
	go_to("winter", 23)
	Campaign.weather_fixed = {"name": "storm", "from_day": Campaign.day_number() + 1, "until_day": Campaign.day_number() + 1}
	ok(view._far_lightning_wanted(night) == 0.0, "nor in winter")
	Campaign.weather_fixed = {}
	# The night's darker edges.
	ok(view._night_share(day) == 0.0 and view._night_share(night) == 1.0, "the view's edges darker: not by day, fully at night")
	var dusk := view._night_share({"amount": 0.62})
	ok(dusk > 0.2 and dusk < 0.8, "some at dusk", "%.2f" % dusk)
	view.free()
	Campaign.reset()
	log_line("")


func on_the_stage():
	log_line("======== on the Light stage's yard ========")
	LightView.plays_headless = true
	LightView.sky_ease_seconds = 0.0
	Campaign.reset()
	go_to("autumn", 12)
	Campaign.current_map = STAGE
	var scene: ExplorationScene = load("res://scenes/exploration.tscn").instantiate()
	get_tree().root.add_child(scene)
	await settle(4)
	scene.end_blocking_interaction()
	var view: LightView = scene.light_view
	ok(view != null, "a view of the light")
	if view == null:
		LightView.plays_headless = false
		LightView.sky_ease_seconds = 2.5
		scene.queue_free()
		await settle()
		return
	var tile_map: TileMap = scene._tile_map
	# Water that moves.
	ok(view._water_tiles.size() == 8 and view._water.visible, "the pond is water: eight tiles of it, drawn", "%d tiles" % view._water_tiles.size())
	ok(view._water.material.get_shader_parameter("water") != null, "and its tiles told to the water's shader")
	Campaign.set_weather("clear", 3)
	await settle()
	var noon_glint: float = view._water.material.get_shader_parameter("glint")
	ok(noon_glint > 0.5, "the sun glints on it at noon", "%.2f" % noon_glint)
	# Cloth and smoke in the wind.
	var banner: WindBanner = scene.find_children("*", "WindBanner", true, false)[0]
	ok(banner._streams(Vector2.ZERO) == Vector2.DOWN, "a banner hangs slack in still air")
	ok(banner._streams(Vector2(0.8, 0.0)).x > 0.6, "and streams out the way a wind blows")
	var chimney: ChimneySmoke = scene.find_children("*", "ChimneySmoke", true, false)[0]
	ok(chimney._smoke != null and chimney._smoke.emitting, "the hall's chimney smokes")
	var flames := view._lights.filter(func(entry): return entry.get("smoke") != null)
	ok(not flames.is_empty(), "and so does a flame out under the sky", "%d of %d lights" % [flames.size(), view._lights.size()])
	# Leaves on the wind.
	Campaign.set_weather("wind", 3)
	await settle()
	ok(view._leaves != null and view._leaves.emitting and view._leaves_are == "leaves", "autumn in a wind: leaves blowing across", view._leaves_are)
	var wind: Vector2 = CombatantSprite.wind_blows
	ok(wind.length() > 0.1 and chimney._smoke.gravity.dot(Vector2(wind.x, wind.y * 0.5)) > 0.0, "the chimney's smoke leans the way it blows",
		"wind %s, smoke %s" % [wind, chimney._smoke.gravity])
	# Birds' shadows.
	Campaign.set_weather("clear", 3)
	await settle()
	ok(view._birds_wanted(view._sky_shown) > 0.5, "a clear noon: birds may go over")
	view.birds_now(1.0)
	var flock: Dictionary = view._birds.flocks.back() if not view._birds.flocks.is_empty() else {}
	ok(not flock.is_empty() and flock.birds.size() >= 3 and flock.birds.size() <= 9, "a flock's shadows", "%d birds" % (flock.birds.size() if not flock.is_empty() else 0))
	var was: Vector2 = flock.get("at", Vector2.ZERO)
	await settle(3)
	ok(not flock.is_empty() and flock.at != was, "going over")
	# After dark: lights glow, the view's edges darken, the low mist lies by the pond.
	Campaign.set_clock(23)
	await settle(3)
	var glowing := view._lights.filter(func(entry): return entry.get("bloom") != null and entry.bloom.modulate.a > 0.05)
	ok(not glowing.is_empty(), "lights glow after dark", "%d of %d" % [glowing.size(), view._lights.size()])
	# A little less under a bright moon (_night_share goes by how lit the night is).
	ok(float(view._grade.material.get_shader_parameter("vignette")) > 0.15 and view._grade.visible, "and the view's edges are darker",
		"%.2f, the sun's amount %.2f" % [float(view._grade.material.get_shader_parameter("vignette")), float(view._sky_shown.get("amount", -1.0))])
	ok(view._ground_mist.visible, "low mist lies in the yard at night")
	var lies: Image = view._ground_mist.material.get_shader_parameter("lies").get_image()
	var at := func(tile: Vector2i) -> float:
		return lies.get_pixelv(tile - view._region.position).r
	ok(at.call(Vector2i(12, 14)) > at.call(Vector2i(9, 13)), "thicker by the pond than out in the yard",
		"%.2f and %.2f" % [at.call(Vector2i(12, 14)), at.call(Vector2i(9, 13))])
	var dark_spot: Vector2 = tile_map.to_global(tile_map.map_to_local(Vector2i(9, 12)))
	ok(LightView.lit_colour_at(dark_spot).r < 0.97, "a banner or smoke out there darkens with the night", "%s" % LightView.lit_colour_at(dark_spot))
	# Lights mirrored: in the pond always, in the wet after rain.
	ok(view._reflections.visible, "lights are mirrored in the pond")
	Campaign.set_weather("rain", 3)
	await settle(3)
	ok(float(view._reflections.material.get_shader_parameter("wet")) > 0.1 and float(view._reflections.material.get_shader_parameter("raining")) > 0.0,
		"and in the wet, in the rain", "wet %.2f" % float(view._reflections.material.get_shader_parameter("wet")))
	# A far flash, and the sky's pixels for a moment.
	view.far_lightning_now(1.0)
	await wait(0.08)
	ok(view._far_flash.visible and float(view._far_flash.material.get_shader_parameter("flash")) > 0.0, "a far flash")
	await wait(1.0)
	ok(not view._far_flash.visible, "and it is gone")
	view.sky_pixels_now()
	await wait(0.05)
	ok(view._pixels == 1.0 and float(view._shade.material.get_shader_parameter("pixels")) == 1.0, "the sky's pixels show for a moment")
	await wait(1.4)
	ok(view._pixels == 0.0 and float(view._shade.material.get_shader_parameter("pixels")) == 0.0, "and are gone again")
	# By day again: no glow to speak of, no darker edges.
	Campaign.set_weather("clear", 3)
	Campaign.set_clock(12)
	await settle(3)
	ok(float(view._grade.material.get_shader_parameter("vignette")) == 0.0, "by day the view's edges are as they were")
	var still_glowing := view._lights.filter(func(entry): return entry.get("bloom") != null and not entry.source.get("opening", false) \
		and view.light.under_the_sky(entry.source.tile) and entry.bloom.modulate.a > 0.05)
	ok(still_glowing.is_empty(), "and a light out in the sun has no glow", "%d glowing" % still_glowing.size())
	ok(not view._ground_mist.visible, "and the low mist has gone")
	LightView.plays_headless = false
	LightView.sky_ease_seconds = 2.5
	for node in get_tree().root.find_children("*", "", true, false):
		if node.scene_file_path == BALLOON:
			node.queue_free()
	scene.queue_free()
	MenuPause.clear(get_tree())
	await settle()
	Campaign.reset()
	log_line("")
