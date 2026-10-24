extends Node
## Autoload. Runs a hack (HackDefinition) - one of Prometheus's three
## minigames - over whatever is on screen, and says how it went.
##
## Started by whatever is being hacked: an Interactable or a Hotspot with a
## Hack, a map object in a fight, the Hack skill on a foe winding something up,
## or a conversation:
##
##     do Hacking.start("archive_ward")
##     if Hacking.succeeded("archive_ward")
##
## Who hacks is whoever has a passive with Can Hack - in a fight the one using
## it, elsewhere the living party member with the most Intellect. Their
## Intellect sets the tries (tries_for) and what each retry costs
## (retry_cost_for): Tries at INTELLECT_PIVOT, in proportion either side, and
## the cost the other way, so twice the tries is half the cost a try.
##
## A hint or making it simpler spends one of the hacker's gates - in a fight
## from their gates now, elsewhere from the next fight's (Campaign
## .spend_gate_outside).
##
## What it leaves behind, for an id that is not "": hacked:<id> on success; on
## failure hack_locked:<id> (Locks For Good) and hack_set_off:<id> (Sets Off).
## In a fight nothing is written - the fight keeps its own.

signal finished(outcome: Dictionary)

## Over the dialogue balloon (30), so a conversation can start one; under the
## journal (40).
const LAYER := 35
## The Intellect a hack's Tries are written for.
const INTELLECT_PIVOT := 30.0
## How long the result stays up before the screen goes.
const RESULT_HOLD := 0.9

const PALETTES := {
	HackDefinition.Look.RUNES: {
		"back": Color("101728"), "edge": Color("c8a24a"), "title": Color("ffd98a"), "text": Color("e8dcb8"),
		"bright": Color("fff0c2"), "dim": Color("9a8e6e"), "good": Color("8fe0c8"), "danger": Color("ff6b6b"),
	},
	HackDefinition.Look.TERMINAL: {
		"back": Color("050c07"), "edge": Color("3fbf5f"), "title": Color("7dff9a"), "text": Color("b5f5c0"),
		"bright": Color("e6ffe9"), "dim": Color("4f8a5c"), "good": Color("7fffd4"), "danger": Color("ff5f5f"),
	},
}

var _hack: HackDefinition = null
var _id := ""
var _combat = null
## The one hacking: a combatant in a fight; a party key elsewhere.
var _hacker: Dictionary = {}
var _hacker_key := ""
var _tries_total := 0
var _tries_left := 0
var _retry_cost := 0.0
var _failed_once := false
var _time_left := 0.0
var _running := false
var _done := false
var _rng := RandomNumberGenerator.new()
var _scene_at_start: Node = null
var _paused_here := false
var _rooted_party = null

var _layer: CanvasLayer = null
var _board = null
var _message: Label = null
var _info: Label = null
var _clock: ProgressBar = null
var _hint_button: Button = null
var _simplify_button: Button = null
var _leave_button: Button = null


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS


## --- Starting one ---

## For a conversation: the hack in res://data/hacks/<key>.tres, its key its id.
## True when it went through.
func start(key: String) -> bool:
	var path := "res://data/hacks/%s.tres" % key
	if not ResourceLoader.exists(path):
		push_warning("Hacking.start: there is no hack '%s' in res://data/hacks/." % key)
		return false
	var outcome: Dictionary = await run(load(path), key)
	return outcome.result == "success"


func succeeded(id: String) -> bool:
	return Campaign.flag("hacked:" + id)


func locked(id: String) -> bool:
	return Campaign.flag("hack_locked:" + id)


func set_off_by(id: String) -> bool:
	return Campaign.flag("hack_set_off:" + id)


## Whether one is on screen now.
func running() -> bool:
	return _running


