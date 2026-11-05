extends Camera2D
class_name CameraController
## Free camera for the battle map: mouse-wheel zoom anchored on the cursor,
## middle-mouse drag and WASD/arrow-key panning, clamped so the middle of the
## view never leaves the map - see clamp_to_map.
##
## The clamp works off the TileMap's actually-used cells rather than a
## hard-coded size, so enlarging or shrinking the map in the editor needs no
## change here. Both the TileMap and this camera live under Terrain, so their
## coordinates are directly comparable.
##
## Controls:
##   Mouse wheel        zoom in/out, keeping whatever is under the cursor
##                      pinned under the cursor
##   Middle-mouse drag  pan
##   WASD / arrow keys  pan
##   Right stick        pan, on a pad; and the view goes along with a pad's
##                      cursor wherever it is stepped to (see CController)
##   Right stick click  out to the whole map, and back
##
## Left and right mouse stay untouched - they still belong to movement and
## skill targeting (see CController._unhandled_input).

## How far out you can pull. Higher zoom = more magnified = less map visible,
## so this is the "whole map" end. If you enlarge the map past what fits at
## this zoom, lower it to still be able to take it all in at once. Scales
## inversely with Grid.TILE_SIZE: 0.17 took in the crossroads at 192-unit
## tiles, and tiles a third bigger need three-quarters of that.
@export var min_zoom := 0.1275
## How far in you can push.
@export var max_zoom := 1.0
## What one mouse-wheel notch multiplies the zoom by.
@export var zoom_step := 1.1
## Keyboard panning speed in screen pixels per second. Divided by zoom when
## applied, so panning feels the same at every zoom level instead of crawling
## across the screen when zoomed in.
@export var keyboard_pan_speed := 600.0
## Which TileMap defines the map's extent - the same one the rest of the game
## treats as the board.
@export var tile_map_path := NodePath("../TileMap")
## Whether the player drives this camera themselves. On in battle, where the
## camera is the only thing WASD and dragging control. Off in exploration,
## where WASD walks the party and the camera follows them instead - leaving it
## on there would have one set of keys doing two things at once, and the
## follow would fight the drag for the camera's position every frame. Zooming
## stays available either way.
@export var free_look := true
## Whether the player may change the zoom. On in battle, where seeing the whole
## board or leaning in on one corner is part of playing it. Off in exploration,
## where the view is a composed shot: the map is drawn to be read at one
## distance, and a scene that walks someone in from off the edge only works if
## the edge is where the framing says it is. A stealth map turns it back on
## (see StealthWatch) - seeing where the guards look is the point there.
@export var allow_zoom := true

var _tile_map: TileMap = null
var _dragging := false
## The zoom to go back to after a pad's look at the whole map.
var _zoom_before := 0.0


func _ready():
	if _tile_map == null:
		_tile_map = get_node_or_null(tile_map_path)
	if _tile_map == null:
		push_warning("CameraController: no TileMap found at '%s' - the camera will not be clamped to the map." % tile_map_path)
	zoom = Vector2.ONE * clampf(zoom.x, min_zoom, max_zoom)
	# Re-clamp when the window changes size (the Options menu resizes it): the
	# visible area changes with it, so a position that was legal may not be.
	get_viewport().size_changed.connect(clamp_to_map)
	clamp_to_map()


## Measures the map by `tile_map` rather than whatever tile_map_path points
## at. For a scene that loads its map itself and knows where the TileMap ended
## up, which one fixed path can't: an exploration map keeps it either straight
## under the map or under a terrain scene inside it (every stealth stage does).
func use_tile_map(tile_map: TileMap):
	_tile_map = tile_map
	if is_inside_tree():
		clamp_to_map()


## The map's extent in world units, taken from the cells the TileMap actually
## uses. Empty if there's no TileMap to measure.
func get_map_rect() -> Rect2:
	if _tile_map == null or _tile_map.tile_set == null:
		return Rect2()
	var used = _tile_map.get_used_rect()
	var cell = Vector2(_tile_map.tile_set.tile_size)
	return Rect2(Vector2(used.position) * cell, Vector2(used.size) * cell)


