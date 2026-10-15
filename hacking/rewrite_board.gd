extends VBoxContainer
class_name RewriteBoard
## Rewrite the Rule (HackDefinition.Kind.REWRITE): the spell's sheet, a line at
## a time - what it is set to, - and + to change it, and what it has to end up
## as. A line can be locked until another has moved from where it started, and
## on a Balanced sheet the watched lines' sum has to end where it started.
## Commit checks the lot: right, and it is rewritten; wrong, and the try is spent.
##
## Two ways of paying for it:
## - from the start (the gentle one): a line costs its Cost for each step it
##   ends away from where it started, and moving it back gives them back
## - every step (HackDefinition.every_step_costs, or any line that pushes
##   others): each step taken costs, back again included, and only Start Over
##   gives them back. With lines pushing each other (HackLine.pushes) and every
##   number held between its ends, the puzzle is the order to take them in.

signal solved
signal failed_try(reason: String)

var hack: HackDefinition = null
## Where each line is now.
var values: Array = []
## Edits spent so far this try, paying every step.
var spent := 0
## Edits there are to spend: the hack's, and more once simplified.
var budget := 0
## What simplifying adds to the edits.
const SIMPLER_EDITS := 4
## What a hint has shown, by line: its words.
var revealed := {}
## A gate spent on it: no locks, no balance.
var simplified := false
var colours := {}
## Set when a hint finds no way on from where the sheet is.
var hint_note := ""

var _rows: Array = []
var _status: Label = null
var _commit: Button = null
var _restart: Button = null


func setup(h: HackDefinition, _rng: RandomNumberGenerator, palette: Dictionary):
	hack = h
	colours = palette
	budget = h.edits
	values = starts()
	add_theme_constant_override("separation", 6)
	_build()
	_refresh()


## A fresh try: the sheet as it started. What hints have shown stays shown.
func reset_try(_rng: RandomNumberGenerator):
	start_over()


## The sheet back as it started, and every edit spent this try given back.
func start_over():
	values = starts()
	spent = 0
	# A next step shown for where the sheet stood is no help back at the start.
	if per_step():
		revealed.clear()
		_hinted_at = ""
	_refresh()


func starts() -> Array:
	return hack.lines.map(func(line): return line.value)


## Whether every step costs (see the top).
func per_step() -> bool:
	return hack.every_step_costs or hack.lines.any(func(line): return not line.pushes.is_empty())


## Edits spent getting the sheet to `at`: every step taken, or how far `at` is
## from the start.
func edits_used(at: Array = values) -> int:
	if per_step():
		return spent
	var used := 0
	for i in hack.lines.size():
		used += absi(at[i] - hack.lines[i].value) * hack.lines[i].cost
	return used


func watched_sum(at: Array) -> int:
	var total := 0
	for i in hack.lines.size():
		if hack.lines[i].watched and not hack.lines[i].is_choice():
			total += at[i]
	return total


func balance_ok(at: Array = values) -> bool:
	return simplified or not hack.balanced or watched_sum(at) == watched_sum(starts())


func all_met(at: Array = values) -> bool:
	for i in hack.lines.size():
		if not hack.lines[i].met_by(at[i]):
			return false
	return true


## The line called `label`, or -1.
func line_called(label: String) -> int:
	for i in hack.lines.size():
		if hack.lines[i].label == label:
			return i
	return -1


## Whether line `i` cannot be touched yet: the line it waits on is still as it
## started.
func is_locked(i: int, at: Array = values) -> bool:
	var key := hack.lines[i].locked_until
	if simplified or key == "":
		return false
	var other := line_called(key)
	return other >= 0 and at[other] == hack.lines[other].value


## `at` with line `i` stepped by `delta` and everything it pushes pushed - or
## [] when that is not a step that can be taken from `at`.
func stepped(at: Array, i: int, delta: int) -> Array:
	if is_locked(i, at):
		return []
	var line: HackLine = hack.lines[i]
	var next := at.duplicate()
	next[i] += delta
	if next[i] < line.lowest() or next[i] > line.highest():
		return []
	for label in line.pushes:
		var other := line_called(label)
		if other < 0:
			continue
		next[other] += line.pushes[label] * delta
		if next[other] < hack.lines[other].lowest() or next[other] > hack.lines[other].highest():
			return []
	return next


