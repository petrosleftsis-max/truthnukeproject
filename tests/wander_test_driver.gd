extends Node
## Wandering, and some weirdness: the proposals of 2026-11-19 as built (docs/wander_built.md). Played on The Wanderer's Quarter and
## The Dream (tools/build_stealth_stages.gd stage_wander and stage_dream): the map's memory, pins and arrow, secrets, marks only the
## dark or a lamp shows, climbing, a barred door, a pond and a flood, hours, a foe on the roam, rest spots, sound by place, things that
## talk, struck words, lost clues, a gate's voice, a forgotten move, Lethe, the shifting archive, the dream and the mementos.

var LOG_PATH := HarnessLog.path_for("wander")
const WANDER := "res://maps/stealth_stages/wander.tscn"
const DREAM := "res://maps/stealth_stages/dream.tscn"
const LIGHT_STAGE := "res://maps/stealth_stages/stealth_9.tscn"

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
	get_tree().create_timer(280.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


func settle(frames: int = 3):
	for i in frames:
		await get_tree().process_frame


func wait(seconds: float):
	var left := seconds
	while left > 0.0:
		await get_tree().process_frame
		left -= get_process_delta_time()


func open_map(map: String, keep := false) -> ExplorationScene:
	if not keep:
		Campaign.reset()
		Campaign.set_clock(12)
		Campaign.set_weather("clear", 5)
	Campaign.current_map = map
	var scene: ExplorationScene = load("res://scenes/exploration.tscn").instantiate()
	get_tree().root.add_child(scene)
	await settle(8)
	scene.end_blocking_interaction()
	return scene


func close(scene: Node):
	MenuPause.clear(get_tree())
	scene.queue_free()
	await settle(3)


func at(scene: ExplorationScene, tile: Vector2i) -> Vector2:
	return scene._tile_map.to_global(scene._tile_map.map_to_local(tile))


func node(scene: ExplorationScene, called: String) -> Node:
	return scene.get_node("Map").find_child(called, true, false)


func run_test():
	log_line("Wandering, and some weirdness (the proposals of 2026-11-19)")
	LightView.plays_headless = true
	var scene := await open_map(WANDER)
	await the_map(scene)
	await the_secrets(scene)
	await the_light_marks(scene)
	await climbing(scene)
	await the_water(scene)
	await the_hours(scene)
	await the_roamer(scene)
	await resting(scene)
	await sound_by_place(scene)
	await talking_things(scene)
	await the_archive(scene)
	await mementos(scene)
	await close(scene)
	await lethe()
	await words_and_gates()
	await the_dream()
	await a_move_forgotten()
	await guard_shifts()
	LightView.plays_headless = false
	log_line("")
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)


func the_map(scene: ExplorationScene):
	log_line("======== a map you can open, the way at the screen's edge ========")
	var memory := scene.memory
	ok(memory != null and memory.screen != null and memory.arrow != null, "every map has its memory, its screen and its arrow")
	ok(memory.has_seen(memory.leader_tile()) and not memory.has_seen(Vector2i(33, 21)), "the ground round the party is seen, far off not yet")
	var before := memory.share_seen()
	scene.party.teleport(at(scene, Vector2i(25, 11)))
	await settle(3)
	ok(memory.has_seen(Vector2i(25, 11)) and memory.share_seen() > before, "walking on fills it in", "%.2f -> %.2f" % [before, memory.share_seen()])
	ok(Campaign.exploration.has(scene.map_path()), "and the run keeps it")
	scene.party.teleport(at(scene, Vector2i(6, 6)))
	await settle(3)
	memory.toggle_pin(Vector2i(33, 21))
	ok(memory.pins().size() == 1 and memory.way_target().distance_to(at(scene, Vector2i(33, 21))) < 1.0, "a pin, and the way points at it")
	await settle(3)
	ok(memory.arrow.shown_at.is_finite(), "off the screen, an arrow at the edge points the way", "%s" % memory.arrow.shown_at)
	memory.toggle_pin(Vector2i(33, 21))
	ok(memory.pins().is_empty(), "clicked again, the pin comes up")
	for i in 4:
		memory.toggle_pin(Vector2i(2 + i * 4, 2))
	ok(memory.pins().size() == MapMemory.MOST_PINS, "no more than %d pins" % MapMemory.MOST_PINS, "%d" % memory.pins().size())
	for pin in memory.pins().duplicate():
		memory.toggle_pin(pin)
	memory.toggle_pin(Vector2i(33, 21))
	memory.screen.open()
	ok(memory.screen.is_open() and MenuPause.is_held(), "the map screen opens, holding the game")
	await settle(2)
	ok(not memory.arrow.shown_at.is_finite(), "and the arrow at the edge is put away under it", "%s" % memory.arrow.shown_at)
	memory.screen.close()
	ok(not memory.screen.is_open() and not MenuPause.is_held(), "and closes")
	memory.toggle_pin(Vector2i(33, 21))
	ok(InputMap.has_action(&"map"), "it has its own key")


