extends Node
class_name LabMetrics
## TEMPORARY test harness, not story content: counts what happens in each fight
## of a dungeon whose Logs Metrics is on - the late-Chapter-I laboratory
## sequence (data/dungeons/lab_chapter1_sequence.tres, docs/chapter1_audit.md).
## Added to the battle by GameScene; listens to Combat's metric signal.
##
## Per fight it writes, to the run's summary (Markdown) and event log (CSV):
## - checkpoints as it begins and ends: everybody's health, who is down, the
##   gates left by depth per caster, what they carry
## - rounds and the real time it took
## - turns offered, taken, lost (and why) and played for them, per side, and the
##   boss's own
## - actions, gates spent by depth per caster, items used
## - hits and damage each way, lingering ticks apart; healing per healer
## - every down: who, the round, and what was happening
## - declared (telegraphed) moves: called, landed, dropped and why; who of the
##   other side stood in the marked tiles when it was called and when it landed,
##   who got out, and what it did to them
## - stagger gained, by source; staggers; damage dealt while staggered
##
## Run by demos/lab_sequence_*.tscn, which set the run's label. From the editor
## the files go to docs/lab_runs/; in a build, to user://lab_runs/.

## The run being logged: its label ("conservation", "free-spending") and when it
## began, which names its files.
static var run_label := ""
static var run_stamp := ""


## Starts a new run's files under `label`.
static func begin_run(label: String):
	run_label = label
	run_stamp = Time.get_datetime_string_from_system(false, true).replace(":", "").replace(" ", "_")


## Where this run's files are written.
static func run_folder() -> String:
	return "res://docs/lab_runs" if OS.has_feature("editor") else "user://lab_runs"


static func summary_path() -> String:
	return run_folder().path_join("%s_%s.md" % [_stamp(), _label()])


static func events_path() -> String:
	return run_folder().path_join("%s_%s_events.csv" % [_stamp(), _label()])


static func _label() -> String:
	return run_label if run_label != "" else "unlabelled"


static func _stamp() -> String:
	if run_stamp == "":
		run_stamp = Time.get_datetime_string_from_system(false, true).replace(":", "").replace(" ", "_")
	return run_stamp


var combat: Combat = null
var _began_msec := 0
var _round := 1
var _opened := false
var _turn_of := -1
var _in_landing := {}
var _checkpoint_in := []
var _turns := {}
var _boss_turns := {}
var _actions := {}
var _gates := {}
var _items := {}
var _damage_to := {}
var _hits := {"party": 0, "enemies": 0}
var _dealt := {"party": 0, "enemies": 0, "lingering on the party": 0, "lingering on the enemies": 0}
var _healed := {}
var _downs := []
var _declared := []
var _stagger := {}
var _staggers := {}
var _while_staggered := {}
## Per boss: its turns in order ([round, outcome, why]), what landed on it and
## from whom, what it shrugged off, and what happened around it.
var _bosses := {}
## Per party member: damage dealt to the enemies, and conditions put on them.
var _dealt_by := {}
## Of that, what their conditions did as they burned.
var _lingering_by := {}
var _conditions_by := {}
var _events: PackedStringArray = []


func _boss(comb: Dictionary) -> Dictionary:
	var name := _name(comb)
	if not _bosses.has(name):
		_bosses[name] = {"turns": [], "landed": {}, "blocked": {}, "story": []}
	return _bosses[name]


## A boss of the fight, if there is one standing - for what happens around it.
func _any_boss() -> Dictionary:
	for comb in combat.combatants:
		if comb.has("boss"):
			return comb
	return {}


func _ready():
	combat = get_parent() as Combat
	if combat == null:
		return
	combat.metric.connect(_on_metric)
	combat.combatant_died.connect(_on_died)
	combat.combat_finished.connect(_on_finished)
	_began_msec = Time.get_ticks_msec()


func _side(comb: Dictionary) -> String:
	return "party" if comb.get("side", 1) == 0 else "enemies"


func _name(comb) -> String:
	return str(comb.get("name", "?")) if comb is Dictionary and not comb.is_empty() else "-"


