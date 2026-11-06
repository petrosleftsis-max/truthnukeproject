extends Node
class_name FightCards
## What opens and closes a fight (the designer, 2026-11-05). All placeholder, drawn in code
## behind slots (EncounterDefinition's and BossDefinition's "Title cards"), none of it
## rolled and none of it changing the fight, so each machine shows its own: not while a
## fight is played through to catch up (Net.catching_up), and headless only for a suite
## that asks (plays_headless). Any press skips what is up.
##
## Opening (opening): on an encounter with Boss Reveal ticked, the view goes to whoever it
## names between letterbox bars - a silhouette lighting up on the sting, its entrance, then
## its name and title with a large portrait over the dimmed arena, shorter once it has been
## seen - and then the screen freezes and shatters, and "Conflict Endless" slams in.
##
## Closing (closing): the last blow slows and drains the colour, then "Will Subdued" - or
## the fight's or the boss's own words, or a defeat's, or those for somebody getting away.
##
## Between: plate (a name plate and a sting, for somebody arriving) and fallen ("X has
## fallen", for one of the party, with any last words written for them). Every number here
## is a PROPOSAL.

const OVERLAY_LAYER := 23
const OPENING_TEXT := "Conflict Endless"
const VICTORY_TEXT := "Will Subdued"
const DEFEAT_TEXT := "Will Broken"
const FLED_TEXT := "They Got Away"
const DRAW_TEXT := "Nobody Stands"
const BAR_SHARE := 0.13
const BAR_SECONDS := 0.22
const FREEZE_SECONDS := 0.14
const SHATTER_SECONDS := 0.55
const SLAM_SECONDS := 0.16
const TITLE_HOLD_SECONDS := 1.15
const DRAIN_SECONDS := 0.8
const CLOSING_SLOW := 0.3
const CLOSING_HOLD_SECONDS := 1.6
const LOOK_SECONDS := 0.65
const LIGHT_UP_SECONDS := 0.35
const SIGNATURE_SECONDS := 0.5
const PLATE_SECONDS := 1.7
const SHORT_PLATE_SECONDS := 0.9
const PORTRAIT_HEIGHT := 440.0
const INK := Color("f2ead8")
const GOOD_INK := Color("f2ead8")
const BAD_INK := Color("ff8a7a")

const DRAIN_SHADER := "shader_type canvas_item;
uniform sampler2D screen: hint_screen_texture, filter_linear;
uniform float amount = 0.0;
void fragment() {
	vec4 seen = texture(screen, SCREEN_UV);
	float grey = dot(seen.rgb, vec3(0.3, 0.59, 0.11));
	COLOR = vec4(mix(seen.rgb, vec3(grey), amount), 1.0);
}"

## Lets a suite play them with nothing on the screen.
static var plays_headless := false

var combat: Combat = null
var _layer: CanvasLayer = null
var _skipped := false
var _bars: Array = []
## Sprites made a silhouette, to be put back however it ends.
var _lit: Array = []
## What the card says, for a suite to read.
var saying := ""


static func shown() -> bool:
	if DisplayServer.get_name() == "headless" and not plays_headless:
		return false
	return not Net.catching_up()


## --- What it says ---


## The opening words of `encounter`: a boss's on the field first, then the fight's own.
static func opening_text(encounter: EncounterDefinition, bosses: Array) -> String:
	for boss in bosses:
		if boss.opening_card != "":
			return boss.opening_card
	return encounter.opening_card if encounter != null and encounter.opening_card != "" else OPENING_TEXT


## The closing words for `kind` ("victory", "defeat", "fled", "draw").
static func closing_text(encounter: EncounterDefinition, bosses: Array, kind: String) -> String:
	for boss in bosses:
		match kind:
			"victory":
				if boss.victory_card != "":
					return boss.victory_card
			"defeat":
				if boss.defeat_card != "":
					return boss.defeat_card
	if encounter != null:
		match kind:
			"victory":
				if encounter.victory_card != "":
					return encounter.victory_card
			"defeat":
				if encounter.defeat_card != "":
					return encounter.defeat_card
			"fled":
				if encounter.fled_card != "":
					return encounter.fled_card
	match kind:
		"defeat":
			return DEFEAT_TEXT
		"fled":
			return FLED_TEXT
		"draw":
			return DRAW_TEXT
	return VICTORY_TEXT


## --- Opening ---


static func opening(on: Combat):
	if not shown() or on == null or on.encounter == null:
		return
	var card := FightCards.new()
	card.combat = on
	on.add_child(card)
	on.cards_playing = true
	await card._play_opening()
	if is_instance_valid(on):
		on.cards_playing = false
	if is_instance_valid(card):
		card.queue_free()


