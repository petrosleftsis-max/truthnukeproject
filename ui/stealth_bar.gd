extends PanelContainer
class_name StealthBar
## A stealth map's own strip of the HUD, along the top: how the one leading is
## doing - sneaking, hidden or in disguise - how on edge the map is, whether
## anybody has noticed anything yet, and everything he can do.
##
## Keys: 1-9 put a disguise on, H hides again, Shift dashes, Ctrl creeps, P
## (held) hurries time along, T throws, Q listens, V vaults over a barrel, F springs an ambush and E beside
## a guard a disguise fools has a word with him. A left click on the map takes a guard
## down, or picks up, puts down or hides a body, and a right click picks pockets (see
## StealthWatch._click_on_guard). Throwing, listening, taking down, dragging
## and picking pockets only show when they have something to do: something to
## throw, a map that hides its guards, a guard unaware or a body right beside
## him. Built by StealthWatch, which it asks everything of.

var watch: StealthWatch = null

## How big a disguise's icon is drawn on its button.
const ICON_SIZE := 40
## How far down from the top of the screen it sits.
const TOP_GAP := 16.0
const CALM := Color("9fc7a4")
const WARY := Color("e0b04a")
const ALARMED := Color("e05a4a")
const GHOST := Color("a9c8f0")

var _row: HBoxContainer = null
## The second row: what he could do right here, right now.
var _here: HBoxContainer = null
var _status: Label = null
var _alert: Label = null
var _ghost: Label = null
var _throw: Button = null
## A button for every other thing he carries to throw, and what they are for.
var _other_throws: Array[Button] = []
var _other_keys: Array = []
var _ears: Button = null
var _dash: Button = null
var _creep: Button = null
var _patience: Button = null
var _vault: Button = null
var _takedown: Button = null
var _drag: Button = null
var _pocket: Button = null
var _ambush: Button = null
var _hide: Button = null
var _buttons: Array[Button] = []
## What the disguise buttons were last built for, so they are only rebuilt
## when that changes rather than every frame.
var _built_for := ""


func _ready():
	name = "StealthBar"
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Two rows: how he is doing and what he always has on the first, and under
	# it whatever he could do right here - which, beside a guard in a disguise,
	# is a good deal, and was more than one row could hold on the screen.
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	add_child(rows)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 10)
	rows.add_child(_row)
	_here = HBoxContainer.new()
	_here.add_theme_constant_override("separation", 10)
	_here.alignment = BoxContainer.ALIGNMENT_CENTER
	rows.add_child(_here)
	_status = _label()
	_alert = _label()
	_ghost = _label()
	_ghost.add_theme_color_override("font_color", GHOST)
	_throw = _button(_on_throw_pressed)
	_ears = _button(_on_ears_pressed)
	_dash = _button(_on_dash_pressed)
	_creep = _button(_on_creep_pressed)
	_creep.toggle_mode = true
	_creep.text = "Creep (Ctrl)"
	_creep.tooltip_text = "Walk slowly, without a sound - across gravel, puddles and broken glass too. Hold Ctrl, or click to keep creeping."
	# Held, not clicked: time runs fast for as long as it is down.
	_patience = Button.new()
	_patience.focus_mode = Control.FOCUS_NONE
	_patience.toggle_mode = true
	_patience.text = "Patience (P)"
	_patience.tooltip_text = "Hold it (or P) and time runs twice as fast - for waiting out a patrol. Let go and it is back to normal."
	_patience.button_down.connect(_on_patience.bind(true))
	_patience.button_up.connect(_on_patience.bind(false))
	_row.add_child(_patience)
	_vault = _button(_on_vault_pressed, _here)
	_vault.text = "Vault (V)"
	_vault.tooltip_text = "Hop over the barrel beside you to the other side."
	_takedown = _button(_on_takedown_pressed, _here)
	_takedown.text = "Take down (Left click)"
	_drag = _button(_on_drag_pressed, _here)
	_pocket = _button(_on_pocket_pressed, _here)
	_pocket.text = "Pick pocket (Right click)"
	_ambush = _button(_on_ambush_pressed, _here)
	_ambush.text = "Ambush (F)"
	_ambush.tooltip_text = "Start the fight here, on your terms: every guard who hadn't noticed you loses their first turn."
	_hide = _button(_on_hide_pressed, _here)
	_hide.text = "Hide (H)"
	refresh()


