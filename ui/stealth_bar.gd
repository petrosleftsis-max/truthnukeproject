extends PanelContainer
class_name StealthBar
## A stealth map's own strip of the HUD, along the top: how the one leading is
## doing - sneaking, hidden or in disguise - how on edge the map is, whether
## anybody has noticed anything yet, and everything he can do.
##
## Keys: 1-9 put a disguise on, H hides again, G chooses who Invisibility hides, Shift dashes, Ctrl creeps, P
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
## The party going invisible (through Iris), and how long it has left.
var _invisible: Button = null
## The choice of who to hide, while it is open.
var _picker = null
## Calling the familiar, or letting it go (Find Familiar - StealthWatch "Familiar").
var _familiar: Button = null
## The choice of which spell, while it is open.
var _choice = null

const InvisibilityPicker := preload("res://ui/invisibility_picker.gd")
const OutsideSpellChoice := preload("res://ui/outside_spell_choice.gd")
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
	# Held, not clicked: time runs fast for as long as it is down.
	_patience = Button.new()
	_patience.focus_mode = Control.FOCUS_NONE
	_patience.toggle_mode = true
	_patience.button_down.connect(_on_patience.bind(true))
	_patience.button_up.connect(_on_patience.bind(false))
	_row.add_child(_patience)
	_invisible = _button(_on_invisible_pressed)
	_familiar = _button(_on_familiar_pressed)
	_vault = _button(_on_vault_pressed, _here)
	_vault.tooltip_text = "Hop over the barrel beside you to the other side."
	_takedown = _button(_on_takedown_pressed, _here)
	_drag = _button(_on_drag_pressed, _here)
	_pocket = _button(_on_pocket_pressed, _here)
	_ambush = _button(_on_ambush_pressed, _here)
	_ambush.tooltip_text = "Start the fight here, on your terms: every guard who hadn't noticed you loses their first turn."
	_hide = _button(_on_hide_pressed, _here)
	refresh()