func _add(table: Dictionary, key: String, sub: String, amount: float = 1.0):
	if not table.has(key):
		table[key] = {}
	table[key][sub] = table[key].get(sub, 0.0) + amount


func _event(event: String, who: String, side: String, target: String = "", amount = "", detail: String = ""):
	var seconds := (Time.get_ticks_msec() - _began_msec) / 1000.0
	var cells := [str(snappedf(seconds, 0.1)), str(_round), event, who, side, target, str(amount), detail]
	for i in cells.size():
		var text: String = cells[i]
		if text.contains(",") or text.contains("\""):
			cells[i] = "\"%s\"" % text.replace("\"", "\"\"")
	_events.append(",".join(cells))


func _fighters(side: int) -> Array:
	return combat.combatants.filter(func(c): return c.get("side", -1) == side and not c.get("illusion", false) \
		and not c.has("summoner") and not c.has("object"))


func _on_metric(event: String, data: Dictionary):
	if not _opened:
		_opened = true
		_checkpoint_in = _checkpoint()
	match event:
		"round":
			_round = int(data.round)
			_event("round", "", "", "", _round)
		"turn":
			var who: Dictionary = data.who
			_turn_of = who.get("id", -1)
			var outcome: String = data.outcome
			_add(_turns, _side(who), outcome + ((" (%s)" % data.why) if data.why != "" else ""))
			if who.has("boss"):
				_add(_boss_turns, _name(who), outcome + ((" (%s)" % data.why) if data.why != "" else ""))
				_boss(who).turns.append([_round, outcome, str(data.why)])
			_event("turn", _name(who), _side(who), "", "", outcome + ((" - " + str(data.why)) if data.why != "" else ""))
		"action":
			var who: Dictionary = data.who
			var skill: SkillDefinition = data.skill
			var kind := "reaction" if data.get("reaction", false) else ("declared, landing" if data.get("landing", false) else ("secondary" if data.get("secondary", false) else "main"))
			_add(_actions, _name(who), "%s (%s)" % [skill.name if skill != null else "?", kind])
			_in_landing = {}
			_event("action", _name(who), _side(who), "", "", "%s - %s" % [skill.name if skill != null else "?", kind])
		"gate":
			var who: Dictionary = data.who
			_add(_gates, _name(who), Stats.gate_name(int(data.gate)).replace("Gates of ", ""))
			_event("gate", _name(who), _side(who), "", "", Stats.gate_name(int(data.gate)))
		# A spare casting in a gate's place (Devotion), listed with the gates.
		"spare":
			var who: Dictionary = data.who
			var called: String = combat.spares_name(who)
			_add(_gates, _name(who), called)
			_event("gate", _name(who), _side(who), "", "", called)
		"item":
			var who: Dictionary = data.who
			_add(_items, _name(who), str(data.item))
			_event("item", _name(who), _side(who), "", "", str(data.item))
		"damage":
			var target: Dictionary = data.target
			var amount := int(data.amount)
			if amount <= 0 or target.has("object"):
				return
			var during: Dictionary = data.during
			# Laid at the door of whoever did it when Combat says (a tick at its
			# source's, a reaction at the reactor's), else at whose turn it is.
			var by: Dictionary = data.get("by", {})
			var burning := str(data.get("lingering", ""))
			var credit: Dictionary = by if not by.is_empty() else during
			var lingering: bool = burning != "" or (by.is_empty() and not during.is_empty()
				and during.get("id", -2) == target.get("id", -1) and _turn_of != target.get("id", -1))
			var side := _side(target)
			if lingering:
				_dealt["lingering on the " + side] += amount
			else:
				_dealt[side] += amount
				_hits[side] += 1
			if side == "party":
				_add(_damage_to, _name(target), "lingering" if lingering else "hits", amount)
			elif not credit.is_empty() and credit.get("side", 1) == 0 and not (lingering and by.is_empty()):
				_dealt_by[_name(credit)] = _dealt_by.get(_name(credit), 0) + amount
				if lingering:
					_lingering_by[_name(credit)] = _lingering_by.get(_name(credit), 0) + amount
			if target.has("boss") and combat.is_staggered(target):
				_while_staggered[_name(target)] = _while_staggered.get(_name(target), 0) + amount
			if not _in_landing.is_empty():
				_in_landing.hit.append("%s %d" % [_name(target), amount])
			var how := "on %s's turn" % _name(during)
			if lingering:
				how = "%s, lingering" % burning if burning != "" else "lingering"
			target["_last_hurt_by"] = "%s (%s)" % [_name(credit), how]
			_event("damage", _name(credit), _side(credit) if not credit.is_empty() else "", _name(target), amount,
				("lingering: %s" % burning if burning != "" else "lingering") if lingering else "")
		"heal":
			var who: Dictionary = data.who
			var amount := int(data.amount)
			if amount > 0:
				_healed[_name(who)] = _healed.get(_name(who), 0) + amount
				_event("heal", _name(who), _side(who), _name(data.target), amount, data.skill.name if data.skill != null else "")
		"declared":
			var who: Dictionary = data.who
			var record := {"who": _name(who), "skill": data.skill.name, "round": _round, "in_area": _standing_in(data.tiles, who),
				"landed": false, "dropped": "", "in_area_at_landing": [], "hit": []}
			_declared.append(record)
			_event("declared", _name(who), _side(who), ", ".join(record.in_area), "", data.skill.name)
		"declared_landed":
			var record := _open_declared(_name(data.who))
			if not record.is_empty():
				record.landed = true
				record.in_area_at_landing = _standing_in(data.tiles, data.who)
				_in_landing = record
			_event("declared landed", _name(data.who), _side(data.who), "", "", data.skill.name)
		"declared_dropped":
			var record := _open_declared(_name(data.who))
			if not record.is_empty():
				record.dropped = str(data.why)
			_event("declared dropped", _name(data.who), _side(data.who), "", "", "%s - %s" % [data.skill.name, data.why])
		"stagger_gain":
			var who: Dictionary = data.who
			_add(_stagger, _name(who), str(data.source) if data.source != "" else "other", float(data.amount))
			_event("stagger", _name(who), _side(who), "", snappedf(float(data.amount), 0.1), str(data.source) + (" (while readying)" if data.readying else ""))
		"staggered":
			var who: Dictionary = data.who
			_staggers[_name(who)] = _staggers.get(_name(who), 0) + 1
			_event("staggered", _name(who), _side(who), "", data.turns_lost, "turns lost")
			if who.has("boss"):
				_boss(who).story.append("Round %d: staggered - %d turn(s) lost" % [_round, data.turns_lost])
		"condition":
			var target: Dictionary = data.target
			var condition: ConditionDefinition = data.condition
			var by: Dictionary = data.get("by", {})
			var by_name: String = _name(by) if not by.is_empty() else str(data.get("by_name", "-"))
			# An aura's, put on again every turn, says nothing new.
			if by_name.ends_with("aura") or condition == null:
				return
			_event("condition", by_name, _side(by) if not by.is_empty() else "", _name(target), data.turns, condition.display_name)
			if target.has("boss"):
				_add(_boss(target).landed, condition.display_name, by_name)
			if by.has("boss"):
				_boss(by).story.append("Round %d: %s is %s by it (%d turns)" % [_round, _name(target), condition.display_name, int(data.turns)])
			if not by.is_empty() and by.get("side", 1) == 0 and target.get("side", 0) == 1:
				_add(_conditions_by, by_name, condition.display_name)
		"blocked":
			var who: Dictionary = data.who
			_event("blocked", _name(who), _side(who), "", "", str(data.what))
			if who.has("boss"):
				var blocked: Dictionary = _boss(who).blocked
				blocked[str(data.what)] = blocked.get(str(data.what), 0) + 1
		"break_free":
			var held: Dictionary = data.held
			var holder: Dictionary = data.holder
			_event("break free", _name(held), _side(held), _name(holder), data.chance, "free" if data.freed else "still held")
			if holder.has("boss"):
				_boss(holder).story.append("Round %d: %s tries to break free (%d%%) - %s" % [_round, _name(held), int(data.chance), "free" if data.freed else "still held"])
		"swallowed":
			_event("swallowed", _name(data.by), _side(data.by), _name(data.who))
			if data.by.has("boss"):
				_boss(data.by).story.append("Round %d: swallows %s" % [_round, _name(data.who)])
		"freed":
			_event("freed", _name(data.who), _side(data.who), _name(data.by), "", str(data.how))
			if data.by.has("boss"):
				_boss(data.by).story.append("Round %d: %s gets out - %s" % [_round, _name(data.who), data.how])
		"digested":
			_event("digested", _name(data.by), _side(data.by), _name(data.who))
			if data.by.has("boss"):
				_boss(data.by).story.append("Round %d: digests %s" % [_round, _name(data.who)])
		"cue":
			var what: String = data.what
			for kind in ["ate:", "used:", "broke:", "phase:"]:
				if what.begins_with(kind):
					_event("cue", "", "", "", "", what)
					var boss := _any_boss()
					if not boss.is_empty():
						var said := {"ate:": "eats %s", "used:": "the party uses %s", "broke:": "its %s breaks", "phase:": "phase: %s"}
						_boss(boss).story.append("Round %d: %s" % [_round, said[kind] % what.trim_prefix(kind)])


