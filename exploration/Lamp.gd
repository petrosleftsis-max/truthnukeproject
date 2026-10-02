@tool
extends Interactable
class_name Lamp
## A lamp on a stealth map made dark (StealthSetup's Dark): everything within
## Light Tiles that it has a clear line to is lit, and a guard sees somebody on
## a lit tile as far off as he sees anything. Everywhere else he only makes
## them out close up.
##
## E beside it puts it out, quietly; a pebble landing beside it knocks it out,
## loudly. A guard who sees a lamp out that should be lit goes to light it
## again - wondering who put it out.

## How far its light reaches, in tiles.
@export var light_tiles: float = 4.0 : set = _set_light_tiles
## Whether it is lit to begin with.
@export var starts_lit: bool = true : set = _set_starts_lit
## Whether it can be put out at all - a brazier too big to pinch out.
@export var can_be_put_out: bool = true

const FLAME := Color(1.0, 0.78, 0.36)
const GLOW := Color(1.0, 0.72, 0.3)
const IRON := Color(0.22, 0.22, 0.25)

var lit := true


func _init():
	prompt = "Put out"
	interaction_radius = Grid.tiles(1.3)


func _set_light_tiles(value: float):
	light_tiles = maxf(value, 0.0)
	queue_redraw()


func _set_starts_lit(value: bool):
	starts_lit = value
	lit = value
	queue_redraw()


func _ready():
	super()
	lit = starts_lit
	z_as_relative = false
	z_index = ExplorationParty.PARTY_Z_TOP - 2
	queue_redraw()


## Only offered while there is a flame to put out.
func is_available() -> bool:
	return super() and lit and can_be_put_out


func interact(scene: Node):
	var watch = scene.get("stealth")
	if watch != null and watch.has_method("put_out"):
		watch.put_out(self, false)
	else:
		set_lit(false)


func set_lit(value: bool):
	lit = value
	queue_redraw()


func _draw():
	var tile := float(Grid.TILE_SIZE)
	if lit:
		for ring in 5:
			draw_circle(Vector2.ZERO, tile * (0.55 - ring * 0.09), Color(GLOW, 0.06 + ring * 0.03))
	# A post and a lantern on it.
	draw_rect(Rect2(-tile * 0.04, -tile * 0.05, tile * 0.08, tile * 0.45), IRON)
	draw_rect(Rect2(-tile * 0.13, -tile * 0.3, tile * 0.26, tile * 0.28), IRON)
	draw_rect(Rect2(-tile * 0.09, -tile * 0.26, tile * 0.18, tile * 0.2), FLAME if lit else Color(0.12, 0.12, 0.14))
	super()
	if Engine.is_editor_hint():
		draw_arc(Vector2.ZERO, Grid.tiles(light_tiles), 0.0, TAU, 48, Color(FLAME, 0.5), 3.0)