## The buttons that never change but for what to press: the keys, or a pad's.
func _name_keys():
	_creep.text = Pad.hint("Creep", &"creep")
	_creep.tooltip_text = "Walk slowly, without a sound - across gravel, puddles and broken glass too. %s, or click to keep creeping." % (
		"Push the stick only a little way" if Pad.using_pad else "Hold %s" % Pad.key(&"creep"))
	_patience.text = Pad.hint("Patience", &"patience")
	_patience.tooltip_text = "Hold it (or %s) and time runs twice as fast - for waiting out a patrol. Let go and it is back to normal." % Pad.key(&"patience")
	_vault.text = Pad.hint("Vault", &"vault")
	_takedown.text = Pad.hint("Take down", &"take_down", "Left click")
	_pocket.text = Pad.hint("Pick pocket", &"pick_pocket", "Right click")
	_ambush.text = Pad.hint("Ambush", &"ambush")
	_hide.text = Pad.hint("Hide", &"take_off_disguise")


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
	elif watch.unseen():
		_status.text = "Invisible %s" % clock(watch.unseen_left())
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
	_name_keys()
	# Lit while time is running fast, whichever way it is held.
	_patience.set_pressed_no_signal(watch.hurried())
	# How on edge the map is.
	var level: String = watch.alert_level()
	_alert.text = level
	_alert.add_theme_color_override("font_color", {"Calm": CALM, "Wary": WARY, "Alarmed": ALARMED}[level])
	_alert.tooltip_text = "How on edge the guards are. Wary and Alarmed guards walk quicker, look wider and grow sure quicker. It never settles by itself - a word with a guard your disguise fools (%s beside one) settles it a level." % Pad.key(&"interact")
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
			if Pad.using_pad:
				_throw.text = "Aiming %s - %s or %s%s" % [item.name, Pad.key(&"throw"), Pad.key(&"pointer_click"), " (D-pad: next)" if more else ""]
			else:
				_throw.text = "Aiming %s - click%s" % [item.name, " (%s: next)" % Pad.key(&"throw") if more else ""]
		else:
			_throw.text = "Throw %s x%d (%s)" % [item.name, count, Pad.key(&"throw")]
		if item.is_poison():
			_throw.tooltip_text = "Throw it at a guard within %d tiles you can see. %s" % [StealthWatch.THROW_TILES, item.description]
		else:
			_throw.tooltip_text = "Throw it somewhere within %d tiles you can see; guards within %d tiles of where it lands go to look." % [
				StealthWatch.THROW_TILES, item.distraction_radius]
		if more:
			if Pad.using_pad:
				_throw.tooltip_text += " While aiming, the D-pad's left and right pick the thing to throw."
			else:
				_throw.tooltip_text += " While aiming, %s again picks the next thing to throw." % Pad.key(&"throw")
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
	# Going invisible, for whoever knows how - and the familiar.
	_refresh_invisible()
	_refresh_familiar()
	# Listening.
	_ears.visible = watch.hides_guards()
	if watch.ears_left() > 0.0:
		_ears.text = "Listening %.1fs" % watch.ears_left()
		_ears.disabled = true
	elif watch.ears_cooldown() > 0.0:
		_ears.text = "Ears %.1fs" % watch.ears_cooldown()
		_ears.disabled = true
	else:
		_ears.text = Pad.hint("Ears", &"listen")
		_ears.disabled = false
	_ears.tooltip_text = "Hear every guard through the walls for %d seconds." % StealthWatch.EARS_SECONDS
	# The dash, and how long until it is ready again.
	var cooling: float = watch.dash_cooldown()
	var no_dash: String = watch.dash_refusal()
	_dash.disabled = cooling > 0.0 or no_dash != ""
	_dash.text = "Dash %.1fs" % cooling if cooling > 0.0 else Pad.hint("Dash", &"dash")
	_dash.tooltip_text = no_dash if no_dash != "" else "A burst of %d tiles, then %d seconds to recover. Anyone who sees it grows sure %d times as fast, and guards within %d tiles hear it." % [
		StealthWatch.DASH_TILES, StealthWatch.DASH_COOLDOWN, StealthWatch.DASH_NOTICE, StealthWatch.DASH_NOISE_TILES]
	# Beside something to hop over.
	_vault.visible = not watch.vault_over().is_empty()
	# Behind somebody who has no idea, or beside somebody out cold.
	var dragging = watch.dragging()
	var down = watch.takedown_target() if dragging == null else null
	_takedown.visible = down != null
	if down != null:
		_takedown.tooltip_text = "%s to knock them out. It is heard: guards within %d tiles come to look, and one who sees them lying there raises the alarm." % [
			Pad.key(&"take_down", "Left click"), StealthWatch.TAKEDOWN_NOISE_TILES]
	if dragging != null:
		var stash = watch.stash_spot()
		_drag.visible = true
		_drag.text = Pad.hint("Hide body" if stash != null else "Drop body", &"take_down", "Left click")
		_drag.tooltip_text = "Into the hiding spot beside you - out of sight, but a guard who comes within a couple of tiles of it will notice. Nobody can hide there any more." if stash != null \
			else "Leave them here. Stand beside a free hiding spot to hide them in it instead."
	else:
		_drag.visible = watch.drag_target() != null
		_drag.text = Pad.hint("Drag body", &"take_down", "Left click")
		_drag.tooltip_text = "Pick them up and drag them after you, at half your pace. Any guard who sees you at it knows you at once."
	_pocket.visible = watch.pocket_target() != null
	_pocket.tooltip_text = "%s to lift what they carry, without them noticing." % Pad.key(&"pick_pocket", "Right click")
	_ambush.visible = watch.ambush_target() != null and watch.ambush_refusal() == ""
	var refusal: String = watch.hide_refusal()
	_hide.visible = watch.worn_by(watch.leader_key()) != ""
	_hide.disabled = refusal != ""
	_hide.tooltip_text = refusal if refusal != "" else "Take the disguise off and slip back out of sight"
	# The second row only while there is something on it.
	_here.visible = _here.get_children().any(func(button): return button.visible)
	# Seeing through the familiar's eyes: nothing the party does is theirs to do.
	if watch.controlling_familiar():
		_status.text = "Through the %s's eyes" % watch.familiar.form.name.to_lower()
		_here.visible = false
		for button in [_throw, _dash, _creep, _ears, _invisible] + _buttons + _other_throws:
			button.disabled = true
	else:
		# What nothing else sets each frame, put back.
		for button in [_throw, _creep] + _other_throws:
			button.disabled = false