func _label() -> Label:
	var label := Label.new()
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_row.add_child(label)
	return label


func _button(pressed: Callable, into: HBoxContainer = null) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(pressed)
	(into if into != null else _row).add_child(button)
	return button


func _process(_delta):
	refresh()
	# Centred along the top by hand rather than by anchors, which resolve
	# against nothing under a bare CanvasLayer - it sat at the left edge with
	# half of it off the screen.
	reset_size()
	position = Vector2(roundf((get_viewport_rect().size.x - size.x) / 2.0), TOP_GAP)


## Brings the bar up to date with the watch.
func refresh():
	if watch == null or _row == null:
		return
	var carried: Array = watch.disguises()
	var worn: String = watch.worn_by(watch.leader_key())
	var wanted = "%s|%s" % [carried, watch.leader_key()]
	if wanted != _built_for:
		_built_for = wanted
		_rebuild(carried)
	var changing: String = watch.changing_into()
	var cannot_wear: String = watch.wear_refusal()
	for i in _buttons.size():
		_buttons[i].set_pressed_no_signal(carried[i] == worn or carried[i] == changing)
		_buttons[i].disabled = cannot_wear != "" and carried[i] != changing
		var item: ItemDefinition = ItemDatabase.item(carried[i])
		_buttons[i].tooltip_text = cannot_wear if cannot_wear != "" and carried[i] != changing \
			else (item.description if item.description != "" else "Wear it")
		_buttons[i].tooltip_text += "\nOn the map while you point at it: grey - fooled by it, amber - would stop you with questions, purple - sees through it."
	# How he is doing.
	if changing != "":
		_status.text = "Changing into %s %.1fs" % [ItemDatabase.item(changing).name, watch.change_left()]
	elif watch.lacing() != "":
		_status.text = "Stirring in %s %.1fs" % [ItemDatabase.item(watch.lacing()).name, watch.lace_left()]
	elif worn != "":
		var copied = CombatantDatabase.combatants.get(ItemDatabase.item(worn).disguise_as)
		_status.text = "Disguised as %s" % (copied.name if copied != null else "somebody else")
	elif watch.leader_hiding():
		_status.text = "Hidden"
	else:
		_status.text = "Creeping" if watch.creeping() else "Sneaking"
		if watch.leader_in_shadow():
			_status.text += " in the dark"
	_creep.set_pressed_no_signal(watch.creeping())
	# Lit while time is running fast, whichever way it is held.
	_patience.set_pressed_no_signal(watch.hurried())
	# How on edge the map is.
	var level: String = watch.alert_level()
	_alert.text = level
	_alert.add_theme_color_override("font_color", {"Calm": CALM, "Wary": WARY, "Alarmed": ALARMED}[level])
	_alert.tooltip_text = "How on edge the guards are. Wary and Alarmed guards walk quicker, look wider and grow sure quicker. It never settles by itself - a word with a guard your disguise fools (R) settles it a level."
	if watch.alert_floor > 0.0:
		_alert.tooltip_text += " A body was found: it will not settle below %s." % StealthWatch.ALERT_NAMES[StealthWatch.level_of(watch.alert_floor)]
	_ghost.text = "Unseen"
	_ghost.visible = watch.never_noticed()
	_ghost.tooltip_text = "Nobody has so much as begun to notice you yet."
	# Throwing.
	var throwable: String = watch.aiming() if watch.is_aiming() else watch.throwable()
	_throw.visible = throwable != ""
	if throwable != "":
		var item: ItemDefinition = ItemDatabase.item(throwable)
		var count = Campaign.count_of(watch.leader_key(), throwable)
		var more: bool = watch.throwables().size() > 1
		if watch.is_aiming():
			_throw.text = "Aiming %s - click%s" % [item.name, " (T: next)" if more else ""]
		else:
			_throw.text = "Throw %s x%d (T)" % [item.name, count]
		if item.is_poison():
			_throw.tooltip_text = "Throw it at a guard within %d tiles you can see. %s" % [StealthWatch.THROW_TILES, item.description]
		else:
			_throw.tooltip_text = "Throw it somewhere within %d tiles you can see; guards within %d tiles of where it lands go to look." % [
				StealthWatch.THROW_TILES, item.distraction_radius]
		if more:
			_throw.tooltip_text += " While aiming, T again picks the next thing to throw."
		_throw.tooltip_text += " Thrown from a hiding spot, anybody who can see the spot sees you do it."
	# Everything else he could throw, a button each beside it - so a dart is not
	# hidden behind the pebbles. A click aims that one instead.
	var others: Array = watch.throwables().filter(func(key): return key != throwable)
	if others != _other_keys:
		_other_keys = others.duplicate()
		for button in _other_throws:
			_row.remove_child(button)
			button.queue_free()
		_other_throws.clear()
		for key in others:
			var button := Button.new()
			button.focus_mode = Control.FOCUS_NONE
			button.pressed.connect(_on_other_throw_pressed.bind(key))
			_row.add_child(button)
			_row.move_child(button, _throw.get_index() + 1 + _other_throws.size())
			_other_throws.append(button)
	for i in others.size():
		var other: ItemDefinition = ItemDatabase.item(others[i])
		_other_throws[i].text = "%s x%d" % [other.name, Campaign.count_of(watch.leader_key(), others[i])]
		_other_throws[i].tooltip_text = "Aim this instead. %s" % other.description
	# Listening.
	_ears.visible = watch.hides_guards()
	if watch.ears_left() > 0.0:
		_ears.text = "Listening %.1fs" % watch.ears_left()
		_ears.disabled = true
	elif watch.ears_cooldown() > 0.0:
		_ears.text = "Ears %.1fs" % watch.ears_cooldown()
		_ears.disabled = true
	else:
		_ears.text = "Ears (Q)"
		_ears.disabled = false
	_ears.tooltip_text = "Hear every guard through the walls for %d seconds." % StealthWatch.EARS_SECONDS
	# The dash, and how long until it is ready again.
	var cooling: float = watch.dash_cooldown()
	var no_dash: String = watch.dash_refusal()
	_dash.disabled = cooling > 0.0 or no_dash != ""
	_dash.text = "Dash %.1fs" % cooling if cooling > 0.0 else "Dash (Shift)"
	_dash.tooltip_text = no_dash if no_dash != "" else "A burst of %d tiles, then %d seconds to recover. Anyone who sees it grows sure %d times as fast, and guards within %d tiles hear it." % [
		StealthWatch.DASH_TILES, StealthWatch.DASH_COOLDOWN, StealthWatch.DASH_NOTICE, StealthWatch.DASH_NOISE_TILES]
	# Beside something to hop over.
	_vault.visible = not watch.vault_over().is_empty()
	# Behind somebody who has no idea, or beside somebody out cold.
	var dragging = watch.dragging()
	var down = watch.takedown_target() if dragging == null else null
	_takedown.visible = down != null
	if down != null:
		_takedown.tooltip_text = "Left click to knock them out. It is heard: guards within %d tiles come to look, and one who sees them lying there raises the alarm." % StealthWatch.TAKEDOWN_NOISE_TILES
	if dragging != null:
		var stash = watch.stash_spot()
		_drag.visible = true
		_drag.text = "Hide body (Left click)" if stash != null else "Drop body (Left click)"
		_drag.tooltip_text = "Into the hiding spot beside you - out of sight, but a guard who comes within a couple of tiles of it will notice. Nobody can hide there any more." if stash != null \
			else "Leave them here. Stand beside a free hiding spot to hide them in it instead."
	else:
		_drag.visible = watch.drag_target() != null
		_drag.text = "Drag body (Left click)"
		_drag.tooltip_text = "Pick them up and drag them after you, at half your pace. Any guard who sees you at it knows you at once."
	_pocket.visible = watch.pocket_target() != null
	_pocket.tooltip_text = "Right click to lift what they carry, without them noticing."
	_ambush.visible = watch.ambush_target() != null and watch.ambush_refusal() == ""
	var refusal: String = watch.hide_refusal()
	_hide.visible = watch.worn_by(watch.leader_key()) != ""
	_hide.disabled = refusal != ""
	_hide.tooltip_text = refusal if refusal != "" else "Take the disguise off and slip back out of sight"
	# The second row only while there is something on it.
	_here.visible = _here.get_children().any(func(button): return button.visible)


