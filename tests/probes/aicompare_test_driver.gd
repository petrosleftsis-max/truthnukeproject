extends Node
## A probe, not a suite: what the AI's mind (Combat "The AI's mind") does to fights, measured. Each fight is
## played twice from the same seeds: "before", with nobody knowing anything and the dials at 1 (what the AI
## was), and "now". Twice over: with the party standing still, to see how fast it is killed, and with the
## AI playing the party too, to see who wins. It is no stand-in for a player. It is only a before and after.
##
##   tests/run.sh aicompare

const LOG_NAME := "aicompare"
const FIGHTS := [
	"res://data/encounters/encounter_01_ambush.tres",
	"res://data/encounters/encounter_02_sappers.tres",
	"res://data/encounters/encounter_03_watcher.tres",
	"res://data/encounters/encounter_hired_blades.tres",
	"res://data/encounters/encounter_bound_golem.tres",
	"res://data/encounters/alchemist_den.tres",
	"res://data/encounters/summoner_den.tres",
	"res://data/encounters/boss_bellkeeper.tres",
	"res://data/encounters/boss_ash_warden.tres",
	"res://data/encounters/boss_glutton.tres",
	"res://data/encounters/level_64_showdown.tres",
]
## Played out with the AI on both sides too, which is slow: real time, whatever Engine.time_scale says.
const BOTH_SIDES := ["res://data/encounters/encounter_02_sappers.tres", "res://data/encounters/encounter_hired_blades.tres",
	"res://data/encounters/boss_ash_warden.tres"]
const SEEDS := [11]
const MOST_ROUNDS := 20
const MOST_SECONDS := 150.0
const MOST_SECONDS_STANDING := 40.0
const STUCK_SECONDS := 30.0

var LOG_PATH := HarnessLog.path_for(LOG_NAME)
var _log: FileAccess = null


func log_line(text: String):
	if _log:
		_log.store_line(text)
		_log.flush()


func _ready():
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	get_tree().create_timer(3000.0, true, false, true).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	Engine.time_scale = 40.0
	await settle()
	var booted = get_tree().current_scene
	if booted != null:
		booted.queue_free()
		await settle()
	var fights := []
	for path in FIGHTS:
		if ResourceLoader.exists(path):
			fights.append(path)
	# Whatever else there is, under the names it goes by.
	if fights.size() < FIGHTS.size():
		log_line("Named fights not found: %d of %d." % [FIGHTS.size() - fights.size(), FIGHTS.size()])
		for file in DirAccess.get_files_at("res://data/encounters"):
			if file.ends_with(".tres") and fights.size() < FIGHTS.size() + 4 and not fights.has("res://data/encounters/" + file):
				fights.append("res://data/encounters/" + file)
	log_line("Fight | party standing still: party damage in 3 rounds, before -> now; rounds to fell them | AI on both sides: party wins of %d, rounds, party health left, before -> now" % SEEDS.size())
	for path in fights:
		var encounter: EncounterDefinition = load(path)
		if encounter.spawns.is_empty():
			continue
		var still_before: Dictionary = await play(path, SEEDS[0], false, false)
		var still_now: Dictionary = await play(path, SEEDS[0], true, false)
		var line := "%s | %d -> %d; %d -> %d" % [encounter.display_name, still_before.damage, still_now.damage, still_before.rounds, still_now.rounds]
		if BOTH_SIDES.has(path):
			var before := []
			var now := []
			for each_seed in SEEDS:
				before.append(await play(path, each_seed, false, true))
				now.append(await play(path, each_seed, true, true))
			line += " | wins %d -> %d, rounds %.1f -> %.1f, health left %d%% -> %d%%" % [_wins(before), _wins(now), _mean(before, "rounds"), _mean(now, "rounds"), roundi(_mean(before, "left") * 100.0), roundi(_mean(now, "left") * 100.0)]
		log_line(line)
	log_line("======== DONE ========")
	_log.close()
	Engine.time_scale = 1.0
	get_tree().quit(0)


func settle(frames: int = 3):
	for i in frames:
		await get_tree().process_frame


func _wins(runs: Array) -> int:
	return runs.filter(func(run): return run.won).size()


func _mean(runs: Array, key: String) -> float:
	var total := 0.0
	for run in runs:
		total += float(run[key])
	return total / maxf(float(runs.size()), 1.0)