## How much of the world fits on screen right now.
func get_visible_world_size() -> Vector2:
	return get_viewport_rect().size / zoom.x


## Keeps the middle of the view on the map, and nothing more: the rest of the
## view is free to run past the map's edges.
##
## It used to keep the whole view inside, stopping the moment the map's edge
## met the screen's. But the HUD sits over every side of the screen - the turn
## queue, the action panel, the log, the portraits - so whatever was painted
## along an edge stayed underneath it with no way to pan it into the open.
## Holding only the middle lets any tile be brought to the centre of the
## screen, while the view still can never be lost off the map altogether.
func clamp_to_map():
	var map_rect = get_map_rect()
	if map_rect.size.x <= 0.0 or map_rect.size.y <= 0.0:
		return
	position = position.clamp(map_rect.position, map_rect.end)


## Zooms to `new_zoom_level` while keeping the world point currently under
## `screen_point` still under it, so zooming towards the cursor doesn't drift
## off whatever you were looking at.
##
## The correction is derived from the screen offset rather than by reading
## get_global_mouse_position() before and after: the camera's transform is only
## applied at the end of the frame, so that would report the pre-zoom position
## both times and correct by nothing.
func zoom_at_screen_point(new_zoom_level: float, screen_point: Vector2):
	if not allow_zoom:
		return
	var old_zoom_level = zoom.x
	new_zoom_level = clampf(new_zoom_level, min_zoom, max_zoom)
	if is_equal_approx(new_zoom_level, old_zoom_level):
		return
	if free_look:
		var offset_from_centre = screen_point - get_viewport_rect().size * 0.5
		position += offset_from_centre / old_zoom_level - offset_from_centre / new_zoom_level
	# When the camera isn't the player's to steer it stays locked on whatever
	# it is following - the party leader in exploration - so zooming pulls in
	# and out around them rather than drifting towards wherever the pointer
	# happened to be.
	zoom = Vector2.ONE * new_zoom_level
	clamp_to_map()


func _unhandled_input(event):
	# Anything the player does to the view takes it back from whatever was moving it.
	if event is InputEventMouseButton and event.pressed and allow_zoom and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_MIDDLE]:
		_take_back()
	if is_following():
		# Locked on somebody: their turn is the thing to be looking at. How close
		# is still the player's (the designer, 2026-11-04: "Cannot unzoom and zoom
		# camera" on a turn not theirs), about the middle of the view.
		if event is InputEventMouseButton and event.pressed and allow_zoom \
				and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			_zoom_to_restore = 0.0
			zoom_at_screen_point(zoom.x * (zoom_step if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / zoom_step), get_viewport_rect().size * 0.5)
			get_viewport().set_input_as_handled()
		return
	if free_look and allow_zoom and event.is_action_pressed(&"zoom_toggle"):
		toggle_whole_map()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed and allow_zoom:
			zoom_at_screen_point(zoom.x * zoom_step, event.position)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed and allow_zoom:
			zoom_at_screen_point(zoom.x / zoom_step, event.position)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_MIDDLE and free_look:
			_dragging = event.pressed
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging:
		# relative is in screen pixels; dividing by zoom turns it into world
		# units so the map tracks the cursor exactly at any zoom level.
		position -= event.relative / zoom.x
		clamp_to_map()


## --- Screen shake ---
##
## Driven through `offset` rather than `position`, for two reasons: position is
## clamped to the map every frame, so a shake written there would be fought by
## the clamp and would stop dead at the map edge, and offset is not something
## panning or zooming ever touches, so a shake can never leave the view
## somewhere the player didn't put it.

## How fast a shake dies away. Higher is snappier.
const SHAKE_DECAY = 9.0
## Below this the shake is over - stops it trailing off into a jitter too small
## to see but still costing a frame's work.
const SHAKE_MINIMUM = 0.4

## Current shake, in screen pixels.
var _shake := 0.0


