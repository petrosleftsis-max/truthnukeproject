extends Control
class_name CardFighter
## One side of a fight in the card game as it is drawn (docs/card_game.md "How it feels"): an enemy (what it will do next over it,
## its figure, its name, its health and Block, its statuses as badges) or the player (their picture, and the same below it). The
## screen (CardStage) tells it what happened and it shows it: knocked back and flashing white when hit, its health draining, its
## Block popping in, shaking and shattering, its statuses flying in and wearing off, stepping forward to act, falling.
##
## An enemy that borrows a main-game combatant (Borrow Picture From) and has no picture of its own stands as that combatant's figure
## (CardFigure): its own idle, slower when hurt, and its own attack when it acts.

signal pressed(fighter: CardFighter)
## The health it shows changed (for the run's bar to follow the player's).
signal health_shown(now: int, most: int)

const SIZE := Vector2(200, 352)
## Where its figure or picture stands, in the panel.
const FIGURE := Rect2(10, 46, 180, 176)
const BAR := Rect2(42, 254, 148, 18)
const SHIELD := Rect2(4, 245, 36, 36)
const BADGES_AT := Vector2(8, 286)
const BADGES_A_ROW := 6
const INTENT_SIDE := 34.0
## An attack this heavy (each hit) shows the heavy sword.
const HEAVY_INTENT := 12
const INK := Color("dce8f5")
const MUTED := Color("8296a9")
const PANEL := Color(0.105, 0.135, 0.18, 0.6)
const EDGE := Color("2b3947")
const AIMABLE := Color("4a86c8")
const AIMED := Color("a8d0ff")
const HEALTH := Color("c0453a")
const INTENT_INK := Color("f0a070")
const BLOCK_INK := Color("7fb4ea")
## How long its count of health takes to run to the new number.
const COUNT_SECONDS := 0.35

const _SHADER := """shader_type canvas_item;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float grey : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec4 c = COLOR;
	float g = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	c.rgb = mix(c.rgb, vec3(g * 0.8), grey);
	c.rgb = mix(c.rgb, vec3(1.0), flash);
	COLOR = c;
}"""

static var _shader: Shader = null

## -1 for the player, else the enemy's index.
var who := -1
var alive := true
var hp := 0
var max_hp := 1
var block := 0
## Its figure, when it stands as one.
var figure: CardFigure = null
## key -> CardBadge, in the order they came.
var badges := {}
var _badge_order: Array = []

var _body: Control
var _panel_box: StyleBoxFlat
var _picture: Control = null
var _material: ShaderMaterial
var _name: Label
var _bar: ProgressBar
var _bar_label: Label
var _shield: Control
var _shield_label: Label
var _badges: Control
var _intent: HBoxContainer
var _intent_damage := -1
var _intent_name := ""
var _intent_signature := ""
var _base_name := ""
var _phase := 0.0
var _count_tween: Tween = null
var _move_tween: Tween = null
var _shield_tween: Tween = null
var _flash_tween: Tween = null
var _stepped := false


