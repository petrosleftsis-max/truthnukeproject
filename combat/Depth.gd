extends RefCounted
class_name Depth
## 2.5D with the art there is (docs/2_5d_plan.md; the designer and their artist, 2026-11-13: A, B and C of
## docs/proposals_2026-11-07.md section 22). What it decides, as static functions with no nodes in them, so a headless suite can
## ask (`depth`); DepthView draws what they say. All of it is only how things look: nothing here is asked by a rule, and a rule
## asks nothing here. Every number is a PROPOSAL.
##
## A. Raised ground, shown. High ground (Combat.is_high: a tile whose Blocks stops a walker but not a flier, and is not
##    see-through) is drawn again RAISED_LIFT higher, and a wall (it stops a flier too) WALL_LIFT higher, with a face under each
##    where what lies to its south is lower. Whoever stands behind something lifted is covered by it, so it goes see-through in
##    a round patch about them (the designer's pick, 2026-11-13: the cutaway). Whoever stands up on high ground is drawn as much
##    higher. On a map every figure takes its z from where it stands (z_at), so the nearer is drawn over the further.

enum Kind { FLOOR, HIGH, WALL, VOID }

## How much higher high ground and walls are drawn, in pixels of the map (a tile is Grid.TILE_SIZE).
const RAISED_LIFT := 80.0
const WALL_LIFT := 160.0
## The value in a tile's Blocks that lets sight through (CController.SEE_THROUGH): a railing, water. Never lifted.
const SEE_THROUGH := 3
## Whether walls are lifted at all. Off, only high ground is.
static var walls_lifted := true
## The TileSet's custom data that says how high one tile is drawn, where that is not what its Blocks would give it (lift_at).
const LIFT_LAYER := "Lift"
## The TileSet's custom data that says a tile's picture is a thing standing on the floor (a barrel, a crate), not raised ground:
## the floor under it stays where it is, and the thing is drawn bigger and standing (stands_at; the designer, 2026-11-13: "the
## barrels themselves, although climbable indeed, don't make sense to be lifted as they are just objects on the map").
const STANDS_LAYER := "Stands"
## How much bigger such a thing is drawn than it is painted in its tile, and how far under its top whoever climbs it stands, as a
## share of its height.
const OBJECT_SCALE := 1.3
const STAND_ON_SHARE := 0.16
## The group of things lying on a map that are to be found (Interactable): drawn over raised ground they lie on, and seen
## through what covers them.
const THINGS := &"depth_things"
## The group of a map's own nodes that stand up like a wall while they are shut or whole (StealthDoor, BreakableWall): each says
## how high with depth_lift() (DepthView "What a map's own nodes stand up").
const UPRIGHTS := &"depth_uprights"

## The group every figure drawn is in (CombatantSprite), for sorting them on a map and for the cutaway.
const FIGURES := &"depth_figures"
## A cutaway: how far round a figure a tile big it reaches, in tiles; how much of what covers them is left in it; and how much of
## its radius is its soft edge.
const CUT_TILES := 0.62
const CUT_ALPHA := 0.16
const CUT_SOFT := 0.3
## The most cutaways at once (the shader's array).
const MOST_CUTS := 24
## How much of somebody has to be showing for them to open a cutaway: nobody the player cannot see ever does.
const CUT_NEEDS_ALPHA := 0.08

## How many steps of z a tile's height on the map is worth, on a map (z_at).
const Z_STEPS_A_TILE := 8

## The tiles whose own picture will not do for their top once lifted, and the tile drawn in its place until the artist's
## top_<column>_<row>.png is there: the laboratory's wall pieces are half wall and half floor, so lifted over the row behind them
## they looked like more floor; their tops are the whole block.
const TOP_STAND_INS := {Vector2i(2, 3): Vector2i(0, 2), Vector2i(3, 3): Vector2i(1, 2)}

## Slots for the artist (docs/depth_on_maps.md): a picture here is drawn in place of what code draws.
const ART := "res://art/terrain/depth/"


## What a tile with this Blocks data is, for drawing. The same test as Combat.is_high, from the tile's own data.
static func kind_of_blocks(blocks) -> int:
	if blocks == null or not (blocks is Array or blocks is PackedInt32Array):
		return Kind.FLOOR
	var walker := false
	var flier := false
	for block in blocks:
		if block == SEE_THROUGH:
			return Kind.FLOOR
		if block == 0:
			walker = true
		elif block == 1:
			flier = true
	if walker and flier:
		return Kind.WALL
	if walker:
		return Kind.HIGH
	return Kind.FLOOR


