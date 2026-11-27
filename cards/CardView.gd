extends Control
class_name CardView
## One card of the card game, drawn (docs/card_game.md): its cost, name, picture (the card's slot, else a stand-in in its type's
## colour), type and rules, worked out against a fight when there is one, with a number the fight has changed coloured (green
## higher, red lower). It can lie face down (CardLooks' card back) and be turned over, glow while it can be played, shake its head
## when it cannot, flash, and burn away (docs/card_game.md "How it feels").
##
## Pressed and let go, it says so (`chosen`); the screen decides what that means. In a hand (`in_hand`, CardHand) the hand places it,
## lifts it and reads the pointer for it; anywhere else it rises a little under the pointer itself and says so (`hovered`), for the
## panel of what its words mean.

signal chosen(view: CardView)
signal hovered(view: CardView, on: bool)

const SIZE := Vector2(150, 212)
## Attack, Skill, Power, Status (what enemies put in the player's piles), Tether (twist 7).
const TYPE_COLOURS := [Color("b05a45"), Color("4a7fb8"), Color("b8963f"), Color("6a6470"), Color("4aa392")]
## Each type's face slot (CardLooks).
const FACES := [&"card_face_attack", &"card_face_skill", &"card_face_power", &"card_face_status", &"card_face_tether"]
## The Message's own face, and its edge (twist 10).
const MESSAGE_FACE := &"card_face_message"
const MESSAGE_EDGE := Color("e8d8a0")
const RARITY_EDGES := [Color("6f7c8a"), Color("9aa7b5"), Color("4a86c8"), Color("d8b24a")]
const UPGRADED_EDGE := Color("7fe0a2")
const INK := Color("dce8f5")
const INK_DIM := Color("c2ceda")
const CARD := Color("1c2531")
const CARD_LIT := Color("24344a")
## A card in the hand that cannot be played just now: dimmed, not see-through (the cards behind it would show).
const UNPLAYABLE := Color(0.6, 0.62, 0.68)
## The glow of a card that can be played, and of the one chosen.
const GLOW := Color(0.42, 0.72, 1.0, 0.85)
const GLOW_CHOSEN := Color(0.75, 0.9, 1.0, 1.0)
## How much it grows under the pointer, outside a hand.
const HOVER_SCALE := 1.05
const HOVER_SECONDS := 0.1
## A refusal: the head shake's swing and length (as the interface's buttons do, UiFeel).
const SHAKE_DEGREES := 4.0
const SHAKE_SECONDS := 0.26

var key := ""
var upgraded := false
## The card as its deck or pile has it (show_card's `card_entry`): the Message's words and cost.
var entry: Dictionary = {}
## Its place in whatever it was drawn for (the hand, the deck, a reward), for the screen.
var index := -1
## In a hand: the hand moves it and reads the pointer for it.
var in_hand := false:
	set(on):
		in_hand = on
		mouse_filter = Control.MOUSE_FILTER_IGNORE if on else Control.MOUSE_FILTER_STOP
var face_down := false

var _body: Control
var _glow: Panel
var _glow_box: StyleBoxFlat
var _box: StyleBoxFlat
var _edge_box: StyleBoxFlat
var _face: TextureRect
var _cost: Label
var _title: Label
var _picture: TextureRect
var _stand_in: ColorRect
var _stand_in_letter: Label
var _type: Label
var _text: RichTextLabel
var _price: Label
var _back: CardIcon
var _cost_badge: Panel
var _flash: ColorRect
var _selected := false
var _hovered := false
var _playable := true
var _glow_tween: Tween = null
var _lift_tween: Tween = null