func _rebuild(carried: Array):
	_preview("")
	for button in _buttons:
		_row.remove_child(button)
		button.queue_free()
	_buttons.clear()
	for i in carried.size():
		var item: ItemDefinition = ItemDatabase.item(carried[i])
		var button := Button.new()
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.text = "%d  %s" % [i + 1, item.name] if i < 9 else item.name
		button.icon = item.icon
		button.expand_icon = false
		button.add_theme_constant_override("icon_max_width", ICON_SIZE)
		button.tooltip_text = item.description if item.description != "" else "Wear it"
		button.pressed.connect(_on_disguise_pressed.bind(carried[i]))
		# Pointed at, the map shows who it would fool.
		button.mouse_entered.connect(_preview.bind(carried[i]))
		button.mouse_exited.connect(_preview.bind(""))
		_row.add_child(button)
		# Straight after the three labels, before the actions.
		_row.move_child(button, 3 + i)
		_buttons.append(button)


func _on_other_throw_pressed(item_key: String):
	if watch != null:
		watch.begin_throw(item_key)


## Colours the guards' view as if the leader wore `item_key` - "" for as he is.
func _preview(item_key: String):
	if watch != null:
		watch.preview_disguise = item_key


func _on_hide_pressed():
	if watch != null:
		watch.hide_again()