func _init():
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _shader == null:
		_shader = Shader.new()
		_shader.code = _SHADER
	_material = ShaderMaterial.new()
	_material.shader = _shader
	_body = Control.new()
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.size = SIZE
	add_child(_body)
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size = SIZE
	_panel_box = StyleBoxFlat.new()
	_panel_box.bg_color = PANEL
	_panel_box.border_color = EDGE
	_panel_box.set_border_width_all(2)
	_panel_box.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", _panel_box)
	_body.add_child(panel)
	_intent = HBoxContainer.new()
	_intent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intent.alignment = BoxContainer.ALIGNMENT_CENTER
	_intent.add_theme_constant_override("separation", 3)
	_intent.position = Vector2(0, 6)
	_intent.size = Vector2(SIZE.x, INTENT_SIDE)
	_intent.pivot_offset = Vector2(SIZE.x / 2.0, INTENT_SIDE / 2.0)
	_body.add_child(_intent)
	_name = Label.new()
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name.theme_type_variation = GameFonts.HEADER
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.add_theme_color_override("font_color", INK)
	_name.add_theme_font_size_override("font_size", 17)
	_name.position = Vector2(0, FIGURE.end.y + 4)
	_name.size = Vector2(SIZE.x, 24)
	_name.clip_text = true
	_body.add_child(_name)
	_bar = ProgressBar.new()
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.show_percentage = false
	_bar.position = BAR.position
	_bar.size = BAR.size
	var fill := StyleBoxFlat.new()
	fill.bg_color = HEALTH
	fill.set_corner_radius_all(3)
	_bar.add_theme_stylebox_override("fill", fill)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.05, 0.06, 0.08, 0.9)
	back.set_corner_radius_all(3)
	_bar.add_theme_stylebox_override("background", back)
	_body.add_child(_bar)
	_bar_label = Label.new()
	_bar_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bar_label.add_theme_font_size_override("font_size", 13)
	_bar_label.add_theme_color_override("font_color", Color.WHITE)
	_bar_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_bar_label.add_theme_constant_override("outline_size", 4)
	_bar_label.position = BAR.position + Vector2(0, -1)
	_bar_label.size = BAR.size
	_body.add_child(_bar_label)
	_shield = Control.new()
	_shield.mouse_filter = Control.MOUSE_FILTER_STOP
	_shield.tooltip_text = "Block: soaks up damage before health. Gone at the start of its next turn."
	_shield.position = SHIELD.position
	_shield.size = SHIELD.size
	_shield.pivot_offset = SHIELD.size / 2.0
	_shield.visible = false
	var shield_icon := CardIcon.new()
	shield_icon.size = SHIELD.size
	shield_icon.show_icon(&"block_shield")
	_shield.add_child(shield_icon)
	_shield_label = Label.new()
	_shield_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shield_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shield_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_shield_label.add_theme_font_size_override("font_size", 15)
	_shield_label.add_theme_color_override("font_color", Color.WHITE)
	_shield_label.add_theme_color_override("font_outline_color", Color(0.05, 0.1, 0.2, 0.95))
	_shield_label.add_theme_constant_override("outline_size", 5)
	_shield_label.size = SHIELD.size
	_shield.add_child(_shield_label)
	_body.add_child(_shield)
	_badges = Control.new()
	_badges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badges.position = BADGES_AT
	_badges.size = Vector2(SIZE.x - 16, 64)
	_body.add_child(_badges)


## --- Who it is ---


## As enemy `index` of a fight, `enemy` being its {name, hp, max_hp, block, statuses, definition...}.
func setup_enemy(index: int, enemy: Dictionary) -> CardFighter:
	who = index
	_name.text = enemy.name
	_base_name = str(enemy.name)
	var definition: CardEnemyDefinition = enemy.definition
	var frames := frames_of(definition)
	if definition.picture == null and frames != null:
		figure = CardFigure.new()
		figure.position = FIGURE.position
		figure.size = FIGURE.size
		_body.add_child(figure)
		figure.setup(frames)
		figure.sprite.material = _material
		_picture = figure
	else:
		_put_picture(definition.picture_now(), &"")
	_over_picture()
	_phase = float(index) * 1.7
	sync(enemy, {})
	return self


## What it will do, its name, health, Block and statuses drawn over its figure, never under it.
func _over_picture():
	for part in [_name, _bar, _bar_label, _shield, _badges, _intent]:
		_body.move_child(part, -1)


## As the player, `player` being their {name, hp, max_hp, block, statuses}.
func setup_player(player: Dictionary, index: int = 0) -> CardFighter:
	who = -1 - index
	_name.text = player.name
	# Their character's own picture (CardCharacterDefinition.picture), else the player's slot.
	var definition := CardDatabase.character(str(player.get("character", "")))
	var own: Texture2D = definition.picture if definition != null else null
	_put_picture(own if own != null else CardLooks.picture(&"player_picture"), &"player_picture")
	_over_picture()
	_intent.visible = false
	mouse_filter = Control.MOUSE_FILTER_PASS
	sync(player, {})
	return self


func _put_picture(texture: Texture2D, stand_in: StringName):
	if texture != null:
		var art := TextureRect.new()
		art.texture = texture
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.position = FIGURE.position
		art.size = FIGURE.size
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.material = _material
		_body.add_child(art)
		_picture = art
		return
	var drawn := _StandIn.new()
	drawn.position = FIGURE.position
	drawn.size = FIGURE.size
	drawn.what = stand_in
	drawn.material = _material
	_body.add_child(drawn)
	_picture = drawn


