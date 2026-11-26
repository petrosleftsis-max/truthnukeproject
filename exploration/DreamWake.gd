@tool
@icon("res://art/editor_icons/interactable.svg")
extends Interactable
class_name DreamWake
## The way out of the dream-place (the proposals of 2026-11-19, "A dream-place"): used, the party wakes by the rest spot they slept
## at (RestSpot.dream keeps it, "dreamt_from"); with none kept, at Fallback Map's first entry. A placeholder pool of light. PROPOSAL.

@export_file("*.tscn") var fallback_map: String = ""


func _init():
	prompt = "Wake"


func interact(scene: Node):
	var from := String(Campaign.flags.get("dreamt_from", ""))
	var spot: Dictionary = Campaign.rest_spots.get(from, {})
	MapFeel.sound(&"dream", -2.0, 0.8, global_position)
	if not spot.is_empty():
		Campaign.travel_to_map(spot.map, RestSpot.ENTRY_PREFIX + from)
	elif fallback_map != "":
		Campaign.travel_to_map(fallback_map, "")
	else:
		return
	scene.reload_map()


func _draw():
	super()
	if texture != null or sprite_frames != null:
		return
	var tile := float(Grid.TILE_SIZE)
	draw_circle(Vector2.ZERO, tile * 0.4, Color(0.85, 0.9, 1.0, 0.35))
	draw_circle(Vector2.ZERO, tile * 0.22, Color(1, 1, 1, 0.6))