func _on_vault_pressed():
	if watch != null:
		watch.vault()


func _on_dash_pressed():
	if watch != null:
		watch.dash()


func _on_creep_pressed():
	if watch != null:
		watch.toggle_creep()


func _on_patience(held: bool):
	if watch != null:
		watch.patience_held = held


## Starts aiming; aiming already, on to the next thing to throw - or, with only
## the one, puts it away again.
func _on_throw_pressed():
	if watch == null:
		return
	if not watch.is_aiming():
		watch.begin_throw()
	elif watch.throwables().size() > 1:
		watch.next_throwable()
	else:
		watch.cancel_throw()


func _on_ears_pressed():
	if watch != null:
		watch.listen()


func _on_takedown_pressed():
	if watch != null:
		watch.take_down()


func _on_drag_pressed():
	if watch == null:
		return
	if watch.dragging() != null:
		watch.put_down()
	else:
		watch.drag()


func _on_pocket_pressed():
	if watch != null:
		watch.pick_pocket()


func _on_ambush_pressed():
	if watch != null:
		watch.ambush()


func _on_disguise_pressed(item_key: String):
	if watch != null:
		watch.wear(item_key)


func _unhandled_key_input(event):
	if watch == null or not event.pressed or event.is_echo():
		return
	if watch.scene != null and watch.scene.has_method("is_holding") and watch.scene.is_holding():
		return
	var acted := true
	match event.physical_keycode:
		KEY_H:
			watch.hide_again()
		KEY_SHIFT:
			watch.dash()
		KEY_T:
			_on_throw_pressed()
		KEY_Q:
			watch.listen()
		KEY_V:
			watch.vault()
		KEY_E, KEY_SPACE:
			# A word with a guard the disguise fools - unless there is something
			# else in reach for E, which the map sees to.
			acted = watch.talk_on_interact()
		KEY_F:
			watch.ambush()
		_:
			acted = false
	if acted:
		get_viewport().set_input_as_handled()
		return
	var index = event.physical_keycode - KEY_1
	var carried: Array = watch.disguises()
	if index >= 0 and index < mini(carried.size(), 9):
		watch.wear(carried[index])
		get_viewport().set_input_as_handled()
