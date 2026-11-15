@tool
@icon("res://art/editor_icons/stealth_door.svg")
extends Interactable
class_name StealthDoor
## A door on a stealth map, on the floor tile it fills. Shut, nobody walks
## through it and nobody sees through it; E opens and shuts it. Guards have
## the keys: one walking through opens it as he goes and shuts it behind him.
##
## Leave one open that is meant to be shut and a guard who sees it will come
## and shut it - wondering who left it open. Requires Flag locks it until that
## flag is set: a key lifted from somebody's pocket, say.

## Whether it starts open. One that starts shut and is left open is noticed.
@export var starts_open: bool = false : set = _set_starts_open

const WOOD := Color(0.42, 0.28, 0.16)
const WOOD_DARK := Color(0.27, 0.17, 0.09)
const IRON := Color(0.35, 0.36, 0.4)

## Whether it stands open right now - by its own state, not a guard passing.
var is_open := false
## Whether a guard walking through is holding it open this moment.
var held := false


func _init():
	prompt = "Open"
	interaction_radius = Grid.tiles(1.3)


func _set_starts_open(value: bool):
	starts_open = value
	is_open = value
	queue_redraw()


func _ready():
	super()
	is_open = starts_open
	prompt = "Close" if is_open else "Open"
	# Over the floor, under anybody walking through it.
	z_as_relative = false
	z_index = ExplorationParty.PARTY_Z_BOTTOM - 2
	queue_redraw()
	if not Engine.is_editor_hint():
		add_to_group(Depth.UPRIGHTS)


## How thick its leaf is drawn, in tiles.
const LEAF_TILES := 0.16

## Set by the view while it draws this door standing (DepthView._keep_the_uprights): then nothing is drawn flat on the tile.
var depth_stood := false : set = _set_depth_stood


func _set_depth_stood(value: bool):
	if value != depth_stood:
		depth_stood = value
		queue_redraw()


## A door is as tall as the walls beside it, shut or open (the designer, 2026-11-14: "the door would be the same height as the
## wall"). DepthView "What a map's own nodes stand up".
func depth_lift() -> float:
	return Depth.lift_of(Depth.Kind.WALL)


## The part of its tile it stands on, in tiles from the tile's north-west corner. `side_on` is a door in a wall that runs north to
## south, which we look along: the way through it goes east and west (the designer, 2026-11-14: "looks weird when a closed door
## is facing me when it's on the left or right of a building, especially when when it's open, it looks like it actually blocks
## their way"). `inside` is which side of it the building is on, for a door side on: 1 east, -1 west, 0 neither known
## (DepthView._inside_of).
## - Facing us (a wall that runs east to west), shut: the whole tile, its front showing (and taking over all but a leaf's
##   thickness of what is lifted: depth_top_deep). Open: its leaf swung back along the west side of its frame, seen edge on, the
##   way through clear beside it.
## - Side on, shut: its leaf seen edge on, from the wall to the north of it to the wall to the south, at the side of its tile the
##   building is on, so it meets the building's roof (the designer, 2026-11-15: "it kind of looks like there is a gap between the
##   door and the roof. Put the door closer to the building, to look connected"); in the middle with neither side known. Open:
##   swung back flat against the north side of the way through, its face to us and the floor of the way clear below it.
func depth_footprint(side_on: bool, inside: int = 0) -> Rect2:
	if side_on:
		if passable():
			return Rect2(0.0, 0.0, 1.0, LEAF_TILES)
		var west := 0.5 - LEAF_TILES * 0.5
		if inside > 0:
			west = 1.0 - LEAF_TILES
		elif inside < 0:
			west = 0.0
		return Rect2(west, 0.0, LEAF_TILES, 1.0)
	return Rect2(0.0, 0.0, LEAF_TILES, 1.0) if passable() else Rect2(0.0, 0.0, 1.0, 1.0)


## How deep its top is seen from above, in tiles. Shut and facing us it is only as thick as its leaf, and its front takes over
## the rest of what is lifted: a door is seen standing, not from above (the designer, 2026-11-15: "When it's closed and 'lifted',
## it's art should take over the part that is 'lifted' as well, as a character would be seeing the door itself, not above it, esp
## when above it is much thinner"). Otherwise all of what it stands on.
func depth_top_deep(side_on: bool) -> float:
	return LEAF_TILES if not side_on and not passable() else 1.0


## Set by the view: whether its ring is drawn at the west end of its front - for a door side on whose building is to the east, so
## that open, the ring is at the end towards the outside, away from where it swung in (the designer, 2026-11-15: "While open the
## handle should face outside, not inwards to where the door is turning").
var depth_handle_west := false