## The Invisibility button: there while somebody on the map knows the spell,
## counting down while it lasts, and saying what it costs and what is left.
func _refresh_invisible():
	var spell: Dictionary = watch.invisibility_spell()
	_invisible.visible = not spell.is_empty()
	if spell.is_empty():
		return
	var skill: SkillDefinition = SkillDatabase.skills[spell.skill]
	var gate := Stats.short_outside_gate_name(skill.outside_gate)
	var left: int = Campaign.outside_gates_left(spell.caster)[skill.outside_gate]
	_invisible.text = Pad.hint("%s (%s %d)" % [skill.name, gate, left], &"outside_spell")
	var nobody_left: bool = watch.could_go_invisible().is_empty()
	_invisible.disabled = nobody_left or left <= 0
	_invisible.add_theme_color_override("font_color", Stats.outside_gate_colour(skill.outside_gate))
	var tip := "%s hides whoever you choose for %s, through the %s - a casting for each (%d left). Hounds still smell them, and whoever does something to a guard is seen again." % [
		Campaign.display_name_of(spell.caster), clock(skill.outside_seconds), Stats.outside_gate_name(skill.outside_gate), left]
	if nobody_left:
		tip = "Everybody is invisible already"
	elif left <= 0:
		tip = "%s has no castings of %s left" % [Campaign.display_name_of(spell.caster), gate]
	var hidden := []
	for key in Campaign.living_party():
		if watch.unseen(key):
			hidden.append("%s %s" % [Campaign.display_name_of(key), clock(watch.unseen_left(key))])
	if not hidden.is_empty():
		tip += "\nInvisible: " + ", ".join(hidden)
	_invisible.tooltip_text = tip


## Minutes and seconds - "9:58".
static func clock(seconds: float) -> String:
	var whole := ceili(seconds)
	return "%d:%02d" % [whole / 60, whole % 60]


## The familiar's button: calling it, with what that costs and what is left, or
## letting it go while it is out.
func _refresh_familiar():
	var spell: Dictionary = watch.familiar_spell()
	_familiar.visible = not spell.is_empty() or watch.familiar != null
	if not _familiar.visible:
		return
	if watch.familiar != null:
		var what: String = watch.familiar.form.name.to_lower()
		_familiar.text = Pad.hint("Let the %s go" % what, &"outside_spell")
		_familiar.disabled = false
		_familiar.tooltip_text = "%s switches between the %s and the party." % [Pad.key(&"swap_leader"), what]
		return
	var skill: SkillDefinition = SkillDatabase.skills[spell.skill]
	var gate := skill.spell_slot_level
	var left: int = Campaign.gates_left_outside(spell.caster)[gate]
	_familiar.text = Pad.hint("%s (%s %d)" % [skill.name, Stats.short_gate_name(gate), left], &"outside_spell")
	_familiar.add_theme_color_override("font_color", Stats.gate_colour(gate))
	var refusal: String = watch.familiar_refusal()
	_familiar.disabled = refusal != ""
	var form: FamiliarForm = watch.familiar_form()
	_familiar.tooltip_text = refusal if refusal != "" else "%s calls a %s and sees through its eyes while the party waits - a casting of %s, off the next fight's (%d left). It slips through gaps nobody else fits through, and guards make it out only within %s tiles; but a magic sensor feels it. %s switches between it and the party." % [
		Campaign.display_name_of(spell.caster), form.name.to_lower(), Stats.short_gate_name(gate), left,
		CharacterSheet._figure(form.noticed_within), Pad.key(&"swap_leader")]


func _on_familiar_pressed():
	if watch.familiar != null:
		watch.dismiss_familiar()
	else:
		watch.summon_familiar()


## The Outside Spell key: lets the familiar go while it is out; otherwise casts
## the one spell the party knows, or asks which when it knows both.
func outside_spell():
	if watch == null or is_instance_valid(_picker) or is_instance_valid(_choice):
		return
	if watch.familiar != null:
		watch.dismiss_familiar()
		return
	var hides: bool = not watch.invisibility_spell().is_empty()
	var calls: bool = not watch.familiar_spell().is_empty()
	if hides and calls:
		if watch.spotted_by != null or (watch.scene != null and watch.scene.has_method("is_holding") and watch.scene.is_holding()):
			return
		_choice = OutsideSpellChoice.new()
		_choice.watch = watch
		_choice.bar = self
		get_parent().add_child(_choice)
	elif calls:
		watch.summon_familiar()
	else:
		open_picker()


