@tool
@icon("res://art/editor_icons/interactable.svg")
extends Interactable
class_name DreamLamp
## A lamp of the dream to light in its order (DreamPlace; the proposals of 2026-11-19, "A dream-place": a puzzle). Lamps of one
## Puzzle are lit by their Order, 1 first; lit out of turn, every one of them goes out again. All lit, the flag "<puzzle>_solved" is
## set, which is what the Rehearsal waits on (its Requires Flag). A placeholder lamp until it has a picture. PROPOSAL.

@export var puzzle: String = "dream_lamps"
@export var order: int = 1:
	set(value):
		order = maxi(value, 1)
		queue_redraw()


func _init():
	prompt = "Light"


func _next() -> int:
	return int(Campaign.flags.get("lamps:" + puzzle, 1))


func is_lit() -> bool:
	return Campaign.flag(puzzle + "_solved") or order < _next()


func is_available() -> bool:
	return super() and (Engine.is_editor_hint() or not is_lit())


func interact(scene: Node):
	var lamps := _lamps()
	if order != _next():
		Campaign.flags["lamps:" + puzzle] = 1
		MapFeel.sound(&"refused", -4.0, 0.8, global_position)
		scene.log_message("The lamps go out, every one.\n")
	else:
		Campaign.flags["lamps:" + puzzle] = order + 1
		MapFeel.sound(&"secret_found", -4.0, 0.8 + order * 0.15, global_position)
		if order >= lamps.size():
			Campaign.set_flag(puzzle + "_solved")
			MapFeel.sound(&"dream", -2.0, 1.0, global_position)
			scene.log_message("Every lamp is lit. Somewhere in the dream, something opens.\n")
	for lamp in lamps:
		lamp.queue_redraw()


func _lamps() -> Array:
	var map: Node = owner if owner != null else get_parent()
	if map == null:
		return [self]
	return map.find_children("*", "DreamLamp", true, false).filter(func(lamp): return lamp.puzzle == puzzle)


func _draw():
	super()
	if texture != null or sprite_frames != null:
		return
	var tile := float(Grid.TILE_SIZE)
	var lit := not Engine.is_editor_hint() and is_lit()
	draw_line(Vector2(0, tile * 0.3), Vector2(0, -tile * 0.5), Color("3c3550"), 7.0)
	draw_circle(Vector2(0, -tile * 0.62), tile * 0.16, Color("ffe08a") if lit else Color("514a66"))
	if lit:
		draw_circle(Vector2(0, -tile * 0.62), tile * 0.3, Color(1.0, 0.88, 0.5, 0.25))
	if Engine.is_editor_hint():
		draw_string(ThemeDB.fallback_font, Vector2(-10, tile * 0.6), str(order), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1, 0.9, 0.5))