## Moves line `i` a step (`delta` -1 or +1). False, and nothing changed, when it
## is locked, would push something past its ends, or would cost more edits than
## there are.
func change(i: int, delta: int) -> bool:
	var next := stepped(values, i, delta)
	if next.is_empty():
		return false
	if per_step():
		if spent + hack.lines[i].cost > budget:
			return false
		spent += hack.lines[i].cost
	elif edits_used(next) > budget:
		return false
	values = next
	_refresh()
	return true


## Puts the sheet to it: rewritten if every line is what it has to be and the
## sum is kept; the try spent otherwise.
func commit():
	for i in hack.lines.size():
		if not hack.lines[i].met_by(values[i]):
			failed_try.emit("%s is not %s." % [hack.lines[i].label, hack.lines[i].goal_text()])
			return
	if not balance_ok():
		failed_try.emit("The sum moved from %d to %d - it noticed." % [watched_sum(starts()), watched_sum(values)])
		return
	solved.emit()


## Shows a little of the way: from the start, a line's answer; every step, the
## next step to take from where the sheet is. False when there is nothing more
## to show (hint_note says why).
## Whether a hint would show anything not on show already - asked before a
## gate is spent on one (Hacking.ask_hint), and every frame for the button.
## Step by step, the next step is shown once for where the sheet stands - or
## that there is none - and a step taken, there is a new one to show.
func hint_available() -> bool:
	if per_step():
		return _hinted_at != _where()
	# Worked out once for each way the sheet stands, not every frame.
	var asked := "%s:%d" % [_where(), revealed.size()]
	if asked == _available_at:
		return _available
	_available_at = asked
	_available = false
	var solution := solve()
	for i in hack.lines.size() if not solution.is_empty() else 0:
		if not revealed.has(i) and (values[i] != solution[i] or hack.lines[i].goal != 0):
			_available = true
	return _available


var _available_at := ""
var _available := false


## Whether there is no way through from where the sheet stands, with what is
## left to spend - asked before a hint is paid for, so being told to start over
## costs nothing.
func dead_end() -> bool:
	if per_step():
		return solve_moves(values, budget - spent).is_empty()
	return solve().is_empty()


## Where the sheet stands: its lines and what has been spent.
func _where() -> String:
	return "%s/%d" % [_key(values), spent]


## Where the sheet stood when the last step-by-step hint was shown.
var _hinted_at := ""


func hint() -> bool:
	hint_note = ""
	if per_step():
		var moves := solve_moves(values, budget - spent)
		_hinted_at = _where()
		if moves.is_empty():
			hint_note = "There is no way through from here - start over."
			return false
		var first: Array = moves[0]
		revealed.clear()
		revealed[first[0]] = "next: %s it" % ("raise" if first[1] > 0 else "lower")
		_hinted_at = _where()
		_refresh()
		return true
	var solution := solve()
	if solution.is_empty():
		return false
	for pass_ in 2:
		for i in hack.lines.size():
			if revealed.has(i):
				continue
			if values[i] != solution[i] or (pass_ == 1 and hack.lines[i].goal != 0):
				revealed[i] = "hint: %s" % hack.lines[i].shown(solution[i])
				_refresh()
				return true
	return false


## No locks, no balance, and a few more edits to spend.
func simplify():
	simplified = true
	budget += SIMPLER_EDITS
	_refresh()


## A sheet that does it, every line's value - or [] for none.
func solve() -> Array:
	if per_step():
		var moves := solve_moves(starts(), budget)
		if moves.is_empty() and not (all_met(starts()) and balance_ok(starts())):
			return []
		var at := starts()
		for move in moves:
			at = stepped(at, move[0], move[1])
		return at
	var found: Array = []
	var trial := starts()
	_search(0, 0, trial, found)
	return found


## The cheapest steps from `from` to a sheet that does it, within `allowed`
## edits: [[line, +1 or -1], ...] - or [] for none (or for none needed).
func solve_moves(from: Array, allowed: int) -> Array:
	if allowed < 0:
		return []
	var best := {_key(from): 0}
	var came := {_key(from): null}
	# Cheapest first, a bucket of sheets for each number of edits spent - the
	# costs are small whole numbers, so this is all the ordering it needs.
	var buckets: Array = []
	buckets.resize(allowed + 1)
	for cost in allowed + 1:
		buckets[cost] = []
	buckets[0].append(from)
	for cost in allowed + 1:
		var index := 0
		while index < buckets[cost].size():
			var at: Array = buckets[cost][index]
			index += 1
			var here := _key(at)
			if best.get(here, 1 << 30) < cost:
				continue
			if all_met(at) and balance_ok(at):
				var moves: Array = []
				while came[here] != null:
					var step: Array = came[here]
					moves.push_front([step[1], step[2]])
					here = step[0]
				return moves
			for i in hack.lines.size():
				for delta in [1, -1]:
					var next := stepped(at, i, delta)
					if next.is_empty():
						continue
					var paid: int = cost + hack.lines[i].cost
					if paid > allowed:
						continue
					var next_key := _key(next)
					if paid < best.get(next_key, 1 << 30):
						best[next_key] = paid
						came[next_key] = [here, i, delta]
						buckets[paid].append(next)
	return []


