extends Control
class_name CardTethers
## The Tethers on the table in a fight (the designer's twist 7, 2026-11-27): each a small card at the feet of whoever it holds, its
## strength as pips, a thread drawn from its holder to it, swaying, thinner as it frays. A player's own can be pressed to let it go
## (let_go_pressed: the stage decides whether it may). Only to look at and press: the rules (CardBattle.tethers) decide; the stage tells
## this what happened as its beats play (tie, did, fray, snap), and `sync` puts it right from the rules once they have.
##
## Slots: CardLooks' tether_card (the small card) and tether_thread (the line); empty, both are drawn here.

signal let_go_pressed(id: int)

const CHIP_SIZE := Vector2(62, 38)
const CHIPS_A_ROW := 3
## Where the chips sit on a figure (its own coordinates): above its name, under its picture.
const CHIPS_AT_Y := 170.0
## Each player's own colour for what they hold (CardGame.PLAYER_INKS), an enemy's.
const HOLDER_INKS := [Color("9cc8f0"), Color("f0c070")]
const ENEMY_INK := Color("e07a6a")

var stage: CardStage = null
## id -> chip.
var chips := {}
var _age := 0.0


func _init():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(owner_stage: CardStage) -> CardTethers:
	stage = owner_stage
	return self


## The colour of what `holder` (a who) holds.
static func ink_of(holder: int) -> Color:
	var p := CardBattle.player_index(holder)
	return HOLDER_INKS[p % HOLDER_INKS.size()] if p >= 0 else ENEMY_INK


## Puts the chips right from the rules' `tethers`: one for each, none for one gone, each at its strength.
func sync(tethers: Array):
	var ids: Array = []
	for tether in tethers:
		ids.append(int(tether.id))
		var chip: _Chip = chips.get(int(tether.id))
		if chip == null:
			chip = _make(_info_of(tether))
		chip.info = _info_of(tether)
		chip.queue_redraw()
	for id in chips.keys():
		if not ids.has(id):
			chips[id].queue_free()
			chips.erase(id)
	_place()


## What a chip shows of a tether of the rules' (or a beat's).
static func _info_of(tether: Dictionary) -> Dictionary:
	return {"id": int(tether.id), "key": str(tether.key), "upgraded": bool(tether.get("upgraded", false)), "holder": int(tether.holder),
		"on": int(tether.on), "strength": int(tether.strength), "most": int(tether.most)}


func _make(info: Dictionary) -> _Chip:
	var chip := _Chip.new()
	chip.info = info
	chip.layer = self
	chip.size = CHIP_SIZE
	chip.pivot_offset = CHIP_SIZE / 2.0
	var definition := CardDatabase.card(str(info.key))
	chip.tooltip_text = "%s\n%s" % [definition.name_for(bool(info.upgraded)), definition.describe(bool(info.upgraded)).replace("[s]", "").replace("[/s]", "")] \
		if definition != null else str(info.key)
	chip.pressed.connect(_chip_pressed.bind(int(info.id)))
	add_child(chip)
	chips[int(info.id)] = chip
	return chip


func _chip_pressed(id: int):
	let_go_pressed.emit(id)


