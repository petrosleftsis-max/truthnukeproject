extends PanelContainer
class_name StoreScreen
## A store (StoreDefinition): what it sells down one side, what the party could
## sell it down the other, and the purse at the top. Built in code; Campaign
## does the buying and selling (Campaign.buy, sell_item, sell_gear), this only
## asks and redraws.
##
## Bought items go into the bag of the first of the party with room, leader
## first; bought gear into the stash, to be put on from the character sheet.
##
## Over a network each player has a store of their own, and both may have the
## same one open (the designer, 2026-10-31). The purse is the party's one: on a
## joiner a deal is asked of the host (Net.store_deal), which makes it, and
## every store open on either machine is drawn again as one is made
## (Net.campaign_changed) - the joiner's told why when it did not go (refused).

## Leave was pressed.
signal closed

const INK := Color("dce8f5")
const MUTED := Color("8296a9")
const GOLD := Color(1.0, 0.84, 0.35)
const LIST_HEIGHT := 360
## How long a deal that did not go is said for, seconds.
const REFUSED_SECONDS := 3.0

var store: StoreDefinition = null

var _key := ""
var _note: Label = null
var _note_left := 0.0
var _gold: Label = null
var _buy_list: VBoxContainer = null
var _sell_list: VBoxContainer = null
var _leave: Button = null
var _focus: FocusOnDemand = null


