extends CanvasLayer
class_name InventoryUI
## The party's bags, opened with I while walking around.
##
## Everyone's inventory is on screen at once, side by side, because the whole
## point of a bag per character is deciding who carries what - and that is a
## comparison, not a list. Click a slot, then click another, and the two swap -
## or, for two things that go together (ItemDefinition.made_from), are put
## together. The second one can belong to somebody else, which is how the party
## hands things round.
##
## Only outside a fight. In a battle a character has what they packed, and
## shuffling the bags mid-turn would make the four combat slots meaningless.

## Palette, shared with the other menus.
const INK := Color("dce8f5")
const INK_DIM := Color("c2ceda")
const MUTED := Color("8296a9")
const ACCENT := Color("4a86c8")
const PANEL := Color("19212c")
const CARD := Color("1c2531")
const CARD_LIT := Color("24344a")
const CARD_EDGE := Color("2b3947")
## The belt (the Baldric) - what comes into a fight - is marked out from the rest of the bag.
const COMBAT_EDGE := Color("c8a24a")

const SLOT := Vector2(50, 50)
## Slots a row, in each container's grid.
const COLUMNS := 5
## What is kept clear above and below the bags when they are as tall as they get.
const SCREEN_MARGIN := 220

var _root: Control = null
var _columns: HBoxContainer = null
## The bags scroll, past the height the screen has for them.
var _scroll: ScrollContainer = null
## Which slot is waiting for a second click: {"key": combatant_key, "slot": int}.
var _holding: Dictionary = {}
## Which container is waiting for a second click: {"key", "kind"} for somebody's,
## {"stash": container key} for one in the stash.
var _holding_container: Dictionary = {}
var _hint: Label = null
var _gold: Label = null
## Containers in the stash, and the way to put one there.
var _stash_row: HFlowContainer = null
## Why the last container move was refused, if it was.
var _said: Label = null


func _ready():
	layer = 60
	# One of the menus a pad's View opens - see Pad.
	add_to_group(&"pad_menu")
	_build()
	visible = false
	if not Campaign.inventory_changed.is_connected(_on_inventory_changed):
		Campaign.inventory_changed.connect(_on_inventory_changed)
	if not Campaign.party_changed.is_connected(_rebuild):
		Campaign.party_changed.connect(_rebuild)


func _build():
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(shade)

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	_root.add_child(column)

	var title := Label.new()
	title.theme_type_variation = GameFonts.HEADER
	title.text = "Inventory"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", INK)
	column.add_child(title)

	# The purse, which every bag shares (Campaign.gold).
	_gold = Label.new()
	_gold.name = "Gold"
	_gold.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold.add_theme_color_override("font_color", Color(1.0, 0.84, 0.35))
	column.add_child(_gold)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_scroll)

	_columns = HBoxContainer.new()
	_columns.alignment = BoxContainer.ALIGNMENT_CENTER
	_columns.add_theme_constant_override("separation", 16)
	_columns.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_scroll.add_child(_columns)

	# Belts, pouches and backpacks in the stash, to put on (Campaign "Containers").
	_stash_row = HFlowContainer.new()
	_stash_row.name = "Stash"
	_stash_row.alignment = FlowContainer.ALIGNMENT_CENTER
	_stash_row.add_theme_constant_override("h_separation", 6)
	column.add_child(_stash_row)

	_said = Label.new()
	_said.name = "Said"
	_said.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_said.add_theme_font_size_override("font_size", 13)
	_said.add_theme_color_override("font_color", Color(1.0, 0.84, 0.35))
	column.add_child(_said)

	var hint := Label.new()
	_hint = hint
	_name_keys()
	if not Pad.changed.is_connected(_name_keys):
		Pad.changed.connect(_name_keys)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", MUTED)
	column.add_child(hint)


## One bag per party member, left to right in marching order.
func _rebuild():
	if _columns == null:
		return
	if _gold != null:
		_gold.text = "%d gold" % Campaign.gold
	for child in _columns.get_children():
		_columns.remove_child(child)
		child.queue_free()
	for key in Campaign.living_party():
		_columns.add_child(_bag(key))
	_show_stash()
	_fit_to_screen()


## One of the party's bag: a grid per container they wear - belt, pouch,
## backpack (Campaign "Containers") - under a header to change it by.
func _bag(key: String) -> Control:
	var holder := VBoxContainer.new()
	holder.name = "Bag_" + key
	holder.add_theme_constant_override("separation", 4)

	var definition: CombatantDefinition = CombatantDatabase.combatants.get(key)
	var who := Label.new()
	who.text = definition.name if definition != null else key
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	who.add_theme_font_size_override("font_size", 16)
	who.add_theme_color_override("font_color", INK_DIM)
	holder.add_child(who)

	var slots = Campaign.inventory_of(key)
	# One bag's badges worked out together, so a Big Bomb and a Blinding Bomb
	# carried side by side do not both say BB.
	var tags := SkillLook.tags_for(slots.map(func(id): return ItemDatabase.item(id) if id != "" else null))
	for kind in Campaign.CONTAINER_SLOTS:
		holder.add_child(_container_header(key, kind))
		var count := Campaign.slots_in(key, kind)
		if count == 0:
			continue
		var grid := GridContainer.new()
		grid.name = kind.capitalize()
		grid.columns = COLUMNS
		grid.add_theme_constant_override("h_separation", 4)
		grid.add_theme_constant_override("v_separation", 4)
		var start := Campaign.container_start(key, kind)
		for i in range(start, start + count):
			grid.add_child(_slot_button(key, i, slots[i], tags[i]))
		holder.add_child(grid)
	return holder


