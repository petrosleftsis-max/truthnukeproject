extends Node
## How the game feels, the next round: the proposals of 2026-11-17 as built (docs/feel_built.md, "The second round"). View, sound
## and feel only, so what is checked is that each thing happens where it should, comes back as it was, keeps to its switch and
## dial, and changes no rule.

var LOG_PATH := HarnessLog.path_for("feel2")
const STAGE := "res://maps/stealth_stages/stealth_9.tscn"
## A map whose party is four, all walking it.
const LAB := "res://maps/laboratory_explore.tscn"

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


## Waits `seconds` of the game's own time.
func wait(seconds: float):
	var left := seconds
	while left > 0.0:
		await get_tree().process_frame
		left -= get_process_delta_time()


func open_map(map: String) -> ExplorationScene:
	Campaign.reset()
	Campaign.current_map = map
	var scene: ExplorationScene = load("res://scenes/exploration.tscn").instantiate()
	get_tree().root.add_child(scene)
	await settle(8)
	scene.end_blocking_interaction()
	return scene


func close(scene: Node):
	scene.queue_free()
	await settle(3)


var game: Node = null
var combat: Combat = null


func open_fight(finish: bool = true, fought: String = "res://data/encounters/encounter_03_watcher.tres", ambient: int = -1):
	await close_fight()
	Campaign.reset()
	Campaign.set_party(["enfina", "cyrus", "prometheus", "alithia"], 64)
	Campaign.current_map = "res://maps/crossroads_explore.tscn"
	Campaign.return_to_position = true
	var encounter: EncounterDefinition = load(fought).duplicate()
	if ambient >= 0:
		encounter.ambient = ambient
	Campaign.current_encounter = encounter
	game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle(6)
	combat = game.get_node("VisualCombat")
	if finish and combat.deployment_active:
		combat.finish_deployment()
		await settle(2)
	for comb in combat.combatants:
		comb.reaction_used = true
		if comb.has("stats"):
			comb.hp = 900
			comb.max_hp = 900
	await settle()


func close_fight():
	if game != null and is_instance_valid(game):
		game.queue_free()
		await settle(3)
	game = null
	combat = null
	Engine.time_scale = 1.0


func who(key: String) -> Dictionary:
	for comb in combat.combatants:
		if comb.get("combatant_key", "") == key and not comb.get("illusion", false):
			return comb
	return {}


func a_foe() -> Dictionary:
	for comb in combat.combatants:
		if comb.get("side", 0) == 1 and comb.get("alive", false) and comb.has("stats") and not comb.has("object"):
			return comb
	return {}


## Puts `members` in a row, two tiles apart, from the first free tile found near the middle of the board. True when all are.
func line_up(members: Array) -> bool:
	var region: Rect2i = combat.controller.tile_map.get_used_rect()
	var middle := region.position + region.size / 2
	for dy in range(-6, 7):
		for dx in range(-8, 3):
			var start := middle + Vector2i(dx, dy)
			var all_free := true
			for i in members.size():
				if not combat.can_land_on(members[i], start + Vector2i(2 * i, 0)):
					all_free = false
					break
			if all_free:
				for i in members.size():
					combat.teleport_to(members[i], start + Vector2i(2 * i, 0))
				return true
	return false


func run_test():
	await idle_pace()
	await party_as_party()
	await rush_stops()
	await sound_placed()
	await stealth_felt()
	await stealth_watched()
	await world_shaken()
	await into_a_fight()
	await the_view()
	await music_layers()
	await close_fight()
	log_line("")
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0)


## Section 1 (and 3's "breathing slower"): the idle slower while hurt, faster once their nerve has broken, slower a while once
## settled; in a fight from their health and nerve, on a map from what the campaign keeps of their health.
func idle_pace():
	log_line("======== the pace of the idle ========")
	await open_fight()
	var cyrus := who("cyrus")
	var sprite: CombatantSprite = cyrus.sprite
	ok(is_equal_approx(sprite.idle_pace(), 1.0), "whole, the idle plays at its own pace", "%.2f" % sprite.idle_pace())
	sprite.set_spirits(0.5, false)
	ok(is_equal_approx(sprite.idle_pace(), 1.0), "half hurt is not yet hurt enough to show")
	sprite.set_spirits(0.3, false)
	var hurt := sprite.idle_pace()
	ok(hurt <= CombatantSprite.HURT_PACE + 0.001 and hurt > CombatantSprite.HURT_SLOWEST, "under a third of their health, slower", "%.2f" % hurt)
	sprite.set_spirits(0.05, false)
	ok(sprite.idle_pace() < hurt, "and slower still near the end", "%.2f" % sprite.idle_pace())
	sprite.set_spirits(0.05, true)
	ok(is_equal_approx(sprite.idle_pace(), CombatantSprite.BROKEN_PACE), "their nerve broken, faster, however hurt", "%.2f" % sprite.idle_pace())
	sprite.set_spirits(1.0, false)
	sprite.settle(1.0)
	var settled := sprite.idle_pace()
	ok(settled < 0.7 and sprite.settling(), "settled, after a heal or a win: slower a while", "%.2f" % settled)
	await wait(0.5)
	ok(sprite.idle_pace() > settled and sprite.idle_pace() < 1.0, "easing back", "%.2f" % sprite.idle_pace())
	await wait(0.7)
	ok(is_equal_approx(sprite.idle_pace(), 1.0) and not sprite.settling(), "and back to its pace")
	# From the fight itself.
	var most := float(combat.get_effective_stat(cyrus, "max_hp"))
	cyrus.hp = roundi(most * 0.2)
	combat.update_combatants.emit(combat.combatants)
	ok(sprite.idle_pace() < CombatantSprite.HURT_PACE, "hurt in a fight, the idle slows", "%.2f" % sprite.idle_pace())
	var animated: bool = sprite._animated != null and sprite._animated.sprite_frames != null and sprite._animated.sprite_frames.has_animation("idle")
	if animated:
		sprite.play_idle()
		await settle(2)
		ok(is_equal_approx(sprite._animated.speed_scale, sprite.idle_pace()), "the idle animation itself plays at that pace", "%.2f" % sprite._animated.speed_scale)
	else:
		ok(true, "(Cyrus has no idle animation here to slow)")
	cyrus.hp = roundi(most)
	combat.update_combatants.emit(combat.combatants)
	ok(is_equal_approx(sprite.idle_pace(), 1.0), "mended, it is its own pace again")
	var foe := a_foe()
	foe["fleeing"] = 2
	combat.update_combatants.emit(combat.combatants)
	ok(is_equal_approx(foe.sprite.idle_pace(), CombatantSprite.BROKEN_PACE), "somebody whose nerve has broken idles faster")
	foe.erase("fleeing")
	combat.update_combatants.emit(combat.combatants)
	ok(cyrus.hp == roundi(most) and not foe.has("fleeing"), "none of it touched their health or their nerve")
	await close_fight()
	# On a map, from what the campaign keeps.
	var scene := await open_map(LAB)
	var leader: CombatantSprite = scene.party.leader
	var key := String(leader.get_meta("combatant_key", ""))
	var kept: Dictionary = Campaign.party_state.get(key, {}).duplicate()
	# Only their health changed: whatever else the campaign keeps of them stays.
	var hurt_state := kept.duplicate()
	hurt_state["hp"] = 10
	hurt_state["max_hp"] = 100
	hurt_state["alive"] = kept.get("alive", true)
	Campaign.party_state[key] = hurt_state
	await wait(ExplorationParty.PACE_EVERY + 0.2)
	ok(leader.idle_pace() < CombatantSprite.HURT_PACE, "walking a map hurt, the idle is slower there too", "%s %.2f" % [key, leader.idle_pace()])
	if kept.is_empty():
		Campaign.party_state.erase(key)
	else:
		Campaign.party_state[key] = kept
	await close(scene)