## The other side's fighters standing on any of `tiles`.
func _standing_in(tiles: Array, who: Dictionary) -> Array:
	var names := []
	for other in combat.combatants:
		if not other.get("alive", false) or other.get("side", -1) == who.get("side", -1) or other.has("object"):
			continue
		var square: Rect2i = Combat.rect_of(other)
		if tiles.any(func(tile): return square.has_point(tile)):
			names.append(_name(other))
	return names


## The last declared move of `who` not yet landed or dropped.
func _open_declared(who: String) -> Dictionary:
	for i in range(_declared.size() - 1, -1, -1):
		var record: Dictionary = _declared[i]
		if record.who == who and not record.landed and record.dropped == "":
			return record
	return {}


func _on_died(comb: Dictionary):
	if comb.has("object") or comb.get("illusion", false):
		return
	_downs.append({"who": _name(comb), "side": _side(comb), "round": _round, "by": comb.get("_last_hurt_by", "-"),
		"declared": "" if _in_landing.is_empty() else "%s's %s" % [_in_landing.who, _in_landing.skill]})
	_event("down", comb.get("_last_hurt_by", "-"), "", _name(comb), "", _side(comb))


## Everybody of the party as things stand: health, down or not, gates left by
## depth, what they carry.
func _checkpoint() -> Array:
	var lines := []
	for comb in _fighters(0):
		var gates := []
		var slots: Array = comb.get("spell_slots", [])
		var full: Array = comb.get("max_spell_slots", [])
		for gate in range(1, mini(slots.size(), full.size())):
			if int(full[gate]) > 0:
				gates.append("%s %d/%d" % [Stats.gate_name(gate).replace("Gates of ", ""), slots[gate], full[gate]])
		var carried: Array = combat.items_of(comb)
		lines.append("| %s | %d / %d | %s | %s | %s |" % [_name(comb), int(comb.hp), int(comb.max_hp), "down" if not comb.alive else "standing",
			", ".join(gates) if not gates.is_empty() else "-", ", ".join(carried) if not carried.is_empty() else "-"])
	return lines


