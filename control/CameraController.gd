extends Camera2D
class_name CameraController
## Free camera for the battle map: mouse-wheel zoom anchored on the cursor,
## middle-mouse drag and WASD/arrow-key panning, clamped so the view never
## leaves the map.
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
##
## Left and right mouse stay untouched - they still belong to movement and
## skill targeting (see CController._unhandled_input).

## How far out you can pull. Higher zoom = more magnified = less map visible,
## so this is the "whole map" end. At 1.0 the whole painted map (37x22 cells =
## 1184x704) fits inside the 1280x720 viewport with room to spare, so fully
## zoomed out shows everything and there is nothing left to pan to. If you
## enlarge the map past the viewport, lower this to still be able to take it
## all in at once.
@export var min_zoom := 0.17
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
## the edge is where the framing says it is.
@export var allow_zoom := true

var _tile_map: TileMap = null
var _dragging := false


func _ready():
	_tile_map = get_node_or_null(tile_map_path)
	if _tile_map == null:
		push_warning("CameraController: no TileMap found at '%s' - the camera will not be clamped to the map." % tile_map_path)
	zoom = Vector2.ONE * clampf(zoom.x, min_zoom, max_zoom)
	# Re-clamp when the window changes size (the Options menu resizes it): the
	# visible area changes with it, so a position that was legal may not be.
	get_viewport().size_changed.connect(clamp_to_map)
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


## Pulls the camera back inside the map. On an axis where the map is smaller
## than the view there is nothing to pan to, so it centres instead - otherwise
## the clamp would have contradictory bounds and pin the map to one edge with
## all the empty space dumped on the other side. At min zoom that centring
## applies on both axes, which is what locks the fully-zoomed-out view in
## place. Note it centres the *painted* map, so it sits 16px right and down of
## the hard-coded (576, 336) this camera previously used - that value centred a
## 36x21 map, but the TileMap actually has 37x22 cells painted.
func clamp_to_map():
	var map_rect = get_map_rect()
	if map_rect.size.x <= 0.0 or map_rect.size.y <= 0.0:
		return
	var half = get_visible_world_size() * 0.5
	var clamped = position
	for axis in 2:
		if map_rect.size[axis] <= half[axis] * 2.0:
			clamped[axis] = map_rect.position[axis] + map_rect.size[axis] * 0.5
		else:
			clamped[axis] = clampf(
				clamped[axis],
				map_rect.position[axis] + half[axis],
				map_rect.position[axis] + map_rect.size[axis] - half[axis]
			)
	position = clamped


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
	if is_following():
		# Locked on somebody: their turn is the thing to be looking at.
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
	if _shake <= 0.0:
		return
	_shake = lerpf(_shake, 0.0, minf(SHAKE_DECAY * delta, 1.0))
	if _shake < SHAKE_MINIMUM:
		_shake = 0.0
		offset = Vector2.ZERO
		return
	# Divided by zoom so the shake is the same size on screen however far out
	# the view is - offset is in world units, which zoom then scales.
	var amount = _shake / maxf(zoom.x, 0.001)
	offset = Vector2(randf_range(-amount, amount), randf_range(-amount, amount))


func _process(delta):
	_shake_step(delta)
	if is_following():
		position = position.lerp(_watched.global_position, minf(1.0, follow_lerp * delta))
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
	var pan = Vector2(
		_axis(KEY_D, KEY_RIGHT) - _axis(KEY_A, KEY_LEFT),
		_axis(KEY_S, KEY_DOWN) - _axis(KEY_W, KEY_UP)
	)
	if pan == Vector2.ZERO:
		return
	position += pan.normalized() * keyboard_pan_speed * delta / zoom.x
	clamp_to_map()


## 1.0 if either key is held, 0.0 otherwise. Read straight off the keyboard
## rather than through input actions so panning needs no additions to the
## project's input map, and so it keeps working while a UI button happens to
## hold focus (the arrow keys would otherwise be spent navigating it).
func _axis(key_a: Key, key_b: Key) -> float:
	return 1.0 if Input.is_physical_key_pressed(key_a) or Input.is_physical_key_pressed(key_b) else 0.0


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


## Rides along with `target` until release() is called. Manual panning and
## dragging are ignored meanwhile - it is a lock, and a camera that fights the
## player for the view is worse than either behaviour on its own.
func follow(target: Node2D):
	_watched = target


func release():
	_watched = null


## Whether the view is currently locked onto somebody.
func is_following() -> bool:
	return _watched != null and is_instance_valid(_watched)