## Section 3: a friend falls, a heal answered, won together.
func party_as_party():
	log_line("======== the party, as a party ========")
	await open_fight()
	MoveFeel.plays_headless = true
	MoveFeel.felt.clear()
	var alithia := who("alithia")
	var cyrus := who("cyrus")
	var enfina := who("enfina")
	var prometheus := who("prometheus")
	var lined := line_up([alithia, cyrus, enfina, prometheus])
	await settle(2)
	ok(lined, "(the party stood in a row, two tiles apart)")
	# A heal answered.
	cyrus.hp -= 100
	var cyrus_was: bool = cyrus.sprite.flipped()
	var mend := EffectDefinition.new()
	mend.type = EffectDefinition.EffectType.HEAL
	mend.min_amount = 30
	mend.max_amount = 30
	combat.do_heal(alithia, cyrus, mend)
	ok(int(MoveFeel.felt.get(&"heal_answered", 0)) == 1 and cyrus.sprite.settling(), "healed, Cyrus breathes easier: his idle slows a while")
	ok(cyrus.sprite.glancing() and alithia.sprite.glancing(), "and healer and healed turn to each other")
	var alithia_west: bool = alithia.position.x < cyrus.position.x
	ok(cyrus.sprite.flipped() == alithia_west and alithia.sprite.flipped() == (not alithia_west), "each facing the other")
	await wait(MoveFeel.HEAL_GLANCE_SECONDS + 0.2)
	ok(not cyrus.sprite.glancing() and cyrus.sprite.flipped() == cyrus_was, "then back the way he was")
	ok(cyrus.hp > 900 - 100, "the heal itself lands as it always did", "%d" % cyrus.hp)
	# A friend falls: the others turn to them, the nearest goes half a step.
	MoveFeel.friend_falls(combat, prometheus)
	ok(not alithia.sprite.glancing(), "not at once: a beat after")
	await wait(MoveFeel.FRIEND_AFTER_SECONDS + 0.05)
	ok(alithia.sprite.glancing() and cyrus.sprite.glancing() and enfina.sprite.glancing(), "a beat after one of the party falls, the others turn to them")
	ok(enfina.sprite.stepping() and not cyrus.sprite.stepping(), "and the nearest takes half a step towards them")
	ok(not alithia.sprite.flipped() and not enfina.sprite.flipped(), "turned the way they lie", "%s %s" % [alithia.sprite.flipped(), enfina.sprite.flipped()])
	await wait(MoveFeel.FRIEND_STEP_SECONDS + 0.1)
	ok(not enfina.sprite.stepping() and enfina.sprite._drawn().position.distance_to(enfina.sprite.size_offset) < 0.01, "and steps back onto her tile")
	ok(enfina.position.x == prometheus.position.x - 2, "only the picture moved")
	await wait(MoveFeel.FRIEND_GLANCE_SECONDS)
	# Won, together.
	MoveFeel.won_together(combat)
	ok(alithia.sprite.settling() and cyrus.sprite.settling() and enfina.sprite.settling() and prometheus.sprite.settling(),
		"a fight won, the party settle, breathing easier")
	ok(alithia.sprite.glancing() and not alithia.sprite.flipped() and prometheus.sprite.glancing() and prometheus.sprite.flipped(),
		"and turn to one another, towards the middle of them")
	MoveFeel.plays_headless = false
	await close_fight()