func _play_opening():
	# The fight's scene has to be up to be frozen.
	await get_tree().process_frame
	await get_tree().process_frame
	while SceneTransition.is_changing():
		await get_tree().process_frame
	_hold_the_board(true)
	var subject := _reveal_subject()
	if combat.encounter.boss_reveal and not subject.is_empty():
		await _reveal(subject)
	if not _skipped and combat.still_running():
		await _shatter_and_title()
	_hold_the_board(false)


## Whoever the reveal is of: the one the encounter names, else the first boss there, else
## nobody.
func _reveal_subject() -> Dictionary:
	var named: String = combat.encounter.reveal_who
	for comb in combat.combatants:
		if comb.get("alive", false) and named != "" and comb.get("combatant_key", "") == named:
			return comb
	for comb in combat.combatants:
		if comb.get("alive", false) and comb.has("boss"):
			return comb
	return {}


func _reveal(subject: Dictionary):
	var flag: String = "reveal_seen:%s" % combat.encounter.display_name
	var again: bool = Campaign.flag(flag)
	Campaign.set_flag(flag)
	_bars_in()
	var sprite = subject.get("sprite")
	var boss: BossDefinition = subject.get("boss")
	var back: Vector2 = combat.camera.position if combat.camera != null else Vector2.ZERO
	if combat.camera != null:
		combat.camera.glide_to(combat.sprite_point(subject) + combat.drawing_offset(subject))
	# On a retry: straight to who it is.
	if not again:
		if sprite != null and is_instance_valid(sprite):
			sprite.modulate = Color(0, 0, 0, 1)
			_lit.append(sprite)
		await _wait(LOOK_SECONDS)
		if _skipped or not combat.still_running():
			_put_lights_back()
			_bars_out()
			return
		_sting(boss.reveal_sound if boss != null and boss.reveal_sound != null else GameSounds.stream(&"boss_reveal"))
		if boss != null and boss.reveal_second_sound != null:
			combat.play_stream(boss.reveal_second_sound)
		combat.shake_camera(16.0)
		if sprite != null and is_instance_valid(sprite):
			var light: Tween = sprite.create_tween().set_ignore_time_scale(true)
			light.tween_property(sprite, "modulate", Color.WHITE, LIGHT_UP_SECONDS)
		_lit.clear()
		await _wait(LIGHT_UP_SECONDS)
		# Its signature: what it was given to come in with, else a roar.
		if subject.get("entrance_style", 0) != 0:
			entrance(combat, subject)
		else:
			_roar(subject)
		await _wait(SIGNATURE_SECONDS)
	if not _skipped and combat.still_running():
		await _portrait_and_plate(subject, boss, SHORT_PLATE_SECONDS if again else PLATE_SECONDS)
	_put_lights_back()
	if combat.camera != null:
		combat.camera.glide_to(back)
	_bars_out()


func _put_lights_back():
	for sprite in _lit:
		if is_instance_valid(sprite):
			sprite.modulate = Color.WHITE
	_lit.clear()


func _roar(subject: Dictionary):
	var sprite = subject.get("sprite")
	if sprite != null and is_instance_valid(sprite) and sprite.has_method("play_skill_and_wait"):
		sprite.play_skill_and_wait("roar")
	combat.shake_camera(20.0)
	var at: Vector2 = MoveFeel.middle_of(combat, subject)
	MoveFeel.spawn(combat, &"shockwave", at, {"colour": Color(1.0, 0.8, 0.6), "reach": Grid.TILE_SIZE * 3.0, "strength": 1.0})
	MoveFeel.screen_flash(combat, Color(1.0, 0.9, 0.8, 0.25), 0.25)


