extends Node
class_name FightCards
## What opens and closes a fight (the designer, 2026-11-05). All placeholder, drawn in code
## behind slots (EncounterDefinition's and BossDefinition's "Title cards"), none of it
## rolled and none of it changing the fight, so each machine shows its own: not while a
## fight is played through to catch up (Net.catching_up), and headless only for a suite
## that asks (plays_headless). Any press skips what is up, but for the opening, which plays to its
## end with the view held (the designer, 2026-11-21); a turn of the wheel never does.
##
## Opening (opening): first of all the screen freezes and shatters (the designer, 2026-11-21).
## Then, on an encounter with Boss Reveal ticked, the view goes to whoever it names between
## letterbox bars - a silhouette lighting up on the sting, its entrance, then its name and
## title with a large portrait over the dimmed arena, shorter once it has been seen - and
## "Conflict Endless" slams in after; with no reveal, it slams in as the view pulls back to
## show the other side ("A look at what you face").
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
## The opening's, slower since the designer's 2026-11-21 ("Make the starting effects of a fight slower"): they were 0.14, 0.55
## and 1.15.
const FREEZE_SECONDS := 0.3
const SHATTER_SECONDS := 0.95
const SLAM_SECONDS := 0.16
const TITLE_HOLD_SECONDS := 1.9
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
## Whether this is a fight's opening, which plays to its end whatever is pressed (_input).
var playing_the_opening := false


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
	card.playing_the_opening = true
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
	# The view is the opening's from the first, while the map's last picture dissolves too.
	_hold_the_view(true)
	while SceneTransition.is_changing():
		await get_tree().process_frame
	_hold_the_board(true)
	# The very start: the screen as it stands, the board without the HUD, frozen and shattered before anything else (the designer,
	# 2026-11-21: "Show battle starting effects of the screen shattering at the very start of combat"; it came after the look at
	# the other side, just before the words).
	await get_tree().process_frame
	await get_tree().process_frame
	if not _skipped and combat.still_running():
		await _freeze_and_shatter()
	# Carried in from the map: on to the party, the board drawn out from them (Combat "The map becomes the board").
	await combat.go_on_from_carried()
	var subject := _reveal_subject()
	if combat.encounter.boss_reveal and not subject.is_empty():
		# The music gives way for the reveal (SoundFollows).
		SoundFollows.give_way(SoundFollows.REVEAL_SECONDS)
		await _reveal(subject)
		if not _skipped and combat.still_running():
			await _the_words()
	elif not _skipped and combat.still_running():
		# The words come as the view pulls back to show who is faced (the designer, 2026-11-21: "show the 'conflict endless' while
		# zooming out to show the enemies"), on their own if there is nobody to look at.
		await _look_at_what_you_face()
	_hold_the_board(false)
	playing_the_opening = false


## --- A look at what you face ---
##
## The proposals of 2026-11-17, section 7. A fight with no boss's reveal opens with the view passing over the other side - the middle
## of whoever of them the party can see - and coming back to where it was, the fight's words up while it goes and is there (the
## designer, 2026-11-21: "show the 'conflict endless' while zooming out to show the enemies"); any press skips it, as it does the
## rest of the opening. Each machine shows its own. PROPOSAL. All of them are framed in the part of the screen the HUD leaves the
## map, the view pulling back as far as that takes and going back to its own zoom after (the designer, 2026-11-17: "if the camera
## is too zoomed, it doesnt fit the enemies when it tries showing them"); it never pushes in.
## Slower since 2026-11-21 (they were 0.55 and 0.6), each glide over exactly that (CameraController.glide_over); and the push
## in on the party, come from a map (Combat.go_on_from_carried), over CARRY_GLIDE_SECONDS.
const FACE_GLIDE_SECONDS := 0.9
const FACE_HOLD_SECONDS := 1.0
const CARRY_GLIDE_SECONDS := 1.4
## How many fights opened with a look at the other side, for a suite.
static var looked := 0