func the_secrets(scene: ExplorationScene):
	log_line("======== secrets worth finding ========")
	var memory := scene.memory
	var all := memory.secrets()
	ok(all.size() >= 6, "the map's secrets are counted", "%d" % all.size())
	var found_before := memory.secrets_found()
	var stash: Stash = node(scene, "StashByTheWell")
	stash.use(scene)
	ok(Campaign.party_carries("shiny_button") and stash.is_found() and not stash.is_available(), "a stash searched: in the bags, found, and empty after")
	var note: WallNote = node(scene, "YardNote")
	note.use(scene)
	ok(note.is_found(), "a note read is a secret found")
	ok(memory.secrets_found() == found_before + 2, "the count goes up", "%d" % memory.secrets_found())
	var cracked: BreakableWall = node(scene, "CrackedWall")
	ok(cracked.light_through and not cracked.is_found(), "a cracked wall lets light through, and is found once broken")


func the_light_marks(scene: ExplorationScene):
	log_line("======== light that finds things ========")
	var mark: HiddenMark = node(scene, "MarkInTheDark")
	var behind: Stash = node(scene, "StashInTheDark")
	ok(behind.kept_hidden and not behind.visible, "what a mark uncovers is out of sight and use till then")
	ok(not mark.shows_now(), "far off, it does not show")
	# Only through the eyes of whoever leads (the designer, 2026-11-19: it showed to everyone, Cyrus being in the party).
	Campaign.set_leader("enfina")
	scene.party.teleport(at(scene, Vector2i(22, 5)))
	await settle(3)
	var level: int = scene.light.level_at(Vector2i(22, 4))
	ok(level == Light.Level.DARK, "the room behind the cracked wall is dark", Light.LEVEL_NAMES[level])
	ok(Campaign.lead_here() == "enfina" and not Campaign.sees_in_darkness("enfina") and not mark.shows_now() and not mark.is_found(),
		"led by Enfina, who cannot see in the dark, the mark does not show")
	Campaign.set_leader("cyrus")
	await settle(3)
	ok(Campaign.sees_in_darkness("cyrus"), "Cyrus sees in the dark")
	ok(mark.shows_now(), "led by Cyrus, through his eyes the dark's mark shows")
	await settle(3)
	ok(mark.is_found() and not behind.kept_hidden and behind.visible, "seen, it is found and uncovers the stash")
	scene.party.teleport(at(scene, Vector2i(6, 6)))
	await settle(2)