## The main-game combatant's animations an enemy borrows, or null.
static func frames_of(definition: CardEnemyDefinition) -> SpriteFrames:
	if definition == null or definition.borrow_picture_from == "":
		return null
	var tree := Engine.get_main_loop() as SceneTree
	var combatants = tree.root.get_node_or_null("/root/CombatantDatabase") if tree != null else null
	if combatants == null or not combatants.combatants.has(definition.borrow_picture_from):
		return null
	return combatants.combatants[definition.borrow_picture_from].sprite_frames


## Shows `fighter` as it is now, at once: health, Block, statuses (and whether it stands). `intent`: what it will do, for an enemy.
func sync(fighter: Dictionary, intent: Dictionary):
	show_hp(int(fighter.hp), int(fighter.max_hp), false)
	show_block(int(fighter.block), false)
	var statuses: Dictionary = fighter.statuses
	for key in badges.keys():
		if not statuses.has(key):
			show_status(key, 0, false)
	for key in statuses:
		show_status(key, int(statuses[key]), false)
	if fighter.has("alive") and not fighter.alive and alive:
		fall(false)
	if not intent.is_empty() and alive:
		show_intent(intent, false)


## --- Health and Block ---


func show_hp(now: int, most: int, animated: bool = true):
	var before := hp
	hp = now
	max_hp = maxi(most, 1)
	_bar.max_value = max_hp
	if animated and CardFeel.shown() and is_inside_tree():
		if now < before:
			HealthBarMarks.drain(_bar, before, now, max_hp)
		elif now > before:
			HealthBarMarks.fill(_bar, before, now, max_hp)
	_bar.value = now
	if figure != null:
		figure.set_health_share(float(now) / float(max_hp))
	if before != now:
		health_shown.emit(now, max_hp)
	if _count_tween != null and _count_tween.is_valid():
		_count_tween.kill()
	if not animated or not CardFeel.shown() or not is_inside_tree() or before == now:
		_write_hp(float(now))
		return
	_count_tween = create_tween()
	_count_tween.tween_method(_write_hp, float(before), float(now), COUNT_SECONDS).set_ease(Tween.EASE_OUT)


func _write_hp(value: float):
	_bar_label.text = "%d/%d" % [roundi(value), max_hp]


## Marks on its health bar the stretch a card aimed at it would take (`lost`), or nothing for 0 (the tactics fights' preview,
## HealthBarMarks).
func preview(lost: int):
	if lost <= 0 or not alive:
		HealthBarMarks.clear_preview(_bar)
		return
	HealthBarMarks.show_preview(_bar, hp, -lost, max_hp)


## What its bar is marking now, for a suite: the preview's node, or null.
func previewing() -> Node:
	return _bar.get_node_or_null("Preview")


## Block now `now`. `struck`: it went down to a blow (it shakes; to nothing, it shatters, the shards the screen's).
func show_block(now: int, animated: bool = true, struck: bool = false):
	var before := block
	block = maxi(now, 0)
	_shield_label.text = str(block)
	if _shield_tween != null and _shield_tween.is_valid():
		_shield_tween.kill()
	_shield.rotation = 0.0
	if not animated or not CardFeel.shown() or not is_inside_tree():
		_shield.visible = block > 0 and alive
		_shield.scale = Vector2.ONE
		_shield.modulate.a = 1.0
		return
	_shield_tween = create_tween()
	if block > before:
		_shield.visible = true
		_shield.modulate.a = 1.0
		_shield.scale = Vector2.ONE * (0.3 if before == 0 else 1.0)
		_shield_tween.tween_property(_shield, "scale", Vector2.ONE * 1.25, 0.1).set_ease(Tween.EASE_OUT)
		_shield_tween.tween_property(_shield, "scale", Vector2.ONE, 0.14).set_ease(Tween.EASE_IN_OUT)
	elif block > 0 and struck:
		for swing in [0.25, -0.2, 0.12, 0.0]:
			_shield_tween.tween_property(_shield, "rotation", swing, 0.04)
	elif block == 0 and struck:
		_shield.visible = false
	elif block == 0:
		_shield_tween.tween_property(_shield, "modulate:a", 0.0, 0.25)
		_shield_tween.tween_callback(func(): _shield.visible = false)