func _table(title: String, data: Dictionary) -> Array:
	var lines := ["", "**%s**" % title, ""]
	if data.is_empty():
		lines.append("none")
		return lines
	for key in data:
		var parts := []
		for sub in data[key]:
			var value: float = data[key][sub]
			parts.append("%s %s" % [sub, str(int(value)) if is_equal_approx(value, roundf(value)) else str(snappedf(value, 0.1))])
		lines.append("- %s: %s" % [key, "; ".join(parts)])
	return lines


func _on_finished():
	if combat == null:
		return
	# Over before anything was counted: its opening checkpoint is its closing one.
	if not _opened:
		_opened = true
		_checkpoint_in = _checkpoint()
	var seconds := (Time.get_ticks_msec() - _began_msec) / 1000.0
	var players_left: bool = combat.groups[Combat.Group.PLAYERS].size() > 0
	var enemies_left: bool = combat.groups[Combat.Group.ENEMIES].size() > 0
	var outcome := "won" if players_left and not enemies_left and combat.lost_because == "" else "lost"
	var lines := []
	var stage := Campaign.dungeon_stage + 1 if Campaign.in_dungeon() else 0
	lines.append("## Stage %d: %s - %s" % [stage, combat.encounter.display_name if combat.encounter != null else "?", outcome])
	lines.append("")
	lines.append("Run: %s. Rounds: %d. Real time: %d s." % [_label(), _round, roundi(seconds)])
	lines.append("")
	lines.append("**Checkpoint, as it began**")
	lines.append("")
	lines.append("| Who | Health | | Gates left | Carrying |")
	lines.append("|---|---|---|---|---|")
	lines.append_array(_checkpoint_in)
	lines.append("")
	lines.append("**Checkpoint, as it ended**")
	lines.append("")
	lines.append("| Who | Health | | Gates left | Carrying |")
	lines.append("|---|---|---|---|---|")
	lines.append_array(_checkpoint())
	lines.append_array(_table("Turns (offered = all of these)", _turns))
	lines.append_array(_table("The boss's turns", _boss_turns))
	lines.append_array(_table("Actions", _actions))
	lines.append_array(_table("Gates spent", _gates))
	lines.append_array(_table("Items used", _items))
	lines.append("")
	lines.append("**Damage**")
	lines.append("")
	lines.append("- Hits on the party: %d, for %d; lingering on the party %d" % [_hits.party, _dealt.party, _dealt["lingering on the party"]])
	lines.append("- Hits on the enemies: %d, for %d; lingering on them %d" % [_hits.enemies, _dealt.enemies, _dealt["lingering on the enemies"]])
	lines.append_array(_table("Damage taken by each of the party", _damage_to))
	lines.append("")
	lines.append("**Healing**: " + (", ".join(_healed.keys().map(func(k): return "%s %d" % [k, _healed[k]])) if not _healed.is_empty() else "none"))
	lines.append("")
	lines.append("**Downs**")
	lines.append("")
	if _downs.is_empty():
		lines.append("none")
	for down in _downs:
		lines.append("- Round %d: %s (%s), by %s%s" % [down.round, down.who, down.side, down.by,
			(" - " + down.declared) if down.declared != "" else ""])
	lines.append("")
	lines.append("**Declared (telegraphed) moves**")
	lines.append("")
	if _declared.is_empty():
		lines.append("none")
	for record in _declared:
		var escaped: Array = record.in_area.filter(func(n): return not record.in_area_at_landing.has(n))
		lines.append("- Round %d: %s's %s - %s. In the marked tiles when called: %s; when it landed: %s; got out: %s; hit: %s" % [
			record.round, record.who, record.skill,
			"landed" if record.landed else ("dropped (%s)" % record.dropped if record.dropped != "" else "still waiting at the end"),
			", ".join(record.in_area) if not record.in_area.is_empty() else "nobody",
			", ".join(record.in_area_at_landing) if record.landed and not record.in_area_at_landing.is_empty() else ("nobody" if record.landed else "-"),
			", ".join(escaped) if not escaped.is_empty() else "nobody",
			", ".join(record.hit) if not record.hit.is_empty() else "nobody"])
	lines.append_array(_table("Stagger gained, by source", _stagger))
	if not _staggers.is_empty():
		lines.append("")
		lines.append("**Staggered**: " + ", ".join(_staggers.keys().map(func(k): return "%s %d time(s); %d dealt to it while staggered" % [k, _staggers[k], _while_staggered.get(k, 0)])))
	lines.append("")
	lines.append("**What each of the party did to the enemies**")
	lines.append("")
	for comb in _fighters(0):
		var put: Dictionary = _conditions_by.get(_name(comb), {})
		lines.append("- %s: %d damage (%d of it lingering); conditions put on them: %s" % [_name(comb), _dealt_by.get(_name(comb), 0),
			_lingering_by.get(_name(comb), 0),
			", ".join(put.keys().map(func(k): return "%s x%d" % [k, int(put[k])])) if not put.is_empty() else "none"])
	for name in _bosses:
		lines.append_array(_boss_section(name, _bosses[name]))
	lines.append("")
	_write(lines)


