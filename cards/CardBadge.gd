extends Control
class_name CardBadge
## A status on somebody in the card game, as a badge (docs/card_game.md "How it feels"): its picture (CardLooks' status_<key>, else
## its first letter in a circle of its colour) with how much of it there is on it, and what it does in its tooltip. It pops as it
## grows and pulses as it counts down.

const SIDE := 28.0
## Each status's colour, for its stand-in.
const COLOURS := {
	&"might": Color("e0873a"), &"footing": Color("b89a5a"), &"ward": Color("5a9ad8"), &"spines": Color("8fa86a"),
	&"frenzy": Color("d04848"), &"exposed": Color("a070d0"), &"weakened": Color("7890a8"), &"brittle": Color("b8805a"),
	&"poison": Color("6ab04a"), &"entangled": Color("7a9a50"), &"confused": Color("c070b0"),
	&"enrage": Color("e05040"), &"curiosity": Color("d0a040"), &"overtime": Color("c8b060"), &"toll": Color("9a8070"),
	&"reactive": Color("d07090"), &"asleep": Color("6878b8"), &"mode_shift": Color("70a0a8"), &"curled": Color("5a8ab0"),
	&"invincible": Color("e0d090"), &"command": Color("c08848"), &"pack": Color("a07050"), &"linked": Color("8070c0"),
	&"holding": Color("b0a080"),
}

var key: StringName = &""
var amount := 0
var _icon: CardIcon
var _number: Label


func _init():
	custom_minimum_size = Vector2.ONE * SIDE
	size = Vector2.ONE * SIDE
	pivot_offset = size / 2.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	_icon = CardIcon.new()
	_icon.size = size
	add_child(_icon)
	_number = Label.new()
	_number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_number.add_theme_font_size_override("font_size", 13)
	_number.add_theme_color_override("font_color", Color.WHITE)
	_number.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_number.add_theme_constant_override("outline_size", 4)
	_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_number.position = Vector2(SIDE * 0.25, SIDE * 0.42)
	_number.size = Vector2(SIDE * 0.95, SIDE * 0.7)
	add_child(_number)


static func colour_of(status: StringName) -> Color:
	return COLOURS.get(status, Color("8296a9"))


## Shows status `status_key` at `how_much`.
func setup(status_key: StringName, how_much: int) -> CardBadge:
	key = status_key
	_icon.show_icon(StringName("status_" + String(status_key)), null, colour_of(status_key), CardStatus.name_of(status_key).substr(0, 1))
	set_amount(how_much, false)
	return self


## Now `how_much`: popping when it grew, pulsing when it fell.
func set_amount(how_much: int, animated: bool = true):
	var before := amount
	amount = how_much
	_number.text = str(how_much)
	tooltip_text = "%s %d: %s" % [CardStatus.name_of(key), how_much, CardStatus.text_of(key, how_much)]
	if not animated or not CardFeel.shown() or not is_inside_tree() or before == how_much:
		return
	var tween := create_tween()
	if how_much > before:
		tween.tween_property(self, "scale", Vector2.ONE * 1.35, 0.08).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "scale", Vector2.ONE, 0.16).set_ease(Tween.EASE_IN_OUT)
	else:
		tween.tween_property(self, "modulate", Color(1.6, 1.6, 1.6), 0.07)
		tween.tween_property(self, "modulate", Color.WHITE, 0.2)


## Comes in: from nothing, overshooting a little.
func pop_in():
	if not CardFeel.shown() or not is_inside_tree():
		scale = Vector2.ONE
		return
	scale = Vector2.ONE * 0.2
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE * 1.25, 0.1).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.14).set_ease(Tween.EASE_IN_OUT)


## Goes: shrinks away and is freed.
func shrink_away():
	if not CardFeel.shown() or not is_inside_tree():
		queue_free()
		return
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.tween_callback(queue_free)