## Rattles the view by `pixels` at its strongest, decaying to nothing. Takes
## the strongest of any overlapping calls rather than adding them up, so three
## things going off together shake once rather than throwing the camera.
func shake(pixels: float):
	_shake = maxf(_shake, pixels)


func _shake_step(delta: float):
	# What leans the view (lean_after) is in offset too, under the shake.
	_lean = _lean.lerp(_lean_aim, 1.0 - exp(-LEAN_RATE * delta))
	if _lean_aim == Vector2.ZERO and _lean.length() * zoom.x < LEAN_GONE_PIXELS:
		_lean = Vector2.ZERO
	if _shake <= 0.0:
		offset = _lean
		return
	_shake = lerpf(_shake, 0.0, minf(SHAKE_DECAY * delta, 1.0))
	if _shake < SHAKE_MINIMUM:
		_shake = 0.0
		offset = _lean
		return
	# Divided by zoom so the shake is the same size on screen however far out
	# the view is - offset is in world units, which zoom then scales.
	var amount = _shake / maxf(zoom.x, 0.001)
	offset = _lean + Vector2(randf_range(-amount, amount), randf_range(-amount, amount))


func _process(delta):
	_shake_step(delta)
	_keep_frame(delta)
	# The keys or a stick take the view back from whatever was moving it.
	if (_gliding or _framing) and free_look and get_viewport().gui_get_focus_owner() == null \
			and Pad.direction(&"pan_left", &"pan_right", &"pan_up", &"pan_down") != Vector2.ZERO:
		_take_back()
	if _gliding:
		_glide_step(delta)
		return
	if _framing:
		return
	if is_following():
		position = position.lerp(_watched.global_position + _watch_offset, minf(1.0, follow_lerp * delta))
		clamp_to_map()
		return
	if not free_look:
		# Exploration drives this camera by following the party; WASD walks
		# them rather than panning the view.
		return
	if get_viewport().gui_get_focus_owner() != null:
		# Something on screen has keyboard focus - in practice the pause menu,
		# since every combat HUD button is focus_mode = None and so can never
		# take it. Leave the arrow keys to walk that menu's buttons instead of
		# dragging the map around underneath it.
		return
	# Keys or stick, never the two added together (Pad.direction).
	var pan := Pad.direction(&"pan_left", &"pan_right", &"pan_up", &"pan_down")
	if pan == Vector2.ZERO:
		return
	# As far as the stick is pushed - all the way, from the keys.
	position += pan.limit_length(1.0) * keyboard_pan_speed * delta / zoom.x
	clamp_to_map()


## Out to the whole map - as far out as the zoom goes - or, out there already,
## back to where it was. A pad's way to take the board in at a glance, having
## no wheel.
func toggle_whole_map():
	var middle := get_viewport_rect().size * 0.5
	if zoom.x > min_zoom * 1.01:
		_zoom_before = zoom.x
		zoom_at_screen_point(min_zoom, middle)
	else:
		zoom_at_screen_point(_zoom_before if _zoom_before > 0.0 else max_zoom * 0.5, middle)


## --- Moved for the player: a turn, a blow, somebody arriving ---
##
## Each an ease, never a cut, and each given up the moment the player touches the
## view (the designer, 2026-11-04: "Have the camera include all user, target and
## projectile when an enemy attacks a player and vice versa. Have the camera
## movements be smooth. Move the camera slightly depending on how the projectile
## does it"; "Whenever a turn starts, smoothly put the camera on the turn
## character for the player whose character is the turn character").
##
## frame() brings a blow into view - only as far as it has to, pulling back only
## if it will not fit - over the part of the screen the HUD leaves the map; it
## stays there until end_frame(), and a beat later goes back where it was, or on
## following whoever it was following. lean_after() and kick() are the slight
## movement with what flies: an offset that never touches where the view is.

