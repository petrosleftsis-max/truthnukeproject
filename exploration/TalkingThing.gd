@tool
@icon("res://art/editor_icons/interactable.svg")
extends DialogueInteractable
class_name TalkingThing
## A thing with something to say (the proposals of 2026-11-19, "Friendly oddities"; the designer: "Do all"): a statue that critiques
## your fighting (Campaign.fight_review), a bin with opinions and an errand, a lamp post that remembers you (Campaign.count_visit).
## Talked to like anybody (its Dialogue, dialogue/oddities.dialogue for the three of them); passed by within Remarks Tiles it says
## one of its Remarks in a bubble, now and then. Drawn as its Kind until it has a picture. The lines are placeholders. PROPOSAL.

enum Kind { STATUE, BIN, LAMP_POST }

@export var kind: Kind = Kind.STATUE:
	set(value):
		kind = value
		queue_redraw()
@export var remarks: Array[String] = []
@export var remarks_tiles: float = 3.0
## Least seconds between two remarks.
@export var remarks_every: float = 14.0

var _quiet := 0.0
var _rng := RandomNumberGenerator.new()
## For a suite: how many remarks it has made.
var remarked := 0


func _init():
	prompt = "Talk"


func _ready():
	super()
	_rng.seed = hash(name)
	_quiet = _rng.randf_range(1.0, 4.0)


func _process(delta: float):
	if Engine.is_editor_hint() or remarks.is_empty():
		return
	_quiet -= delta
	if _quiet > 0.0:
		return
	var up := get_parent()
	while up != null and not up.has_method("party_position"):
		up = up.get_parent()
	if up == null or up.party_position().distance_to(global_position) > Grid.tiles(remarks_tiles):
		return
	_quiet = remarks_every
	remarked += 1
	SpeechBubbles.say_over(get_tree(), self, remarks[_rng.randi_range(0, remarks.size() - 1)])


func _draw():
	super()
	if texture != null or sprite_frames != null:
		return
	var tile := float(Grid.TILE_SIZE)
	match kind:
		Kind.STATUE:
			draw_rect(Rect2(-tile * 0.3, tile * 0.1, tile * 0.6, tile * 0.3), Color("8d8a86"))
			draw_rect(Rect2(-tile * 0.16, -tile * 0.7, tile * 0.32, tile * 0.82), Color("b9b5ae"))
			draw_circle(Vector2(0, -tile * 0.82), tile * 0.15, Color("c9c5be"))
			draw_line(Vector2(-tile * 0.06, -tile * 0.84), Vector2(-tile * 0.02, -tile * 0.84), Color("4a4744"), 4.0)
			draw_line(Vector2(tile * 0.02, -tile * 0.84), Vector2(tile * 0.06, -tile * 0.84), Color("4a4744"), 4.0)
		Kind.BIN:
			draw_rect(Rect2(-tile * 0.22, -tile * 0.35, tile * 0.44, tile * 0.6), Color("4f6b55"))
			draw_rect(Rect2(-tile * 0.26, -tile * 0.42, tile * 0.52, tile * 0.09), Color("3a5040"))
			draw_circle(Vector2(-tile * 0.08, -tile * 0.12), tile * 0.04, Color.WHITE)
			draw_circle(Vector2(tile * 0.08, -tile * 0.12), tile * 0.04, Color.WHITE)
		Kind.LAMP_POST:
			draw_line(Vector2(0, tile * 0.3), Vector2(0, -tile * 1.1), Color("2c2c34"), 9.0)
			draw_rect(Rect2(-tile * 0.13, -tile * 1.3, tile * 0.26, tile * 0.24), Color("ffd98a"))
			draw_rect(Rect2(-tile * 0.13, -tile * 1.3, tile * 0.26, tile * 0.24), Color("2c2c34"), false, 4.0)