func depth_top() -> Color:
	return WOOD.lerp(WOOD_DARK, 0.35)


## Its top, drawn on `canvas` in `above`: a leaf seen edge on has its two iron bands across it.
func depth_paint_top(canvas: CanvasItem, above: Rect2):
	var top := depth_top()
	canvas.draw_rect(above, top)
	var tile := float(Grid.TILE_SIZE)
	if minf(above.size.x, above.size.y) < tile * 0.5:
		for share in [0.2, 0.72]:
			if above.size.y > above.size.x:
				canvas.draw_rect(Rect2(above.position.x, above.position.y + above.size.y * share, above.size.x, above.size.y * 0.08), IRON)
			else:
				canvas.draw_rect(Rect2(above.position.x + above.size.x * share, above.position.y, above.size.x * 0.08, above.size.y), IRON)
	canvas.draw_rect(above.grow(-3.0), top.darkened(0.3), false, 6.0)


## Its front, drawn on `canvas` in `front`: planks, two iron bands and a ring (at the west end if depth_handle_west, else the
## east). Seen edge on, `front` is only as wide as its leaf is thick.
func depth_paint(canvas: CanvasItem, front: Rect2):
	canvas.draw_rect(front, WOOD)
	var planks := maxi(roundi(front.size.x / (float(Grid.TILE_SIZE) * 0.25)), 1)
	for i in range(1, planks):
		var x: float = front.position.x + front.size.x * i / float(planks)
		canvas.draw_line(Vector2(x, front.position.y), Vector2(x, front.end.y), WOOD_DARK, 5.0)
	canvas.draw_rect(Rect2(front.position.x, front.position.y + front.size.y * 0.2, front.size.x, front.size.y * 0.09), IRON)
	canvas.draw_rect(Rect2(front.position.x, front.position.y + front.size.y * 0.72, front.size.x, front.size.y * 0.09), IRON)
	if planks >= 3:
		var ring_at := 0.2 if depth_handle_west else 0.8
		canvas.draw_circle(Vector2(front.position.x + front.size.x * ring_at, front.position.y + front.size.y * 0.5), front.size.x * 0.045, IRON)
	canvas.draw_rect(front, WOOD_DARK, false, 6.0)


## Whether anybody can walk and see through it right now.
func passable() -> bool:
	return is_open or held


func interact(scene: Node):
	var watch = scene.get("stealth")
	if watch != null and watch.has_method("set_door"):
		watch.set_door(self, not is_open, true)
		return
	set_open(not is_open)
	if scene.has_method("set_tile_shut") and scene.get("_tile_map") != null:
		var tile_map: TileMap = scene._tile_map
		scene.set_tile_shut(tile_map.local_to_map(tile_map.to_local(global_position)), not passable())


## Opens or shuts it, as far as it itself knows. The watch keeps the map's
## walls in step - see StealthWatch.set_door.
func set_open(value: bool):
	is_open = value
	prompt = "Close" if is_open else "Open"
	queue_redraw()


func _draw():
	var tile := float(Grid.TILE_SIZE)
	var half := tile / 2.0
	if depth_stood:
		# Drawn standing by the view: only its sill is on the floor.
		draw_rect(Rect2(-half, -half, tile, tile), Color(WOOD_DARK, 0.22))
	elif passable():
		# Swung back against the side of its frame.
		draw_rect(Rect2(-half, -half, tile * 0.14, tile), WOOD_DARK)
		draw_rect(Rect2(-half, -half, tile * 0.14, tile), WOOD, false, 4.0)
	else:
		draw_rect(Rect2(-half, -half, tile, tile), WOOD)
		for i in range(1, 4):
			var x = -half + tile * i / 4.0
			draw_line(Vector2(x, -half), Vector2(x, half), WOOD_DARK, 5.0)
		draw_rect(Rect2(-half, -half * 0.55, tile, tile * 0.08), IRON)
		draw_rect(Rect2(-half, half * 0.45, tile, tile * 0.08), IRON)
		draw_circle(Vector2(half * 0.6, 0.0), tile * 0.05, IRON)
		draw_rect(Rect2(-half, -half, tile, tile), WOOD_DARK, false, 6.0)
	super()
	if Engine.is_editor_hint():
		draw_string(ThemeDB.fallback_font, Vector2(-half + 8, -half + 28), "Door (open)" if starts_open else "Door",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1.0, 0.85, 0.3, 0.9))
