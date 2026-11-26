@tool
@icon("res://art/editor_icons/interactable.svg")
extends Node2D
class_name HiddenMark
## A mark only the dark or a light shows (the proposals of 2026-11-19, "Light that finds things"; the designer: "Do all"). In The
## Dark: it shows only while its tile is Dark and whoever leads, near it, sees in the dark (Cyrus, with Cat Eyes) - only through
## his eyes, not whenever he is somewhere in the party (the designer, 2026-11-19: it showed to everyone). In The Light: only
## while a lamp's light, a Flare's or any light the rules make reaches its tile (LightMap.glow), not the day's. Seen the first time,
## it is a secret found and uncovers what it Reveals: an Interactable kept out of sight and use till then. A placeholder rune until
## it has a Picture. PROPOSAL.

enum Shown { IN_THE_DARK, IN_THE_LIGHT }

@export var shown_in: Shown = Shown.IN_THE_DARK:
	set(value):
		shown_in = value
		queue_redraw()
## Words with it, shown under it while it shows.
@export_multiline var text: String = ""
## What it uncovers once seen: an Interactable, out of sight and use until then.
@export var reveals: NodePath
@export var picture: Texture2D:
	set(value):
		picture = value
		queue_redraw()
## How near one of the party has to be to see it, in tiles.
@export var seen_from_tiles: float = 4.0
## Counted on the map screen, and found the first time it is seen.
@export var secret: bool = true

## How much it shows now, 0 to 1, easing.
var shown_share := 0.0
## The lighthouse lens (Memento LOOK_BACK): where it was looked through and until when (ticks, ms); within Memento.LENS_TILES every
## mark shows, whatever the light.
static var lens_at := Vector2.INF
static var lens_until := 0
const EASE_SECONDS := 0.6


func _ready():
	if Engine.is_editor_hint():
		return
	z_as_relative = false
	z_index = ExplorationParty.PARTY_Z_BOTTOM - 1
	if secret:
		add_to_group(&"secrets")
	var target: Node = get_node_or_null(reveals) if reveals != NodePath() else null
	if target != null and not is_found():
		_hide(target, true)


func found_flag() -> String:
	var map: Node = owner if owner != null else get_parent()
	return "seen:%s::%s" % [map.scene_file_path if map != null else "", String(map.get_path_to(self)) if map != null else String(name)]


func is_found() -> bool:
	return Campaign.flag(found_flag())


## Whether it shows now, by the light where it is and who is near.
func shows_now() -> bool:
	if lens_at.is_finite() and Time.get_ticks_msec() < lens_until and lens_at.distance_to(global_position) <= Grid.tiles(Memento.LENS_TILES):
		return true
	var scene := _scene()
	if scene == null or scene.get("_tile_map") == null:
		return false
	var tile_map: TileMap = scene._tile_map
	var tile := tile_map.local_to_map(tile_map.to_local(global_position))
	var light = scene.get("light")
	if light == null:
		return false
	if scene.party_position().distance_to(global_position) > Grid.tiles(seen_from_tiles):
		return false
	if shown_in == Shown.IN_THE_LIGHT:
		return float(light.glow.get(tile, 0.0)) > 0.0
	if light.level_at(tile) != Light.Level.DARK:
		return false
	# Through the eyes of whoever leads here (over a network, this machine's player's lead).
	return Campaign.sees_in_darkness(Campaign.lead_here())


func _scene() -> Node:
	var up := get_parent()
	while up != null:
		if up.has_method("party_position") and up.get("light") != null:
			return up
		up = up.get_parent()
	return null


func _process(delta: float):
	if Engine.is_editor_hint():
		return
	var showing := shows_now()
	var was := shown_share
	shown_share = move_toward(shown_share, 1.0 if showing else 0.0, delta / EASE_SECONDS)
	if showing and not is_found():
		Campaign.set_flag(found_flag())
		MapFeel.sound(&"mark_seen", -4.0, 1.0, global_position)
		var target: Node = get_node_or_null(reveals) if reveals != NodePath() else null
		if target != null:
			_hide(target, false)
	if not is_equal_approx(was, shown_share):
		queue_redraw()


func _hide(target: Node, hidden: bool):
	if target is CanvasItem:
		target.visible = not hidden
	if "kept_hidden" in target:
		target.kept_hidden = hidden


func _draw():
	var share := 1.0 if Engine.is_editor_hint() else shown_share
	if share <= 0.01:
		return
	var colour := Color(0.62, 0.95, 0.88) if shown_in == Shown.IN_THE_DARK else Color(1.0, 0.82, 0.45)
	colour.a = share
	if picture != null:
		draw_texture(picture, -picture.get_size() * 0.5, Color(1, 1, 1, share))
	else:
		# A rune scratched where only the right eyes or the right light will find it.
		var r := float(Grid.TILE_SIZE) * 0.28
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, colour, 5.0)
		draw_line(Vector2(0, -r * 0.8), Vector2(0, r * 0.8), colour, 5.0)
		draw_line(Vector2(-r * 0.6, -r * 0.2), Vector2(r * 0.6, r * 0.35), colour, 5.0)
	if text != "" and not Engine.is_editor_hint():
		var font := ThemeDB.fallback_font
		draw_string_outline(font, Vector2(-Grid.tiles(1.5), Grid.tiles(0.7)), text, HORIZONTAL_ALIGNMENT_CENTER, Grid.tiles(3.0), 34, 8, Color(0, 0, 0, share))
		draw_string(font, Vector2(-Grid.tiles(1.5), Grid.tiles(0.7)), text, HORIZONTAL_ALIGNMENT_CENTER, Grid.tiles(3.0), 34, colour)
