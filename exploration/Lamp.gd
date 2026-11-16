@tool
@icon("res://art/editor_icons/lamp.svg")
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
## Lit around dusk and put out around dawn, each one at a slightly different minute (Light.lamp_lit_at). Whoever puts it out
## in between leaves it out until the next time it would change.
@export var by_the_clock: bool = false

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
	z_index = ExplorationParty.PARTY_Z_BOTTOM - 2
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


## --- Put out, seen ---
##
## A lamp put out sends up a puff of smoke, and its own glow dies over GLOW_OUT_SECONDS instead of going at once (the proposals of
## 2026-11-16, section 3; the designer, 2026-11-17); the map's dark comes in as it already did (LightView "Darkness comes on
## slowly"). Lit again, it catches over GLOW_IN_SECONDS. Whether it is lit, and what a guard sees by it, change at once (`lit`).
## PROPOSAL.
const GLOW_OUT_SECONDS := 0.45
const GLOW_IN_SECONDS := 0.25

## How much of its glow is drawn, 0 to 1.
var _glow := -1.0


func glow() -> float:
	var aim := 1.0 if lit else 0.0
	if _glow < 0.0 or Engine.is_editor_hint() or not MapFeel.shown():
		_glow = aim
	return _glow


func _process(delta: float):
	if Engine.is_editor_hint():
		return
	var aim := 1.0 if lit else 0.0
	var was := glow()
	if was == aim:
		return
	_glow = move_toward(was, aim, delta / (GLOW_IN_SECONDS if aim > was else GLOW_OUT_SECONDS))
	queue_redraw()


func set_lit(value: bool):
	var was := lit
	lit = value
	if was and not value and is_inside_tree() and not Engine.is_editor_hint():
		MapFeel.spawn(get_parent(), &"smoke", position + Vector2(0.0, -Grid.TILE_SIZE * 0.3), {"toward": Vector2(Campaign.wind_now())})
		MapFeel.sound(&"lamp_out", -10.0)
	queue_redraw()


func _draw():
	var tile := float(Grid.TILE_SIZE)
	var glowing := glow()
	if glowing > 0.0:
		for ring in 5:
			draw_circle(Vector2.ZERO, tile * (0.55 - ring * 0.09) * (0.6 + 0.4 * glowing), Color(GLOW, (0.06 + ring * 0.03) * glowing))
	# A post and a lantern on it.
	draw_rect(Rect2(-tile * 0.04, -tile * 0.05, tile * 0.08, tile * 0.45), IRON)
	draw_rect(Rect2(-tile * 0.13, -tile * 0.3, tile * 0.26, tile * 0.28), IRON)
	draw_rect(Rect2(-tile * 0.09, -tile * 0.26, tile * 0.18, tile * 0.2), Color(0.12, 0.12, 0.14).lerp(FLAME, glowing))
	super()
	if Engine.is_editor_hint():
		draw_arc(Vector2.ZERO, Grid.tiles(light_tiles), 0.0, TAU, 48, Color(FLAME, 0.5), 3.0)
