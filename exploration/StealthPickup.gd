@tool
extends Interactable
class_name StealthPickup
## Something lying about on a stealth map to be taken: a ledger on a desk, a
## key on a hook, a poison on a shelf. E beside it puts it in the leader's bag.
##
## Something a guard would miss: once it is gone, a guard who sees where it
## stood goes to look - wondering who took it.

## What it is, by item key.
@export var item_key: String = "" : set = _set_item_key
## Whether a guard who sees it gone comes to look.
@export var missed_when_taken: bool = true
## Set when it is taken.
@export var taken_flag: String = ""

var taken := false


func _init():
	prompt = "Take"


func _set_item_key(value: String):
	item_key = value
	queue_redraw()


func _ready():
	super()
	z_as_relative = false
	z_index = ExplorationParty.PARTY_Z_TOP - 2
	var item = _item()
	if item != null:
		prompt = "Take the %s" % item.name.to_lower()
	queue_redraw()


func _item() -> ItemDefinition:
	if item_key == "" or Engine.is_editor_hint() and not is_inside_tree():
		return null
	var database = get_node_or_null("/root/ItemDatabase")
	if database == null:
		return load("res://items/%s.tres" % item_key) if ResourceLoader.exists("res://items/%s.tres" % item_key) else null
	return database.item(item_key)


func is_available() -> bool:
	return super() and not taken


func interact(scene: Node):
	var watch = scene.get("stealth")
	if watch != null and watch.has_method("take_pickup"):
		watch.take_pickup(self)
		return
	var members = Campaign.party_members()
	if not members.is_empty() and Campaign.give_item(members[0].key, item_key):
		mark_taken()


## Gone from where it lay.
func mark_taken():
	taken = true
	if taken_flag != "":
		Campaign.set_flag(taken_flag)
	queue_redraw()


func _draw():
	var tile := float(Grid.TILE_SIZE)
	# Whatever it lies on: a little stand, which stays when it is gone.
	draw_rect(Rect2(-tile * 0.3, tile * 0.05, tile * 0.6, tile * 0.18), Color(0.3, 0.22, 0.14))
	if not taken:
		var item = _item()
		if item != null and item.icon != null:
			var size = Vector2.ONE * tile * 0.5
			draw_texture_rect(item.icon, Rect2(Vector2(-size.x / 2.0, -size.y * 0.75), size), false)
		else:
			draw_circle(Vector2(0, -tile * 0.1), tile * 0.15, Color(0.95, 0.85, 0.4))
	super()