## --- Statuses ---


## Status `key` now `amount` (nothing: gone). A new one waits hidden for its flight to land (`land`) unless `at_once`.
func show_status(key: StringName, amount: int, animated: bool = true, at_once: bool = true):
	var badge: CardBadge = badges.get(key)
	if amount <= 0:
		if badge != null:
			badges.erase(key)
			_badge_order.erase(key)
			if animated:
				badge.shrink_away()
			else:
				badge.queue_free()
			_place_badges(animated)
		return
	if badge == null:
		badge = CardBadge.new().setup(key, amount)
		badges[key] = badge
		_badge_order.append(key)
		_badges.add_child(badge)
		_place_badges(false)
		if animated and not at_once:
			badge.visible = false
		elif animated:
			badge.pop_in()
		return
	badge.set_amount(amount, animated)


## A flown status landed on its badge: it shows, popping in.
func land(key: StringName):
	var badge: CardBadge = badges.get(key)
	if badge != null and is_instance_valid(badge):
		badge.visible = true
		badge.pop_in()


func _place_badges(animated: bool):
	for i in _badge_order.size():
		var badge: CardBadge = badges.get(_badge_order[i])
		if badge == null:
			continue
		var at := Vector2((i % BADGES_A_ROW) * (CardBadge.SIDE + 3.0), floori(i / float(BADGES_A_ROW)) * (CardBadge.SIDE + 3.0))
		if animated and CardFeel.shown() and is_inside_tree():
			badge.create_tween().tween_property(badge, "position", at, 0.15).set_ease(Tween.EASE_OUT)
		else:
			badge.position = at


## Where status `key`'s badge sits (or will), global: where a status flies to.
func badge_place(key: StringName) -> Vector2:
	var i := _badge_order.find(key)
	if i < 0:
		i = _badge_order.size()
	var at := Vector2((i % BADGES_A_ROW) * (CardBadge.SIDE + 3.0), floori(i / float(BADGES_A_ROW)) * (CardBadge.SIDE + 3.0))
	return global_position + BADGES_AT + at + Vector2.ONE * CardBadge.SIDE / 2.0


## --- What it will do ---