## Section 2: a rush that stops - shoved, the drawing slides home and skids; a run of three or more stopping beside the other side.
func rush_stops():
	log_line("======== a rush that stops ========")
	await open_fight()
	MoveFeel.plays_headless = true
	MoveFeel.felt.clear()
	var cyrus := who("cyrus")
	var foe := a_foe()
	var sprite: CombatantSprite = foe.sprite
	var at := MoveFeel.middle_of(combat, foe)
	var skids: int = sprite.skids
	MoveFeel.shoved_skid(combat, foe, at - Vector2(Grid.tiles(2.0), 0.0), at, 2)
	ok(sprite.skids == skids + 1, "shoved, they skid")
	await settle(1)
	ok(sprite._drawn().position.distance_to(sprite.size_offset) > Grid.tiles(0.8), "from where they were, sliding",
		"%.0f" % sprite._drawn().position.distance_to(sprite.size_offset))
	await wait(CombatantSprite.SKID_SECONDS + 0.15)
	ok(sprite._drawn().position.distance_to(sprite.size_offset) < 0.01 and is_equal_approx(sprite._drawn().rotation, 0.0), "and come to rest on their tile")
	# Through a real shove.
	var west: Vector2i = foe.position + Vector2i.LEFT
	var spots_east := combat.can_land_on(foe, foe.position + Vector2i.RIGHT) and combat.can_land_on(foe, foe.position + Vector2i.RIGHT * 2)
	if combat.can_land_on(cyrus, west) and spots_east:
		combat.teleport_to(cyrus, west)
		await settle(2)
		var push := EffectDefinition.new()
		push.type = EffectDefinition.EffectType.PUSH
		push.knockback_distance = 2
		var from: Vector2i = foe.position
		skids = sprite.skids
		combat.apply_knockback(cyrus, foe, push, false)
		ok(foe.position != from and sprite.skids == skids + 1, "a shove in the fight slides them there, skidding", "%s -> %s" % [from, foe.position])
		await wait(CombatantSprite.SKID_SECONDS + 0.15)
	else:
		ok(true, "(no room to shove the foe east here)")
	# A charge that stops.
	var beside: Vector2i = foe.position + Vector2i.LEFT
	if combat.can_land_on(cyrus, beside) or cyrus.position == beside:
		combat.teleport_to(cyrus, beside)
		await settle(2)
		skids = cyrus.sprite.skids
		MoveFeel.charge_stops(combat, cyrus, 3, Vector2.RIGHT)
		ok(cyrus.sprite.skids == skids + 1 and int(MoveFeel.felt.get(&"charge_stopped", 0)) == 1, "three tiles run and stopping beside a foe: a skid")
		await wait(CombatantSprite.SKID_STOP_SECONDS + 0.1)
		MoveFeel.charge_stops(combat, cyrus, 2, Vector2.RIGHT)
		ok(cyrus.sprite.skids == skids + 1, "two tiles are no charge")
	else:
		ok(true, "(no room beside the foe)")
	var lonely := false
	for dy in range(-6, 7):
		for dx in range(-6, 7):
			var tile: Vector2i = cyrus.position + Vector2i(dx, dy) * 3
			if combat.can_land_on(cyrus, tile) and combat.combatants.all(func(c): return not (c.get("side", 0) == 1 and c.get("alive", false)) or maxi(absi(c.position.x - tile.x), absi(c.position.y - tile.y)) > 3):
				combat.teleport_to(cyrus, tile)
				lonely = true
				break
		if lonely:
			break
	if lonely:
		await settle(2)
		skids = cyrus.sprite.skids
		MoveFeel.charge_stops(combat, cyrus, 5, Vector2.RIGHT)
		ok(cyrus.sprite.skids == skids, "with nobody of the other side to stop beside, no skid")
	MoveFeel.plays_headless = false
	await close_fight()


## Section 4: sound with a place - heard from where it happens, quieter off the screen, gone well past it, dulled behind a wall;
## a guard heard while near; voices in a fight.
func sound_placed():
	log_line("======== sound with a place ========")
	var viewport := get_viewport()
	var canvas := viewport.get_canvas_transform()
	var screen := viewport.get_visible_rect().size
	var middle: Vector2 = canvas.affine_inverse() * (screen * 0.5)
	ok(is_equal_approx(SoundFollows.loudness_at(middle), 1.0), "in the middle of the screen, heard whole")
	var edge: Vector2 = canvas.affine_inverse() * Vector2(screen.x, screen.y * 0.5)
	ok(absf(SoundFollows.loudness_at(edge) - SoundFollows.PLACE_AT_EDGE) < 0.03, "at its edge, quieter", "%.2f" % SoundFollows.loudness_at(edge))
	var gone: Vector2 = edge + Vector2(Grid.tiles(SoundFollows.PLACE_FADE_TILES + 1.0), 0.0)
	ok(SoundFollows.loudness_at(gone) == 0.0, "well past it, not at all")
	var player := AudioStreamPlayer2D.new()
	add_child(player)
	ok(SoundFollows.place(player, middle, -3.0) and player.global_position.distance_to(middle) < 0.01 and is_equal_approx(player.volume_db, -3.0)
		and is_equal_approx(player.panning_strength, SoundFollows.PLACE_PANNING), "a sound placed in the middle: there, as loud as asked, and panned")
	var aside: Vector2 = canvas.affine_inverse() * Vector2(screen.x * 0.97, screen.y * 0.5)
	ok(SoundFollows.place(player, aside, 0.0) and player.volume_db < 0.0, "towards the edge, quieter", "%.1f dB" % player.volume_db)
	ok(not SoundFollows.place(player, gone, 0.0), "and one too far off is not played at all")
	player.queue_free()
	# Fights' sounds are placed by who they are about.
	await open_fight()
	var cyrus := who("cyrus")
	var foe := a_foe()
	var count := func() -> int: return int(SoundFollows.placed.get(&"heard", 0)) + int(SoundFollows.placed.get(&"behind", 0)) + int(SoundFollows.placed.get(&"unheard", 0))
	var placed: int = count.call()
	combat.play_stream(PlaceholderSounds.make("impact_thud"), 0.0, 1.0, MoveFeel.middle_of(combat, foe))
	ok(count.call() == placed + 1, "a blow's sound in a fight is heard from where it lands")
	placed = count.call()
	combat.play_stream(PlaceholderSounds.make("impact_dull"))
	ok(count.call() == placed, "one with no place is heard in the middle, as before")
	# Voices in a fight: silent until filled; a creature's own, else the party's pitched for them.
	MoveFeel.plays_headless = true
	MoveFeel.voiced.clear()
	MoveFeel.voice(combat, cyrus, &"effort")
	ok(MoveFeel.voiced.is_empty(), "with nothing in the slot, silence")
	var bank := GameSounds.bank()
	bank.voice_effort = PlaceholderSounds.make("voice_tick")
	MoveFeel.voice(combat, cyrus, &"effort")
	ok(int(MoveFeel.voiced.get(&"effort", 0)) == 1, "filled, one of the party makes an effort with a blow, pitched for them")
	MoveFeel.voice(combat, foe, &"effort")
	ok(int(MoveFeel.voiced.get(&"effort", 0)) == 1, "a creature with no voice of its own says nothing")
	bank.voice_effort = null
	bank.voice_hurt = PlaceholderSounds.make("voice_tick")
	combat.show_damage(cyrus, 400, Damage.Type.PHYSICAL)
	ok(int(MoveFeel.voiced.get(&"hurt", 0)) == 1, "hurt by more than a scratch, a cry")
	combat.show_damage(cyrus, 2, Damage.Type.PHYSICAL)
	ok(int(MoveFeel.voiced.get(&"hurt", 0)) == 1, "a scratch, none")
	bank.voice_hurt = null
	MoveFeel.plays_headless = false
	await close_fight()
	# A guard heard while near where the party last stepped.
	var steps := Footsteps.guard_steps
	Footsteps._stepped_from = Vector2(1000.0, 1000.0)
	Footsteps.guard_step(Vector2(1000.0, 1000.0) + Vector2(Grid.tiles(3.0), 0.0))
	ok(Footsteps.guard_steps == steps + 1, "a guard's step near the party is heard")
	Footsteps.guard_step(Vector2(1000.0, 1000.0) + Vector2(Grid.tiles(Footsteps.GUARD_HEARD_TILES + 4.0), 0.0))
	ok(Footsteps.guard_steps == steps + 1, "one far off is not")