## A boss, turn by turn: whether it could be kept from acting (chain control),
## what was put on it and what it shrugged off, and what it did and suffered.
func _boss_section(name: String, record: Dictionary) -> Array:
	var lines := ["", "### The boss: %s" % name, ""]
	var turns: Array = record.turns
	var lost := turns.filter(func(t): return t[1] == "lost")
	var played_for := turns.filter(func(t): return t[1] in ["confused", "deceived"])
	var run := 0
	var longest := 0
	for turn in turns:
		run = run + 1 if turn[1] != "taken" else 0
		longest = maxi(longest, run)
	# A round it had turns in and acted in none of.
	var rounds := {}
	for turn in turns:
		if not rounds.has(turn[0]):
			rounds[turn[0]] = false
		if turn[1] == "taken":
			rounds[turn[0]] = true
	var idle: Array = rounds.keys().filter(func(r): return not rounds[r])
	lines.append("- Turns offered: %d; its own: %d; lost: %d; played for it (confused, deceived): %d" % [turns.size(),
		turns.size() - lost.size() - played_for.size(), lost.size(), played_for.size()])
	var why := {}
	for turn in lost:
		why[turn[2]] = why.get(turn[2], 0) + 1
	lines.append("- Lost, by cause: %s" % (", ".join(why.keys().map(func(k): return "%s %d" % [k, why[k]])) if not why.is_empty() else "none"))
	lines.append("- Longest run of turns not its own, in a row: %d. Rounds in which it never acted for itself: %d%s" % [longest, idle.size(),
		(" (%s)" % ", ".join(idle.map(func(r): return str(r)))) if not idle.is_empty() else ""])
	lines.append("- In order: %s" % (" ".join(turns.map(func(t): return "R%d:%s" % [t[0], "-" if t[1] == "taken" else t[1]])) if not turns.is_empty() else "none"))
	var landed: Dictionary = record.landed
	var landed_text := []
	for condition in landed:
		var from: Dictionary = landed[condition]
		landed_text.append("%s (%s)" % [condition, ", ".join(from.keys().map(func(k): return "%s x%d" % [k, int(from[k])]))])
	lines.append("- Put on it: %s" % (", ".join(landed_text) if not landed_text.is_empty() else "nothing"))
	var blocked: Dictionary = record.blocked
	lines.append("- Shrugged off: %s" % (", ".join(blocked.keys().map(func(k): return "%s x%d" % [k, int(blocked[k])])) if not blocked.is_empty() else "nothing"))
	lines.append("- What happened around it:")
	if record.story.is_empty():
		lines.append("  - nothing logged")
	for said in record.story:
		lines.append("  - %s" % said)
	return lines


