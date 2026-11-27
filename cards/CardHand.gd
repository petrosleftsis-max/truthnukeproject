extends Control
class_name CardHand
## The hand of a fight, drawn as a fan (docs/card_game.md "How it feels"): one CardView a card, kept for as long as the card is in
## the hand (by its id), each eased to its place as cards come and go. The card under the pointer rises out of the fan to full size,
## upright and over the others, its neighbours leaning apart to make room; the card chosen, and the keys' card while the keys are
## in use, rise the same way.
##
## The hand reads the pointer for its cards (they ignore it themselves), so what rises is always what a press would choose: a press
## let go where it was is `clicked`; a press pulled further than DRAG_FROM is a drag (`drag_started`, `dragged`, `drag_ended`), and
## the screen decides what a drag does, placing the card where it wants it meanwhile (`hold`). It is only there where its cards are
## (`_has_point`), so the rest of the screen under it can still be pressed.

signal clicked(id: int)
## The card under the pointer, or -1 for none.
signal pointed(id: int)
signal drag_started(id: int)
signal dragged(id: int, at: Vector2)
signal drag_ended(id: int, at: Vector2)

## A card at rest in the fan, and risen.
const REST_SCALE := 0.9
const RISEN_SCALE := 1.3
## The most between two cards' middles, in pixels; fewer cards spread no further than this.
const STEP_MOST := 128.0
## The fan's turn: degrees a card from the middle, and at most.
const TURN_A_CARD := 3.0
const TURN_MOST := 15.0
## How much lower the outer cards rest: pixels for a card's distance from the middle, squared.
const DROP_A_CARD := 4.5
## How far a risen card's neighbours lean apart (the next one; those further, less).
const LEAN_APART := 46.0
## How long a card takes to ease to its place.
const LAYOUT_SECONDS := 0.16
## How far a press must be pulled to be a drag rather than a click.
const DRAG_FROM := 12.0

## id -> CardView.
var views := {}
## The ids, left to right.
var order: Array = []
## The card chosen (risen, set by the screen), or -1.
var chosen := -1
## The keys' card (risen while the keys are in use), or -1.
var focus := -1
## Cards placed outside the fan meanwhile (dragged): id -> {at (a middle, global), scale}.
var held := {}

var _pointed := -1
var _press_id := -1
var _press_at := Vector2.ZERO
var _dragging := false
var _tweens := {}


func _init():
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_exited.connect(_on_exited)


## Takes `view` in as card `id`; from `from` (a middle, global) when given, small, easing to its place.
func add(view: CardView, id: int, from: Vector2 = Vector2.INF):
	view.in_hand = true
	if view.get_parent() != self:
		if view.get_parent() != null:
			view.reparent(self, false)
		else:
			add_child(view)
	views[id] = view
	if not order.has(id):
		order.append(id)
	if from.is_finite():
		view.position = from - global_position - CardView.SIZE / 2.0
		view.scale = Vector2.ONE * 0.4
		view.rotation = 0.0
	layout()


## Lets card `id` go from the hand (played, discarded): its view is handed back, still here, for the screen to send on its way.
func take(id: int) -> CardView:
	var view: CardView = views.get(id)
	views.erase(id)
	order.erase(id)
	held.erase(id)
	if _pointed == id:
		_pointed = -1
	if chosen == id:
		chosen = -1
	if focus == id:
		focus = -1
	var tween: Tween = _tweens.get(id)
	if tween != null and tween.is_valid():
		tween.kill()
	_tweens.erase(id)
	layout()
	return view


## Every view let go at once and freed (a fight over, a hand put right).
func clear_all():
	for id in views.keys():
		var view: CardView = views[id]
		if is_instance_valid(view):
			view.queue_free()
	views.clear()
	order.clear()
	held.clear()
	_tweens.clear()
	_pointed = -1
	chosen = -1
	focus = -1


## The card that is risen: chosen, else pointed at, else the keys' card.
func risen() -> int:
	if chosen >= 0 and views.has(chosen):
		return chosen
	if _pointed >= 0 and views.has(_pointed):
		return _pointed
	if focus >= 0 and views.has(focus):
		return focus
	return -1


## The card the pointer is over, or -1.
func pointed_at() -> int:
	return _pointed


## Places card `id` at `at` (a middle, global) at `card_scale`, upright, outside the fan, until `release`.
func hold(id: int, at: Vector2, card_scale: float = 1.0):
	if not views.has(id):
		return
	held[id] = {"at": at, "scale": card_scale}
	var view: CardView = views[id]
	var tween: Tween = _tweens.get(id)
	if tween != null and tween.is_valid():
		tween.kill()
	view.position = at - global_position - CardView.SIZE / 2.0
	view.scale = Vector2.ONE * card_scale
	view.rotation = 0.0
	move_child(view, -1)


func release(id: int):
	held.erase(id)
	layout()


