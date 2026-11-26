@tool
@icon("res://art/editor_icons/interactable.svg")
extends Node2D
class_name MapLabel
## A place's name, written on the map screen where it stands (MapScreen) once the party has seen it (the proposals of 2026-11-19,
## "A map you can open" and Lethe's touch; the designer: "Do all"). With Fades After Days, Lethe takes it: the days since the party
## was last near it wear it away, gone at that many, and coming near again writes it back. Nothing is drawn on the map itself
## but in the editor. PROPOSAL.

@export var text: String = "":
	set(value):
		text = value
		queue_redraw()
## Days until Lethe has worn it away; 0 never.
@export var fades_after_days: int = 0
## How near the party has to come to write it back, in tiles.
@export var seen_within_tiles: float = 6.0

const CHECK_EVERY := 1.0
var _check := 0.0


func seen_flag() -> String:
	var map: Node = owner if owner != null else get_parent()
	return "label_seen:%s::%s" % [map.scene_file_path if map != null else "", String(map.get_path_to(self)) if map != null else String(name)]


## How much of it shows, 0 to 1: all of it for a name Lethe does not touch.
func shown_share() -> float:
	if fades_after_days <= 0:
		return 1.0
	if not Campaign.flags.has(seen_flag()):
		return 0.0
	var days := Campaign.day_number() - int(Campaign.flags[seen_flag()])
	return clampf(1.0 - float(days) / float(fades_after_days), 0.0, 1.0)


func _process(delta: float):
	if Engine.is_editor_hint():
		return
	_check -= delta
	if _check > 0.0:
		return
	_check = CHECK_EVERY
	var up := get_parent()
	while up != null and not up.has_method("party_position"):
		up = up.get_parent()
	if up != null and up.party_position().distance_to(global_position) <= Grid.tiles(seen_within_tiles):
		Campaign.flags[seen_flag()] = Campaign.day_number()


func _draw():
	if Engine.is_editor_hint():
		draw_string(ThemeDB.fallback_font, Vector2(-80, 0), "Label: " + text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1, 1, 1, 0.9))