## Section 5: stealth, felt - a takedown, a thrown thing, a hiding spot, holding your breath, a body dragged; and a wall that dulls.
func stealth_felt():
	log_line("======== stealth, felt ========")
	MapFeel.plays_headless = true
	LightView.plays_headless = true
	var scene := await open_map(STAGE)
	var watch: StealthWatch = scene.stealth
	ok(watch != null, "the Light stage is watched")
	if watch == null:
		MapFeel.plays_headless = false
		LightView.plays_headless = false
		await close(scene)
		return
	scene.camera.make_current()
	await settle(3)
	# Behind a wall, from the middle of the view.
	var view: LightView = LightView.showing
	var viewport := get_viewport()
	var middle: Vector2 = viewport.get_canvas_transform().affine_inverse() * (viewport.get_visible_rect().size * 0.5)
	ok(not SoundFollows.behind_wall(middle), "a sound where the view is, is not behind a wall")
	var tile_map: TileMap = view._tile_map
	# Floor, a wall, floor again: the wall stands between the two floors, and nothing between two floors side by side.
	var near := Vector2i(-99999, -99999)
	var far := Vector2i(-99999, -99999)
	for tile in tile_map.get_used_cells(0):
		if Depth.kind_at(tile_map, tile) != Depth.Kind.FLOOR or Depth.kind_at(tile_map, tile + Vector2i.RIGHT) != Depth.Kind.WALL:
			continue
		for step in range(2, 5):
			if Depth.kind_at(tile_map, tile + Vector2i.RIGHT * step) == Depth.Kind.FLOOR:
				near = tile
				far = tile + Vector2i.RIGHT * step
				break
		if near.x != -99999:
			break
	ok(near.x != -99999 and SoundFollows.wall_between(tile_map, near, far) and not SoundFollows.wall_between(tile_map, near, near + Vector2i.LEFT),
		"a wall between a sound and the view is found; none between two tiles of floor side by side", "%s - %s" % [near, far])
	ok(SoundFollows._behind_bus() == SoundFollows.BEHIND_BUS
		and AudioServer.get_bus_send(AudioServer.get_bus_index(SoundFollows.BEHIND_BUS)) == &"SFX", "behind one, it plays dulled, on its own bus sending on to SFX")
	# A takedown that lands.
	var guard: Guard = null
	for each in watch.guards:
		if is_instance_valid(each) and not each.knocked_out and each.sprite is CombatantSprite:
			guard = each
			break
	ok(guard != null, "(a guard to take down)")
	if guard != null:
		var felt: int = watch.takedowns_felt
		var still: int = int(MapFeel.made.get(&"still", 0))
		watch._takedown_lands(guard)
		guard.knock_out(Vector2.RIGHT)
		ok(watch.takedowns_felt == felt + 1 and int(MapFeel.heard.get(&"takedown", 0)) >= 1, "a takedown lands with a muffled thump")
		ok(int(MapFeel.made.get(&"still", 0)) == still + 1 and is_equal_approx(Engine.time_scale, 1.0), "and a moment's stillness asked for - never bent headless")
		await wait(CombatantSprite.FOLD_SECONDS + 0.2)
		ok(absf(guard.sprite._drawn().rotation) > 1.0, "the guard folds down and tips over", "%.2f" % guard.sprite._drawn().rotation)
		guard.wake_up()
		await wait(CombatantSprite.DEATH_SECONDS + 0.1)
		ok(absf(guard.sprite._drawn().rotation) < 0.05, "and stands as he was once brought round")
	# A body dragged.
	var marks := LightView.drag_marks_left
	var scrapes := int(MapFeel.heard.get(&"body_drag", 0))
	var start: Vector2 = scene.party.leader.global_position
	watch._dragged_from = Vector2.INF
	for i in 8:
		watch._drag_felt(start + Vector2(Grid.tiles(0.35) * float(i), 0.0))
	ok(LightView.drag_marks_left >= marks + 6, "a body dragged leaves faint marks behind it", "%d" % (LightView.drag_marks_left - marks))
	ok(int(MapFeel.heard.get(&"body_drag", 0)) > scrapes, "and scrapes as it goes")
	MapFeel.plays_headless = false
	LightView.plays_headless = false
	await close(scene)