## The button over one of somebody's containers: what it is, to press and then
## press another of the same kind (somebody else's, to swap) or one in the stash.
func _container_header(key: String, kind: String) -> Button:
	var piece := EquipmentDefinition.named(Campaign.container_in(key, kind))
	var header := Button.new()
	header.name = "Header_" + kind
	header.focus_mode = Control.FOCUS_NONE
	header.flat = true
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.add_theme_font_size_override("font_size", 12)
	var held: bool = _holding_container.get("key", "") == key and _holding_container.get("kind", "") == kind
	header.add_theme_color_override("font_color", ACCENT if held else (COMBAT_EDGE if kind == "belt" else MUTED))
	header.text = "%s: %s" % [EquipmentDefinition.slot_name_of(kind), piece.name if piece != null else "none"]
	header.tooltip_text = TooltipText.wrap(piece.summary() if piece != null else "No %s worn. Press, then press one in the stash to put it on." % kind)
	header.pressed.connect(_on_container_pressed.bind(key, kind))
	return header


## The containers in the stash, a button each, and where to put one back.
func _show_stash():
	for child in _stash_row.get_children():
		_stash_row.remove_child(child)
		child.queue_free()
	var label := Label.new()
	label.text = "Stash:"
	label.add_theme_color_override("font_color", MUTED)
	_stash_row.add_child(label)
	var seen := {}
	for piece_key in Campaign.gear:
		var piece := EquipmentDefinition.named(piece_key)
		if piece == null or not piece.is_container() or seen.has(piece_key):
			continue
		seen[piece_key] = true
		var button := Button.new()
		button.name = "Stash_" + piece_key
		button.focus_mode = Control.FOCUS_NONE
		var count := Campaign.gear.count(piece_key)
		button.text = piece.name + (" x%d" % count if count > 1 else "")
		button.tooltip_text = TooltipText.wrap(piece.summary())
		if _holding_container.get("stash", "") == piece_key:
			button.add_theme_color_override("font_color", ACCENT)
		button.pressed.connect(_on_stash_pressed.bind(piece_key))
		_stash_row.add_child(button)
	var away := Button.new()
	away.name = "PutAway"
	away.focus_mode = Control.FOCUS_NONE
	away.text = "Put in the stash"
	away.tooltip_text = "Press a pouch or a baldric, then this, to take it off - what is in it goes into the other containers."
	away.pressed.connect(_on_put_away_pressed)
	_stash_row.add_child(away)


## A container's header pressed: picked up, or put down on another of its kind.
func _on_container_pressed(key: String, kind: String):
	_holding = {}
	if _holding_container.is_empty():
		_holding_container = {"key": key, "kind": kind}
		_said.text = ""
		_rebuild()
		return
	var from := _holding_container
	_holding_container = {}
	var why := ""
	if from.has("stash"):
		why = _wear_from_stash(key, from.stash)
	elif from.key == key and from.kind == kind:
		why = ""
	elif from.kind != kind:
		why = "A %s swaps for a %s, not a %s" % [from.kind, from.kind, kind]
	else:
		why = Campaign.swap_containers(from.key, key, kind)
	_said.text = why
	_rebuild()


## A container in the stash pressed: put on whoever's container is picked up,
## or picked up itself.
func _on_stash_pressed(piece_key: String):
	_holding = {}
	if _holding_container.has("kind"):
		var on: Dictionary = _holding_container
		_holding_container = {}
		_said.text = _wear_from_stash(on.key, piece_key)
		_rebuild()
		return
	_holding_container = {} if _holding_container.get("stash", "") == piece_key else {"stash": piece_key}
	_said.text = ""
	_rebuild()


## Put in the stash pressed, with somebody's pouch or belt picked up: off it comes.
func _on_put_away_pressed():
	if not _holding_container.has("kind"):
		_said.text = "Press a pouch or a baldric first."
		return
	var off: Dictionary = _holding_container
	_holding_container = {}
	_said.text = Campaign.take_off_container(off.key, off.kind)
	_rebuild()


## `key` puts on `piece_key` from the stash. "" when done, or why not.
func _wear_from_stash(key: String, piece_key: String) -> String:
	var piece := EquipmentDefinition.named(piece_key)
	if piece == null:
		return ""
	return Campaign.wear_container(key, piece_key)