## A Tether just tied: its chip springs up where it holds.
func tie(info: Dictionary):
	var chip: _Chip = chips.get(int(info.id))
	if chip == null:
		chip = _make(_info_of(info))
	_place()
	if CardFeel.shown():
		chip.pop = 0.2
		chip.create_tween().tween_property(chip, "pop", 1.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		chip.flare = 1.0


## A Tether doing its thing: its chip and thread light up.
func did(info: Dictionary):
	var chip: _Chip = chips.get(int(info.id))
	if chip != null:
		chip.flare = 1.0


## A Tether frayed (or held anew): its strength as it is now, a shiver.
func fray(info: Dictionary, strength: int):
	var chip: _Chip = chips.get(int(info.id))
	if chip == null:
		return
	chip.info.strength = strength
	chip.info.most = int(info.get("most", chip.info.most))
	chip.queue_redraw()
	chip.shiver = 1.0


## A Tether gone (`why`: frayed, let_go, cut, broken, loose, renewed): its chip bursts and goes. Where it was, for the stage's sparks.
func snap(info: Dictionary, _why: StringName) -> Vector2:
	var chip: _Chip = chips.get(int(info.id))
	if chip == null:
		return Vector2.INF
	var at := chip.global_position + chip.size / 2.0
	chips.erase(int(info.id))
	if not CardFeel.shown():
		chip.queue_free()
		return at
	var tween := chip.create_tween().set_parallel()
	tween.tween_property(chip, "scale", Vector2.ONE * 1.4, 0.18)
	tween.tween_property(chip, "modulate:a", 0.0, 0.18)
	tween.chain().tween_callback(chip.queue_free)
	return at


## Each chip at the feet of whoever it holds, a row of them, scaled as that figure is.
func _place():
	if stage == null:
		return
	var by_whom := {}
	for id in chips:
		var on := int(chips[id].info.on)
		by_whom[on] = by_whom.get(on, []) + [chips[id]]
	for on in by_whom:
		var figure: CardFighter = stage.fighter(on)
		var row: Array = by_whom[on]
		row.sort_custom(func(a, b): return int(a.info.id) < int(b.info.id))
		for i in row.size():
			var chip: _Chip = row[i]
			if figure == null or not is_instance_valid(figure):
				chip.visible = false
				continue
			chip.visible = true
			var across := mini(row.size(), CHIPS_A_ROW)
			var column := i % CHIPS_A_ROW
			var line := i / CHIPS_A_ROW
			var left := (CardFighter.SIZE.x - across * (CHIP_SIZE.x + 4.0) + 4.0) / 2.0
			var local := Vector2(left + column * (CHIP_SIZE.x + 4.0), CHIPS_AT_Y - line * (CHIP_SIZE.y + 4.0))
			var at := figure.get_global_transform() * local
			chip.global_position = at
			chip.scale = Vector2.ONE * figure.scale.x * chip.pop
			chip.ink = ink_of(int(chip.info.holder))
			chip.mine = stage.lets_go(int(chip.info.holder))


func _process(delta: float):
	_age += delta
	_place()
	queue_redraw()


## The threads: from each holder's figure to its chip, swaying, its colour the holder's, thinner as it frays.
func _draw():
	if stage == null:
		return
	var picture := CardLooks.picture(&"tether_thread")
	for id in chips:
		var chip: _Chip = chips[id]
		if not chip.visible or int(chip.info.holder) == int(chip.info.on):
			continue
		var from_figure: CardFighter = stage.fighter(int(chip.info.holder))
		if from_figure == null or not is_instance_valid(from_figure) or not from_figure.alive:
			continue
		var from := from_figure.centre() - global_position
		var to := chip.global_position + chip.size * chip.scale / 2.0 - global_position
		var share := clampf(float(chip.info.strength) / maxf(float(chip.info.most), 1.0), 0.0, 1.0)
		var colour: Color = chip.ink
		colour.a = 0.45 + 0.4 * share + 0.3 * chip.flare
		var width := 1.5 + 2.5 * share + 2.0 * chip.flare
		if picture != null:
			draw_set_transform(from, (to - from).angle(), Vector2.ONE)
			draw_texture_rect(picture, Rect2(Vector2(0, -width * 2.0), Vector2(from.distance_to(to), width * 4.0)), false, colour)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			continue
		# A sagging line, swaying a little.
		var points := PackedVector2Array()
		var steps := 14
		var sag := 18.0 + 10.0 * sin(_age * 1.7 + float(id))
		for step in steps + 1:
			var t := float(step) / float(steps)
			var point := from.lerp(to, t)
			point.y += sin(t * PI) * sag * (1.0 - 0.5 * share)
			points.append(point)
		draw_polyline(points, colour, width, true)
		if share < 0.5:
			# Frayed: loose fibres off the line.
			for step in range(2, steps - 1, 3):
				var fibre: Vector2 = points[step]
				draw_line(fibre, fibre + Vector2(sin(_age * 3.0 + step) * 6.0, 7.0), Color(colour, colour.a * 0.6), 1.0, true)


## A held Tether's small card: its name, its strength as pips, edged in its holder's colour; lit while pressable.
class _Chip extends Button:
	var info := {}
	var layer: CardTethers = null
	var ink := Color.WHITE
	## Whether pressing it lets it go (the player's own, on their turn).
	var mine := false
	var flare := 0.0
	var shiver := 0.0
	## Its size as it springs up (CardTethers.tie), over the figure's.
	var pop := 1.0

	func _init():
		flat = true
		focus_mode = Control.FOCUS_NONE
		mouse_filter = Control.MOUSE_FILTER_STOP
		custom_minimum_size = CardTethers.CHIP_SIZE

	func _process(delta: float):
		flare = maxf(flare - delta * 2.5, 0.0)
		shiver = maxf(shiver - delta * 4.0, 0.0)
		if flare > 0.0 or shiver > 0.0:
			queue_redraw()

	func _draw():
		var rect := Rect2(Vector2.ZERO, size)
		if shiver > 0.0:
			rect.position.x += sin(shiver * 40.0) * 2.5 * shiver
		var picture := CardLooks.picture(&"tether_card")
		var back := Color("1a2a2c").lerp(ink, 0.18 + 0.25 * flare)
		if picture != null:
			draw_texture_rect(picture, rect, false, Color.WHITE.lerp(ink, 0.3))
		else:
			var box := StyleBoxFlat.new()
			box.bg_color = back
			box.border_color = ink.lightened(0.2) if mine and is_hovered() else ink
			box.set_border_width_all(2 if not (mine and is_hovered()) else 3)
			box.set_corner_radius_all(5)
			draw_style_box(box, rect)
		var definition := CardDatabase.card(str(info.get("key", "")))
		var title := definition.name_for(bool(info.get("upgraded", false))) if definition != null else str(info.get("key", ""))
		var font := get_theme_default_font()
		draw_string(font, rect.position + Vector2(4, 14), title, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 8.0, 11, Color("dce8f5"))
		# Its strength as pips: lit for what is left, hollow for what has frayed.
		var most := maxi(int(info.get("most", 1)), 1)
		var left := int(info.get("strength", 0))
		var pip := minf(7.0, (rect.size.x - 10.0) / float(most) / 2.0 - 1.0)
		var start := rect.position.x + rect.size.x / 2.0 - (most * (pip * 2.0 + 2.0)) / 2.0 + pip + 1.0
		for i in most:
			var centre := Vector2(start + i * (pip * 2.0 + 2.0), rect.position.y + rect.size.y - pip - 5.0)
			if i < left:
				draw_circle(centre, pip, ink)
			else:
				draw_arc(centre, pip - 0.5, 0.0, TAU, 12, Color(ink, 0.5), 1.0, true)