## Section 5 again, on the crossroads made a watched map with a watchman of its own (as the stealth suites do): a thrown thing whose
## noise waits for it to land, a hiding spot stirred going in and out, the held breath as his look passes over somebody hidden in
## front of him, and a takedown from behind him.
func stealth_watched():
	log_line("======== stealth, felt, with somebody watching ========")
	MapFeel.plays_headless = true
	LightView.plays_headless = true
	Campaign.reset()
	Campaign.set_party(["cyrus"], 20)
	Campaign.current_map = "res://maps/crossroads_explore.tscn"
	var scene: ExplorationScene = load("res://scenes/exploration.tscn").instantiate()
	get_tree().root.add_child(scene)
	await settle(4)
	scene.end_blocking_interaction()
	var map: Node = scene.get_node("Map")
	var tile_map: TileMap = scene._tile_map
	var sight := StealthSight.new(tile_map)
	var setup := StealthSetup.new()
	setup.battle_terrain = load("res://maps/crossroads_terrain.tscn")
	map.add_child(setup)
	var at := func(tile: Vector2i) -> Vector2: return tile_map.to_global(tile_map.map_to_local(tile))
	var standable := func(tile: Vector2i) -> bool: return scene.is_walkable(at.call(tile))
	# A post looking east down four open tiles, with two free behind it.
	var post := Vector2i(-99999, -99999)
	var start := tile_map.local_to_map(scene.party.position_of_leader())
	var frontier := [start]
	var visited := {start: true}
	while not frontier.is_empty():
		var tile: Vector2i = frontier.pop_front()
		var fits: bool = standable.call(tile) and standable.call(tile + Vector2i.LEFT) and standable.call(tile + Vector2i.LEFT * 2)
		for step in range(1, 5):
			fits = fits and standable.call(tile + Vector2i.RIGHT * step)
		if fits and sight.clear(tile, tile + Vector2i.RIGHT * 4) and sight.clear(tile + Vector2i.LEFT * 2, tile + Vector2i.RIGHT * 4):
			post = tile
			break
		for d in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = tile + d
			if not visited.has(next) and sight.region().has_point(next) and standable.call(next):
				visited[next] = true
				frontier.append(next)
	ok(post.x != -99999, "(a post on the crossroads, looking down an open row)", "%s" % post)
	if post.x == -99999:
		MapFeel.plays_headless = false
		LightView.plays_headless = false
		await close(scene)
		return
	var guard := Guard.new()
	guard.name = "Watchman"
	guard.display_name = "Watchman"
	guard.combatant_key = "barbarian"
	guard.level = 2
	guard.facing_degrees = 0.0
	guard.looks_around = false
	map.add_child(guard)
	guard.global_position = at.call(post)
	var spot := HidingSpot.new()
	spot.look = load("res://art/editor_icons/battle_object.svg")
	map.add_child(spot)
	spot.global_position = at.call(post + Vector2i.RIGHT * 3)
	Campaign.give_item(Campaign.party_members()[0].key, "pebble")
	scene.party.teleport(at.call(post + Vector2i.LEFT * 2))
	scene.begin_stealth()
	var watch: StealthWatch = scene.stealth
	watch.leave_for_battle = false
	await settle(4)
	ok(watch != null and watch.guards.has(guard) and watch._hiding_spots.has(spot), "(watched: a watchman, and a hiding spot in front of him)")
	if watch == null:
		MapFeel.plays_headless = false
		LightView.plays_headless = false
		await close(scene)
		return
	# A thrown thing, far enough from him that he hears nothing of it.
	var from: Vector2i = post + Vector2i.LEFT * 2
	var landing := Vector2i(-99999, -99999)
	var best := 0.0
	for dx in range(-6, 7):
		for dy in range(-6, 7):
			var tile := from + Vector2i(dx, dy)
			var gap := Vector2(tile - post).length()
			if gap > best and gap > 5.0 and watch.can_throw_to(tile) and standable.call(tile):
				best = gap
				landing = tile
	ok(landing.x != -99999, "(somewhere to throw a pebble, away from the watchman)", "%s" % landing)
	if landing.x != -99999:
		var ripples: int = watch._ripples.size()
		var skitters := int(MapFeel.made.get(&"skitter", 0))
		ok(watch.throw_at(landing), "a pebble thrown")
		await settle(2)
		ok(watch._ripples.size() == ripples, "in the air, it has made no noise yet")
		await wait(MapFeel.flight_seconds(Vector2(landing - from).length()) + 0.2)
		ok(watch._ripples.size() == ripples + 1, "landing, its noise is made where it comes down")
		ok(int(MapFeel.made.get(&"skitter", 0)) == skitters + 1 or LightView.in_water(at.call(landing)), "and it skitters on")
		ok(guard.mood != Guard.Mood.INVESTIGATING, "too far off for the watchman to hear it", Guard.Mood.keys()[guard.mood])
	# Into the hiding spot in front of him: it stirs, and his look passes over somebody he cannot make out.
	var held: int = watch.held_breaths
	var hushes := SoundFollows.hushes
	var stirred: int = spot.stirred
	scene.party.teleport(spot.global_position)
	await settle(8)
	ok(spot.stirred == stirred + 1, "going into a hiding spot stirs it")
	ok(watch.held_breaths == held + 1 and SoundFollows.hushes == hushes + 1, "his look passing over him unseen, the world holds its breath")
	ok(watch.spotted_by == null and float(watch.suspicion.get(guard, 0.0)) == 0.0, "and hidden, he is not seen",
		"%.2f" % float(watch.suspicion.get(guard, 0.0)))
	await settle(8)
	ok(watch.held_breaths == held + 1, "once a look, not every moment of it")
	# Out again, to right behind him.
	scene.party.teleport(at.call(post + Vector2i.LEFT))
	await settle(8)
	ok(spot.stirred == stirred + 2, "coming out stirs it again")
	# A takedown from behind.
	var felt: int = watch.takedowns_felt
	ok(watch.take_down(guard), "taken down from behind")
	ok(guard.knocked_out and watch.takedowns_felt == felt + 1, "with its beat and its thump")
	await wait(CombatantSprite.FOLD_SECONDS + 0.2)
	ok(guard.sprite != null and absf(guard.sprite._drawn().rotation) > 1.0, "he folds down where he stood")
	MapFeel.plays_headless = false
	LightView.plays_headless = false
	scene.queue_free()
	MenuPause.clear(get_tree())
	await settle(3)
	Engine.time_scale = 1.0