func _init():
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	pivot_offset = SIZE / 2.0
	# The glow, under everything, a soft light about the card's edge.
	_glow = Panel.new()
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_glow_box = StyleBoxFlat.new()
	_glow_box.bg_color = Color(0, 0, 0, 0)
	_glow_box.set_corner_radius_all(10)
	_glow_box.shadow_color = GLOW
	_glow_box.shadow_size = 12
	_glow_box.border_color = GLOW
	_glow_box.set_border_width_all(2)
	_glow_box.set_expand_margin_all(2)
	_glow.add_theme_stylebox_override("panel", _glow_box)
	_glow.modulate.a = 0.0
	add_child(_glow)
	# Everything else, on a body of its own: turned over by its width, shaken by its rotation, while the card itself is placed.
	_body = Control.new()
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.size = SIZE
	_body.pivot_offset = SIZE / 2.0
	add_child(_body)
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size = SIZE
	_box = StyleBoxFlat.new()
	_box.bg_color = CARD
	_box.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", _box)
	_body.add_child(panel)
	_face = TextureRect.new()
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.size = SIZE
	_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_face.stretch_mode = TextureRect.STRETCH_SCALE
	_face.visible = false
	_body.add_child(_face)
	var edge := Panel.new()
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge.size = SIZE
	_edge_box = StyleBoxFlat.new()
	_edge_box.draw_center = false
	_edge_box.set_border_width_all(3)
	_edge_box.set_corner_radius_all(8)
	edge.add_theme_stylebox_override("panel", _edge_box)
	_body.add_child(edge)
	_title = _label(Vector2(30, 6), Vector2(SIZE.x - 36, 22), 14, INK)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.clip_text = true
	_title.theme_type_variation = GameFonts.HEADER
	_stand_in = ColorRect.new()
	_stand_in.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stand_in.position = Vector2(10, 32)
	_stand_in.size = Vector2(SIZE.x - 20, 70)
	_body.add_child(_stand_in)
	_stand_in_letter = _label(Vector2(10, 32), Vector2(SIZE.x - 20, 70), 34, Color(1, 1, 1, 0.55))
	_stand_in_letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stand_in_letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_picture = TextureRect.new()
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picture.position = _stand_in.position
	_picture.size = _stand_in.size
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_body.add_child(_picture)
	_type = _label(Vector2(10, 104), Vector2(SIZE.x - 20, 16), 11, INK_DIM)
	_type.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text = RichTextLabel.new()
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.bbcode_enabled = true
	_text.scroll_active = false
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.position = Vector2(8, 122)
	_text.size = Vector2(SIZE.x - 16, SIZE.y - 126)
	_text.add_theme_font_size_override("normal_font_size", 12)
	_text.add_theme_font_size_override("italics_font_size", 11)
	_text.add_theme_color_override("default_color", INK)
	_body.add_child(_text)
	# The cost, in a round badge at the top left.
	var badge := Panel.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.position = Vector2(-6, -6)
	badge.size = Vector2(32, 32)
	var round_box := StyleBoxFlat.new()
	round_box.bg_color = Color("2d5a8c")
	round_box.border_color = Color("7fb4ea")
	round_box.set_border_width_all(2)
	round_box.set_corner_radius_all(16)
	badge.add_theme_stylebox_override("panel", round_box)
	_body.add_child(badge)
	_cost_badge = badge
	_cost = _label(Vector2(-6, -6), Vector2(32, 32), 18, Color.WHITE)
	_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_price = _label(Vector2(0, SIZE.y + 2), Vector2(SIZE.x, 20), 14, Color("e8c872"))
	_price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_price.visible = false
	# Its back, over all of it while it lies face down.
	_back = CardIcon.new()
	_back.size = SIZE
	_back.show_icon(&"card_back")
	_back.visible = false
	_body.add_child(_back)
	# A white flash, over everything (an upgrade taking).
	_flash = ColorRect.new()
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.size = SIZE
	_flash.color = Color(1, 1, 1, 0)
	_body.add_child(_flash)
	mouse_entered.connect(_hover.bind(true))
	mouse_exited.connect(_hover.bind(false))


