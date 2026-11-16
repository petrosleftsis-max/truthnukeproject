@tool
@icon("res://art/editor_icons/pickup.svg")
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
	z_index = ExplorationParty.PARTY_Z_BOTTOM - 2
	var item = _item()
	if item != null:
		prompt = "Take the %s" % item.name.to_lower()
	queue_redraw()


func _item() -> ItemDefinition:
	if item_key == "" or Engine.is_editor_hint() and not is_inside_tree():
		return null
	var database = get_node_or_null("/root/ItemDatabase")
	if database == null:
		return load("res://data/items/%s.tres" % item_key) if ResourceLoader.exists("res://data/items/%s.tres" % item_key) else null
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


## Gone from where it lay: it rises, and flies off to the leader's portrait, landing with a tick (the proposals of 2026-11-16,
## section 3: "Picked up"; MapFeel.fly_to_bag). Only to look at: it is in the bag already.
func mark_taken():
	if not taken and is_inside_tree() and not Engine.is_editor_hint():
		_fly_off()
	taken = true
	if taken_flag != "":
		Campaign.set_flag(taken_flag)
	queue_redraw()


func _fly_off():
	var item = _item()
	var to_screen := get_viewport().get_canvas_transform()
	var from: Vector2 = to_screen * (global_position + Vector2(0.0, -Grid.TILE_SIZE * 0.25))
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var to := Vector2(48.0, screen.y - 48.0)
	var scene := get_tree().current_scene
	var hud = scene.get("game_ui") if scene != null else null
	if hud != null and is_instance_valid(hud) and hud.has_node("Actions/StatusIcon") and hud.get_node("Actions/StatusIcon").is_visible_in_tree():
		to = hud.get_node("Actions/StatusIcon").get_global_rect().get_center()
	MapFeel.fly_to_bag(scene if scene != null else self, item.icon if item != null else null, from, to, func(): MapFeel.sound(&"picked_up", -8.0))


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