func climbing(scene: ExplorationScene):
	log_line("======== climbing and shortcuts ========")
	ok(scene.climbable(Vector2i(9, 2)) and scene.is_walkable(at(scene, Vector2i(9, 2))), "raised ground is stood on")
	# Up only by a ladder, or by Cyrus once he has Cat Burglar, and he goes up alone (the designer, 2026-11-19).
	var level := Campaign.party_level
	Campaign.party_level = 1
	ok(Campaign.leader() == "cyrus" and not Campaign.climbs_anywhere("cyrus"), "Cyrus leads, without Cat Burglar yet", Campaign.leader())
	ok(scene.may_cross(at(scene, Vector2i(10, 4)), at(scene, Vector2i(10, 3))), "anybody climbs by a ladder")
	ok(not scene.may_cross(at(scene, Vector2i(9, 4)), at(scene, Vector2i(9, 3))), "and nowhere else from below")
	ok(not scene.may_cross(at(scene, Vector2i(7, 2)), at(scene, Vector2i(8, 2))), "nor from the side")
	ok(scene.may_cross(at(scene, Vector2i(9, 3)), at(scene, Vector2i(9, 4))), "dropped from anywhere")
	ok(scene.staying.is_empty(), "and nobody is left behind by any of it")
	Campaign.party_level = 24
	ok(Campaign.climbs_anywhere("cyrus") and not Campaign.climbs_anywhere("enfina"), "from 24 Cyrus climbs anywhere, and only he")
	scene.party.teleport(at(scene, Vector2i(7, 5)))
	await settle(2)
	ok(not scene.may_cross(at(scene, Vector2i(9, 4)), at(scene, Vector2i(9, 3))) and scene.staying.is_empty(),
		"Cyrus does not go up at the first touch, so brushing an edge splits nobody off")
	var up := false
	for i in 40:
		up = scene.may_cross(at(scene, Vector2i(9, 4)), at(scene, Vector2i(9, 3)))
		if up:
			break
		await wait(0.05)
	ok(up, "pushed against it a moment, he climbs where no ladder stands")
	var others := Campaign.party_order.size() - 1
	ok(scene.staying.size() == others and scene.party.followers.is_empty(), "and goes up alone, the rest staying below",
		"%s" % [scene.staying.keys()])
	scene.party.teleport(at(scene, Vector2i(9, 2)))
	await settle(2)
	ok(scene.leads_alone() and scene.staying.size() == others, "up there, nobody follows him")
	ok(not scene.steps_between(Vector2i(9, 4), Vector2i(9, 3)) and scene.steps_between(Vector2i(9, 3), Vector2i(9, 4))
		and scene.steps_between(Vector2i(10, 4), Vector2i(10, 3)), "the rest step up only by the ladder, and down anywhere")
	var route := scene.walking_route(Vector2i(7, 5), Vector2i(9, 2))
	ok(not route.is_empty() and route.has(Vector2i(10, 3)) and route.back() == Vector2i(9, 2), "their way to him goes up the ladder",
		"%s" % [route])
	var far := Vector2i(33, 21)
	ok(not scene.memory.has_seen(far) and scene.walking_route(Vector2i(7, 5), far).is_empty(), "and no way crosses ground nobody has seen")
	var ladders: Dictionary = scene._ladder_tiles.duplicate()
	scene._ladder_tiles.clear()
	scene._call_checked_ms = -1000000
	ok(not scene.can_call_party(), "with no ladder up, nobody can be called to him")
	scene._ladder_tiles = ladders
	scene._call_checked_ms = -1000000
	ok(scene.can_call_party(), "with it, they can")
	# Alone, Stay Here calls them (a pad's only way); they walk over and fall in behind.
	ok(scene.stay_here() and scene.coming.size() == others, "Stay Here, with nobody else in the line, calls them over")
	for i in 100:
		if scene.staying.is_empty():
			break
		await wait(0.1)
	ok(scene.staying.is_empty() and scene.coming.is_empty() and scene.party.followers.size() == others,
		"they climb the ladder to him and fall in behind", "%s" % [scene.staying.keys()])
	# A trap the party knows of is walked round; a hidden one is walked over, and goes off as it would for anybody.
	var trap := MagicTrap.new()
	trap.name = "WanderTestTrap"
	scene.get_node("Map").add_child(trap)
	trap.global_position = at(scene, Vector2i(6, 6))
	scene._traps.append(trap)
	var past := scene.walking_route(Vector2i(4, 6), Vector2i(8, 6))
	ok(not past.is_empty() and not past.has(Vector2i(6, 6)), "a way goes round a trap the party knows of", "%s" % [past])
	trap.concealed = true
	past = scene.walking_route(Vector2i(4, 6), Vector2i(8, 6))
	ok(past.has(Vector2i(6, 6)), "and over a hidden one, as if it were not there", "%s" % [past])
	scene.party.teleport(at(scene, Vector2i(4, 6)))
	await settle(2)
	scene._climbs_alone(scene.party)
	scene.party.teleport(at(scene, Vector2i(8, 6)))
	await settle(2)
	scene._call_checked_ms = -1000000
	ok(scene.call_party() and scene.coming.size() == others, "called from where they wait, they come")
	for i in 60:
		if not trap.armed:
			break
		await wait(0.1)
	ok(not trap.armed, "and walking over the hidden trap, they set it off")
	for i in 150:
		if scene.springing == null and scene.staying.is_empty():
			break
		await wait(0.1)
	ok(scene.staying.is_empty(), "then fall in behind all the same")
	scene._traps.erase(trap)
	trap.queue_free()
	Campaign.party_level = level
	var barred: StealthDoor = node(scene, "ArchiveDoor")
	scene.party.teleport(at(scene, Vector2i(19, 15)))
	await settle(2)
	barred.interact(scene)
	ok(not barred.is_open, "a door barred on this side stays shut")
	scene.party.teleport(at(scene, Vector2i(21, 15)))
	await settle(2)
	barred.interact(scene)
	ok(barred.is_open and Campaign.flag(barred.unbarred_flag()), "from the far side it opens, unbarred")
	barred.interact(scene)
	scene.party.teleport(at(scene, Vector2i(19, 15)))
	await settle(2)
	barred.interact(scene)
	ok(barred.is_open, "and from then on from both")
	scene.party.teleport(at(scene, Vector2i(6, 6)))
	await settle(2)