## Where card `id` rests in the fan just now: {at (a middle, local), turn (radians), scale}.
func rest_of(id: int) -> Dictionary:
	var count := order.size()
	var i := order.find(id)
	if i < 0:
		return {"at": size / 2.0, "turn": 0.0, "scale": REST_SCALE}
	var middle := (count - 1) / 2.0
	var offset := float(i) - middle
	var step := minf(STEP_MOST, (size.x - CardView.SIZE.x * REST_SCALE) / maxf(count - 1, 1))
	var at := Vector2(size.x / 2.0 + offset * step, _rest_y() + offset * offset * DROP_A_CARD)
	var turn := deg_to_rad(clampf(offset * TURN_A_CARD, -TURN_MOST, TURN_MOST))
	var card_scale := REST_SCALE
	var up := risen()
	if up >= 0 and up != id and not held.has(up):
		var apart := float(i - order.find(up))
		at.x += signf(apart) * LEAN_APART / absf(apart)
	elif up == id:
		at = Vector2(at.x, size.y - CardView.SIZE.y * RISEN_SCALE / 2.0 - 4.0)
		turn = 0.0
		card_scale = RISEN_SCALE
	return {"at": at, "turn": turn, "scale": card_scale}


func _rest_y() -> float:
	return size.y - CardView.SIZE.y * REST_SCALE / 2.0 - 36.0


## Eases every card to its place; at once when `animated` is false or nothing moves (headless).
func layout(animated: bool = true):
	var moves := animated and CardFeel.shown() and is_inside_tree()
	for i in order.size():
		var id: int = order[i]
		var view: CardView = views[id]
		if not is_instance_valid(view):
			continue
		move_child(view, i)
		if held.has(id):
			continue
		var rest := rest_of(id)
		var to_position: Vector2 = rest.at - CardView.SIZE / 2.0
		var old: Tween = _tweens.get(id)
		if old != null and old.is_valid():
			old.kill()
		if not moves:
			view.position = to_position
			view.rotation = rest.turn
			view.scale = Vector2.ONE * rest.scale
			continue
		var tween := view.create_tween().set_parallel()
		tween.tween_property(view, "position", to_position, LAYOUT_SECONDS).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(view, "rotation", rest.turn, LAYOUT_SECONDS).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(view, "scale", Vector2.ONE * rest.scale, LAYOUT_SECONDS).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		_tweens[id] = tween
	# The risen card, and anything held, over the rest.
	var up := risen()
	if up >= 0 and views.has(up):
		move_child(views[up], -1)
	for id in held:
		if views.has(id):
			move_child(views[id], -1)


## The card a press at `point` (local) would choose: the risen card where it is over it, else the one whose middle is nearest
## among those whose place at rest is under the point.
func card_at(point: Vector2) -> int:
	var up := risen()
	if up >= 0 and not held.has(up) and _rect_of(up).has_point(point):
		return up
	var best := -1
	var nearest := INF
	for id in order:
		if held.has(id):
			continue
		var rect := _rect_of(id, true)
		if rect.has_point(point):
			var off := absf(rect.get_center().x - point.x)
			if off < nearest:
				nearest = off
				best = id
	return best


## Card `id`'s place (local), risen or at rest; `at_rest`: where it rests whatever it is doing.
func _rect_of(id: int, at_rest: bool = false) -> Rect2:
	var rest := rest_of(id)
	var card_scale: float = rest.scale
	if at_rest:
		card_scale = REST_SCALE
		if risen() == id:
			# Where it would rest were it not risen, for the cards about it.
			var count := order.size()
			var offset := float(order.find(id)) - (count - 1) / 2.0
			var step := minf(STEP_MOST, (size.x - CardView.SIZE.x * REST_SCALE) / maxf(count - 1, 1))
			rest.at = Vector2(size.x / 2.0 + offset * step, _rest_y() + offset * offset * DROP_A_CARD)
	var area := CardView.SIZE * card_scale
	return Rect2(rest.at - area / 2.0, area)


func _has_point(point: Vector2) -> bool:
	if _dragging or _press_id >= 0:
		return true
	return card_at(point) >= 0


func _gui_input(event: InputEvent):
	if event is InputEventMouseMotion:
		if _press_id >= 0 and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			if not _dragging and event.global_position.distance_to(_press_at) > DRAG_FROM:
				_dragging = true
				drag_started.emit(_press_id)
			if _dragging:
				dragged.emit(_press_id, event.global_position)
			return
		_point(card_at(event.position))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if event.pressed:
			_press_id = card_at(event.position)
			_press_at = event.global_position
			_dragging = false
			return
		var id := _press_id
		var was_drag := _dragging
		_press_id = -1
		_dragging = false
		if id < 0:
			return
		if was_drag:
			drag_ended.emit(id, event.global_position)
		else:
			clicked.emit(id)


func _point(id: int):
	if id == _pointed:
		return
	_pointed = id
	pointed.emit(id)
	if id >= 0:
		CardFeel.sound(&"card_hover", -16.0)
	layout()


func _on_exited():
	if _press_id < 0:
		_point(-1)


## A card's middle, global, where it is drawn now.
func centre_of(id: int) -> Vector2:
	var view: CardView = views.get(id)
	if view == null:
		return global_position + size / 2.0
	return view.get_global_transform() * view.pivot_offset


## The middle of the fan, global: where a card coming in aims.
func middle() -> Vector2:
	return global_position + Vector2(size.x / 2.0, _rest_y())