## Runs `hack`, and returns how it went: {"result": "success", "failed",
## "walked_away", "locked", "nobody" or "busy", "set_off": bool, "locked_out":
## bool}. `id` names it for the flags it leaves ("" for none). In a fight,
## `combat` and the combatant `hacker`.
func run(hack: HackDefinition, id: String = "", combat = null, hacker: Dictionary = {}) -> Dictionary:
	if _running or hack == null:
		return {"result": "busy"}
	if id != "" and locked(id):
		Campaign.announce("It is locked out for good.\n")
		return {"result": "locked"}
	_combat = combat
	_hacker = hacker
	_hacker_key = hacker.get("combatant_key", "") if combat != null else hacker_key()
	if combat == null and _hacker_key == "":
		Campaign.announce("Nobody here knows how to hack this.\n")
		return {"result": "nobody"}
	_hack = hack
	_id = id
	_running = true
	_done = false
	_failed_once = false
	_rng.randomize()
	var intellect := _intellect()
	_tries_total = tries_for(hack, intellect)
	_tries_left = _tries_total
	_retry_cost = retry_cost_for(hack, intellect)
	_scene_at_start = get_tree().current_scene
	_hold_world()
	_build_screen()
	_begin_try(true)
	var outcome: Dictionary = await finished
	_close_screen()
	_release_world()
	_running = false
	_settle(outcome)
	return outcome


## --- How good the hacker is ---

func tries_for(hack: HackDefinition, intellect: float) -> int:
	return maxi(1, roundi(hack.tries * intellect / INTELLECT_PIVOT))


## What each retry costs: the written cost, scaled down as the tries go up.
func retry_cost_for(hack: HackDefinition, intellect: float) -> float:
	return hack.retry_cost_amount * float(hack.tries) / float(tries_for(hack, intellect))


## Whether `passives` let somebody hack.
static func hacks(passives: Array) -> bool:
	return passives.any(func(passive): return passive != null and passive.can_hack)


## The living party member, outside a fight, who hacks: one who can, with the
## most Intellect. "" for nobody.
func hacker_key() -> String:
	var best := ""
	var most := -1.0
	for key in Campaign.living_party():
		var definition: CombatantDefinition = CombatantDatabase.combatants.get(key)
		if definition == null:
			continue
		var allowed := definition.passives.filter(func(p): return p != null and p.required_level <= Campaign.party_level)
		if not hacks(allowed):
			continue
		var intellect := intellect_of_member(key)
		if intellect > most:
			most = intellect
			best = key
	return best


## `key`'s Intellect outside a fight, at the party's level.
func intellect_of_member(key: String) -> float:
	var definition: CombatantDefinition = CombatantDatabase.combatants.get(key)
	if definition == null:
		return Stats.BASE_STAT
	var stats := Stats.stats_for_level(Campaign.party_level, definition.main_stat, definition.secondary_stat)
	return float(stats.get(Stats.stat_key(Stats.Type.INTELLECT), Stats.BASE_STAT))


func _intellect() -> float:
	if _combat != null:
		return float(_combat.stat_of(_hacker, Stats.Type.INTELLECT))
	return intellect_of_member(_hacker_key)


func hacker_name() -> String:
	if _combat != null:
		return _hacker.get("name", "")
	return Campaign.display_name_of(_hacker_key)


## --- Gates ---

## The gate a hint or simplifying at `level` would take - that one or the
## nearest deeper one left - or 0 for none.
func gate_for(level: int) -> int:
	if level <= 0:
		return 0
	if _combat != null:
		return _combat.slot_available_for(_hacker, level)
	var left: Array = Campaign.gates_left_outside(_hacker_key)
	for gate in range(level, left.size()):
		if left[gate] > 0:
			return gate
	return 0


func _spend_gate(level: int) -> bool:
	var gate := gate_for(level)
	if gate <= 0:
		return false
	if _combat != null:
		_hacker.spell_slots[gate] -= 1
		_combat.update_combatants.emit(_combat.combatants)
		return true
	return Campaign.spend_gate_outside(_hacker_key, gate)


## --- A try ---

func _begin_try(first: bool):
	if first:
		_board.setup(_hack, _rng, _palette())
	else:
		_board.reset_try(_rng)
	_time_left = float(_hack.time_limit)
	_refresh()
	_focus_board.call_deferred()


func _on_solved():
	if _done:
		return
	_message.text = "Access granted." if _hack.look == HackDefinition.Look.TERMINAL else "It answers to him now."
	_message.add_theme_color_override("font_color", _palette().good)
	_finish({"result": "success"})