func the_water(scene: ExplorationScene):
	log_line("======== the weather changes the map ========")
	var pond: WaterPatch = node(scene, "Pond")
	await wait(1.2)
	ok(not scene.is_walkable(at(scene, Vector2i(3, 9))), "a deep pond is not waded")
	pond.set_frozen(true)
	ok(scene.is_walkable(at(scene, Vector2i(3, 9))), "frozen, it is walked on")
	pond.set_frozen(false)
	var flood: FloodPatch = node(scene, "LaneFlood")
	flood.set_flooded(true)
	ok(not scene.is_walkable(at(scene, Vector2i(7, 15))), "the lane flooded, nobody walks through")
	flood.set_flooded(false)
	ok(scene.is_walkable(at(scene, Vector2i(7, 15))), "drained, it is ground again")


func the_hours(scene: ExplorationScene):
	log_line("======== the hours ========")
	var shop: Node2D = node(scene, "Shopkeeper")
	var townsman: Node2D = node(scene, "Townsman")
	var day_place := townsman.global_position
	ok(shop.visible and not shop.kept_hidden, "by day the shop is open")
	Campaign.set_clock(23)
	await wait(1.3)
	ok(not shop.visible and shop.kept_hidden, "at night it is shut", Light.TIME_NAMES[Campaign.time_of_day])
	ok(townsman.global_position.distance_to(at(scene, Vector2i(4, 20))) < 2.0, "and the townsman is at home")
	Campaign.set_clock(12)
	await wait(1.3)
	ok(shop.visible and townsman.global_position.distance_to(day_place) < 2.0, "the day back, so are they")


func the_roamer(scene: ExplorationScene):
	log_line("======== foes that roam ========")
	var roamer: Roamer = node(scene, "FieldRoamer")
	ok(roamer != null and roamer.visible and roamer.mood == Roamer.Mood.WANDERING, "a foe walks its ground")
	var home := roamer.global_position
	await wait(3.5)
	ok(roamer.global_position.distance_to(home) > 1.0, "wandering about", "%.0f" % roamer.global_position.distance_to(home))
	roamer.hold_still(1.0)
	var held_at := roamer.global_position
	await wait(0.5)
	ok(roamer.global_position.distance_to(held_at) < 0.5, "held still, it does not move")
	await wait(0.6)
	roamer.global_position = at(scene, Vector2i(30, 6))
	roamer._aim = roamer.global_position
	scene.party.teleport(at(scene, Vector2i(27, 6)))
	roamer.meets_within = 0.0
	await wait(0.5)
	ok(roamer.chases >= 1 and roamer.mood == Roamer.Mood.CHASING, "it sees the party and comes for them")
	scene.party.teleport(at(scene, Vector2i(6, 6)))
	await wait(roamer.gives_up_seconds + 0.5)
	ok(roamer.mood != Roamer.Mood.CHASING, "out of sight a while, it gives up")


