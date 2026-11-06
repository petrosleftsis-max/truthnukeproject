extends Node2D
class_name MapAim
## Aiming a move on a map (the designer, 2026-11-07: "great snare, and other damaging spells should
## still need you to target and hit somebody with them. and what should happen is IF it hits an enemy,
## they start a fight and before anyone's turns starts for everyone who got hit to take the damage they
## should"). Picking a damaging move or a trap from the moves panel only takes it up: its reach shows
## round whoever uses it, what it would cover follows the pointer with a ring on everybody it would
## catch, a click lets it go (OutsideMoves.fire_at) and a right click or Cancel puts it away. The
## pointer is a pad's too (Pad's pad_pointer group). Over a network the aiming is done on this
## machine's own screen and what it comes to on the host (Net.do_on_host, "strike"). A view of
## OutsideMoves' rules: nothing is decided here.

const REACH_COLOUR := Color(1.0, 0.86, 0.5, 0.2)
const AREA_COLOUR := Color(1.0, 0.42, 0.18, 0.42)
const REFUSED_COLOUR := Color(0.85, 0.2, 0.2, 0.55)
const RING_COLOUR := Color(1.0, 0.28, 0.16, 0.95)

## The map (ExplorationScene), who uses it, and which of their moves.
var scene: Node = null
var key := ""
var move := ""
var skill: SkillDefinition = null

var _tile_map: TileMap = null
var _from := OutsideMoves.NOWHERE
var _reach: Array = []
var _aim := OutsideMoves.NOWHERE
var _in_reach := false
var _struck := {}


func _ready():
	name = "MapAim"
	z_as_relative = false
	z_index = ExplorationParty.PARTY_Z_TOP + 1
	add_to_group(&"pad_pointer")
	skill = OutsideMoves.definition_of(move)
	_tile_map = scene.get("_tile_map")
	if scene.has_method("log_message"):
		scene.log_message("%s: %s where it goes, %s to put it away.\n" % [skill.name, Pad.key(&"pointer_click", "Click"), Pad.key(&"ui_cancel")])


## A pad's pointer stays up, and its button clicks on the map, for as long as this is aiming.
func wants_pad_pointer() -> bool:
	return true


func _process(_delta):
	if scene == null or not is_instance_valid(scene) or _tile_map == null or skill == null:
		queue_free()
		return
	# Whoever it was has stopped leading, or it is no use now.
	if Campaign.lead_here() != key or OutsideMoves.refusal(scene, key, move) != "":
		cancel()
		return
	var from: Vector2i = OutsideMoves.member_tile(scene, key)
	if from != _from:
		_from = from
		_reach = OutsideMoves.reach_tiles(scene, key, skill)
	var pointed: Vector2i = _tile_map.local_to_map(_tile_map.to_local(get_global_mouse_position()))
	var aim: Vector2i = OutsideMoves.aim_from(skill, _from, pointed)
	_aim = aim
	_in_reach = OutsideMoves.in_reach(scene, key, skill, aim)
	_struck = OutsideMoves.struck_at(scene, key, skill, aim)
	queue_redraw()


func _draw():
	if _tile_map == null or skill == null:
		return
	for tile in _reach:
		_mark(tile, REACH_COLOUR)
	if _aim == OutsideMoves.NOWHERE:
		return
	if not _in_reach:
		_mark(_aim, REFUSED_COLOUR)
		return
	for tile in _struck.get("tiles", []):
		_mark(tile, AREA_COLOUR)
	var size := float(Grid.TILE_SIZE)
	for guard in _struck.get("guards", []):
		if is_instance_valid(guard):
			draw_arc(to_local(guard.global_position), size * 0.48, 0.0, TAU, 28, RING_COLOUR, 5.0)
	var placed = _struck.get("placed")
	if placed != null and is_instance_valid(placed):
		draw_arc(to_local(placed.global_position), size * 0.48, 0.0, TAU, 28, RING_COLOUR, 5.0)


func _mark(tile: Vector2i, colour: Color):
	var size := float(Grid.TILE_SIZE)
	var middle := to_local(_tile_map.to_global(_tile_map.map_to_local(tile)))
	draw_rect(Rect2(middle - Vector2(size, size) / 2.0, Vector2(size, size)), colour)


func _unhandled_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		get_viewport().set_input_as_handled()
		if event.button_index == MOUSE_BUTTON_LEFT:
			_let_go_of_it(_tile_map.local_to_map(_tile_map.to_local(_world_at(event.position))))
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			cancel()
	elif event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		cancel()


func _world_at(screen_position: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen_position


func _let_go_of_it(pointed: Vector2i):
	var aim: Vector2i = OutsideMoves.aim_from(skill, OutsideMoves.member_tile(scene, key), pointed)
	var refused: String = OutsideMoves.aim_refusal(scene, key, skill, aim)
	if refused != "":
		if scene.has_method("log_message"):
			scene.log_message(refused + ".\n")
		return
	queue_free()
	if Net.follows():
		Net.do_on_host("strike", [key, move, aim])
		return
	OutsideMoves.fire_at(scene, key, move, aim)
	var panel = scene.get("moves_panel")
	if panel != null and is_instance_valid(panel):
		panel.refresh()


func cancel():
	queue_free()