func _on_failed_try(reason: String):
	if _done:
		return
	_failed_once = true
	_tries_left -= 1
	if _tries_left <= 0:
		_message.text = reason + "  " + (_hack.failure_line if _hack.failure_line != "" else "Out of tries.")
		_message.add_theme_color_override("font_color", _palette().danger)
		_finish({"result": "failed"})
		return
	_pay_retry()
	_message.text = "%s  Again - %s." % [reason, _retry_cost_text()]
	_message.add_theme_color_override("font_color", _palette().danger)
	_begin_try(false)


func _pay_retry():
	var amount := roundi(_retry_cost)
	match _hack.retry_cost:
		HackDefinition.RetryCost.STRAIN:
			if _combat != null:
				var taken := mini(amount, _hacker.hp - 1)
				if taken > 0:
					_combat.lose_hp(_hacker, taken)
					_combat.show_damage(_hacker, taken, Damage.Type.PSYCHIC)
					_combat.update_combatants.emit(_combat.combatants)
			else:
				Campaign.strain(_hacker_key, amount)
		HackDefinition.RetryCost.ALERT:
			var watch = Campaign.stealth_watch
			if watch != null and is_instance_valid(watch):
				watch.raise_alert(_retry_cost / 100.0)


func _retry_cost_text() -> String:
	var amount := roundi(_retry_cost)
	match _hack.retry_cost:
		HackDefinition.RetryCost.STRAIN:
			return "%d health of %s's" % [amount, hacker_name()]
		HackDefinition.RetryCost.ALERT:
			return "the guards %d%% more on edge" % amount
	return "nothing"


## The hint button: a gate for the board to show the way a little.
func ask_hint() -> bool:
	if _done:
		return false
	# Nothing new to show: nothing paid for it.
	if _board.has_method("hint_available") and not _board.hint_available():
		var note = _board.get("hint_note")
		_message.text = note if note is String and note != "" else "Nothing new to show - make a move first."
		_message.add_theme_color_override("font_color", _palette().dim)
		_refresh()
		return false
	# No way through from here this try: said for nothing, and the hint left
	# for after a fresh start.
	if _board.has_method("dead_end") and _board.dead_end():
		_board.hint()
		var said = _board.get("hint_note")
		_message.text = said if said is String and said != "" else "There is no way through from here any more - this try is lost."
		_message.add_theme_color_override("font_color", _palette().danger)
		_refresh()
		return false
	if not _spend_gate(_hack.hint_gate):
		return false
	var shown: bool = _board.hint()
	var note = _board.get("hint_note")
	_message.text = "A gate opens a crack - look." if shown else (note if note is String and note != "" else "There is nothing more to show.")
	_message.add_theme_color_override("font_color", _palette().good)
	_refresh()
	return shown


## The simplify button: a gate to make the board easier, once a hack.
func ask_simplify() -> bool:
	if _done or _board.get("simplified") == true or _simplify_spent or not _spend_gate(_hack.simplify_gate):
		return false
	_simplify_spent = true
	_board.simplify()
	_message.text = "A gate opens - it is simpler now."
	_message.add_theme_color_override("font_color", _palette().good)
	_refresh()
	return true

var _simplify_spent := false


## Walking away: nothing lost before a try has failed; after, it counts as
## failing.
func walk_away():
	if _done:
		return
	if _failed_once:
		_message.text = "He walks away from it - it knows he was there."
		_finish({"result": "failed"})
	else:
		_finish({"result": "walked_away"})


func _finish(outcome: Dictionary):
	_done = true
	_refresh()
	if outcome.result == "failed":
		outcome["set_off"] = _hack.sets_off
		outcome["locked_out"] = _hack.locks_for_good
	await get_tree().create_timer(RESULT_HOLD, true, false, true).timeout
	finished.emit(outcome)


## What an outcome leaves behind, and what it says.
func _settle(outcome: Dictionary):
	match outcome.result:
		"success":
			if _id != "":
				Campaign.set_flag("hacked:" + _id)
			Campaign.announce("[color=lightgreen]%s hacks %s.[/color]\n" % [hacker_name(), _hack.title if _hack.title != "" else "it"])
		"failed":
			if _hack.failure_line != "":
				Campaign.announce("[color=red]%s[/color]\n" % _hack.failure_line)
			if _hack.raises_alert:
				var watch = Campaign.stealth_watch
				if watch != null and is_instance_valid(watch):
					watch.raise_alert_level()
			if _id != "":
				if _hack.locks_for_good:
					Campaign.set_flag("hack_locked:" + _id)
				if _hack.sets_off:
					Campaign.set_flag("hack_set_off:" + _id)


