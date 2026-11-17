@tool
@icon("res://art/editor_icons/hiding.svg")
extends Node2D
class_name HidingSpot
## Somewhere to hide on a stealth map: behind barrels, in a locker, in a dark
## alcove. Place it on a floor tile. Whoever stands on its tile cannot be seen
## by a guard unless the guard is right beside it - though a dog's nose still
## finds them, and a guard who saw them step in walks over to look.
##
## One spot hides one person: a party of two needs two spots side by side, or
## the one following behind is left standing in the open. A knocked-out guard
## stuffed into it fills it - nowhere to hide any more - and hides him from
## everybody but a guard who comes within a couple of tiles of it with it in
## view: a body never quite fits, and a boot sticking out gives it away.

## What it looks like - barrels, a crate. Empty: a patch of shadow only.
@export var look: Texture2D : set = _set_look
## How big `look` is drawn, as a share of a tile.
@export var look_scale: float = 1.0 : set = _set_look_scale

const SHADOW := Color(0.0, 0.0, 0.0, 0.45)
const EDITOR_EDGE := Color(0.45, 0.85, 1.0, 0.9)
## How a spot with a body in it is drawn: darker, so it reads as taken.
const FULL_TINT := Color(0.5, 0.45, 0.45)
const BOOT := Color(0.2, 0.14, 0.1)

## The guard stuffed in here, if any. Set by the StealthWatch.
var holds_body: Node2D = null : set = _set_holds_body


func _set_holds_body(value: Node2D):
	holds_body = value
	queue_redraw()


## --- Stirred ---
##
## The proposals of 2026-11-17, section 5 ("A hiding spot that answers"): somebody of the party going in or coming out shakes it a
## moment and it settles, with a rustle or a creak - `stirs_with`; by itself, a creak for anything drawn and nothing for a patch of
## shadow, which does not shake either (StealthWatch._stir_hiding_spots). Only to look at and hear: no guard hears it. PROPOSAL.
enum Stir { AUTOMATIC, RUSTLE, CREAK, NOTHING }
@export var stirs_with: Stir = Stir.AUTOMATIC
const STIR_SECONDS := 0.38
const STIR_TURN := 0.07
var _stir_tween: Tween = null
## How many times it has been stirred, for a suite.
var stirred := 0


func stir():
	stirred += 1
	var sound := stirs_with
	if sound == Stir.AUTOMATIC:
		sound = Stir.CREAK if look != null else Stir.NOTHING
	if sound != Stir.NOTHING:
		MapFeel.sound(&"rustle" if sound == Stir.RUSTLE else &"creak", -12.0, 1.0, global_position)
	if look == null or not MapFeel.shown():
		return
	if _stir_tween != null and _stir_tween.is_valid():
		_stir_tween.kill()
	_stir_tween = create_tween()
	_stir_tween.tween_method(_stir_at, 0.0, 1.0, STIR_SECONDS)


func _stir_at(t: float):
	var shake := sin(t * PI * 5.0) * (1.0 - t)
	rotation = STIR_TURN * shake
	scale = Vector2(1.0 + 0.04 * absf(shake), 1.0 - 0.06 * absf(shake))


## Whether somebody could still hide here.
func is_free() -> bool:
	return holds_body == null


func _set_look(value: Texture2D):
	look = value
	queue_redraw()


func _set_look_scale(value: float):
	look_scale = value
	queue_redraw()


func _ready():
	# Under the party, so whoever hides is drawn in front of the spot rather
	# than vanishing behind it.
	z_as_relative = false
	z_index = ExplorationParty.PARTY_Z_BOTTOM - 1
	queue_redraw()


func _draw():
	var tile := Vector2(Grid.TILE_SIZE, Grid.TILE_SIZE)
	draw_circle(Vector2(0, Grid.tiles(0.18)), Grid.tiles(0.42), SHADOW)
	if look != null:
		var size = tile * look_scale
		draw_texture_rect(look, Rect2(-size / 2.0, size), false, Color.WHITE if is_free() else FULL_TINT)
	elif not is_free():
		draw_circle(Vector2(0, Grid.tiles(0.18)), Grid.tiles(0.3), SHADOW)
	if not is_free():
		# A boot sticking out: a body never quite fits, and a guard close by
		# notices.
		var heel = Vector2(Grid.tiles(0.28), Grid.tiles(0.3))
		draw_rect(Rect2(heel, Vector2(Grid.tiles(0.18), Grid.tiles(0.09))), BOOT)
		draw_rect(Rect2(heel + Vector2(0, -Grid.tiles(0.12)), Vector2(Grid.tiles(0.07), Grid.tiles(0.13))), BOOT)
	if Engine.is_editor_hint():
		draw_rect(Rect2(-tile / 2.0, tile), EDITOR_EDGE, false, 4.0)
		draw_string(ThemeDB.fallback_font, Vector2(-tile.x / 2.0 + 8, -tile.y / 2.0 + 28), "Hide",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 26, EDITOR_EDGE)