## Shows `intent` (CardBattle.intent_of) over it: pictures (CardLooks' intent_*), the attack's number, a countdown's turns, the words
## in its tooltip, and with Second Sight its plan after it, smaller and dimmed ("then"). `words`: those words. It pops in when
## `animated`, and pulses when only its number changed.
func show_intent(intent: Dictionary, animated: bool = true, words: String = ""):
	if who < 0:
		return
	var damage := int(intent.get("damage", 0))
	var same_move := str(intent.get("name", "")) == _intent_name and _intent.get_child_count() > 0
	for child in _intent.get_children():
		_intent.remove_child(child)
		child.queue_free()
	_intent_name = str(intent.get("name", ""))
	_intent_signature = signature_of(intent)
	_intent.tooltip_text = words
	_intent.mouse_filter = Control.MOUSE_FILTER_PASS if words != "" else Control.MOUSE_FILTER_IGNORE
	if not alive:
		_intent.visible = false
		return
	_intent.visible = true
	_intent_parts(intent, 1.0)
	var then = intent.get("then")
	if then is Dictionary and not then.is_empty() and not intent.get("hidden", false):
		var label := Label.new()
		label.text = "then"
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_color", MUTED)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_intent.add_child(label)
		var from := _intent.get_child_count()
		_intent_parts(then, 0.62)
		for i in range(from, _intent.get_child_count()):
			_intent.get_child(i).modulate.a = 0.6
	var damage_changed := same_move and damage != _intent_damage
	_intent_damage = damage
	_intent.modulate.a = 1.0
	_intent.scale = Vector2.ONE
	if not animated or not CardFeel.shown() or not is_inside_tree():
		return
	# The same move with its number (or its countdown) changed pulses; a new one pops in; otherwise nothing moves.
	if same_move and damage_changed:
		var pulse := create_tween()
		pulse.tween_property(_intent, "scale", Vector2.ONE * 1.3, 0.08)
		pulse.tween_property(_intent, "scale", Vector2.ONE, 0.16)
	elif not same_move:
		_intent.scale = Vector2.ONE * 0.3
		create_tween().tween_property(_intent, "scale", Vector2.ONE, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


## Whether it already shows `intent` (the same move and number, countdown and plan).
func shows_intent(intent: Dictionary) -> bool:
	return _intent.visible and _intent_signature == signature_of(intent) and _intent.get_child_count() > 0


## What tells two intents apart on the screen.
static func signature_of(intent: Dictionary) -> String:
	var then = intent.get("then")
	return "%s|%d|%d|%s|%s|%s" % [intent.get("name", ""), int(intent.get("damage", 0)), int(intent.get("countdown", 0)),
		str(intent.get("hidden", false)), str(intent.get("encrypted", false)), then.get("name", "") if then is Dictionary else ""]


## The pictures and numbers of one intent (or a plan, at `share` of the size), added to the row over it.
func _intent_parts(intent: Dictionary, share: float):
	var side := INTENT_SIDE * share
	var start := _intent.get_child_count()
	if intent.get("hidden", false):
		# Encrypted (the twist "what the system lets him see"): its own picture, until it is Scanned.
		_intent_icon(&"intent_encrypted" if intent.get("encrypted", false) else &"intent_unknown", side)
		return
	if intent.get("asleep", false):
		_intent_icon(&"intent_asleep", side)
		return
	var damage := int(intent.get("damage", 0))
	var hits := int(intent.get("hits", 1))
	var helps := int(intent.get("helps", 0)) != CardEnemyMove.Helps.ITSELF
	if damage > 0:
		_intent_icon(&"intent_attack_heavy" if damage >= HEAVY_INTENT else &"intent_attack", side)
		_intent_number(str(damage) if hits <= 1 else "%dx%d" % [damage, hits], share, INTENT_INK)
	if int(intent.get("block", 0)) > 0:
		_intent_icon(&"intent_curled" if intent.get("curled", false) else (&"intent_help" if helps else &"intent_block"), side)
	if int(intent.get("heal", 0)) > 0:
		_intent_icon(&"intent_heal", side)
	var apply: StringName = intent.get("apply", &"")
	if apply != &"":
		var status_icon := CardIcon.new()
		status_icon.custom_minimum_size = Vector2.ONE * side * 0.85
		status_icon.show_icon(StringName("status_" + String(apply)), null, CardBadge.colour_of(apply), CardStatus.name_of(apply).substr(0, 1))
		_intent.add_child(status_icon)
	if intent.get("gain", &"") != &"":
		_intent_icon(&"intent_help" if helps else &"intent_grow", side)
	if str(intent.get("adds", "")) != "":
		_intent_icon(&"intent_card", side)
	if int(intent.get("steals", 0)) > 0:
		_intent_icon(&"intent_steal", side)
	if intent.get("summons", false):
		_intent_icon(&"intent_summon", side)
	# Tethers (twist 7): one of its own tied onto you, or yours cut.
	if str(intent.get("ties", "")) != "":
		_intent_icon(&"intent_tether", side)
	if int(intent.get("cuts", 0)) > 0:
		_intent_icon(&"intent_cut", side)
	if _intent.get_child_count() == start:
		var kind: int = intent.get("intent", CardEnemyMove.Intent.NOTHING)
		_intent_icon(&"intent_unknown" if kind == CardEnemyMove.Intent.NOTHING else &"intent_curse", side)
	# A countdown: how many of its turns before it lands.
	var countdown := int(intent.get("countdown", 0))
	if countdown > 0:
		_intent_icon(&"intent_countdown", side * 0.7)
		_intent_number(str(countdown), share, Color("ffe08a"))


func _intent_number(text: String, share: float, colour: Color):
	var number := Label.new()
	number.text = text
	number.theme_type_variation = GameFonts.HEADER
	number.add_theme_font_size_override("font_size", int(20 * share))
	number.add_theme_color_override("font_color", colour)
	number.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	number.add_theme_constant_override("outline_size", 5)
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intent.add_child(number)


func _intent_icon(slot: StringName, side: float = INTENT_SIDE):
	var icon := CardIcon.new()
	icon.custom_minimum_size = Vector2.ONE * side
	icon.show_icon(slot)
	_intent.add_child(icon)


## Fallen for now (Linked): where its health was, how many turns before it rises again; 0 for gone for good.
func show_rising(left: int):
	_bar_label.visible = left > 0
	_bar_label.text = "Rises in %d" % left
	_bar_label.add_theme_color_override("font_color", Color("b8a8f0"))


## Its intent flares and goes: it is acting on it.
func intent_flare():
	if not CardFeel.shown() or not is_inside_tree():
		_intent.visible = false
		return
	var tween := create_tween()
	tween.tween_property(_intent, "scale", Vector2.ONE * 1.45, 0.12).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_intent, "modulate:a", 0.0, 0.22)
	tween.tween_callback(func():
		_intent.visible = false
		_intent_name = ""
		_intent_signature = "")


