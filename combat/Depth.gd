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

## How much higher high ground and walls are drawn, in pixels of the map (a tile is Grid.TILE_SIZE). A wall is three quarters of a
## tile: the designer's pick, 2026-11-16 ("192"), having seen 160, 192, 224 and 256 beside somebody the size of Cyrus's idle
## animation. It was 160. Behind a wall that much of the floor is covered, so a tile-deep room still shows a quarter of its floor.
## A door stands as tall (StealthDoor.depth_lift), and a DepthPiece left at its own Height rests on the walls. High ground is half
## a wall, as it was when they were 80 and 160: the designer's pick too, the same day ("96"), from pictures of 80 and 96.
const RAISED_LIFT := 96.0
const WALL_LIFT := 192.0
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
## The group of the figures that are the party's (ExplorationParty's on a map, side 0's in a fight): a roof fades for them.
const PARTY := &"depth_party"
## The group every DepthPiece in the game is in.
const PIECES := &"depth_pieces"

## --- B. Layers and parallax (DepthPiece) ---
##
## How far a piece moves against the ground as the view moves, as a share of how far the view's middle is from it, where the piece
## does not say (its Moves below 0). Only what stands free moves: a tree's crown, in front, and anything behind the ground. A roof,
## an arch and a balcony rest on walls, which do not move, so they stay.
const PIECE_MOVES_FRONT := 0.12
const PIECE_MOVES_BEHIND := 0.5
## What is at the screen's very edge, nearest of all (a DepthPiece of kind Edge), slides fastest.
const PIECE_MOVES_EDGE := 0.35
## How far a piece behind the ground can move at most, each way, in tiles: its picture is drawn that much bigger than the part of
## the ground it is seen through, so it never runs out.
const BEHIND_MARGIN_TILES := 4.0
## A roof fades away whole while one of the party is under it or within this many tiles of it, over this long.
const ROOF_NEAR_TILES := 2.0
const PIECE_FADE_SECONDS := 0.35
## The z of a piece in front: over every figure and lifted row, and - coming after the light's own nodes in the tree, at the same z -
## over the embers, the shafts from windows and the glow round a lamp, which are all inside under a roof (the mist and the clouds'
## shadows with them: a roof stands out of the mist). Smoke from a chimney is one higher. And of one behind, under the ground.
const PIECE_Z_FRONT := ExplorationParty.PARTY_Z_TOP
const PIECE_Z_BEHIND := -50
## One behind that knows the map it is on (DepthPiece "Behind the ground") is drawn over the ground and its shade instead, kept off
## every painted tile: at the ground's own z, after it in the tree, so under every figure and lifted row.
const PIECE_Z_BEHIND_MASKED := 0


## How far a piece moves against the ground: what it says for itself (`own`, 0 or more), or by whether it is `behind` the ground
## and whether it `stands_free` (a tree).
static func piece_moves(own: float, behind: bool, stands_free: bool) -> float:
	if own >= 0.0:
		return own
	if behind:
		return PIECE_MOVES_BEHIND
	return PIECE_MOVES_FRONT if stands_free else 0.0


## Where a piece is drawn off its own place, with the view's middle at `view` and its own at `middle`, both in the world: nothing
## when the view is centred on it. What is in front (nearer than the ground) slides away from the view's middle, as the top of
## something tall does seen from above; what is behind (further) lags after the view, held to BEHIND_MARGIN_TILES.
static func piece_offset(moves: float, behind: bool, middle: Vector2, view: Vector2) -> Vector2:
	if moves <= 0.0:
		return Vector2.ZERO
	if not behind:
		return (middle - view) * moves
	var most := BEHIND_MARGIN_TILES * float(Grid.TILE_SIZE)
	var lag := (view - middle) * moves
	return Vector2(clampf(lag.x, -most, most), clampf(lag.y, -most, most))


## Whether somebody standing at `at` opens a roof over the ground `covered` (both in the world): under it, or near it.
static func roof_opens(covered: Rect2, at: Vector2) -> bool:
	return covered.grow(ROOF_NEAR_TILES * float(Grid.TILE_SIZE)).has_point(at)
## A cutaway: how far round a figure a tile big it reaches, in tiles; how much of what covers them is left in it; and how much of
## its radius is its soft edge.
const CUT_TILES := 0.62
const CUT_ALPHA := 0.16
const CUT_SOFT := 0.3
## The most cutaways at once (the shader's array).
const MOST_CUTS := 24


## The shape of a cutaway about somebody drawn `taller` than a tile (CombatantSprite.head_height, as drawn), `reach` to either
## side: (how far over the point they stand on its middle is, how far up and down from there it goes). The designer, 2026-11-14:
## "The cutaway doesn't look right for the size of Cyrus' idle animation": it was a round patch about the tile, so whoever is drawn
## taller than a tile stood with their head out of it. Now it is as tall as they are: an oval from where the round one ended under
## their feet to as far over their head. Somebody a tile tall has the round patch still. It goes by each figure's own frame, so it
## is right for whoever has been redrawn to Cyrus's size and for whoever has not been yet.
static func cut_shape(taller: float, reach: float) -> Vector2:
	var up := maxf(taller, 0.0) * 0.5
	return Vector2(up, reach + up)
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


## Whether `node` is part of the same scene as `of`: the same node hanging from the root above each. The depth of a map or a fight
## counts only its own scene's figures, things, doors and pieces. In the tests another scene stands in the same world as the one
## being tested (the game's own fight, which every suite starts with), and one of its figures, standing where the Light stage's
## tree is, once opened a cutaway in the tree with nobody of the stage under it (2026-11-15). In the game there is one scene.
static func same_scene(node: Node, of: Node) -> bool:
	return _scene_of(node) == _scene_of(of)


static func _scene_of(node: Node) -> Node:
	var at := node
	while at.get_parent() != null and at.get_parent().get_parent() != null:
		at = at.get_parent()
	return at


## The picture in the slot `name` (without ".png"), or null. With a normal map beside it (`name`_n.png), the two together, so the
## real lights fall on it by that (DepthView "Light that knows height").
static func slot(name: String) -> Texture2D:
	var path := ART + name + ".png"
	if not _slots.has(path):
		var picture: Texture2D = load(path) if ResourceLoader.exists(path) else null
		var normal_path := ART + name + "_n.png"
		if picture != null and ResourceLoader.exists(normal_path):
			var both := CanvasTexture.new()
			both.diffuse_texture = picture
			both.normal_texture = load(normal_path)
			picture = both
		_slots[path] = picture
	return _slots[path]


static var _slots := {}