func _hover(on: bool):
	if in_hand:
		return
	_hovered = on
	hovered.emit(self, on)
	_refresh_look()
	if _lift_tween != null and _lift_tween.is_valid():
		_lift_tween.kill()
	var to := Vector2.ONE * (HOVER_SCALE if on else 1.0)
	if not CardFeel.shown() or not is_inside_tree():
		scale = to
		return
	_lift_tween = create_tween()
	_lift_tween.set_ignore_time_scale(true)
	_lift_tween.tween_property(self, "scale", to, HOVER_SECONDS).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


func _label(at: Vector2, area: Vector2, font_size: int, colour: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = at
	label.size = area
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	_body.add_child(label)
	return label


## Shows card `card_key`, upgraded or not; `battle` and `who` (an enemy's index) work its numbers out as they stand in a fight, and
## colour those the fight has changed. `card_entry`: the card as the deck or a pile has it, for what is its own (the Message's words
## and cost); kept for the next call that leaves it out.
func show_card(card_key: String, is_upgraded: bool, battle = null, who: int = -1, card_entry: Dictionary = {}):
	if card_key != key:
		entry = {}
	key = card_key
	upgraded = is_upgraded
	if not card_entry.is_empty():
		entry = card_entry
	var definition := CardDatabase.card(card_key)
	if definition == null:
		_title.text = card_key
		_text.text = "An unknown card."
		return
	_title.text = definition.name_for(is_upgraded)
	_cost.text = str(definition.cost_for(is_upgraded) if not entry.has("message") else int(entry.message.get("cost", definition.cost)))
	_cost.remove_theme_color_override("font_color")
	_cost.add_theme_color_override("font_color", Color.WHITE)
	# A card that cannot be played has no cost to show.
	_cost.visible = not definition.unplayable and not face_down
	_cost_badge.visible = not definition.unplayable and not face_down
	_type.text = definition.type_name() if definition.type == CardDefinition.Type.STATUS \
		else "%s - %s" % [definition.type_name(), ["Starter", "Common", "Uncommon", "Rare"][definition.rarity]]
	var message := card_key == CardDefinition.MESSAGE
	if message:
		_type.text = "The Message"
	var text := "[center]%s" % definition.describe(is_upgraded, battle, who, battle != null, card_key, entry)
	# The Message's words as the run wrote them, under its rules, in italics.
	if message and entry.has("message"):
		var said: Array = entry.message.get("words", []).map(func(word): return "\"%s\"" % str(word.get("line", "")).replace("[", "[lb]"))
		if not said.is_empty():
			text += "\n[color=#%s][i]%s[/i][/color]" % [MESSAGE_EDGE.to_html(false), " ".join(said)]
	if definition.flavour != "" and not (message and not entry.get("message", {}).get("words", []).is_empty()):
		text += "\n[color=#%s][i]%s[/i][/color]" % [INK_DIM.to_html(false), definition.flavour.replace("[", "[lb]")]
	_text.text = text + "[/center]"
	_picture.texture = definition.picture
	_picture.visible = definition.picture != null
	_stand_in.color = TYPE_COLOURS[clampi(definition.type, 0, TYPE_COLOURS.size() - 1)].darkened(0.35)
	_stand_in_letter.text = definition.type_name().substr(0, 1) if not message else "M"
	_stand_in.visible = definition.picture == null
	_stand_in_letter.visible = definition.picture == null
	var face: Texture2D = CardLooks.picture(MESSAGE_FACE if message else FACES[clampi(definition.type, 0, FACES.size() - 1)])
	if face == null and message:
		face = CardLooks.picture(FACES[clampi(definition.type, 0, FACES.size() - 1)])
	_face.texture = face
	_face.visible = face != null
	_edge_box.border_color = RARITY_EDGES[clampi(definition.rarity, 0, RARITY_EDGES.size() - 1)] if not is_upgraded else UPGRADED_EDGE
	if message:
		_edge_box.border_color = MESSAGE_EDGE
	_refresh_look()


## What it costs in this fight, where that is not what it says (Confused): green when less, red when more.
func show_cost(cost: int):
	var definition := CardDatabase.card(key)
	if definition == null or definition.unplayable:
		return
	var printed := definition.cost_for(upgraded)
	if entry.has("message"):
		printed = int(entry.message.get("cost", printed))
	_cost.text = str(cost)
	_cost.remove_theme_color_override("font_color")
	_cost.add_theme_color_override("font_color", Color.WHITE if cost == printed else (CardDefinition.HIGHER if cost < printed else CardDefinition.LOWER))


## What the statuses and words on it mean, a line each, for the panel beside it (and nothing when there is nothing to explain).
func keywords() -> String:
	var definition := CardDatabase.card(key)
	if definition == null:
		return ""
	var lines: Array[String] = []
	for effect in definition.effects:
		if effect.status != &"" and CardStatus.ALL.has(effect.status):
			var line := "%s: %s" % [CardStatus.name_of(effect.status), CardStatus.text_of(effect.status, effect.amount_for(upgraded))]
			if not lines.has(line):
				lines.append(line)
	if definition.exhausts:
		lines.append("Exhaust: gone for the rest of the fight once played.")
	if definition.type == CardDefinition.Type.STATUS:
		lines.append("Status: an enemy put it in your deck. It is gone once the fight is.")
	if definition.ethereal:
		lines.append("Ethereal: still in your hand as your turn ends, it is exhausted.")
	if definition.type == CardDefinition.Type.POWER:
		lines.append("Power: stays in effect for the whole fight once played.")
	if definition.type == CardDefinition.Type.TETHER and not definition.enemy_only:
		lines.append("Tether: stays on the table holding what it was played on. At the end of each of your turns it does its thing and frays by 1; at 0 it snaps and does its snap. Press it to let go early. The same card played onto the same again renews it. You hold %d at once." % CardBattle.TETHER_SLOTS)
	if definition.type == CardDefinition.Type.TETHER and definition.enemy_only:
		lines.append("An enemy's Tether: at the end of each of its holder's turns it does its thing to you, and frays. Hurt its holder to break it.")
	for effect in definition.effects + definition.snap_effects:
		if effect.kind == CardEffect.Kind.DRAIN and not lines.any(func(line): return line.begins_with("Drain")):
			lines.append("Drain: the one drained loses that much health, Block or not, and the drainer mends as much.")
	if key == CardDefinition.MESSAGE:
		lines.append("The Message: in every deck, never taken out or rewritten. Events add its words; how it grows is yours to choose. At the system's last boss it says every word twice.")
	if definition.target == CardDefinition.Target.ALL_ENEMIES and key != CardDefinition.MESSAGE:
		lines.append("Hits every enemy.")
	return "\n".join(lines)


func set_selected(on: bool):
	_selected = on
	_refresh_look()


## Whether it can be played just now: it glows if so, and is dimmed if not. `animated`: the glow fades rather than snapping.
func set_playable(on: bool, animated: bool = true):
	_playable = on
	if in_hand:
		modulate = Color.WHITE if on else UNPLAYABLE
	else:
		modulate = Color.WHITE if on else Color(1, 1, 1, 0.45)
	_set_glow(1.0 if on and in_hand else 0.0, animated)


func playable() -> bool:
	return _playable


var _glow_to := 0.0


func _set_glow(to: float, animated: bool):
	if is_equal_approx(to, _glow_to) and (_glow_tween == null or not _glow_tween.is_valid()) and is_equal_approx(_glow.modulate.a, to):
		return
	_glow_to = to
	if _glow_tween != null and _glow_tween.is_valid():
		_glow_tween.kill()
	if not animated or not CardFeel.shown() or not is_inside_tree():
		_glow.modulate.a = to
		return
	_glow_tween = create_tween()
	_glow_tween.set_ignore_time_scale(true)
	_glow_tween.tween_property(_glow, "modulate:a", to, 0.18)


## A price under it (a shop), or none with -1.
func set_price(price: int, affordable: bool = true):
	_price.visible = price >= 0
	_price.text = "%d gold" % price
	_price.add_theme_color_override("font_color", Color("e8c872") if affordable else Color("8a7a5a"))


## Lies face down (its back up), or face up, at once.
func set_face_down(down: bool):
	_show_side(down)
	_body.scale.x = 1.0


## Shows its back (`down`) or its face; the cost badge, which reaches past the card's edge, only with its face.
func _show_side(down: bool):
	face_down = down
	_back.visible = down
	var definition := CardDatabase.card(key)
	var costs := definition == null or not definition.unplayable
	_cost_badge.visible = not down and costs
	_cost.visible = not down and costs


## Turns over to face up (or down) over `seconds`: its width closes, it changes sides, and it opens again. `landed` is called once
## it is over.
func turn_over(to_face_up: bool = true, seconds: float = 0.22, landed: Callable = Callable()):
	if not CardFeel.shown() or not is_inside_tree():
		set_face_down(not to_face_up)
		if landed.is_valid():
			landed.call()
		return
	var tween := create_tween()
	tween.tween_property(_body, "scale:x", 0.0, seconds / 2.0).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(_show_side.bind(not to_face_up))
	tween.tween_property(_body, "scale:x", 1.0, seconds / 2.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	if landed.is_valid():
		tween.tween_callback(landed)


## Shakes its head: it cannot be played (or bought) just now. With the interface's Refused sound.
func refuse():
	CardFeel.note(&"card_refused")
	if not CardFeel.shown() or not is_inside_tree():
		return
	MapFeel.sound(&"refused", -12.0)
	var shake := create_tween()
	shake.set_ignore_time_scale(true)
	var turn := deg_to_rad(SHAKE_DEGREES)
	for swing in [1.0, -0.8, 0.5, -0.25, 0.0]:
		shake.tween_property(_body, "rotation", turn * swing, SHAKE_SECONDS / 5.0).set_trans(Tween.TRANS_SINE)


## A white flash over it, fading over `seconds` (an upgrade taking).
func flash(seconds: float = 0.35, strength: float = 0.9):
	if not CardFeel.shown() or not is_inside_tree():
		return
	_flash.color.a = strength * Comfort.share(Comfort.FLASHES)
	var tween := create_tween()
	tween.tween_property(_flash, "color:a", 0.0, seconds)


## Burns away over `seconds`: reddens, darkens and is gone (an exhausted card, a card taken out of the deck). The embers are the
## screen's (CardFx); `gone` is called at the end, and the card is not freed here.
func burn(seconds: float = 0.45, gone: Callable = Callable()):
	if not CardFeel.shown() or not is_inside_tree():
		modulate.a = 0.0
		if gone.is_valid():
			gone.call()
		return
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.4, 0.75, 0.35, 1.0), seconds * 0.3)
	tween.tween_property(self, "modulate", Color(0.25, 0.1, 0.05, 0.0), seconds * 0.7)
	tween.parallel().tween_property(self, "scale", scale * 0.9, seconds * 0.7)
	if gone.is_valid():
		tween.tween_callback(gone)


func _refresh_look():
	_box.bg_color = CARD_LIT if _hovered or _selected else CARD
	_glow_box.shadow_color = GLOW_CHOSEN if _selected else GLOW
	_glow_box.border_color = GLOW_CHOSEN if _selected else GLOW
	if not in_hand:
		z_index = 1 if _hovered else 0


func _gui_input(event: InputEvent):
	# Pressed and let go on it (a button's way), outside a hand; the hand reads its own cards.
	if in_hand:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if not event.pressed:
			chosen.emit(self)