## Where its intent sits, global.
func intent_place() -> Vector2:
	return global_position + Vector2(SIZE.x / 2.0, 6.0 + INTENT_SIDE / 2.0) * scale


## --- Moving ---


## The middle of its figure, global, at rest.
func centre() -> Vector2:
	return global_position + FIGURE.get_center() * scale


## A little over its figure's head, global: where numbers jump out.
func head() -> Vector2:
	return global_position + Vector2(FIGURE.get_center().x, FIGURE.position.y + 34.0) * scale


func shield_place() -> Vector2:
	return global_position + SHIELD.get_center() * scale


## Knocked `pixels` along `away` and springing back.
func knock(away: Vector2, pixels: float):
	if not CardFeel.shown() or not is_inside_tree() or pixels <= 0.0:
		return
	_kill_move()
	_move_tween = create_tween()
	var to := _rest() + away.normalized() * pixels
	_move_tween.tween_property(_body, "position", to, 0.05).set_ease(Tween.EASE_OUT)
	_move_tween.tween_property(_body, "position", _rest(), 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


## Steps `pixels` towards `toward` (a global place): acting with no animation of its own.
func step(toward: Vector2, pixels: float = 38.0):
	if not CardFeel.shown() or not is_inside_tree():
		return
	_kill_move()
	_stepped = true
	_move_tween = create_tween()
	_move_tween.tween_property(_body, "position", (toward - centre()).normalized() * pixels, CardFeel.time(0.14)).set_ease(Tween.EASE_OUT)


func step_back():
	if not _stepped:
		return
	_stepped = false
	if not CardFeel.shown() or not is_inside_tree():
		_body.position = Vector2.ZERO
		return
	_kill_move()
	_move_tween = create_tween()
	_move_tween.tween_property(_body, "position", Vector2.ZERO, CardFeel.time(0.18)).set_ease(Tween.EASE_IN_OUT)


func _rest() -> Vector2:
	return Vector2.ZERO


func _kill_move():
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()


## Flashes white for a moment, `strength` of the Flashes dial's share.
func flash(strength: float = 0.85, seconds: float = 0.14):
	var amount := strength * Comfort.share(Comfort.FLASHES)
	if not CardFeel.shown() or not is_inside_tree() or amount <= 0.0:
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_material.set_shader_parameter("flash", amount)
	_flash_tween = create_tween()
	_flash_tween.tween_method(_set_flash, amount, 0.0, seconds)


func _set_flash(value: float):
	_material.set_shader_parameter("flash", value)


## A hit as a glitch (the hacking juice, docs/proposals_2026-11-26_card_juice.md section 11): the figure torn into offset strips for
## an instant, `strength` of the Flashes dial's share. Only to look at.
func glitch(strength: float = 1.0, seconds: float = 0.13):
	var amount := strength * Comfort.share(Comfort.FLASHES)
	if not CardFeel.shown() or not is_inside_tree() or amount <= 0.0:
		return
	if _glitch == null:
		if _glitch_shader == null:
			_glitch_shader = Shader.new()
			_glitch_shader.code = _GLITCH_SHADER
		_glitch = ColorRect.new()
		_glitch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_glitch.position = FIGURE.position
		_glitch.size = FIGURE.size
		var tearing := ShaderMaterial.new()
		tearing.shader = _glitch_shader
		_glitch.material = tearing
		_body.add_child(_glitch)
	_body.move_child(_glitch, -1)
	_glitch.visible = true
	var torn: ShaderMaterial = _glitch.material
	torn.set_shader_parameter("tear", 0.035 * amount)
	torn.set_shader_parameter("seed", randf() * 100.0)
	if _glitch_tween != null and _glitch_tween.is_valid():
		_glitch_tween.kill()
	_glitch_tween = create_tween()
	_glitch_tween.tween_interval(seconds)
	_glitch_tween.tween_callback(_glitch_over)


func _glitch_over():
	if _glitch != null and is_instance_valid(_glitch):
		_glitch.visible = false


var _glitch: ColorRect = null
var _glitch_tween: Tween = null
static var _glitch_shader: Shader = null
const _GLITCH_SHADER := """shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform float tear = 0.03;
uniform float seed = 0.0;
void fragment() {
	float strip = floor(UV.y * 11.0);
	float r = fract(sin(strip * 91.73 + seed) * 43758.5453);
	float shift = (r - 0.5) * tear * step(0.35, r);
	vec2 uv = SCREEN_UV + vec2(shift, 0.0);
	vec3 c = textureLod(screen, uv, 0.0).rgb;
	c.r = textureLod(screen, uv + vec2(tear * 0.2, 0.0), 0.0).r;
	COLOR = vec4(c, 1.0);
}"""


func _set_grey(value: float):
	_material.set_shader_parameter("grey", value)


## Comes in from `from` (an offset), `delay` seconds from now: a fight beginning.
func arrive(from: Vector2, delay: float):
	if not CardFeel.shown() or not is_inside_tree():
		return
	_body.position = from
	_body.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_property(_body, "position", Vector2.ZERO, CardFeel.time(0.38)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.parallel().tween_property(_body, "modulate:a", 1.0, CardFeel.time(0.25))


## Falls: a flash, then grey, sinking and fading; what it would do, its Block and its statuses gone at once.
func fall(animated: bool = true):
	alive = false
	_intent.visible = false
	_shield.visible = false
	_bar.visible = false
	_bar_label.visible = false
	for key in badges:
		badges[key].queue_free()
	badges.clear()
	_badge_order.clear()
	_name.add_theme_color_override("font_color", MUTED)
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	if figure != null and figure.sprite != null:
		figure.sprite.pause()
	if not animated or not CardFeel.shown() or not is_inside_tree():
		_set_grey(1.0)
		_body.modulate.a = 0.45
		return
	_kill_move()
	_material.set_shader_parameter("flash", 1.0 * Comfort.share(Comfort.FLASHES))
	var tween := create_tween()
	tween.tween_method(_set_flash, 1.0 * Comfort.share(Comfort.FLASHES), 0.0, 0.18)
	tween.parallel().tween_method(_set_grey, 0.0, 1.0, 0.45)
	tween.parallel().tween_property(_body, "position", Vector2(0, 26), 0.55).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(_body, "modulate:a", 0.45, 0.55)


## 0: nothing aimed at it; 1: a card chosen could be aimed at it; 2: aimed at it.
func set_aim(state: int):
	_panel_box.border_color = [EDGE, AIMABLE, AIMED][clampi(state, 0, 2)]
	_panel_box.set_border_width_all(3 if state == 2 else 2)


## Its rest, global: where it is pressed and pointed at.
func rest_rect() -> Rect2:
	return Rect2(global_position, SIZE * scale)


func _process(delta: float):
	_phase += delta
	if _intent.visible and who >= 0:
		_intent.position.y = 6.0 + sin(_phase * 2.3) * 3.0


func _gui_input(event: InputEvent):
	if who >= 0 and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		accept_event()
		pressed.emit(self)


## A stand-in figure while there is no picture: a plain shape.
class _StandIn extends Control:
	var what: StringName = &""

	func _draw():
		if what == &"player_picture":
			var middle := size / 2.0
			draw_circle(middle + Vector2(0, -size.y * 0.22), size.y * 0.13, Color("4a5a6e"))
			var body := PackedVector2Array([middle + Vector2(-size.x * 0.22, size.y * 0.45), middle + Vector2(-size.x * 0.16, -size.y * 0.02),
				middle + Vector2(0, -size.y * 0.07), middle + Vector2(size.x * 0.16, -size.y * 0.02), middle + Vector2(size.x * 0.22, size.y * 0.45)])
			draw_colored_polygon(body, Color("4a5a6e"))
			return
		draw_rect(Rect2(Vector2(size.x * 0.08, 0), Vector2(size.x * 0.84, size.y)), Color("3a2630"))