## The bags as tall as they want, up to what the screen has room for, scrolling
## past that. Measured a frame late, once laid out.
func _fit_to_screen():
	await get_tree().process_frame
	if not visible or _scroll == null:
		return
	var room := get_viewport().get_visible_rect().size.y - SCREEN_MARGIN
	_scroll.custom_minimum_size.y = minf(_columns.get_combined_minimum_size().y, room)


func _slot_button(key: String, index: int, item_id: String, tag: String = "") -> Button:
	var button := Button.new()
	button.custom_minimum_size = SLOT
	button.focus_mode = Control.FOCUS_NONE
	var in_combat_slots = index < Campaign.combat_slots_of(key)
	var edge = COMBAT_EDGE if in_combat_slots else CARD_EDGE
	var held = _holding.get("key", "") == key and _holding.get("slot", -1) == index
	button.add_theme_stylebox_override("normal", _box(CARD_LIT if held else CARD, ACCENT if held else edge))
	button.add_theme_stylebox_override("hover", _box(CARD_LIT, ACCENT))
	button.add_theme_stylebox_override("pressed", _box(CARD_LIT, ACCENT))

	var item: ItemDefinition = ItemDatabase.item(item_id) if item_id != "" else null
	if item != null:
		button.tooltip_text = TooltipText.wrap("%s\n%s" % [item.name, item.description])
		if item.icon != null:
			var art := TextureRect.new()
			art.texture = item.icon
			art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(art)
			SkillLook.decorate(art, item, tag)
		else:
			# No art yet: the name, shortened, is better than an empty square.
			button.text = item.name.substr(0, 3)
			button.add_theme_font_size_override("font_size", 12)
			button.add_theme_color_override("font_color", INK)
		# A stack of bombs, where a container lets them share a slot.
		var count := Campaign.count_in(key, index)
		if count > 1:
			var badge := Label.new()
			badge.name = "Count"
			badge.text = "x%d" % count
			badge.add_theme_font_size_override("font_size", 12)
			badge.add_theme_color_override("font_color", INK)
			badge.add_theme_color_override("font_outline_color", Color.BLACK)
			badge.add_theme_constant_override("outline_size", 4)
			badge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
			badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			badge.grow_vertical = Control.GROW_DIRECTION_BEGIN
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(badge)
			button.tooltip_text = TooltipText.wrap("%s (%d)\n%s" % [item.name, count, item.description])
	elif in_combat_slots:
		button.tooltip_text = "A baldric slot - whatever is here comes into battle."
	button.pressed.connect(_on_slot_pressed.bind(key, index))
	return button


## First click picks a slot up, second puts it down. Putting it back where it
## came from is how you change your mind.
func _on_slot_pressed(key: String, index: int):
	_holding_container = {}
	if _holding.is_empty():
		_holding = {"key": key, "slot": index}
		_rebuild()
		return
	var from_key = _holding.key
	var from_slot = _holding.slot
	_holding = {}
	if from_key == key and from_slot == index:
		_rebuild()
		return
	# Two things that go together are put together rather than swapped (see
	# ItemDefinition.made_from).
	if Campaign.combine_slots(from_key, from_slot, key, index) == "":
		Campaign.move_item(from_key, from_slot, key, index)
	_rebuild()


func _on_inventory_changed(_key = ""):
	if visible:
		_rebuild()


func _box(fill: Color, edge: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(2 if edge == COMBAT_EDGE or edge == ACCENT else 1)
	box.set_corner_radius_all(5)
	return box


func open():
	_holding = {}
	_holding_container = {}
	if _said != null:
		_said.text = ""
	_rebuild()
	visible = true


func close():
	_holding = {}
	_holding_container = {}
	visible = false


## The line along the bottom: how to use it, and what closes it - from the
## keyboard or from a pad.
func _name_keys():
	if _hint == null or not is_instance_valid(_hint):
		return
	var pick := "Press %s on a slot" % Pad.key(&"pointer_click") if Pad.using_pad else "Click a slot"
	_hint.text = ("%s, then another, to move or swap - including into somebody else's bag.\n"
		+ "The baldric is what comes with you into a fight; press a container's name, then another's or one in the stash, to change it.    %s or %s to close.") % [
		pick, Pad.key([&"inventory", &"menus"]), Pad.key(&"ui_cancel")]


## --- For a pad's View (see Pad) ---


func pad_menu_order() -> int:
	return 2


func pad_menu_available() -> bool:
	var pictures = get_node_or_null("/root/Pictures")
	return is_inside_tree() and not (pictures != null and pictures.is_open()) and not MenuPause.held_by_another(self)


func pad_menu_is_open() -> bool:
	return visible


func pad_menu_open():
	open()


func pad_menu_close():
	close()


func toggle():
	if visible:
		close()
	else:
		open()


func is_open() -> bool:
	return visible


func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel") and visible:
		close()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"inventory"):
		toggle()
		get_viewport().set_input_as_handled()