func resting(scene: ExplorationScene):
	log_line("======== rest and travel ========")
	var fire: RestSpot = node(scene, "YardFire")
	await settle(3)
	ok(fire.is_known(), "a rest spot is found by coming near it")
	var bench: RestSpot = node(scene, "ArchiveBench")
	ok(not bench.is_known(), "one far off is not")
	scene.party.teleport(bench.global_position + Vector2(0, Grid.tiles(1.0)))
	await settle(3)
	ok(bench.is_known(), "come near, it is")
	ok(fire.places_to_go().has(bench.spot_id()), "and the fire offers travel to it")
	var hour := Campaign.minute_of_day()
	fire._scene_used = scene
	ok(fire.rest_here(), "a rest spot gives a short rest")
	ok(fire.rested == 1 and Campaign.minute_of_day() != hour, "and an hour passes")
	# Once a day at each spot, and no preparing of spells, which only a long rest brings (the designer, 2026-11-19).
	ok(not fire.rest_here() and fire.rested == 1 and fire.rested_today(), "but only once a day there")
	fire._open_menu()
	var labels: Array = []
	var rest_button: Button = null
	for button in fire._menu.find_children("*", "Button", true, false):
		labels.append(button.text)
		if button.text == "Rested here today":
			rest_button = button
	ok(rest_button != null and rest_button.disabled, "its menu says it has been rested at today", "%s" % [labels])
	ok(not labels.has("Prepare spells"), "and offers no preparing of spells", "%s" % [labels])
	fire._close_menu()
	# The next day it rests again; with nothing to choose, resting from the menu shuts it.
	Campaign.advance_clock(0.0, 1)
	ok(not fire.rested_today(), "the next day it can be rested at again")
	fire._open_menu()
	fire._rest_from_menu()
	ok(fire.rested == 2 and not fire.is_menu_open(), "rested from its menu with nothing to choose, the menu shuts")
	# With somebody fallen, the rest's own panel (Resuscitate, Meditate) takes the menu's place, a short rest's on a map: no
	# way to the title screen, and Done shuts it all. The bench, the same day as the fire: each spot gives its own rest.
	var down: String = Campaign.party_order.back()
	var had_state: bool = Campaign.party_state.has(down)
	var old_state: Dictionary = Campaign.party_state.get(down, {}).duplicate(true)
	Campaign.party_state[down] = {"hp": 0, "max_hp": Campaign._full_health(down), "alive": false}
	bench._scene_used = scene
	bench._open_menu()
	bench._rest_from_menu()
	ok(bench.rested == 1, "another spot still gives its rest the same day")
	var panel: RestPanel = null
	for child in bench._menu.get_children() if bench._menu != null else []:
		if child is RestPanel:
			panel = child
	ok(panel != null and panel.on_a_map, "with somebody fallen, resting there puts up the rest's own panel")
	if panel != null:
		ok(panel.find_child("MainMenu", true, false) == null and panel.find_child("FallenHeading", true, false) != null,
			"with the fallen on it and no way to the title screen")
		ok((panel.find_child("Rested", true, false) as Label).text.begins_with("A short rest"), "in a short rest's words")
		var party_line: String = (panel.find_child("Party", true, false) as Label).text
		ok(Campaign.party_order.all(func(key): return party_line.contains(Campaign.display_name_of(key))),
			"naming the whole party, fielded or not", party_line)
		panel.continued.emit()
		await settle(1)
	ok(not bench.is_menu_open(), "and Done shuts it")
	if had_state:
		Campaign.party_state[down] = old_state
	else:
		Campaign.party_state.erase(down)
	scene.party.teleport(at(scene, Vector2i(6, 6)))
	await settle(2)


