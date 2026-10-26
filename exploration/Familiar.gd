extends Node2D
class_name Familiar
## Alithia's familiar on a map (Find Familiar - see StealthWatch "Familiar"): a
## spirit in the shape of the map's animal (FamiliarForm), steered with the
## party's own keys or stick while the player is seeing through its eyes, and
## sitting where it was left while they are not.
##
## It walks the way the party does - freely, sliding along what it runs into -
## by a walkability test the map supplies (ExplorationScene.is_walkable_for), so
## a small gap only it fits through is open to it and a flying one goes over
## what stops only walkers. Drawn from the form's animation or still, or with
## neither as a small shape in its colour; a faint shimmer about it says it is
## not an animal at all.

signal moved(position: Vector2)

## The party's pace it moves at a share of (FamiliarForm.speed), in pixels a
## second - ExplorationParty's.
const BASE_SPEED := Grid.TILE_SIZE * 3.4375
## Half the width of what is tested against the map: a fifth of a tile, so it
## goes down a one-tile gap without catching.
const BODY_RADIUS := Grid.TILE_SIZE * 0.2
## How big it is drawn, Tiny and Small, as a radius.
const TINY_BODY := Grid.TILE_SIZE * 0.14
const SMALL_BODY := Grid.TILE_SIZE * 0.21
## The shimmer: how far it reaches past the body, and how fast it breathes.
const SHIMMER_PIXELS := Grid.TILE_SIZE * 0.07
const SHIMMER_SPEED := 3.0
const SHIMMER := Color(0.75, 0.6, 1.0, 0.35)

var form: FamiliarForm = null
## Whether the player is steering it now - seeing through its eyes.
var controlled := false
## Held still: a conversation, a menu, a catch (ExplorationScene.is_holding).
var holding := false
## Takes a world position, a size and a movement class; true where it may be.
var _walkable: Callable = Callable()
var _facing_left := false
var _sprite: AnimatedSprite2D = null


## Puts it in `the_form` at `at`, testing where it may go with `walkable`.
func setup(the_form: FamiliarForm, at: Vector2, walkable: Callable):
	form = the_form
	global_position = at
	_walkable = walkable
	z_as_relative = false
	z_index = ExplorationParty.PARTY_Z_TOP + 1
	if form.sprite_frames != null:
		_sprite = AnimatedSprite2D.new()
		_sprite.sprite_frames = form.sprite_frames
		add_child(_sprite)
		_play("idle")
	queue_redraw()


## Where it is, as a tile of `tile_map`.
func tile_on(tile_map: TileMap) -> Vector2i:
	return tile_map.local_to_map(tile_map.to_local(global_position))


func _process(delta):
	queue_redraw()
	if not controlled or holding:
		_play("idle")
		return
	var direction := Pad.direction(&"move_left", &"move_right", &"move_up", &"move_down")
	if direction == Vector2.ZERO:
		_play("idle")
		return
	step(direction, delta)


## One step in `direction`, sliding along anything in the way. False when it
## could not move at all.
func step(direction: Vector2, delta: float) -> bool:
	if direction.x != 0.0:
		_facing_left = direction.x < 0.0
	var travel := direction.normalized() * BASE_SPEED * (form.speed if form != null else 1.0) * delta
	var before := global_position
	var moved_to := global_position
	var candidate := Vector2(moved_to.x + travel.x, moved_to.y)
	if can_be_at(candidate):
		moved_to = candidate
	candidate = Vector2(moved_to.x, moved_to.y + travel.y)
	if can_be_at(candidate):
		moved_to = candidate
	if moved_to == before:
		_play("idle")
		return false
	global_position = moved_to
	_play("walk")
	moved.emit(global_position)
	return true


## Whether its body fits at `centre`: each corner of a small box about it, by
## the map's test for its size and how it gets about.
func can_be_at(centre: Vector2) -> bool:
	if not _walkable.is_valid():
		return true
	var size: int = form.size if form != null else Sizes.Size.TINY
	var flies: int = form.movement_class if form != null else 0
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		if not _walkable.call(centre + corner * BODY_RADIUS, size, flies):
			return false
	return true


func _play(animation: String):
	if _sprite == null:
		return
	_sprite.flip_h = _facing_left
	if _sprite.sprite_frames.has_animation(animation) and _sprite.animation != animation:
		_sprite.play(animation)


func _draw():
	var breath := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * SHIMMER_SPEED)
	var body: float = TINY_BODY if form == null or form.size == Sizes.Size.TINY else SMALL_BODY
	draw_circle(Vector2.ZERO, body + SHIMMER_PIXELS * (0.6 + 0.4 * breath), Color(SHIMMER, SHIMMER.a * (0.5 + 0.5 * breath)))
	if _sprite != null:
		return
	if form != null and form.texture != null:
		var size := form.texture.get_size()
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1.0 if _facing_left else 1.0, 1.0))
		draw_texture(form.texture, -size / 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	# A small animal in its colour: a body, a head with ears, a tail - or wings.
	var colour := form.colour if form != null else Color("8a7f74")
	var ahead := -1.0 if _facing_left else 1.0
	var flying := form != null and form.movement_class == 1
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(ahead, 1.0))
	draw_circle(Vector2(0, 0), body * 0.8, colour)
	draw_circle(Vector2(body * 0.85, -body * 0.35), body * 0.5, colour)
	if flying:
		draw_colored_polygon(PackedVector2Array([Vector2(-body * 0.2, -body * 0.3), Vector2(-body * 1.4, -body * 1.2), Vector2(-body * 0.6, body * 0.1)]), colour.darkened(0.2))
		draw_colored_polygon(PackedVector2Array([Vector2(body * 1.25, -body * 0.4), Vector2(body * 1.7, -body * 0.25), Vector2(body * 1.25, -body * 0.15)]), Color("d8b24a"))
	else:
		draw_colored_polygon(PackedVector2Array([Vector2(body * 0.7, -body * 0.7), Vector2(body * 0.85, -body * 1.15), Vector2(body * 1.0, -body * 0.75)]), colour)
		draw_line(Vector2(-body * 0.7, 0), Vector2(-body * 1.6, -body * 0.5), colour, body * 0.18)
	draw_circle(Vector2(body * 1.05, -body * 0.45), body * 0.12, Color(0.95, 0.9, 0.6))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