## How quickly the view glides: the share of the way left covered in a second is
## 1 - e^-this - a PROPOSAL value.
const GLIDE_RATE := 6.0
## Near enough to be there, in world units, and in zoom.
const GLIDE_THERE := 3.0
const GLIDE_THERE_ZOOM := 0.004
## Room kept round everything framed, in tiles.
const FRAME_ROOM_TILES := 1.5
## How long a blow stays framed once it is over, before the view goes back.
const FRAME_HOLD_SECONDS := 0.45
## How far what flies may lean the view, in screen pixels, how quickly it follows,
## and how little is nothing.
const LEAN_MOST_PIXELS := 70.0
const LEAN_RATE := 8.0
const LEAN_GONE_PIXELS := 0.5

## Whether any of this moves anything: with no screen to see it on, nothing - the
## suites play thousands of blows - unless a test wants to see it.
static var moves_headless := false

var _gliding := false
var _glide_aim := Vector2.ZERO
var _glide_zoom_aim := 0.0
var _framing := false
var _frame_hold := 0.0
## The view to go back to after a blow: {position, zoom}, or empty.
var _frame_back := {}
var _lean := Vector2.ZERO
var _lean_aim := Vector2.ZERO


static func moves() -> bool:
	return DisplayServer.get_name() != "headless" or moves_headless


## Eases the view onto `at` - and to `zoom_level`, when one is given.
func glide_to(at: Vector2, zoom_level: float = 0.0):
	if not moves():
		return
	if _zoom_tween != null and _zoom_tween.is_valid() and zoom_level > 0.0:
		_zoom_tween.kill()
	var map_rect = get_map_rect()
	_glide_aim = at.clamp(map_rect.position, map_rect.end) if map_rect.size.x > 0.0 else at
	_glide_zoom_aim = clampf(zoom_level, min_zoom, max_zoom) if zoom_level > 0.0 else 0.0
	_gliding = true


## Whether the view is on its way somewhere.
func is_gliding() -> bool:
	return _gliding


func _glide_step(delta: float):
	var share := 1.0 - exp(-GLIDE_RATE * delta)
	position = position.lerp(_glide_aim, share)
	if _glide_zoom_aim > 0.0:
		zoom = zoom.lerp(Vector2.ONE * _glide_zoom_aim, share)
	var zoomed: bool = _glide_zoom_aim <= 0.0 or absf(zoom.x - _glide_zoom_aim) <= GLIDE_THERE_ZOOM
	if position.distance_to(_glide_aim) <= GLIDE_THERE and zoomed:
		position = _glide_aim
		if _glide_zoom_aim > 0.0:
			zoom = Vector2.ONE * _glide_zoom_aim
		_gliding = false


## Keeps `points` (world positions) in the part of the screen `room` leaves the
## map, moving the view only if they are not all there now and pulling back only
## if they will not fit. True when the view has to move.
func frame(points: Array, room: Rect2) -> bool:
	if not moves() or points.is_empty():
		return false
	var box := Rect2(points[0], Vector2.ZERO)
	for point in points:
		box = box.expand(point)
	box = box.grow(Grid.tiles(FRAME_ROOM_TILES))
	_framing = true
	_frame_hold = 0.0
	var middle := get_viewport_rect().size * 0.5
	var shown := Rect2(position + (room.position - middle) / zoom.x, room.size / zoom.x)
	if shown.encloses(box):
		return false
	var needed := minf(room.size.x / maxf(box.size.x, 1.0), room.size.y / maxf(box.size.y, 1.0))
	var to_zoom := clampf(minf(needed, zoom.x), min_zoom, max_zoom)
	if _frame_back.is_empty():
		_frame_back = {"position": position, "zoom": zoom.x}
	glide_to(box.get_center() - (room.get_center() - middle) / to_zoom, to_zoom)
	return true


## The blow is over: a beat for it to be seen, and the view goes back.
func end_frame():
	if _framing:
		_frame_hold = FRAME_HOLD_SECONDS
	lean_off()