## Escape, the pad's back button or a right click: walking away - and nothing
## underneath (a picture, the pause menu) hears it.
func _input(event: InputEvent):
	if not _running or _done:
		return
	var cancel: bool = event.is_action_pressed("ui_cancel") \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT)
	if cancel:
		get_viewport().set_input_as_handled()
		walk_away()


func _process(delta: float):
	if not _running or _done:
		return
	# A move on the board may have made a new hint worth buying.
	if _hint_button != null and is_instance_valid(_hint_button) and _board != null and _board.has_method("hint_available"):
		var fresh: bool = _board.hint_available()
		var can_pay := gate_for(_hack.hint_gate) > 0
		_hint_button.disabled = not fresh or not can_pay
		_hint_button.tooltip_text = "" if fresh else "Nothing new to show - make a move first."
	# Caught, or carried off somewhere else, while he worked: it is over.
	if get_tree().current_scene != _scene_at_start:
		_done = true
		finished.emit({"result": "walked_away"})
		return
	if _hack.time_limit > 0:
		_time_left -= delta
		if _clock != null:
			_clock.value = maxf(_time_left, 0.0)
		if _time_left <= 0.0:
			_on_failed_try("Out of time.")


## --- Holding the world ---

func _hold_world():
	_paused_here = false
	_rooted_party = null
	if _combat == null and _hack.world_keeps_moving and Campaign.stealth_watch != null and is_instance_valid(Campaign.stealth_watch):
		# The guards carry on: only the party stands still while he works.
		var scene = get_tree().current_scene
		if scene != null and scene.get("party") != null:
			_rooted_party = scene.party
			_rooted_party.rooted = true
		return
	if not get_tree().paused:
		get_tree().paused = true
		_paused_here = true


func _release_world():
	if _rooted_party != null and is_instance_valid(_rooted_party):
		_rooted_party.rooted = false
	_rooted_party = null
	if _paused_here:
		get_tree().paused = false
	_paused_here = false


## --- The screen ---

func _palette() -> Dictionary:
	var palette: Dictionary = PALETTES[_hack.look].duplicate()
	if _hack.look == HackDefinition.Look.TERMINAL:
		var mono := SystemFont.new()
		mono.font_names = PackedStringArray(["Consolas", "Courier New", "monospace"])
		palette["font"] = mono
	return palette


## The minigame on screen now - for the tests to play.
func board():
	return _board


func tries_left() -> int:
	return _tries_left


func tries_total() -> int:
	return _tries_total


func retry_cost() -> float:
	return _retry_cost


func _build_screen():
	var palette := _palette()
	_simplify_spent = false
	_layer = CanvasLayer.new()
	_layer.layer = LAYER
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_to_group(&"hack_screen")
	_layer.add_child(root)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.6)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(centre)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = palette.back
	style.border_color = palette.edge
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size.x = 720
	centre.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var title := Label.new()
	title.text = _hack.title if _hack.title != "" else _hack.kind_name()
	title.theme_type_variation = GameFonts.HEADER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", palette.title)
	column.add_child(title)
	var about := Label.new()
	about.text = _hack.kind_name() + ((" - " + _hack.description) if _hack.description != "" else "")
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	about.custom_minimum_size.x = 680
	about.add_theme_color_override("font_color", palette.text)
	column.add_child(about)
	_info = Label.new()
	_info.add_theme_color_override("font_color", palette.dim)
	column.add_child(_info)
	# The hacker's gates, each in its colour - what a hint or making it simpler
	# would come out of.
	_gates_row = HBoxContainer.new()
	_gates_row.add_theme_constant_override("separation", 16)
	column.add_child(_gates_row)
	if _hack.time_limit > 0:
		_clock = ProgressBar.new()
		_clock.max_value = _hack.time_limit
		_clock.show_percentage = false
		_clock.custom_minimum_size = Vector2(680, 8)
		column.add_child(_clock)
	else:
		_clock = null
	_message = Label.new()
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size.x = 680
	column.add_child(_message)
	match _hack.kind:
		HackDefinition.Kind.REWRITE:
			_board = RewriteBoard.new()
		HackDefinition.Kind.INFILTRATE:
			_board = InfiltrateBoard.new()
		_:
			_board = ResonanceBoard.new()
	_board.solved.connect(_on_solved)
	_board.failed_try.connect(_on_failed_try)
	column.add_child(_board)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(buttons)
	_hint_button = Button.new()
	_hint_button.pressed.connect(ask_hint)
	buttons.add_child(_hint_button)
	_simplify_button = Button.new()
	_simplify_button.pressed.connect(ask_simplify)
	buttons.add_child(_simplify_button)
	_leave_button = Button.new()
	_leave_button.text = "Walk away"
	_leave_button.pressed.connect(walk_away)
	buttons.add_child(_leave_button)