## Opens the choice of who to hide - or, with only one to choose, hides them.
func open_picker():
	if watch == null or is_instance_valid(_picker):
		return
	if watch.spotted_by != null or watch.invisibility_spell().is_empty():
		return
	if watch.scene != null and watch.scene.has_method("is_holding") and watch.scene.is_holding():
		return
	var could: Array = watch.could_go_invisible()
	if could.size() <= 1:
		watch.go_invisible(could)
		return
	_picker = InvisibilityPicker.new()
	_picker.watch = watch
	get_parent().add_child(_picker)


func _on_invisible_pressed():
	open_picker()


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


## The keys, through _unhandled_key_input as they always were, so they come in
## the same order against the map's own E as before.
func _unhandled_key_input(event):
	_act(event)


## A pad's buttons, which _unhandled_key_input never hears.
func _unhandled_input(event):
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_act(event)


func _act(event: InputEvent):
	if watch == null or not event.is_pressed() or event.is_echo():
		return
	if watch.scene != null and watch.scene.has_method("is_holding") and watch.scene.is_holding():
		return
	var from_pad := not event is InputEventKey
	# Seeing through the familiar's eyes: only letting it go is theirs to do here
	# (switching back is the map's Swap Leader).
	if watch.controlling_familiar():
		if Pad.went_down(event, &"outside_spell"):
			watch.dismiss_familiar()
			get_viewport().set_input_as_handled()
		return
	var acted := true
	if watch.is_aiming() and from_pad and Pad.went_down(event, &"throw"):
		# A pad lets go where its pointer is: RT is the mouse's click.
		watch.throw_at_pointer()
	elif Pad.went_down(event, &"throw"):
		_on_throw_pressed()
	elif watch.is_aiming() and from_pad and Pad.went_down(event, &"take_off_disguise"):
		# Aiming, the D-pad's sides go through what there is to throw.
		watch.next_throwable(-1)
	elif watch.is_aiming() and from_pad and Pad.went_down(event, &"next_disguise"):
		watch.next_throwable(1)
	elif Pad.went_down(event, &"take_off_disguise"):
		watch.hide_again()
	elif Pad.went_down(event, &"next_disguise"):
		_wear_next()
	elif Pad.went_down(event, &"dash"):
		watch.dash()
	elif Pad.went_down(event, &"listen"):
		watch.listen()
	elif Pad.went_down(event, &"vault"):
		watch.vault()
	elif Pad.went_down(event, &"outside_spell"):
		outside_spell()
	elif Pad.went_down(event, &"ambush"):
		watch.ambush()
	elif Pad.went_down(event, &"take_down"):
		_on_takedown_or_drag()
	elif Pad.went_down(event, &"pick_pocket"):
		watch.pick_pocket()
	elif Pad.went_down(event, &"interact"):
		# A word with a guard the disguise fools - unless there is something
		# else in reach for E, which the map sees to.
		acted = watch.talk_on_interact()
	else:
		acted = false
	if acted:
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventKey:
		return
	var index = event.physical_keycode - KEY_1
	var carried: Array = watch.disguises()
	if index >= 0 and index < mini(carried.size(), 9):
		watch.wear(carried[index])
		get_viewport().set_input_as_handled()


## A pad's X: what a left click on the guard beside him does - knock him out,
## or take up the body there, or put down the one being dragged. With no click
## to say which guard, whoever it can be done to.
func _on_takedown_or_drag():
	if watch.dragging() != null:
		watch.put_down()
	elif not watch.take_down():
		watch.drag()


## A pad's D-pad right: into the next disguise he carries, round and round.
func _wear_next():
	var carried: Array = watch.disguises()
	if carried.is_empty():
		return
	var worn: String = watch.worn_by(watch.leader_key())
	watch.wear(carried[(carried.find(worn) + 1) % carried.size()])