func sound_by_place(scene: ExplorationScene):
	log_line("======== sound by place ========")
	ok(SoundArea.surface_at(at(scene, Vector2i(6, 6))) == "grass", "the yard is grass underfoot")
	ok(SoundArea.surface_at(at(scene, Vector2i(25, 16))) == "stone", "the archive stone")
	ok(SoundArea.surface_at(at(scene, Vector2i(3, 20))) == "wood", "the house wood")
	await settle(2)
	var yard: SoundArea = node(scene, "Sound1_1")
	ok(yard.party_inside, "the party is in the yard's bed of wind")


func talking_things(scene: ExplorationScene):
	log_line("======== things that talk ========")
	ok(Campaign.fight_review() != "", "the statue has a view of the last fight", Campaign.fight_review())
	var first := Campaign.remembered_line("test_post")
	var second := Campaign.remembered_line("test_post")
	ok(first != second and Campaign.flags.get("visits:test_post", 0) == 2, "the lamp post remembers each visit")
	var statue: TalkingThing = node(scene, "Statue")
	scene.party.teleport(statue.global_position + Vector2(0, Grid.tiles(1.0)))
	statue._quiet = 0.0
	await settle(3)
	ok(statue.remarked >= 1, "passed by, it remarks")
	ok(Campaign.hand_over_item("shiny_button") and not Campaign.party_carries("shiny_button"), "the bin's errand: the button handed over")
	scene.party.teleport(at(scene, Vector2i(6, 6)))
	await settle(2)


func the_archive(scene: ExplorationScene):
	log_line("======== the archive that rearranges ========")
	var room: ShiftingRoom = node(scene, "ShiftingRoom")
	ok(room.layouts().size() == 3, "a shifting room with three layouts")
	ok(room.shifts > 0, "out of the view a while, it has shifted by itself", "%d" % room.shifts)
	# From here on, only as the suite shifts it.
	room._wait = 1.0e9
	while room.layout != 0:
		room.shift(scene)
	var base := room.shifts
	ok(not scene._blocking.has(Vector2i(27, 16)), "as built, the first layout")
	room.shift(scene)
	ok(room.layout == 1 and scene._blocking.has(Vector2i(27, 16)), "shifted, the map takes the next: walls where there were none")
	room.shift(scene)
	room.shift(scene)
	ok(room.layout == 0 and not scene._blocking.has(Vector2i(27, 16)) and room.shifts == base + 3, "and round again", "layout %d, shifts %d, blocked %s, cell %s" % [room.layout, room.shifts, scene._blocking.has(Vector2i(27, 16)), scene._tile_map.get_cell_atlas_coords(0, Vector2i(27, 16))])
	scene.party.teleport(at(scene, Vector2i(31, 21)))
	await settle(2)
	ok(room.is_watched(scene) == room.covers_rect().intersects(scene.get_viewport().get_canvas_transform().affine_inverse() * Rect2(Vector2.ZERO, scene.get_viewport().get_visible_rect().size)), "it knows when it is watched")
	var corridor: LoopingCorridor = node(scene, "LoopingCorridor")
	scene.party.teleport(at(scene, Vector2i(26, 21)))
	await settle(2)
	ok(corridor.loops == 1 and scene.party_position().x > at(scene, Vector2i(29, 21)).x, "past the corridor's end, back at its start", "%d" % corridor.loops)
	Campaign.set_flag("corridor_noticed")
	scene.party.teleport(at(scene, Vector2i(26, 21)))
	await settle(2)
	ok(corridor.loops == 1 and corridor.is_broken(), "the odd note read, it is a corridor again")
	scene.party.teleport(at(scene, Vector2i(6, 6)))
	await settle(2)


