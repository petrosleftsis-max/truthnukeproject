extends Control
class_name CardOrb
## The energy left this turn, as an orb (CardLooks' energy_orb) with its number (docs/card_game.md "How it feels"): the number pops as
## it is spent, the orb dims at nothing, flares as it fills, and flashes red when a card asks for more than there is.

const SIDE := 84.0
const RED := Color(1.6, 0.45, 0.4)

var energy := 0
var most := 0
var _icon: CardIcon
var _label: Label
var _fx: CardFx = null


func _init():
	custom_minimum_size = Vector2.ONE * SIDE
	size = custom_minimum_size
	pivot_offset = size / 2.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Energy: what playing a card costs. It fills again at the start of each turn."
	_icon = CardIcon.new()
	_icon.size = size
	_icon.show_icon(&"energy_orb")
	add_child(_icon)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.theme_type_variation = GameFonts.HEADER
	_label.add_theme_font_size_override("font_size", 26)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color(0.05, 0.1, 0.2, 0.95))
	_label.add_theme_constant_override("outline_size", 7)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.size = size
	add_child(_label)


## The effects layer its flare is drawn on.
func use_fx(fx: CardFx):
	_fx = fx


## `now` of `most_now`: a pop as it changes, a flare (`filled`) as it fills at the start of a turn.
func set_energy(now: int, most_now: int, animated: bool = true, filled: bool = false):
	var before := energy
	energy = now
	most = most_now
	_label.text = "%d/%d" % [now, most_now]
	_icon.modulate = Color(0.45, 0.5, 0.6) if now <= 0 else Color.WHITE
	if not animated or not CardFeel.shown() or not is_inside_tree() or before == now:
		return
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE * (1.18 if now > before else 0.88), 0.07).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.16).set_ease(Tween.EASE_IN_OUT)
	if filled and _fx != null:
		_fx.ring(global_position + size / 2.0, Color("9cd0ff"), SIDE * 0.45, SIDE * 1.1, 0.45, 6.0)


## A card asked for more than there is: a red flash.
func refuse():
	CardFeel.note(&"orb_refused")
	if not CardFeel.shown() or not is_inside_tree():
		return
	var tween := create_tween()
	tween.set_ignore_time_scale(true)
	tween.tween_property(self, "modulate", RED, 0.06)
	tween.tween_property(self, "modulate", Color.WHITE, 0.3)