func _refresh():
	if _info == null:
		return
	var pips := "●".repeat(_tries_left) + "○".repeat(maxi(_tries_total - _tries_left, 0))
	var line := "%s   Intellect %d   Tries %s" % [hacker_name(), roundi(_intellect()), pips]
	if _tries_left > 1 and _hack.retry_cost != HackDefinition.RetryCost.NOTHING:
		line += "   A retry costs %s" % _retry_cost_text()
	if _hack.time_limit > 0:
		line += "   %d seconds a try" % _hack.time_limit
	_info.text = line
	_refresh_gates()
	_hint_button.visible = _hack.hint_gate > 0
	_hint_button.text = "Hint - %s" % Stats.short_gate_name(_hack.hint_gate)
	# Nothing new to show (the step shown already not taken yet), nothing paid.
	var fresh: bool = not _board.has_method("hint_available") or _board.hint_available()
	_hint_button.disabled = _done or gate_for(_hack.hint_gate) <= 0 or not fresh
	_hint_button.tooltip_text = "" if fresh else "Nothing new to show - make a move first."
	_simplify_button.visible = _hack.simplify_gate > 0
	_simplify_button.text = "Simplify - %s" % Stats.short_gate_name(_hack.simplify_gate)
	_simplify_button.disabled = _done or _simplify_spent or gate_for(_hack.simplify_gate) <= 0
	_leave_button.disabled = _done
	_leave_button.tooltip_text = "Counts as failing, now a try has failed." if _failed_once else "Nothing lost yet."


func _focus_board():
	if _board != null and is_instance_valid(_board) and _board.has_method("first_focus"):
		var first = _board.first_focus()
		if first != null and is_instance_valid(first):
			first.grab_focus()


func _close_screen():
	if _layer != null:
		_layer.queue_free()
	_layer = null
	_board = null
	_info = null
	_message = null
	_clock = null
	_gates_row = null


## --- The hacker's gates ---

var _gates_row: HBoxContainer = null


## What the hacker has left through each gate, index 0 unused: in a fight their
## gates now, elsewhere what the next fight will start with.
func gates_left() -> Array:
	if _combat != null:
		return _hacker.get("spell_slots", []).duplicate()
	return Campaign.gates_left_outside(_hacker_key)


## The most the hacker has through each gate.
func gates_most() -> Array:
	if _combat != null:
		return _hacker.get("max_spell_slots", []).duplicate()
	return Campaign.gates_most(_hacker_key)


func _refresh_gates():
	if _gates_row == null or not is_instance_valid(_gates_row):
		return
	for child in _gates_row.get_children():
		child.queue_free()
	var left := gates_left()
	var title := Label.new()
	title.text = "Gates"
	title.add_theme_color_override("font_color", _palette().dim)
	_gates_row.add_child(title)
	var most := gates_most()
	for gate in range(1, left.size()):
		# Only the gates they have at all: not ten of them, most at nothing.
		if left[gate] <= 0 and gate < most.size() and most[gate] <= 0:
			continue
		var shown := Label.new()
		shown.text = "%s %d" % [Stats.short_gate_name(gate), left[gate]]
		shown.add_theme_color_override("font_color", Stats.gate_colour(gate) if left[gate] > 0 else _palette().dim)
		_gates_row.add_child(shown)