func mementos(scene: ExplorationScene):
	log_line("======== things that remember ========")
	ok(OutsideMoves.use_of(ItemDatabase.items.get("childs_shoe")) == OutsideMoves.Use.FIND_THE_WAY, "the child's shoe is a move outside fights")
	ok(ItemDatabase.items.get("stopped_clock").stealth_only(), "mementos stay out of fights")
	var roamer: Roamer = node(scene, "FieldRoamer")
	scene.party.teleport(roamer.global_position + Vector2(Grid.tiles(2.0), 0))
	await settle(2)
	ok(Memento.use(scene, "cyrus", ItemDatabase.items.get("stopped_clock"), OutsideMoves.Use.STOP_TIME) and roamer._held > 0.0, "the stopped clock holds a roamer still")
	var lit: HiddenMark = node(scene, "MarkInTheLight")
	scene.party.teleport(lit.global_position)
	await settle(2)
	ok(Memento.use(scene, "cyrus", ItemDatabase.items.get("lighthouse_lens"), OutsideMoves.Use.LOOK_BACK) and HiddenMark.lens_until > Time.get_ticks_msec(), "the lens looks back a while")
	ok(lit.shows_now(), "and through it a mark shows, whatever the light")
	HiddenMark.lens_until = 0
	scene.memory.toggle_pin(Vector2i(33, 15))
	ok(Memento.use(scene, "cyrus", ItemDatabase.items.get("childs_shoe"), OutsideMoves.Use.FIND_THE_WAY), "the shoe leads the way to a pin")


func lethe():
	log_line("======== Lethe's touch ========")
	Campaign.reset()
	Campaign.set_flag("met_neighbour")
	var scene := await open_map(WANDER, true)
	var neighbour: DialogueInteractable = node(scene, "Neighbour")
	ok(neighbour.has_forgotten() and not Campaign.flag("met_neighbour"), "come back, the neighbour has forgotten the party")
	var label: MapLabel = node(scene, "LabelTheArchive")
	Campaign.flags[label.seen_flag()] = Campaign.day_number() - 2
	ok(label.shown_share() > 0.2 and label.shown_share() < 0.5, "a name on the map wears away with the days", "%.2f" % label.shown_share())
	scene.party.teleport(label.global_position)
	await wait(1.2)
	ok(is_equal_approx(label.shown_share(), 1.0), "come near, it is written back")
	await close(scene)
	var key: String = ClueBook.all().keys()[0]
	Campaign.learn_clue(key)
	Campaign.lose_clue(key)
	ok(not Campaign.clue_in_journal(key), "a clue lost to Lethe is out of the Journal")
	Campaign.find_clue(key)
	ok(Campaign.clue_in_journal(key), "found again, it is back")


func words_and_gates():
	log_line("======== struck-out words, a gate's voice ========")
	Campaign.reset()
	var text := "Paid to [struck=knows_who]the archivist[/struck] in full."
	ok(ClueBook.shown_text(text) == "Paid to ███ █████████ in full.", "struck words are blacked out", ClueBook.shown_text(text))
	Campaign.set_flag("knows_who")
	ok(ClueBook.shown_text(text) == "Paid to the archivist in full.", "until the party learns them")
	GateVoice.speak(null, 2)
	ok(GateVoice.last_said.contains("HERMES") and Campaign.flag("gate_voice:2"), "the first casting through a gate, it speaks", GateVoice.last_said)
	GateVoice.last_said = ""
	GateVoice.speak(null, 2)
	ok(GateVoice.last_said == "", "and only the first")


func the_dream():
	log_line("======== the dream-place ========")
	var scene := await open_map(DREAM)
	ok(node(scene, "DreamPlace") != null and node(scene, "Rehearsal") != null and node(scene, "Wake") != null, "the dream, its rehearsal and the way out")
	var rehearsal: Rehearsal = node(scene, "Rehearsal")
	ok(not rehearsal.is_unlocked(), "the rehearsal waits on the lamps")
	var lamps := {}
	for i in [1, 2, 3]:
		lamps[i] = node(scene, "DreamLamp%d" % i)
	lamps[2].use(scene)
	ok(not lamps[2].is_lit(), "lit out of turn, the lamps go out")
	for i in [1, 2, 3]:
		lamps[i].use(scene)
	ok(Campaign.flag("dream_lamps_solved") and rehearsal.is_unlocked(), "lit in order, the rehearsal opens")
	var bigger: DreamZone = node(scene, "Bigger")
	scene.party.teleport(bigger.covers_rect().get_center())
	await wait(1.0)
	var place: DreamPlace = node(scene, "DreamPlace")
	var sprite: Node2D = scene.party.leader
	ok(place.zone_now == bigger and sprite.scale.x > 1.3, "in a zone, the party is drawn bigger", "%.2f" % sprite.scale.x)
	Campaign.run_blessing = "blessing_swift"
	Campaign.set_flag(Rehearsal.LAST_FLAG)
	Rehearsal.end_run_if_over()
	ok(Campaign.run_blessing == "", "a run over, its blessing is gone")
	await close(scene)