## Section 6: the world shaken - trees and things that stand, lights swinging; a blast's light; dust from above.
func world_shaken():
	log_line("======== the world shaken by a fight ========")
	LightView.plays_headless = true
	var scene := await open_map(STAGE)
	var tree_piece: DepthPiece = null
	var stander: DepthPiece = null
	for piece in get_tree().get_nodes_in_group(Depth.PIECES):
		if not piece is DepthPiece or not Depth.same_scene(piece, scene):
			continue
		if piece.kind == DepthPiece.Kind.TREE and tree_piece == null:
			tree_piece = piece
		elif piece.stands() and stander == null:
			stander = piece
	ok(tree_piece != null and stander != null, "(the yard has a tree and something that stands)")
	for piece in [tree_piece, stander]:
		if piece == null:
			continue
		var foot: Vector2 = piece.to_global(piece.ground_rect().get_center())
		var shaken: int = piece.shaken
		MapLife.blast_at(get_tree(), foot + Vector2(Grid.tiles(1.0), 0.0), 1.0)
		ok(piece.shaken == shaken + 1, "a blast beside the %s shakes it" % DepthPiece.Kind.keys()[piece.kind].to_lower())
		await wait(0.12)
		ok(absf(piece.shaken_now()) > 0.0, "it rocks", "%.3f" % piece.shaken_now())
		await wait(DepthPiece.SHAKEN_SECONDS)
		ok(piece.shaken_now() == 0.0, "and settles")
		MapLife.blast_at(get_tree(), foot + Vector2(Grid.tiles(40.0), 0.0), 1.0)
		ok(piece.shaken == shaken + 1, "one far off does not touch it")
	var swung := LightView.swung
	var view: LightView = LightView.showing
	if view != null and not view._lights.is_empty():
		var entry: Dictionary = view._lights[0]
		MapLife.blast_at(get_tree(), view.to_global(entry.at) + Vector2(Grid.tiles(0.5), 0.0), 1.0)
		ok(LightView.swung > swung and entry.has("swing"), "a light beside a blast swings")
	else:
		ok(true, "(no light shown to swing, headless)")
	await close(scene)
	# A blast's light and dust from above, in a fight.
	await open_fight()
	MoveFeel.plays_headless = true
	MoveFeel.felt.clear()
	var foe := a_foe()
	var at := MoveFeel.middle_of(combat, foe)
	var blade: SkillDefinition = SkillDatabase.skills["rapier"]
	MoveFeel.blast_light(combat, at, Damage.Type.FIRE, blade, false)
	ok(int(MoveFeel.felt.get(&"glowed", 0)) == 1, "a fire blow lights what is about it")
	MoveFeel.blast_light(combat, at, Damage.Type.PHYSICAL, blade, false)
	ok(int(MoveFeel.felt.get(&"glowed", 0)) == 1, "a plain blow gives no light")
	var flashes := Comfort.share(Comfort.FLASHES)
	Comfort.set_share(Comfort.FLASHES, 0.0)
	MoveFeel.blast_light(combat, at, Damage.Type.LIGHTNING, blade, true)
	ok(int(MoveFeel.felt.get(&"glowed", 0)) == 1, "and with Flashes off, none at all")
	Comfort.set_share(Comfort.FLASHES, flashes)
	var lights: LightView = LightView.showing
	var open := Vector2i(-99999, -99999)
	if lights != null and lights.light != null and lights._tile_map != null:
		for tile in lights._tile_map.get_used_cells(0):
			if Depth.kind_at(lights._tile_map, tile) == Depth.Kind.FLOOR and lights.light.under_the_sky(tile):
				open = tile
				break
	ok(open.x != -99999, "(the crossroads has open sky)")
	if open.x != -99999:
		MoveFeel.dust_from_above(combat, lights._tile_map.to_global(lights._tile_map.map_to_local(open)))
		ok(int(MoveFeel.felt.get(&"grit", 0)) == 0, "out under the sky, nothing comes down")
	# Underground: the laboratory, where there is no sky at all.
	await open_fight(true, "res://data/encounters/encounter_02_sappers.tres", Light.Ambient.UNDERGROUND)
	MoveFeel.felt.clear()
	var below: LightView = LightView.showing
	var inside := Vector2i(-99999, -99999)
	if below != null and below.light != null and below._tile_map != null:
		for tile in below._tile_map.get_used_cells(0):
			if Depth.kind_at(below._tile_map, tile) == Depth.Kind.FLOOR:
				inside = tile
				break
	ok(inside.x != -99999 and combat._light_ambient == Light.Ambient.UNDERGROUND, "(the laboratory, underground)")
	if inside.x != -99999:
		MoveFeel.dust_from_above(combat, below._tile_map.to_global(below._tile_map.map_to_local(inside)))
		ok(int(MoveFeel.felt.get(&"grit", 0)) == 1, "under a roof, a blast brings dust and grit down")
	MoveFeel.plays_headless = false
	LightView.plays_headless = false
	await close_fight()