## `knowing`: as the data says now; otherwise nobody knows anything. `party_fights`: the AI plays them too.
func play(path: String, each_seed: int, knowing: bool, party_fights: bool) -> Dictionary:
	Campaign.reset()
	Campaign.asks_to_prepare = false
	var encounter: EncounterDefinition = load(path).duplicate()
	encounter.set_meta("seed", each_seed)
	Campaign.current_encounter = encounter
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle(6)
	var combat = game.get_node("VisualCombat")
	combat.reaction_prompt = null
	if not knowing:
		combat.combatant_added.connect(_knows_nothing)
		for comb in combat.combatants:
			_knows_nothing(comb)
	if party_fights:
		for comb in combat.combatants:
			_plays_itself(comb)
	var party: Array = combat.combatants.filter(func(comb): return comb.get("side", 1) == 0 and not comb.has("object") and comb.has("stats"))
	var health_at_first := {}
	var whole := 0.0
	for comb in party:
		health_at_first[comb.get("id", -1)] = comb.hp
		whole += float(comb.hp)
	var taken_by_round_three := -1
	var started: bool = false
	if combat.deployment_active:
		combat.finish_deployment()
		started = true
	await settle(2)
	# Nothing starts the opening turn of somebody the AI plays on the party's side but this.
	if party_fights and combat.get_current_combatant().get("side", 1) == 0:
		combat._start_opening_ai_turn()
	var clock := Time.get_ticks_msec()
	var going := false
	var turn_was := -1
	var turn_since := Time.get_ticks_msec()
	var most_seconds: float = MOST_SECONDS if party_fights else MOST_SECONDS_STANDING
	while float(Time.get_ticks_msec() - clock) / 1000.0 < most_seconds and combat.round_number <= MOST_ROUNDS and not combat.combat_over \
			and combat.groups[0].size() > 0 and combat.groups[1].size() > 0:
		if combat.round_number >= 4 and taken_by_round_three < 0:
			taken_by_round_three = _taken(party, health_at_first)
		# Nobody's turn lasts this long: say whose it was, and stop waiting for it.
		if combat.round_number * 1000 + combat.turn != turn_was:
			turn_was = combat.round_number * 1000 + combat.turn
			turn_since = Time.get_ticks_msec()
		elif float(Time.get_ticks_msec() - turn_since) / 1000.0 > STUCK_SECONDS:
			var who: Dictionary = combat.get_current_combatant()
			log_line("  stuck: %s, round %d, on %s (%s), player_turn %s, movement %s, locked %s" % [encounter.display_name, combat.round_number, who.get("name", "?"), who.get("ai_function", ""), combat.controller.player_turn, combat.controller.movement, combat.controller.action_locked])
			break
		# With nobody at the keyboard, whoever's turn it is hands it on.
		if not going and combat.controller.player_turn and not combat.get_current_combatant().get("ai_controlled", false):
			going = true
			await combat.advance_turn()
			going = false
		await get_tree().process_frame
	if taken_by_round_three < 0:
		taken_by_round_three = _taken(party, health_at_first)
	var left := 0.0
	for comb in party:
		if comb.get("alive", false):
			left += float(comb.hp)
	var run := {"damage": taken_by_round_three, "rounds": combat.round_number, "left": left / maxf(whole, 1.0),
		"won": party.any(func(comb): return comb.get("alive", false)) and not combat.groups[1].any(func(index): return combat.combatants[index].get("alive", false) and not combat.combatants[index].get("illusion", false))}
	game.queue_free()
	await settle(3)
	return run


func _taken(party: Array, at_first: Dictionary) -> int:
	var total := 0
	for comb in party:
		total += maxi(int(at_first.get(comb.get("id", -1), 0)) - int(comb.get("hp", 0)), 0)
	return total


func _knows_nothing(comb: Dictionary):
	comb["ai_knows"] = 0
	comb["ai_smarts"] = CombatantDefinition.AiSmarts.TRAINED
	comb["ai_commands_tiles"] = 0
	comb["ai_grudge"] = 0.0
	comb["ai_hunter"] = false
	comb["ai_guards"] = ""
	comb["ai_pack"] = 0
	comb["ai_fears"] = []
	comb["ai_learns"] = false
	comb["ai_greedy"] = false
	for dial in ["ai_aggression", "ai_caution", "ai_focus", "ai_self_preservation"]:
		comb[dial] = 1.0


func _plays_itself(comb: Dictionary):
	if comb.get("side", 1) != 0 or comb.has("object"):
		return
	comb["ai_controlled"] = true
	match comb.get("combatant_key", ""):
		"prometheus":
			comb["ai_function"] = "ai_caster"
		"alithia":
			comb["ai_function"] = "ai_healer"
		"cyrus":
			comb["ai_function"] = "ai_ranger"
		_:
			comb["ai_function"] = "ai_melee_rush"
