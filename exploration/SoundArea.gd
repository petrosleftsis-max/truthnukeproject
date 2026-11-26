@tool
@icon("res://art/editor_icons/interactable.svg")
extends Node2D
class_name SoundArea
## The sound of a place (the proposals of 2026-11-19, "Sound by place"; the designer: "Do all"). A rectangle of the map, placed on
## its top left tile, Size Tiles across: while the party is in it its Ambience plays quietly, looping, faded in and out (the
## SoundBank's ambience_<kind>, a stand-in meanwhile), and their steps sound of its Surface (step_<surface>). PROPOSAL.

enum Ambience { NONE, WIND, CITY, DRIPS, DREAM }
enum Surface { AS_IT_IS, STONE, WOOD, GRASS }

const AMBIENCE_SLOTS := ["", "ambience_wind", "ambience_city", "ambience_drips", "ambience_dream"]
const SURFACE_NAMES := ["", "stone", "wood", "grass"]
const GROUP := &"sound_areas"
## How loud the bed is at full, and how long it takes to come in or go.
const BED_DB := -16.0
const FADE_SECONDS := 1.5

@export var size_tiles: Vector2i = Vector2i(6, 4):
	set(value):
		size_tiles = Vector2i(maxi(value.x, 1), maxi(value.y, 1))
		queue_redraw()
@export var ambience: Ambience = Ambience.NONE
@export var surface: Surface = Surface.AS_IT_IS

var _player: AudioStreamPlayer = null
var _share := 0.0
## For a suite: whether the party is in it now.
var party_inside := false


func _ready():
	if not Engine.is_editor_hint():
		add_to_group(GROUP)


## The world rectangle it covers.
func covers_rect() -> Rect2:
	var tile := float(Grid.TILE_SIZE)
	return Rect2(global_position - Vector2.ONE * tile / 2.0, Vector2(size_tiles) * tile)


## What is underfoot at `at` (the world): the surface's name of the first area there that says, else "".
static func surface_at(at: Vector2) -> String:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return ""
	for area in tree.get_nodes_in_group(GROUP):
		if area.surface != Surface.AS_IT_IS and area.covers_rect().has_point(at):
			return SURFACE_NAMES[area.surface]
	return ""


func _process(delta: float):
	if Engine.is_editor_hint() or ambience == Ambience.NONE:
		return
	var up := get_parent()
	while up != null and not up.has_method("party_position"):
		up = up.get_parent()
	party_inside = up != null and covers_rect().has_point(up.party_position())
	_share = move_toward(_share, 1.0 if party_inside else 0.0, delta / FADE_SECONDS)
	if _share > 0.0 and _player == null and DisplayServer.get_name() != "headless":
		_player = AudioStreamPlayer.new()
		_player.bus = &"SFX"
		_player.stream = _bed()
		add_child(_player)
		_player.play()
	if _player != null:
		_player.volume_db = lerpf(-60.0, BED_DB, _share)
		if _share <= 0.0:
			_player.queue_free()
			_player = null


## The bed of sound, looped: the designer's from the SoundBank, else a stand-in.
func _bed() -> AudioStream:
	var slot: String = AMBIENCE_SLOTS[ambience]
	var stream: AudioStream = GameSounds.stream(StringName(slot))
	if stream == null:
		var made := PlaceholderSounds.make(slot).duplicate() as AudioStreamWAV
		made.loop_mode = AudioStreamWAV.LOOP_FORWARD
		made.loop_begin = 0
		made.loop_end = made.data.size() / 2
		return made
	if stream is AudioStreamWAV:
		stream = stream.duplicate()
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif "loop" in stream:
		stream = stream.duplicate()
		stream.loop = true
	return stream


func _draw():
	if not Engine.is_editor_hint():
		return
	var tile := float(Grid.TILE_SIZE)
	var rect := Rect2(-Vector2.ONE * tile / 2.0, Vector2(size_tiles) * tile)
	draw_rect(rect, Color(0.6, 0.4, 0.9, 0.12))
	draw_rect(rect, Color(0.75, 0.55, 1.0, 0.8), false, 3.0)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(8, 28), "Sound: %s / %s" % [Ambience.keys()[ambience].capitalize(),
			Surface.keys()[surface].capitalize()], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.85, 0.7, 1.0))
