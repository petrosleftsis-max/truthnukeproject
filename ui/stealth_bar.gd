extends PanelContainer
class_name StealthBar
## A stealth map's own strip of the HUD, along the top: how the one leading is
## doing - sneaking, hidden or in disguise - how on edge the map is, whether
## anybody has noticed anything yet, and everything he can do.
##
## Keys: 1-9 put a disguise on, H hides again, Shift dashes, T throws, Q
## listens and V vaults over a barrel. A left click on the map takes a guard down, or picks up, puts down
## or hides a body, and a right click picks pockets (see
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
var _status: Label = null
var _alert: Label = null
var _ghost: Label = null
var _throw: Button = null
var _ears: Button = null
var _dash: Button = null
var _vault: Button = null
var _takedown: Button = null
var _drag: Button = null
var _pocket: Button = null
var _hide: Button = null
var _buttons: Array[Button] = []
## What the disguise buttons were last built for, so they are only rebuilt
## when that changes rather than every frame.
var _built_for := ""


func _ready():
	name = "StealthBar"
	mouse_filter = Control.MOUSE_FILTER_STOP
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 10)
	add_child(_row)
	_status = _label()
	_alert = _label()
	_ghost = _label()
	_ghost.add_theme_color_override("font_color", GHOST)
	_throw = _button(_on_throw_pressed)
	_ears = _button(_on_ears_pressed)
	_dash = _button(_on_dash_pressed)
	_vault = _button(_on_vault_pressed)
	_vault.text = "Vault (V)"
	_vault.tooltip_text = "Hop over the barrel beside you to the other side."
	_takedown = _button(_on_takedown_pressed)
	_takedown.text = "Take down (Left click)"
	_drag = _button(_on_drag_pressed)
	_pocket = _button(_on_pocket_pressed)
	_pocket.text = "Pick pocket (Right click)"
	_hide = _button(_on_hide_pressed)
	_hide.text = "Hide (H)"
	refresh()


func _label() -> Label:
	var label := Label.new()
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_row.add_child(label)
	return label


func _button(pressed: Callable) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(pressed)
	_row.add_child(button)
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
	# How he is doing.
	if changing != "":
		_status.text = "Changing into %s %.1fs" % [ItemDatabase.item(changing).name, watch.change_left()]
	elif worn != "":
		var copied = CombatantDatabase.combatants.get(ItemDatabase.item(worn).disguise_as)
		_status.text = "Disguised as %s" % (copied.name if copied != null else "somebody else")
	elif watch.leader_hiding():
		_status.text = "Hidden"
	else:
		_status.text = "Sneaking"
	# How on edge the map is.
	var level: String = watch.alert_level()
	_alert.text = level
	_alert.add_theme_color_override("font_color", {"Calm": CALM, "Wary": WARY, "Alarmed": ALARMED}[level])
	_alert.tooltip_text = "How on edge the guards are. Wary and Alarmed guards walk quicker, look wider and grow sure quicker."
	_ghost.text = "Unseen"
	_ghost.visible = watch.never_noticed()
	_ghost.tooltip_text = "Nobody has so much as begun to notice you yet."
	# Throwing.
	var throwable: String = watch.throwable()
	_throw.visible = throwable != ""
	if throwable != "":
		var item: ItemDefinition = ItemDatabase.item(throwable)
		var count = Campaign.count_of(watch.leader_key(), throwable)
		_throw.text = ("Aiming - click" if watch.is_aiming() else "Throw %s x%d (T)" % [item.name, count])
		_throw.tooltip_text = "Throw it somewhere within %d tiles you can see; guards within %d tiles of where it lands go to look." % [
			StealthWatch.THROW_TILES, item.distraction_radius]
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
		_drag.tooltip_text = "Into the hiding spot beside you, where no guard will find them - and nobody can hide there any more." if stash != null \
			else "Leave them here. Stand beside a free hiding spot to hide them in it instead."
	else:
		_drag.visible = watch.drag_target() != null
		_drag.text = "Drag body (Left click)"
		_drag.tooltip_text = "Pick them up and drag them after you, at half your pace. Any guard who sees you at it knows you at once."
	_pocket.visible = watch.pocket_target() != null
	_pocket.tooltip_text = "Right click to lift what they carry, without them noticing."
	var refusal: String = watch.hide_refusal()
	_hide.visible = watch.worn_by(watch.leader_key()) != ""
	_hide.disabled = refusal != ""
	_hide.tooltip_text = refusal if refusal != "" else "Take the disguise off and slip back out of sight"


func _rebuild(carried: Array):
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
		_row.add_child(button)
		# Straight after the three labels, before the actions.
		_row.move_child(button, 3 + i)
		_buttons.append(button)


func _on_hide_pressed():
	if watch != null:
		watch.hide_again()


func _on_vault_pressed():
	if watch != null:
		watch.vault()


func _on_dash_pressed():
	if watch != null:
		watch.dash()


func _on_throw_pressed():
	if watch == null:
		return
	if watch.is_aiming():
		watch.cancel_throw()
	else:
		watch.begin_throw()


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