## Builds the store for `key`.
func open_on(key: String):
	_key = key
	store = StoreDefinition.named(key)
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size = Vector2(820, 0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	add_child(column)
	var title := Label.new()
	title.theme_type_variation = &"HeaderLabel"
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = store.name if store != null else "Store"
	column.add_child(title)
	if store != null and store.greeting != "":
		var greeting := Label.new()
		greeting.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		greeting.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		greeting.add_theme_color_override("font_color", MUTED)
		greeting.text = store.greeting
		column.add_child(greeting)
	_gold = Label.new()
	_gold.name = "Gold"
	_gold.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold.add_theme_color_override("font_color", GOLD)
	column.add_child(_gold)
	_note = Label.new()
	_note.name = "Note"
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
	_note.visible = false
	column.add_child(_note)
	var sides := HBoxContainer.new()
	sides.add_theme_constant_override("separation", 18)
	column.add_child(sides)
	_buy_list = _side(sides, "Buy")
	if store != null and store.buys_back:
		_sell_list = _side(sides, "Sell")
	_leave = Button.new()
	_leave.name = "Leave"
	_leave.text = "Leave"
	_leave.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_leave.pressed.connect(func(): closed.emit())
	column.add_child(_leave)
	# Over a network: a deal the other player makes, drawn here too.
	Net.campaign_changed.connect(redraw)
	redraw()


## A deal asked of the host did not go (Net._store_refused): said for a moment.
func refused(why: String):
	_note.text = why
	_note.visible = true
	_note_left = REFUSED_SECONDS


## What was last said of a deal that did not go, while it is up - or "".
func note() -> String:
	return _note.text if _note != null and _note.visible else ""


func _process(delta):
	if _note_left > 0.0:
		_note_left -= delta
		if _note_left <= 0.0:
			_note.visible = false


## A heading and a scrolling list under it.
func _side(sides: HBoxContainer, heading: String) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sides.add_child(column)
	var label := Label.new()
	label.theme_type_variation = &"HeaderLabel"
	label.add_theme_font_size_override("font_size", 20)
	label.text = heading
	column.add_child(label)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, LIST_HEIGHT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.name = heading + "List"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	return list


## Everything worked out again - after anything is bought or sold, here or by
## the other player. The keyboard's place is kept, on the same row.
func redraw():
	if _gold == null:
		return
	var focused := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	var focused_row := ""
	if focused != null and is_ancestor_of(focused) and focused.name == "Button":
		focused_row = String(focused.get_parent().name)
	_gold.text = "%d gold" % Campaign.gold
	for list in [_buy_list, _sell_list]:
		if list == null:
			continue
		for child in list.get_children():
			list.remove_child(child)
			child.queue_free()
	if store == null:
		return
	for key in store.stock:
		var refusal := Campaign.cannot_buy(store, key)
		_buy_list.add_child(_row("Buy_" + key, _name_of(key), _reading_of(key), Campaign.price_of(key), "Buy",
			refusal, _on_buy.bind(key)))
	if _sell_list != null:
		for row in sellable():
			_sell_list.add_child(_row("Sell_%s_%s" % [row.owner, row.key], row.label, _reading_of(row.key),
				Campaign.sell_price(store, row.key), "Sell", "", _on_sell.bind(row.owner, row.key)))
		if _sell_list.get_child_count() == 0:
			var none := Label.new()
			none.text = "Nothing the store would buy."
			none.add_theme_color_override("font_color", MUTED)
			_sell_list.add_child(none)
	if _focus == null:
		_focus = FocusOnDemand.attach(self, _first_button())
	else:
		_focus.remember(_first_button())
	if focused_row != "":
		var again := _button_on(focused_row)
		(again if again != null and not again.disabled else _first_button()).grab_focus()


## The button on the row called `row_name`, or null.
func _button_on(row_name: String) -> Button:
	for list in [_buy_list, _sell_list]:
		if list != null and list.has_node(row_name):
			return list.get_node(row_name).get_node_or_null("Button")
	return null


## What the party could sell here: each item in each bag once, with how many,
## then each piece in the gear stash. `owner` is whose bag, or "" for the stash.
func sellable() -> Array:
	var found := []
	for character in Campaign.living_party():
		var seen := {}
		for key in Campaign.inventory_of(character):
			if key == "" or seen.has(key) or Campaign.sell_price(store, key) <= 0:
				continue
			seen[key] = true
			var count := Campaign.count_of(character, key)
			found.append({"owner": character, "key": key,
				"label": "%s%s - %s" % [_name_of(key), " x%d" % count if count > 1 else "", Campaign.display_name_of(character)]})
	var stashed := {}
	for key in Campaign.gear:
		if stashed.has(key) or Campaign.sell_price(store, key) <= 0:
			continue
		stashed[key] = true
		found.append({"owner": "", "key": key, "label": "%s - stash" % _name_of(key)})
	return found


## One line: what it is, what it costs, and the button.
func _row(row_name: String, text: String, reading: String, price: int, verb: String, refusal: String, action: Callable) -> Control:
	var row := HBoxContainer.new()
	row.name = row_name
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	label.tooltip_text = TooltipText.wrap(reading)
	row.add_child(label)
	var cost := Label.new()
	cost.text = "%d" % price
	cost.add_theme_color_override("font_color", GOLD)
	row.add_child(cost)
	var button := Button.new()
	button.name = "Button"
	button.text = verb
	button.disabled = refusal != ""
	button.tooltip_text = refusal
	button.pressed.connect(action)
	row.add_child(button)
	return row


func _name_of(key: String) -> String:
	if ItemDatabase.is_item(key):
		var item: ItemDefinition = ItemDatabase.item(key)
		return item.name if item != null else key
	var piece := EquipmentDefinition.named(key)
	return piece.name if piece != null else key


func _reading_of(key: String) -> String:
	if ItemDatabase.is_item(key):
		var item: ItemDefinition = ItemDatabase.item(key)
		return "%s\n\n%s" % [item.name, item.description] if item != null else key
	var piece := EquipmentDefinition.named(key)
	if piece == null:
		return key
	var lines := [piece.name, piece.summary()]
	if not piece.for_characters.is_empty():
		lines.append("For " + ", ".join(piece.for_characters.map(func(who): return Campaign.display_name_of(who))))
	if piece.description != "":
		lines.append_array(["", piece.description])
	return "\n".join(lines)


func _on_buy(key: String):
	if Net.follows():
		Net.store_deal(_key, "buy", "", key)
		return
	Campaign.buy(store, key)
	redraw()
	Net.send_now()


func _on_sell(owner_key: String, key: String):
	if Net.follows():
		Net.store_deal(_key, "sell", owner_key, key)
		return
	if owner_key == "":
		Campaign.sell_gear(store, key)
	else:
		Campaign.sell_item(store, owner_key, key)
	redraw()
	Net.send_now()


func _first_button() -> Control:
	for list in [_buy_list, _sell_list]:
		if list == null:
			continue
		for row in list.get_children():
			var button = row.get_node_or_null("Button")
			if button != null and not button.disabled:
				return button
	return _leave