## Section 7: into a fight - the ground a map and its fight share, a fight opening where the map's view was and going on to the
## party, the board drawn out; a look at what you face; placed with a thump.
func into_a_fight():
	log_line("======== into a fight ========")
	var scene := await open_map(STAGE)
	var ground := SceneTransition._ground_of(scene._tile_map)
	var setup = scene.stealth.setup if scene.stealth != null else null
	ok(ground != "" and setup != null and setup.battle_terrain != null and setup.battle_terrain.resource_path == ground,
		"the Light stage and the fight caught on it are on the same ground", ground)
	ok(not SceneTransition._carries(SceneTransition.FIGHT_SCENE), "headless, a change is the fade it always was")
	await close(scene)
	SceneTransition._carried_view = {"at": Vector2(Grid.tiles(20.0), Grid.tiles(18.0)), "zoom": Vector2(0.25, 0.25)}
	await open_fight()
	ok(combat.opened_carried() and SceneTransition.take_carried_view().is_empty(), "a fight carried in opens where the map's view was, taking it once")
	ok(combat.camera.zoom.is_equal_approx(Vector2(0.25, 0.25)), "at the map's zoom")
	MoveFeel.felt.clear()
	await combat.go_on_from_carried()
	ok(not combat.opened_carried() and combat.camera.zoom.x > 0.3, "then on to the party, as it would have opened", "%.2f" % combat.camera.zoom.x)
	ok(int(MoveFeel.felt.get(&"board_out", 0)) == 1, "the board's lines drawn out from them")
	await close_fight()
	# A look at what you face.
	await open_fight()
	CameraController.moves_headless = true
	FightCards.looked = 0
	var card := FightCards.new()
	card.combat = combat
	combat.add_child(card)
	var seen := combat.combatants.filter(func(c): return c.get("alive", false) and c.get("side", -1) != Combat.Group.PLAYERS and c.has("position") and not c.has("object") and not c.get("illusion", false) and not combat.unseen_by_party(c)).size()
	var start: Vector2 = combat.camera.position
	await card._look_at_what_you_face()
	var until := Time.get_ticks_msec() + 2000
	while combat.camera.is_gliding() and Time.get_ticks_msec() < until:
		await get_tree().process_frame
	ok(FightCards.looked == (1 if seen > 0 else 0), "a fight with no boss's reveal opens with a look at whoever of the other side can be seen", "%d seen" % seen)
	ok(combat.camera.position.distance_to(start) < Grid.tiles(1.0), "and the view comes back", "%.0f" % combat.camera.position.distance_to(start))
	card.queue_free()
	CameraController.moves_headless = false
	await close_fight()
	# Zoomed right in, the look pulls back until every one of them is in view, and goes back to the zoom it had (the designer,
	# 2026-11-17: "if the camera is too zoomed, it doesnt fit the enemies when it tries showing them").
	await open_fight(true, "res://data/encounters/encounter_02_sappers.tres")
	CameraController.moves_headless = true
	var looker := FightCards.new()
	looker.combat = combat
	combat.add_child(looker)
	var foes := combat.combatants.filter(func(c): return c.get("alive", false) and c.get("side", -1) != Combat.Group.PLAYERS and c.has("position") and not c.has("object") and not c.get("illusion", false) and not combat.unseen_by_party(c))
	var room: Rect2 = combat.game_ui.map_view_rect()
	var closest: float = combat.camera.max_zoom
	# Too far apart to be seen together that close: the last of them moved away from the first, if they are not already.
	var fit_close := func() -> bool:
		var spread := Rect2(combat.sprite_point(foes[0]), Vector2.ZERO)
		for foe in foes:
			spread = spread.expand(combat.sprite_point(foe))
		return room.size.x / closest >= spread.size.x + Grid.tiles(3.0) and room.size.y / closest >= spread.size.y + Grid.tiles(3.0)
	if foes.size() >= 2 and fit_close.call():
		for reach in range(6, 16):
			if combat.teleport_to(foes[-1], foes[0].position + Vector2i(reach, 0)) or combat.teleport_to(foes[-1], foes[0].position - Vector2i(reach, 0)):
				if not fit_close.call():
					break
	combat.camera.zoom = Vector2.ONE * closest
	await settle(2)
	var start_at: Vector2 = combat.camera.position
	var done := [false]
	(func(): await looker._look_at_what_you_face(); done[0] = true).call()
	await wait(FightCards.FACE_GLIDE_SECONDS + 0.25)
	var middle: Vector2 = combat.camera.get_viewport_rect().size * 0.5
	var shown := Rect2(combat.camera.position + (room.position - middle) / combat.camera.zoom.x, room.size / combat.camera.zoom.x)
	var outside := foes.filter(func(c): return not shown.has_point(combat.sprite_point(c) + combat.drawing_offset(c)))
	ok(foes.size() >= 2 and not fit_close.call() and outside.is_empty() and combat.camera.zoom.x < closest - 0.01,
			"zoomed right in, the look at what you face pulls back until every one of them is in view",
			"%d of %d outside, zoom %.2f from %.2f" % [outside.size(), foes.size(), combat.camera.zoom.x, closest])
	var until_back := Time.get_ticks_msec() + 4000
	while (not done[0] or combat.camera.is_gliding()) and Time.get_ticks_msec() < until_back:
		await get_tree().process_frame
	ok(absf(combat.camera.zoom.x - closest) < 0.01 and combat.camera.position.distance_to(start_at) < Grid.tiles(1.0),
			"and goes back to the zoom and the place it had", "zoom %.2f, %.0f away" % [combat.camera.zoom.x, combat.camera.position.distance_to(start_at)])
	looker.queue_free()
	CameraController.moves_headless = false
	await close_fight()
	# Placed with a thump.
	await open_fight(false)
	MoveFeel.plays_headless = true
	MoveFeel.felt.clear()
	var cyrus := who("cyrus")
	var elsewhere := Vector2i(-99999, -99999)
	for tile in combat.deployment_tiles:
		if tile != cyrus.position:
			elsewhere = tile
			break
	ok(combat.deployment_active and elsewhere.x != -99999, "(the party is being placed, with somewhere else to go)")
	if combat.deployment_active and elsewhere.x != -99999:
		var there = combat.controller.get_combatant_at_position(elsewhere)
		var from: Vector2i = cyrus.position
		combat.controller._swap_deployed(cyrus, elsewhere)
		ok(cyrus.position == elsewhere and int(MoveFeel.felt.get(&"placed", 0)) == 1, "placed before a fight, he hops onto the tile with a thump")
		ok(cyrus.sprite._hop_tween != null and cyrus.sprite._hop_tween.is_valid(), "the drawing hopping there")
		if there != null:
			ok(there.position == from and there.sprite._hop_tween != null and there.sprite._hop_tween.is_valid(), "and whoever stood there slides past to where he was")
	MoveFeel.plays_headless = false
	await close_fight()