func _keep_frame(delta: float):
	if not _framing or _frame_hold <= 0.0:
		return
	_frame_hold -= delta
	if _frame_hold > 0.0:
		return
	_framing = false
	var back := _frame_back
	_frame_back = {}
	if back.is_empty():
		return
	# Following somebody, the follow takes the view; only the zoom is put back.
	if is_following():
		_gliding = false
		_glide_zoom(back.zoom)
	else:
		glide_to(back.position, back.zoom)


## The player has touched the view: it is theirs, as they have it now.
func _take_back():
	_gliding = false
	_framing = false
	_frame_hold = 0.0
	_frame_back = {}


## The view leans a little after `point`, by `share` of the way from its middle -
## what flies, as it flies.
func lean_after(point: Vector2, share: float):
	if not moves():
		return
	_lean_aim = ((point - position) * share).limit_length(LEAN_MOST_PIXELS / maxf(zoom.x, 0.001))


## It comes back to the middle.
func lean_off():
	_lean_aim = Vector2.ZERO


## A little shove the way `direction` goes, by `pixels` on the screen - what flew
## landing. It comes back by itself.
func kick(direction: Vector2, pixels: float):
	if not moves() or direction == Vector2.ZERO:
		return
	_lean += direction.normalized() * pixels / maxf(zoom.x, 0.001)


## --- Watching somebody act ---
##
## An enemy's turn happens wherever they are standing, which is as often as not
## somewhere the player is not looking - across the map, or off the edge of the
## view entirely. A fight you cannot see reads as the game having hung. While
## the AI plays a turn the view rides along with whoever is taking it, and is
## handed straight back afterwards.

## How fast the view closes on whoever it is watching, as a fraction of the
## remaining distance per second. Eased rather than snapped: a cut leaves the
## player with no idea which part of the map they are now looking at, while a
## glide carries the eye across and answers that on the way.
@export var follow_lerp := 6.0

var _watched: Node2D = null
## Where on whoever is watched the view centres, from their node: the middle
## of the square somebody bigger than a tile covers.
var _watch_offset := Vector2.ZERO
## The zoom to go back to once whoever was watched is let go, if fitting them
## in pulled the view back (fit_in_view). 0 for nothing to put back.
var _zoom_to_restore := 0.0
## How long the view takes to pull back for somebody big, and to come in again.
const FIT_SECONDS := 0.35
var _zoom_tween: Tween = null


## Rides along with `target` until release() is called, centred `offset_from_it`
## away from it. Manual panning and dragging are ignored meanwhile - it is a
## lock, and a camera that fights the player for the view is worse than either
## behaviour on its own.
func follow(target: Node2D, offset_from_it: Vector2 = Vector2.ZERO):
	_watched = target
	_watch_offset = offset_from_it


## Lets go of whoever was watched, and puts back the zoom if the view pulled
## back to fit them in.
func release():
	_watched = null
	_watch_offset = Vector2.ZERO
	if _zoom_to_restore > 0.0:
		_glide_zoom(_zoom_to_restore)
		_zoom_to_restore = 0.0


## Pulls the view back, if it has to, until something `world_size` across fits
## on screen with `room` to spare around it - an enemy bigger than the view,
## whose turn it is. release() brings the zoom back in.
func fit_in_view(world_size: Vector2, room: float = 1.5):
	var view := get_viewport_rect().size
	var needed := minf(view.x / maxf(world_size.x * room, 1.0), view.y / maxf(world_size.y * room, 1.0))
	needed = clampf(needed, min_zoom, max_zoom)
	if zoom.x <= needed:
		return
	if _zoom_to_restore <= 0.0:
		_zoom_to_restore = zoom.x
	_glide_zoom(needed)


func _glide_zoom(to: float):
	if _zoom_tween != null and _zoom_tween.is_valid():
		_zoom_tween.kill()
	if not is_inside_tree():
		zoom = Vector2.ONE * to
		return
	_zoom_tween = create_tween()
	_zoom_tween.tween_property(self, "zoom", Vector2.ONE * to, FIT_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Whether the view is currently locked onto somebody.
func is_following() -> bool:
	return _watched != null and is_instance_valid(_watched)