func _look_at_what_you_face():
	if combat.camera == null or not is_instance_valid(combat.camera):
		await _the_words()
		return
	var camera = combat.camera
	var box := Rect2()
	var boxed := false
	var seen := 0
	for comb in combat.combatants:
		if comb.get("alive", false) and comb.get("side", -1) != Combat.Group.PLAYERS and comb.has("position") and not comb.has("object") \
				and not comb.get("illusion", false) and not combat.unseen_by_party(comb):
			# Where they are drawn, and every tile they cover, so somebody big is seen whole.
			var points := [combat.sprite_point(comb) + combat.drawing_offset(comb)]
			for tile in Combat.tiles_of(comb):
				points.append(Grid.tile_to_world(tile))
			for point in points:
				box = box.expand(point) if boxed else Rect2(point, Vector2.ZERO)
				boxed = true
			seen += 1
	if seen == 0:
		await _the_words()
		return
	looked += 1
	# As a blow is framed (CameraController.frame): room round them, in the part of the screen the HUD leaves the map, the zoom
	# pulled back only if they will not fit at the one the view has.
	box = box.grow(Grid.tiles(CameraController.FRAME_ROOM_TILES))
	var room: Rect2 = combat.game_ui.map_view_rect() if combat.game_ui != null and combat.game_ui.has_method("map_view_rect") \
			else camera.get_viewport_rect()
	var back: Vector2 = camera.position
	var back_zoom: float = camera.zoom.x
	var needed := minf(room.size.x / maxf(box.size.x, 1.0), room.size.y / maxf(box.size.y, 1.0))
	var to_zoom := clampf(minf(needed, back_zoom), camera.min_zoom, camera.max_zoom)
	var middle: Vector2 = camera.get_viewport_rect().size * 0.5
	var aim := box.get_center() - (room.get_center() - middle) / to_zoom
	var pulls_back := to_zoom < back_zoom - CameraController.GLIDE_THERE_ZOOM
	if aim.distance_to(back) < Grid.TILE_SIZE * 2.0 and not pulls_back:
		await _the_words()
		return
	camera.glide_over(aim, to_zoom if pulls_back else 0.0, FACE_GLIDE_SECONDS)
	# The words slam in as it goes, are up while it is there, and go as it comes back.
	var words := _slam_in_the_words()
	await _wait(FACE_GLIDE_SECONDS + FACE_HOLD_SECONDS)
	if is_instance_valid(combat) and combat.camera != null and is_instance_valid(combat.camera):
		combat.camera.glide_over(back, back_zoom if pulls_back else 0.0, FACE_GLIDE_SECONDS)
	_words_away(words)
	if not _skipped:
		await _wait(FACE_GLIDE_SECONDS)


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


## The fight's words ("Conflict Endless", or its own or a boss's) slammed in between the bars with their sting: the label, for
## _words_away.
func _slam_in_the_words() -> Label:
	var encounter: EncounterDefinition = combat.encounter
	var bosses: Array = combat.living_bosses().map(func(comb): return comb.boss)
	saying = opening_text(encounter, bosses)
	_bars_in()
	var title := _title(saying, INK)
	_sting(encounter.card_sound if encounter.card_sound != null else GameSounds.stream(&"card_opening"))
	combat.shake_camera(14.0)
	return title


func _words_away(title: Label):
	_fade_out(title)
	_bars_out()


## The words on their own: after a boss's reveal, or with nobody of the other side to look at.
func _the_words():
	var title := _slam_in_the_words()
	await _wait(TITLE_HOLD_SECONDS)
	_words_away(title)
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
	# Whatever read the screen first this frame (the shade, under the figures) leaves the old picture for
	# anything after it, unless it is copied again.
	var fresh := BackBufferCopy.new()
	fresh.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	layer.add_child(fresh)
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


## Where the name plate of somebody arriving comes to rest: low on the left of the screen, but right of the party's portraits and
## everything beside them, and above the HUD along the bottom, wherever the HUD has put them (CombatUI.words_room; the designer,
## 2026-11-20: it sat on the portraits, hard to read). PROPOSAL.
const PLATE_LEFT := 48.0
const PLATE_HEIGHT_AT := 0.72
const PLATE_ROOM := 24.0


## The top-left corner the plate, `size` big, rests at.
func plate_rest(size: Vector2, screen: Vector2) -> Vector2:
	var rest := Vector2(PLATE_LEFT, screen.y * PLATE_HEIGHT_AT)
	var hud = combat.game_ui if combat != null and is_instance_valid(combat) else null
	if hud != null and is_instance_valid(hud) and hud.has_method("words_room"):
		var room: Rect2 = hud.words_room()
		rest.x = maxf(rest.x, room.position.x + PLATE_ROOM)
		rest.y = clampf(room.end.y - size.y - PLATE_ROOM, screen.y * 0.3, rest.y)
	return rest


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
	layer.add_child(line)
	line.reset_size()
	var rest := plate_rest(line.size, screen)
	line.position = Vector2(minf(-420.0, -line.size.x - 40.0), rest.y)
	var sliding := line.create_tween().set_ignore_time_scale(true)
	sliding.tween_property(line, "position:x", rest.x, 0.18).set_ease(Tween.EASE_OUT)
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
	# A fight's opening plays to its end whatever is pressed, and nothing else answers meanwhile (the designer, 2026-11-21: "Make
	# the starting effects of a fight slower and unskippable (right now if i zoom in or out during them it sorta skips them)").
	if playing_the_opening:
		get_viewport().set_input_as_handled()
		return
	# Anything else up is skipped by a press; a turn of the wheel is the view being zoomed, not a press.
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
		return
	if event.is_pressed() and not event.is_echo():
		_skipped = true
		get_viewport().set_input_as_handled()


## Cuts it short, for a suite: a player's press no longer does, not of the opening.
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
	_hold_the_view(on)


## The view, which only the opening moves meanwhile (CameraController.held).
func _hold_the_view(on: bool):
	if combat.camera != null and is_instance_valid(combat.camera) and "held" in combat.camera:
		combat.camera.held = on
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