## What the tile at `tile` of `tile_map` is: VOID where nothing is painted.
static func kind_at(tile_map: TileMap, tile: Vector2i) -> int:
	var data := tile_map.get_cell_tile_data(0, tile)
	if data == null:
		return Kind.VOID
	if tile_map.tile_set == null or tile_map.tile_set.get_custom_data_layer_by_name("Blocks") < 0:
		return Kind.FLOOR
	return kind_of_blocks(data.get_custom_data("Blocks"))


## How much higher something of `kind` is drawn.
static func lift_of(kind: int) -> float:
	if kind == Kind.HIGH:
		return RAISED_LIFT
	if kind == Kind.WALL and walls_lifted:
		return WALL_LIFT
	return 0.0


## How much higher the tile at `tile` of `tile_map` is drawn: by what it is, unless the TileSet's "Lift" says otherwise for that
## tile (LIFT_LAYER: below 0, never lifted - the sewer's channel, which the rules count as high ground and which lies low; above 0,
## that many pixels). Only high ground and walls are ever lifted: nobody stands up on anything else.
static func lift_at(tile_map: TileMap, tile: Vector2i) -> float:
	if tile_map == null:
		return 0.0
	var lift := lift_of(kind_at(tile_map, tile))
	if lift > 0.0 and stands_at(tile_map, tile):
		return 0.0
	if lift <= 0.0 or tile_map.tile_set == null or tile_map.tile_set.get_custom_data_layer_by_name(LIFT_LAYER) < 0:
		return lift
	var data := tile_map.get_cell_tile_data(0, tile)
	var own = data.get_custom_data(LIFT_LAYER) if data != null else 0.0
	if own == null or float(own) == 0.0:
		return lift
	return maxf(float(own), 0.0)


## Whether the tile at `tile` is high ground whose picture is a thing standing on the floor (the TileSet's "Stands").
static func stands_at(tile_map: TileMap, tile: Vector2i) -> bool:
	if tile_map == null or tile_map.tile_set == null or tile_map.tile_set.get_custom_data_layer_by_name(STANDS_LAYER) < 0:
		return false
	if kind_at(tile_map, tile) != Kind.HIGH:
		return false
	var data := tile_map.get_cell_tile_data(0, tile)
	return data != null and bool(data.get_custom_data(STANDS_LAYER))


## Every tile of `tile_map` with a thing standing on it (stands_at).
static func standers_of(tile_map: TileMap) -> Array:
	var found := []
	if tile_map == null:
		return found
	for tile in tile_map.get_used_cells(0):
		if stands_at(tile_map, tile):
			found.append(tile)
	return found


## Every tile of `tile_map` that is drawn lifted, {tile: lift}.
static func lifts_of(tile_map: TileMap) -> Dictionary:
	var lifts := {}
	if tile_map == null:
		return lifts
	for tile in tile_map.get_used_cells(0):
		var lift := lift_at(tile_map, tile)
		if lift > 0.0:
			lifts[tile] = lift
	return lifts


## How tall the face under `tile` is, given every lift (lifts_of): by how much it stands over what lies to its south. 0: none.
static func face_under(lifts: Dictionary, tile: Vector2i) -> float:
	var here: float = lifts.get(tile, 0.0)
	return maxf(here - float(lifts.get(tile + Vector2i.DOWN, 0.0)), 0.0)


## The z a figure standing at `y` in the world takes on a map whose tiles begin at `top` (the world y of its first row's north
## edge): between ExplorationParty.PARTY_Z_BOTTOM and just under PARTY_Z_TOP, higher the further down the screen. A lifted row
## takes the z of its north edge, so whoever stands on it or in front of it is over it, and whoever stands behind it under it.
static func z_at(y: float, top: float) -> int:
	var steps := floori((y - top) / (float(Grid.TILE_SIZE) / float(Z_STEPS_A_TILE)))
	return clampi(ExplorationParty.PARTY_Z_BOTTOM + steps, ExplorationParty.PARTY_Z_BOTTOM, ExplorationParty.PARTY_Z_TOP - 1)


## Whether a figure standing at `at` (a y in the world) is covered by a lifted row whose north edge is at `north`: it stands
## behind the row. On it, or in front of it, it is drawn over it.
static func stands_behind(at: float, north: float) -> bool:
	return at < north


## Whether somebody drawn `alpha` solid and `visible` opens a cutaway in what covers them: only who the player can see.
static func opens_a_cutaway(visible: bool, alpha: float) -> bool:
	return visible and alpha > CUT_NEEDS_ALPHA


## The picture in the slot `name` (without ".png"), or null.
static func slot(name: String) -> Texture2D:
	var path := ART + name + ".png"
	if not _slots.has(path):
		_slots[path] = load(path) if ResourceLoader.exists(path) else null
	return _slots[path]


static var _slots := {}