static func _key(at: Array) -> String:
	var parts := PackedStringArray()
	for value in at:
		parts.append(str(value))
	return ",".join(parts)


func _search(i: int, spent_so_far: int, trial: Array, found: Array):
	if not found.is_empty():
		return
	if i == hack.lines.size():
		if all_met(trial) and balance_ok(trial) and _order_possible(trial):
			found.append_array(trial)
		return
	var line: HackLine = hack.lines[i]
	var candidates := range(line.lowest(), line.highest() + 1)
	# Nearest the start first: the cheapest ways are tried before the dear ones.
	candidates.sort_custom(func(a, b): return absi(a - line.value) < absi(b - line.value))
	for value in candidates:
		var cost: int = absi(value - line.value) * line.cost
		if spent_so_far + cost > budget:
			continue
		trial[i] = value
		_search(i + 1, spent_so_far + cost, trial, found)
		if not found.is_empty():
			return
	trial[i] = line.value


func _order_possible(at: Array) -> bool:
	if simplified:
		return true
	for i in hack.lines.size():
		if at[i] != hack.lines[i].value and hack.lines[i].locked_until != "":
			var other := line_called(hack.lines[i].locked_until)
			if other >= 0 and at[other] == hack.lines[other].value:
				return false
	return true


func _build():
	for line in hack.lines:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		add_child(row)
		var name_label := _label(line.label, colours.text, 120)
		row.add_child(name_label)
		var minus := _button("-")
		row.add_child(minus)
		var value := _label("", colours.bright, 110)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(value)
		var plus := _button("+")
		row.add_child(plus)
		var note := _label("", colours.dim, 0)
		note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(note)
		var index := _rows.size()
		minus.pressed.connect(func(): change(index, -1))
		plus.pressed.connect(func(): change(index, 1))
		_rows.append({"value": value, "minus": minus, "plus": plus, "note": note})
	_status = _label("", colours.dim, 0)
	add_child(_status)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 10)
	add_child(buttons)
	if per_step():
		_restart = _button("Start over")
		_restart.pressed.connect(start_over)
		buttons.add_child(_restart)
	_commit = _button("Commit the change" if hack.look == HackDefinition.Look.RUNES else "Write it")
	_commit.pressed.connect(commit)
	buttons.add_child(_commit)


func _refresh():
	for i in _rows.size():
		var line: HackLine = hack.lines[i]
		var row: Dictionary = _rows[i]
		row.value.text = line.shown(values[i])
		row.value.add_theme_color_override("font_color", colours.good if line.met_by(values[i]) and line.goal != 0 else colours.bright)
		var locked := is_locked(i)
		row.minus.disabled = locked
		row.plus.disabled = locked
		var notes: Array[String] = []
		if line.goal != 0:
			notes.append("must be %s" % line.goal_text())
		if not line.pushes.is_empty():
			var dragged: Array[String] = []
			for label in line.pushes:
				dragged.append("%s %+d" % [label, line.pushes[label]])
			notes.append("each + moves %s" % ", ".join(dragged))
		if line.watched and hack.balanced and not simplified:
			notes.append("counted")
		if locked:
			notes.append("locked until %s moves" % line.locked_until)
		if revealed.has(i):
			notes.append(revealed[i])
		row.note.text = " - ".join(notes)
	var parts: Array[String] = ["Edits %s %d / %d" % ["spent" if per_step() else "", edits_used(), budget]]
	if hack.balanced and not simplified:
		parts.append("Sum %d, must stay %d" % [watched_sum(values), watched_sum(starts())])
	if per_step():
		parts.append("every step costs - Start Over gives them back")
	_status.text = "      ".join(parts)


func first_focus() -> Control:
	return _rows[0].plus if not _rows.is_empty() else _commit


func _label(text: String, colour: Color, width: float) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", colour)
	if width > 0:
		label.custom_minimum_size.x = width
	if colours.has("font"):
		label.add_theme_font_override("font", colours.font)
	return label


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(36, 30)
	return button
