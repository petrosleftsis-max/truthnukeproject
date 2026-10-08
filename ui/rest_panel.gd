extends PanelContainer
class_name RestPanel
## The rest between a dungeon's fights (see DungeonDefinition): everyone back to
## full health, and what nobody used still in their bags - then on to the next
## stage.
##
## And, while the dungeon still has one to give, the offer to bring back gates
## spent - Prometheus's, in the demo - with a few points to spend: each casting
## costs its gate's price (World 1, Hermes 2, Yaldabaoth 3), and nothing can be
## brought back that was not spent. Only so many rests in a run may do it, and
## the offer says so, so the player knows it is now or a later rest - not both.
##
## Built in code, by ResultUI, once the battle and whatever is said after it are
## over. Campaign does the resting and the recovering; this only asks.

## Continue was pressed: on to the next stage.
signal continued

const INK := Color("dce8f5")
const MUTED := Color("8296a9")
const GOLD := Color(1.0, 0.84, 0.35)

## Per gate, of whoever is being offered: how many castings to bring back.
var chosen: Array = []
## Whose gates are offered, or "".
var offered_to := ""

var _gate_box: VBoxContainer = null
var _rows: Array = []
var _points: Label = null
var _recover: Button = null
var _continue: Button = null


func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size = Vector2(520, 0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	add_child(column)
	var title := Label.new()
	title.theme_type_variation = &"HeaderLabel"
	title.add_theme_font_size_override("font_size", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = "Rest"
	column.add_child(title)
	var rested := Label.new()
	rested.name = "Rested"
	rested.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rested.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rested.text = "Everyone is back to full health. Whatever was not used, they still carry."
	column.add_child(rested)
	var party := Label.new()
	party.name = "Party"
	party.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	party.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	party.add_theme_color_override("font_color", MUTED)
	var described := Campaign.describe_party()
	party.text = "Party: " + described if described != "" else ""
	column.add_child(party)
	_gate_box = VBoxContainer.new()
	_gate_box.name = "Gates"
	_gate_box.add_theme_constant_override("separation", 8)
	column.add_child(_gate_box)
	_continue = Button.new()
	_continue.name = "Continue"
	_continue.text = "Continue"
	_continue.pressed.connect(func(): continued.emit())
	column.add_child(_continue)
	_offer_gates()
	FocusOnDemand.attach(self, _first_button())


## Whose gates there are to offer, if anybody's.
func _offer_gates():
	offered_to = ""
	for key in Campaign.dungeon.gate_recovery_for if Campaign.dungeon != null else []:
		if Campaign.can_recover_gates(key):
			offered_to = key
			break
	for child in _gate_box.get_children():
		child.queue_free()
	_rows.clear()
	if offered_to == "":
		return
	var dungeon: DungeonDefinition = Campaign.dungeon
	var who := Campaign.display_name_of(offered_to)
	var question := Label.new()
	question.name = "Question"
	question.text = "Recover %s's gates?" % who
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question.add_theme_color_override("font_color", GOLD)
	question.add_theme_font_size_override("font_size", 20)
	_gate_box.add_child(question)
	var terms := Label.new()
	terms.name = "Terms"
	terms.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	terms.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	terms.text = "%d points to spend: %s. %s" % [dungeon.gate_recovery_points, _prices(), _how_often()]
	_gate_box.add_child(terms)
	var left := Campaign.gates_left(offered_to)
	var most := Campaign.gates_most(offered_to)
	chosen = []
	chosen.resize(most.size())
	chosen.fill(0)
	for gate in range(1, most.size()):
		if dungeon.gate_cost(gate) <= 0 or most[gate] <= 0:
			continue
		var row := HBoxContainer.new()
		row.name = "Gate%d" % gate
		row.add_theme_constant_override("separation", 10)
		var label := Label.new()
		label.custom_minimum_size = Vector2(230, 0)
		label.add_theme_color_override("font_color", Stats.gate_colour(gate))
		row.add_child(label)
		var price := Label.new()
		price.custom_minimum_size = Vector2(110, 0)
		price.add_theme_color_override("font_color", MUTED)
		var cost := dungeon.gate_cost(gate)
		price.text = "%d point%s each" % [cost, "" if cost == 1 else "s"]
		row.add_child(price)
		var less := Button.new()
		less.name = "Less"
		less.text = "-"
		less.custom_minimum_size = Vector2(36, 0)
		less.pressed.connect(change.bind(gate, -1))
		row.add_child(less)
		var count := Label.new()
		count.custom_minimum_size = Vector2(28, 0)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(count)
		var more := Button.new()
		more.name = "More"
		more.text = "+"
		more.custom_minimum_size = Vector2(36, 0)
		more.pressed.connect(change.bind(gate, 1))
		row.add_child(more)
		_gate_box.add_child(row)
		_rows.append({"gate": gate, "label": label, "count": count, "less": less, "more": more, "left": left[gate], "most": most[gate]})
	_points = Label.new()
	_points.name = "Points"
	_points.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gate_box.add_child(_points)
	_recover = Button.new()
	_recover.name = "Recover"
	_recover.text = "Recover gates"
	_recover.pressed.connect(recover)
	_gate_box.add_child(_recover)
	_refresh()


## "World 1, Hermes 2, Yaldabaoth 3" - what each gate's casting costs.
func _prices() -> String:
	var dungeon: DungeonDefinition = Campaign.dungeon
	var each: Array = []
	for gate in range(1, dungeon.gate_costs.size()):
		if dungeon.gate_cost(gate) > 0:
			each.append("%s costs %d" % [Stats.short_gate_name(gate), dungeon.gate_cost(gate)])
	return ", ".join(each)


## What the offer is worth keeping for: how many rests in the run may use it.
func _how_often() -> String:
	var dungeon: DungeonDefinition = Campaign.dungeon
	if dungeon.gate_recoveries == 1:
		return "This can be done at only one rest in the whole dungeon - this one, or a later one."
	return "This can be done at %d rests in the dungeon, and %d %s left." % [
		dungeon.gate_recoveries, Campaign.gate_recoveries_left, "is" if Campaign.gate_recoveries_left == 1 else "are"]


## What is chosen costs, against what there is to spend.
func points_left() -> int:
	return Campaign.dungeon.gate_recovery_points - Campaign.gate_recovery_cost(chosen)


## One more - or one less - casting through `gate`, if it is affordable and
## was spent in the first place.
func change(gate: int, by: int):
	if offered_to == "" or gate >= chosen.size():
		return
	var row = _row_for(gate)
	if row == null:
		return
	var wanted: int = chosen[gate] + by
	if wanted < 0 or row.left + wanted > row.most:
		return
	if by > 0 and Campaign.dungeon.gate_cost(gate) * by > points_left():
		return
	chosen[gate] = wanted
	_refresh()


## Brings back what is chosen, if anything is.
func recover() -> bool:
	if offered_to == "" or not Campaign.recover_gates(offered_to, chosen):
		return false
	var who := Campaign.display_name_of(offered_to)
	for child in _gate_box.get_children():
		child.queue_free()
	_rows.clear()
	var done := Label.new()
	done.name = "Recovered"
	done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	done.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	done.add_theme_color_override("font_color", GOLD)
	done.text = "%s's gates: %s." % [who, _gates_now(offered_to)]
	_gate_box.add_child(done)
	offered_to = ""
	# The button pressed has gone with the rest of the offer; the keyboard, if
	# it was being used, goes on to Continue rather than nowhere.
	if get_viewport().gui_get_focus_owner() != null or Pad.using_pad:
		_continue.grab_focus.call_deferred()
	return true


func _gates_now(key: String) -> String:
	var left := Campaign.gates_left(key)
	var most := Campaign.gates_most(key)
	var each: Array = []
	for gate in range(1, most.size()):
		if most[gate] > 0:
			each.append("%s %d/%d" % [Stats.short_gate_name(gate), left[gate], most[gate]])
	return ", ".join(each)


func _refresh():
	var spare := points_left()
	for row in _rows:
		var gate: int = row.gate
		var cost: int = Campaign.dungeon.gate_cost(gate)
		row.label.text = "%s   %d / %d" % [Stats.gate_name(gate), row.left + chosen[gate], row.most]
		row.count.text = str(chosen[gate])
		row.less.disabled = chosen[gate] <= 0
		row.more.disabled = cost > spare or row.left + chosen[gate] >= row.most
	if _points != null:
		_points.text = "Points left: %d of %d" % [spare, Campaign.dungeon.gate_recovery_points]
	if _recover != null:
		_recover.disabled = Campaign.gate_recovery_cost(chosen) <= 0


func _row_for(gate: int):
	for row in _rows:
		if row.gate == gate:
			return row
	return null


func _first_button() -> Control:
	for row in _rows:
		if not row.more.disabled:
			return row.more
	return _continue