## Section 8: the view - never quite still in a fight, with its switch and dial; weather near the eye.
func the_view():
	log_line("======== the view ========")
	await open_fight()
	var camera: CameraController = combat.camera
	ok(camera.drift_now() == Vector2.ZERO, "headless the view never drifts")
	CameraController.moves_headless = true
	var drift := camera.drift_now()
	ok(drift != Vector2.ZERO and drift.length() * camera.zoom.x <= CameraController.DRIFT_PIXELS * 1.42, "in a fight it drifts a few pixels",
		"%.1f px" % (drift.length() * camera.zoom.x))
	await settle(2)
	ok(camera.offset.distance_to(camera.drift_now()) < 2.0 / camera.zoom.x, "in the view's own offset, under any lean or shake")
	CameraController.drifts = false
	ok(camera.drift_now() == Vector2.ZERO, "switched off, it is still")
	CameraController.drifts = true
	var sway := Comfort.share(Comfort.SWAY)
	Comfort.set_share(Comfort.SWAY, 0.0)
	ok(camera.drift_now() == Vector2.ZERO, "and still with Camera sway at nothing")
	Comfort.set_share(Comfort.SWAY, sway)
	CameraController.moves_headless = false
	await close_fight()
	LightView.plays_headless = true
	var scene := await open_map(STAGE)
	scene.camera.make_current()
	LightView.sky_ease_seconds = 0.0
	Campaign.set_clock(12)
	Campaign.set_weather("clear", 3)
	await wait(0.4)
	var view: LightView = LightView.showing
	ok(view != null and view._near_kind() == "", "a clear day: nothing passes by the eye")
	Campaign.set_weather("rain", 3)
	await wait(0.4)
	var outdoors: bool = view != null and view._under_the_sky(scene.camera.get_screen_center_position())
	if outdoors:
		ok(view._near_kind() == "rain", "out under the sky in the rain, big drops pass by the eye")
	else:
		ok(view != null and view._near_kind() == "", "under a roof, nothing passes by the eye")
	Campaign.set_weather("", 1)
	await close(scene)
	LightView.plays_headless = false


## Section 9: music in layers - parts in and out with how things stand, thinned with the party down to one, swelling for a leader
## felled; a track with no parts left alone.
func music_layers():
	log_line("======== music in layers ========")
	Music._start_parts("no_such_track_here", true)
	ok(Music.parts().is_empty(), "a track with no parts beside it plays alone, as always")
	var wav := PlaceholderSounds.make("danger")
	for part_name in Music.PARTS:
		var part := AudioStreamPlayer.new()
		part.stream = wav
		part.volume_db = Music.PART_OUT_DB
		Music.add_child(part)
		Music._parts[part_name] = part
	var standing: int = Music.standing_now()
	for i in 150:
		Music._process(0.1)
	if standing >= 2:
		ok(absf(Music._parts.wary.volume_db) < 0.5 and absf(Music._parts.fighting.volume_db) < 0.5, "in a fight, every part comes in",
			"%.1f %.1f" % [Music._parts.wary.volume_db, Music._parts.fighting.volume_db])
	else:
		ok(Music._parts.fighting.volume_db < -50.0, "calm, the fighting part stays out")
	Music.thin(true)
	for i in 150:
		Music._process(0.1)
	ok(Music._parts.wary.volume_db < -50.0 and Music._player.volume_db < -20.0, "the party down to one: thinned to its fighting part",
		"%.1f %.1f" % [Music._parts.wary.volume_db, Music._player.volume_db])
	Music.thin(false)
	Music.swell()
	for i in 150:
		Music._process(0.1)
	if standing >= 2:
		ok(Music._parts.fighting.volume_db > 2.0, "a leader felled: it swells", "%.1f" % Music._parts.fighting.volume_db)
	Music._start_parts("", false)
	Music._player.volume_db = 0.0
	ok(Music.parts().is_empty(), "put away with the track")
	# The turn of a fight, from the fight.
	await open_fight()
	for key in ["enfina", "prometheus", "alithia"]:
		who(key).alive = false
	combat._turn_the_music()
	ok(Music._thin, "in a fight, the party down to one thins the music")
	for key in ["enfina", "prometheus", "alithia"]:
		who(key).alive = true
	combat._turn_the_music()
	ok(not Music._thin, "two again, it comes back")
	var foe := a_foe()
	var others := combat.combatants.filter(func(c): return c != foe and c.get("side", 0) == 1 and c.get("alive", false) and not c.has("object"))
	foe["leads"] = true
	var leaders_left := others.any(func(c): return c.get("leads", false) or c.has("boss"))
	ok(combat._last_leader_felled(foe) == (not others.is_empty() and not leaders_left), "their side's last leader felled, others standing: the music swells",
		"%d others" % others.size())
	foe.erase("leads")
	ok(not combat._last_leader_felled(foe), "nobody's leader, nothing")
	await close_fight()
