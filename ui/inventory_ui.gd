extends CanvasLayer
class_name InventoryUI
## The party's bags, opened with I while walking around.
##
## Everyone's inventory is on screen at once, side by side, because the whole
## point of a bag per character is deciding who carries what - and that is a
## comparison, not a list. Click a slot, then click another, and the two swap.
## The second one can belong to somebody else, which is how the party hands
## things round.
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
## The four that come into a fight are marked out from the rest of the bag.
const COMBAT_EDGE := Color("c8a24a")

const SLOT := Vector2(54, 54)

var _root: Control = null
var _columns: HBoxContainer = null
## Which slot is waiting for a second click: {"key": combatant_key, "slot": int}.
var _holding: Dictionary = {}


func _ready():
	layer = 60
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

	_columns = HBoxContainer.new()
	_columns.alignment = BoxContainer.ALIGNMENT_CENTER
	_columns.add_theme_constant_override("separation", 16)
	_columns.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_columns)

	var hint := Label.new()
	hint.text = "Click a slot, then another, to move or swap - including into somebody else's bag.\nThe four marked slots are what comes with you into a fight.    I or Esc to close."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", MUTED)
	column.add_child(hint)


## One bag per party member, left to right in marching order.
func _rebuild():
	if _columns == null:
		return
	for child in _columns.get_children():
		_columns.remove_child(child)
		child.queue_free()
	for key in Campaign.living_party():
		_columns.add_child(_bag(key))


func _bag(key: String) -> Control:
	var holder := VBoxContainer.new()
	holder.add_theme_constant_override("separation", 6)

	var definition: CombatantDefinition = CombatantDatabase.combatants.get(key)
	var who := Label.new()
	who.text = definition.name if definition != null else key
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	who.add_theme_font_size_override("font_size", 16)
	who.add_theme_color_override("font_color", INK_DIM)
	holder.add_child(who)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	var slots = Campaign.inventory_of(key)
	# One bag's badges worked out together, so a Big Bomb and a Blinding Bomb
	# carried side by side do not both say BB.
	var tags := SkillLook.tags_for(slots.map(func(id): return ItemDatabase.item(id) if id != "" else null))
	for i in slots.size():
		grid.add_child(_slot_button(key, i, slots[i], tags[i]))
	holder.add_child(grid)
	return holder


func _slot_button(key: String, index: int, item_id: String, tag: String = "") -> Button:
	var button := Button.new()
	button.custom_minimum_size = SLOT
	button.focus_mode = Control.FOCUS_NONE
	var in_combat_slots = index < Campaign.COMBAT_SLOTS
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
	elif in_combat_slots:
		button.tooltip_text = "A fighting slot - whatever is here comes into battle."
	button.pressed.connect(_on_slot_pressed.bind(key, index))
	return button


## First click picks a slot up, second puts it down. Putting it back where it
## came from is how you change your mind.
func _on_slot_pressed(key: String, index: int):
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
	_rebuild()
	visible = true


func close():
	_holding = {}
	visible = false


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
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_I:
		toggle()
		get_viewport().set_input_as_handled()