func _portrait_and_plate(subject: Dictionary, boss: BossDefinition, seconds: float):
	var layer := _overlay()
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0, 0, 0, 0.0)
	dim.size = screen
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dim)
	var dimming := dim.create_tween().set_ignore_time_scale(true)
	dimming.tween_property(dim, "color:a", 0.6, 0.2)
	# The art slot, else their icon drawn large.
	var art: Texture2D = boss.reveal_portrait if boss != null and boss.reveal_portrait != null else subject.get("icon")
	var portrait := TextureRect.new()
	portrait.name = "Portrait"
	portrait.texture = art
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.size = Vector2(PORTRAIT_HEIGHT, PORTRAIT_HEIGHT)
	portrait.position = Vector2(screen.x + 40.0, (screen.y - PORTRAIT_HEIGHT) / 2.0)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(portrait)
	var sliding := portrait.create_tween().set_ignore_time_scale(true)
	sliding.tween_property(portrait, "position:x", screen.x - PORTRAIT_HEIGHT - 40.0, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var title: String = boss.title if boss != null else ""
	var name_label := _words(subject.get("name", ""), 56, INK)
	name_label.name = "BossName"
	name_label.position = Vector2(56.0, screen.y * 0.42)
	layer.add_child(name_label)
	saying = subject.get("name", "")
	if title != "":
		var title_label := _words(title, 26, Color(INK, 0.85))
		title_label.name = "BossTitle"
		title_label.position = Vector2(60.0, screen.y * 0.42 + 72.0)
		layer.add_child(title_label)
	await _wait(seconds)
	for node in [dim, portrait, name_label, layer.get_node_or_null("BossTitle")]:
		if node != null and is_instance_valid(node):
			node.queue_free()


func _shatter_and_title():
	var encounter: EncounterDefinition = combat.encounter
	var bosses: Array = combat.living_bosses().map(func(comb): return comb.boss)
	saying = opening_text(encounter, bosses)
	await _freeze_and_shatter()
	if not combat.still_running():
		return
	_bars_in()
	var title := _title(saying, INK)
	_sting(encounter.card_sound if encounter.card_sound != null else GameSounds.stream(&"card_opening"))
	combat.shake_camera(14.0)
	await _wait(TITLE_HOLD_SECONDS)
	_fade_out(title)
	_bars_out()
	await _wait(BAR_SECONDS)


## The screen as it stands, frozen a moment and then falling apart.
func _freeze_and_shatter():
	var layer := _overlay()
	var viewport_texture := get_viewport().get_texture()
	var frozen: Image = viewport_texture.get_image() if viewport_texture != null else null
	if frozen == null or frozen.is_empty():
		return
	var picture := ImageTexture.create_from_image(frozen)
	var screen := Vector2(frozen.get_size())
	var scale_back: Vector2 = get_viewport().get_visible_rect().size / screen
	var scatter := RandomNumberGenerator.new()
	scatter.seed = 7
	var shards := []
	var columns := 7
	var rows := 5
	var points := {}
	for x in columns + 1:
		for y in rows + 1:
			var jitter := Vector2.ZERO
			if x > 0 and x < columns and y > 0 and y < rows:
				jitter = Vector2(scatter.randf_range(-0.35, 0.35) * screen.x / columns, scatter.randf_range(-0.35, 0.35) * screen.y / rows)
			points[Vector2i(x, y)] = Vector2(screen.x * x / columns, screen.y * y / rows) + jitter
	for x in columns:
		for y in rows:
			for triangle in [[Vector2i(x, y), Vector2i(x + 1, y), Vector2i(x, y + 1)], [Vector2i(x + 1, y), Vector2i(x + 1, y + 1), Vector2i(x, y + 1)]]:
				var corners := PackedVector2Array([points[triangle[0]], points[triangle[1]], points[triangle[2]]])
				var middle := (corners[0] + corners[1] + corners[2]) / 3.0
				var shard := Polygon2D.new()
				shard.texture = picture
				shard.uv = corners
				shard.polygon = PackedVector2Array([corners[0] - middle, corners[1] - middle, corners[2] - middle])
				shard.position = middle
				shard.scale = Vector2.ONE
				var holder := Node2D.new()
				holder.scale = scale_back
				holder.add_child(shard)
				layer.add_child(holder)
				shards.append(shard)
	await _wait(FREEZE_SECONDS)
	_sting(PlaceholderSounds.make("impact_shatter"))
	for shard in shards:
		var outward: Vector2 = (shard.position - screen / 2.0).normalized() * scatter.randf_range(60.0, 260.0)
		var flying: Tween = shard.create_tween().set_ignore_time_scale(true).set_parallel(true)
		flying.tween_property(shard, "position", shard.position + outward + Vector2(0, scatter.randf_range(180.0, 520.0)), SHATTER_SECONDS).set_ease(Tween.EASE_IN)
		flying.tween_property(shard, "rotation", scatter.randf_range(-3.0, 3.0), SHATTER_SECONDS)
		flying.tween_property(shard, "modulate:a", 0.0, SHATTER_SECONDS).set_ease(Tween.EASE_IN)
	await _wait(SHATTER_SECONDS if not _skipped else 0.0)
	for shard in shards:
		if is_instance_valid(shard):
			shard.get_parent().queue_free()


## --- Closing ---


static func closing(on: Combat, kind: String):
	if not shown() or on == null:
		return
	var card := FightCards.new()
	card.combat = on
	on.add_child(card)
	on.cards_playing = true
	await card._play_closing(kind)
	if is_instance_valid(on):
		on.cards_playing = false
	if is_instance_valid(card):
		card.queue_free()


func _play_closing(kind: String):
	var bosses: Array = []
	for comb in combat.combatants:
		if comb.has("boss"):
			bosses.append(comb.boss)
	saying = closing_text(combat.encounter, bosses, kind)
	var layer := _overlay()
	Engine.time_scale = CLOSING_SLOW
	var drain := ColorRect.new()
	drain.name = "Drain"
	drain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drain.size = get_viewport().get_visible_rect().size
	var shader := Shader.new()
	shader.code = DRAIN_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	drain.material = material
	layer.add_child(drain)
	var draining := drain.create_tween().set_ignore_time_scale(true)
	draining.tween_method(func(value): material.set_shader_parameter("amount", value), 0.0, 1.0, DRAIN_SECONDS)
	await _wait(DRAIN_SECONDS)
	Engine.time_scale = 1.0
	if combat.still_running():
		_bars_in()
		_title(saying, BAD_INK if kind in ["defeat", "fled"] else GOOD_INK)
		var heard: AudioStream = combat.encounter.card_sound if combat.encounter != null else null
		if heard == null:
			heard = GameSounds.stream({"victory": &"card_victory", "defeat": &"card_defeat"}.get(kind, &"card_fled"))
		_sting(heard)
		await _wait(CLOSING_HOLD_SECONDS)
	Engine.time_scale = 1.0


## --- In between ---


## One of the party has fallen: their name across the screen for a moment, and any last
## words written for them - the encounter's for them first, then their own. None by default.
static func fallen(on: Combat, comb: Dictionary):
	if not shown() or on == null:
		return
	var card := FightCards.new()
	card.combat = on
	on.add_child(card)
	card._show_fallen(comb)


## What `comb` says as they fall, "" for nothing.
static func last_words_of(encounter: EncounterDefinition, comb: Dictionary) -> String:
	var key: String = comb.get("combatant_key", "")
	if encounter != null and encounter.last_words.has(key):
		return str(encounter.last_words[key])
	var definition = CombatantDatabase.combatants.get(key)
	return definition.last_words if definition != null else ""


func _show_fallen(comb: Dictionary):
	var layer := _overlay()
	var screen: Vector2 = get_viewport().get_visible_rect().size
	saying = "%s has fallen" % comb.get("name", "")
	var line := _words(saying, 44, BAD_INK)
	line.name = "Fallen"
	line.size = Vector2(screen.x, 60.0)
	line.position = Vector2(0.0, screen.y * 0.3)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(line)
	var words := last_words_of(combat.encounter, comb)
	if words != "":
		var said := _words("\"%s\"" % words, 22, Color(INK, 0.9))
		said.name = "LastWords"
		said.size = Vector2(screen.x, 40.0)
		said.position = Vector2(0.0, screen.y * 0.3 + 62.0)
		said.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		layer.add_child(said)
	var heard: AudioStream = GameSounds.stream(&"party_falls")
	_sting(heard if heard != null else PlaceholderSounds.make("card_fall"))
	await get_tree().create_timer(2.0, true, false, true).timeout
	queue_free()


## Somebody arriving: their name and what they are, low on the screen, and a sting.
static func plate(on: Combat, comb: Dictionary):
	if not shown() or on == null:
		return
	var card := FightCards.new()
	card.combat = on
	on.add_child(card)
	card._show_plate(comb)


func _show_plate(comb: Dictionary):
	var layer := _overlay()
	var screen: Vector2 = get_viewport().get_visible_rect().size
	saying = comb.get("name", "")
	var line := _words(saying, 34, INK)
	line.name = "Plate"
	line.position = Vector2(-420.0, screen.y * 0.72)
	layer.add_child(line)
	var sliding := line.create_tween().set_ignore_time_scale(true)
	sliding.tween_property(line, "position:x", 48.0, 0.18).set_ease(Tween.EASE_OUT)
	sliding.tween_interval(0.9)
	sliding.tween_property(line, "modulate:a", 0.0, 0.25)
	_sting(PlaceholderSounds.make("card_sting"))
	await get_tree().create_timer(1.4, true, false, true).timeout
	queue_free()


## `comb` coming in, as they were given to (CombatantDefinition.entrance_style): out of
## the ground, down from above, through a door, or - Automatic - in a cloud of dust.
static func entrance(on: Combat, comb: Dictionary):
	var sprite = comb.get("sprite")
	if on == null or sprite == null or not is_instance_valid(sprite):
		return
	var at: Vector2 = MoveFeel.middle_of(on, comb)
	var tile := float(Grid.TILE_SIZE)
	match comb.get("entrance_style", 0):
		CombatantDefinition.EntranceStyle.BURSTS_FROM_GROUND:
			sprite.fly_in(Vector2(0.0, tile * 0.9), 0.28, tile * 0.5)
			MoveFeel.spawn(on, &"rock_break", at, {"colour": Color(0.65, 0.55, 0.42)})
			MoveFeel.dust(on, at, 1.8)
			on.shake_camera(14.0)
		CombatantDefinition.EntranceStyle.DROPS_IN:
			sprite.fly_in(Vector2(0.0, -tile * 6.0), 0.3, 0.0)
			MoveFeel.thud(on, at)
		CombatantDefinition.EntranceStyle.KICKS_DOOR:
			sprite.fly_in(Vector2(-tile * 1.5, 0.0), 0.16, 0.0)
			MoveFeel.spawn(on, &"shatter", at, {"colour": Color(0.72, 0.58, 0.4)})
			MoveFeel.thud(on, at)
		_:
			MoveFeel.dust(on, at, 1.2)
			MoveFeel.thud(on, at)


## --- The pieces ---


func _input(event: InputEvent):
	if not (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton):
		return
	if event.is_pressed() and not event.is_echo():
		_skipped = true
		get_viewport().set_input_as_handled()


## Whether a press has skipped it, for a suite.
func skip():
	_skipped = true


func _wait(seconds: float):
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until and not _skipped and is_instance_valid(combat) and combat.still_running():
		await get_tree().process_frame


func _overlay() -> CanvasLayer:
	if _layer == null:
		_layer = CanvasLayer.new()
		_layer.name = "FightCardsLayer"
		_layer.layer = OVERLAY_LAYER
		add_child(_layer)
	return _layer


func _hold_the_board(on: bool):
	if combat.controller != null and is_instance_valid(combat.controller):
		combat.controller.action_locked = on
	var hud = combat.game_ui
	if hud != null and is_instance_valid(hud) and hud.has_method("set_ui_hidden"):
		hud.set_ui_hidden(on)


func _bars_in():
	if not _bars.is_empty():
		return
	var layer := _overlay()
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var high := screen.y * BAR_SHARE
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.name = "BarTop" if top else "BarBottom"
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.size = Vector2(screen.x, high)
		bar.position = Vector2(0.0, -high if top else screen.y)
		layer.add_child(bar)
		var sliding := bar.create_tween().set_ignore_time_scale(true)
		sliding.tween_property(bar, "position:y", 0.0 if top else screen.y - high, BAR_SECONDS).set_ease(Tween.EASE_OUT)
		_bars.append(bar)


func _bars_out():
	var screen: Vector2 = get_viewport().get_visible_rect().size
	for bar in _bars:
		if is_instance_valid(bar):
			var sliding: Tween = bar.create_tween().set_ignore_time_scale(true)
			var top: bool = bar.name == "BarTop"
			sliding.tween_property(bar, "position:y", -bar.size.y if top else screen.y, BAR_SECONDS)
			sliding.tween_callback(bar.queue_free)
	_bars = []


func _words(text: String, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = GameFonts.HEADER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Big words in the middle of the screen, slammed in from larger.
func _title(text: String, colour: Color) -> Label:
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var label := _words(text, 72, colour)
	label.name = "Title"
	label.size = Vector2(screen.x, 110.0)
	label.position = Vector2(0.0, (screen.y - 110.0) / 2.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.pivot_offset = label.size / 2.0
	label.scale = Vector2(2.4, 2.4)
	label.modulate.a = 0.0
	_overlay().add_child(label)
	var slam := label.create_tween().set_ignore_time_scale(true).set_parallel(true)
	slam.tween_property(label, "scale", Vector2.ONE, SLAM_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	slam.tween_property(label, "modulate:a", 1.0, SLAM_SECONDS * 0.6)
	return label


func _fade_out(label: Label):
	if is_instance_valid(label):
		var fading := label.create_tween().set_ignore_time_scale(true)
		fading.tween_property(label, "modulate:a", 0.0, 0.2)
		fading.tween_callback(label.queue_free)


## The sting: its slot, else a stand-in.
func _sting(stream: AudioStream):
	combat.play_stream(stream if stream != null else PlaceholderSounds.make("card_sting"))
