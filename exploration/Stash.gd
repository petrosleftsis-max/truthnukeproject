@tool
@icon("res://art/editor_icons/interactable.svg")
extends Interactable
class_name Stash
## Something tucked away: a loose board, a hollow in a hiding spot, a purse under a stone (the proposals of 2026-11-19, "Secrets
## worth finding"; the designer: "Do all"). Searched once: its items go into the leader's bags and its gold to the purse, and it is a
## secret found. Kept searched in the flags ("searched:" and where it is). A placeholder loose board until it has a picture. PROPOSAL.

## What is in it: item files' names (data/items), and gold.
@export var items: Array[String] = []
@export var gold: int = 0


func _init():
	prompt = "Search"
	secret = true


## The flag it is kept searched in.
func searched_flag() -> String:
	return "searched:" + hack_id()


func is_available() -> bool:
	return super() and (Engine.is_editor_hint() or not Campaign.flag(searched_flag()))


func interact(scene: Node):
	Campaign.set_flag(searched_flag())
	var who := Campaign.leader()
	var found := []
	for item in items:
		if Campaign.give_item(who, item):
			found.append(item)
	if gold > 0:
		Campaign.give_gold(gold)
	var said := []
	for item in found:
		var definition = ItemDatabase.items.get(item)
		said.append(definition.name if definition != null else item)
	if gold > 0:
		said.append("%d gold" % gold)
	if scene != null and scene.has_method("log_message"):
		scene.log_message("Found %s.\n" % (", ".join(said) if not said.is_empty() else "nothing after all"))
	queue_redraw()


func _draw():
	super()
	if texture == null and sprite_frames == null and not Engine.is_editor_hint() and Campaign.flag(searched_flag()):
		return
	if texture == null and sprite_frames == null:
		# A loose board, a little proud of the floor.
		var tile := float(Grid.TILE_SIZE)
		var rect := Rect2(-tile * 0.3, -tile * 0.1, tile * 0.6, tile * 0.2)
		draw_rect(rect, Color("6b4a2c"))
		draw_rect(rect, Color("3a2614"), false, 3.0)
		draw_line(rect.position + Vector2(8, rect.size.y * 0.5), rect.end - Vector2(8, rect.size.y * 0.5), Color("3a2614"), 2.0)