func _write(lines: Array):
	var folder := run_folder()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var new_run := not FileAccess.file_exists(summary_path())
	var summary := FileAccess.open(summary_path(), FileAccess.READ_WRITE if not new_run else FileAccess.WRITE)
	if summary == null:
		push_warning("LabMetrics: could not write %s" % summary_path())
		return
	if new_run:
		summary.store_line("# Laboratory run: %s (%s)" % [_label(), _stamp()])
		summary.store_line("")
		summary.store_line("TEMPORARY test harness - docs/chapter1_audit.md, section 7. Not story content.")
		summary.store_line("")
	else:
		summary.seek_end()
	summary.store_string("\n".join(lines) + "\n")
	summary.close()
	var new_events := not FileAccess.file_exists(events_path())
	var events := FileAccess.open(events_path(), FileAccess.READ_WRITE if not new_events else FileAccess.WRITE)
	if events == null:
		return
	if new_events:
		events.store_line("stage,seconds,round,event,who,side,target,amount,detail")
	else:
		events.seek_end()
	var stage := str(Campaign.dungeon_stage + 1 if Campaign.in_dungeon() else 0)
	for line in _events:
		events.store_line(stage + "," + line)
	events.close()
	combat.update_information.emit("[color=gray]Logged to %s[/color]\n" % ProjectSettings.globalize_path(summary_path()))