## Shifts that change while the party is on the map (the designer, 2026-11-19: "Change while I watch"): the Light stage's post by the
## hall's north wall, a day watch and a night watch changing over at the cellar door (StealthWatch "Shifts").
func guard_shifts():
	log_line("======== guard shifts, changing while you watch ========")
	var scene := await open_map(LIGHT_STAGE)
	var watch: StealthWatch = scene.stealth
	watch.leave_for_battle = false
	var day: Guard = node(scene, "DayWatch")
	var night: Guard = node(scene, "NightWatch")
	var post: Vector2 = day.global_position
	ok(day != null and night != null and watch.guards.has(day) and not watch.guards.has(night) and watch.off_shift.has(night)
		and not night.visible, "by day the day watch keeps the post, and the night watch is not on the map")
	Campaign.set_time_of_day(Light.Hour.DUSK)
	await wait(StealthWatch.SHIFT_CHECK_SECONDS + 0.5)
	ok(watch.guards.has(night) and night.global_position.distance_to(watch._changeover_of(night)) < Grid.tiles(1.5),
		"at dusk the night watch comes up from the cellar door")
	ok(day.mood == Guard.Mood.LEAVING_SHIFT and watch.guards.has(day), "and the day watch sets off for it", Guard.Mood.keys()[day.mood])
	for i in 150:
		if watch.off_shift.has(day) and night.global_position.distance_to(post) < Grid.tiles(0.6):
			break
		await wait(0.1)
	ok(watch.off_shift.has(day) and not watch.guards.has(day) and not day.visible, "reaching it, he is gone")
	ok(night.global_position.distance_to(post) < Grid.tiles(0.6), "and the night watch takes the post")
	Campaign.set_time_of_day(Light.Hour.DAWN)
	for i in 150:
		if watch.off_shift.has(night) and day.global_position.distance_to(post) < Grid.tiles(0.6):
			break
		await wait(0.1)
	ok(watch.off_shift.has(night) and watch.guards.has(day) and day.global_position.distance_to(post) < Grid.tiles(0.6),
		"at dawn they change back")
	await close(scene)


func a_move_forgotten():
	log_line("======== a move forgotten ========")
	Campaign.reset()
	Campaign.set_party(["enfina", "cyrus"], 20)
	Campaign.current_encounter = load("res://data/encounters/encounter_02_sappers.tres")
	# A rehearsal under way: its blessing on the party in this fight.
	Campaign.run_blessing = "blessing_iron"
	var game: Node = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle(6)
	var combat: Combat = game.get_node("VisualCombat")
	var who: Dictionary = {}
	for comb in combat.combatants:
		if comb.get("side", 1) == 0 and comb.get("alive", false):
			who = comb
			break
	var forgotten: ConditionDefinition = load("res://data/conditions/forgotten.tres")
	combat.put_condition(who, forgotten, 2, "Lethe Water")
	var lost: Array = combat.forgotten_moves(who)
	ok(lost.size() == 1, "Lethe's water: one move forgotten", "%s" % [lost])
	if not lost.is_empty():
		var skill: SkillDefinition = SkillDatabase.skills[lost[0]]
		ok(not combat.can_afford_skill(who, skill) and combat.wasted_on(who, skill).contains("forgotten"), "not to be used, and its tooltip says why")
	ok(who.passives.any(func(passive): return passive != null and passive.resource_path.ends_with("blessing_iron.tres")), "a rehearsal's blessing lies on the party in its fights")
	Campaign.run_blessing = ""
	game.queue_free()
	await settle(3)
