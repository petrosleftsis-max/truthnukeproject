extends Node
## What opens and closes a fight (FightCards; the designer, 2026-11-05), how somebody comes
## in late and how they fall. Played with nothing on the screen, for what they say, what
## they hold up, what skips them, and that none of it touches the fight.

const LOG_NAME := "fightcards"
const WATCHER := "res://data/encounters/encounter_03_watcher.tres"
const BOSS_FIGHT := "res://data/encounters/boss_ash_warden.tres"
const PARTY := ["enfina", "cyrus", "alithia"]

var LOG_PATH := HarnessLog.path_for(LOG_NAME)
var _log: FileAccess = null
var _fail := 0
var game = null
var combat: Combat = null
var controller = null
var ui = null


func log_line(text: String):
	if _log:
		_log.store_line(text)
		_log.flush()


func ok(condition: bool, label: String, detail: String = ""):
	if condition:
		log_line("  PASS  %s %s" % [label, detail])
	else:
		_fail += 1
		log_line("  FAIL  %s %s" % [label, detail])


func _ready():
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	get_tree().create_timer(170.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await settle()
	var booted = get_tree().current_scene
	if booted != null:
		booted.queue_free()
		await settle()
	the_words()
	await the_opening()
	await the_boss_reveal()
	await the_closing()
	await arrivals()
	await falling()
	await close_fight()
	FightCards.plays_headless = false
	MoveFeel.plays_headless = false
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


func settle(frames: int = 3):
	for i in frames:
		await get_tree().process_frame


func open_fight(path: String, cards: bool):
	await close_fight()
	FightCards.plays_headless = cards
	Campaign.reset()
	Campaign.set_party(PARTY, 14)
	Campaign.current_map = "res://maps/crossroads_explore.tscn"
	Campaign.return_to_position = true
	Campaign.current_encounter = load(path)
	game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle(2)
	combat = game.get_node("VisualCombat")
	controller = game.get_node("Controller")
	ui = game.get_node("CanvasLayer/UI")


func close_fight():
	FightCards.plays_headless = false
	if game != null and is_instance_valid(game):
		game.queue_free()
		await settle(3)
	game = null
	combat = null


func the_card() -> FightCards:
	if combat == null:
		return null
	for child in combat.get_children():
		if child is FightCards:
			return child
	return null


func until(condition: Callable, seconds: float) -> bool:
	var left := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < left:
		if condition.call():
			return true
		await get_tree().process_frame
	return condition.call()


func the_words():
	log_line("======== what they say ========")
	var plain := EncounterDefinition.new()
	ok(FightCards.opening_text(plain, []) == "Conflict Endless", "as a fight opens")
	ok(FightCards.closing_text(plain, [], "victory") == "Will Subdued", "won")
	ok(FightCards.closing_text(plain, [], "defeat") != "Will Subdued", "lost, something else", FightCards.closing_text(plain, [], "defeat"))
	ok(FightCards.closing_text(plain, [], "fled") != FightCards.closing_text(plain, [], "defeat"), "and for somebody getting away", FightCards.closing_text(plain, [], "fled"))
	var own := EncounterDefinition.new()
	own.opening_card = "The Last Stand"
	own.victory_card = "It Is Done"
	own.defeat_card = "It Is Over"
	own.fled_card = "Gone"
	ok(FightCards.opening_text(own, []) == "The Last Stand", "a fight's own words")
	ok(FightCards.closing_text(own, [], "victory") == "It Is Done" and FightCards.closing_text(own, [], "defeat") == "It Is Over" and FightCards.closing_text(own, [], "fled") == "Gone", "for each way it ends")
	var boss := BossDefinition.new()
	boss.opening_card = "The Warden Wakes"
	boss.victory_card = "The Gate Falls"
	ok(FightCards.opening_text(own, [boss]) == "The Warden Wakes", "a boss's before the fight's")
	ok(FightCards.closing_text(own, [boss], "victory") == "The Gate Falls", "at the end too")
	ok(FightCards.closing_text(own, [boss], "defeat") == "It Is Over", "and the fight's where the boss says nothing")
	log_line("")


func the_opening():
	log_line("======== the opening ========")
	await open_fight(WATCHER, true)
	ok(await until(func(): return the_card() != null, 5.0), "it plays")
	ok(combat.cards_playing, "and says so")
	ok(not combat.deployment_active and combat.turn == 0, "nothing begins beneath it")
	var state = combat.rng.state
	ok(await until(func(): var card = the_card(); return card != null and card.saying != "", 5.0), "it has its words")
	ok(the_card().saying == "Conflict Endless", "the words", the_card().saying)
	ok(ui.ui_hidden and controller.action_locked, "the board is nobody's meanwhile")
	# Any press and it is over.
	var press := InputEventKey.new()
	press.keycode = KEY_SPACE
	press.pressed = true
	the_card()._input(press)
	ok(await until(func(): return not combat.cards_playing, 5.0), "any press skips it")
	await settle(3)
	ok(combat.deployment_active or combat.turn >= 0, "and then the fight begins")
	ok(not ui.ui_hidden and not controller.action_locked, "the board is back")
	ok(combat.rng.state == state, "and not a roll spent on it")
	# Without it, in every other suite, nothing is waited for.
	await open_fight(WATCHER, false)
	ok(the_card() == null and not combat.cards_playing, "headless, nothing")
	log_line("")


func the_boss_reveal():
	log_line("======== a boss's reveal ========")
	var fight: EncounterDefinition = load(BOSS_FIGHT)
	ok(fight.boss_reveal, "a switch on the encounter")
	await open_fight(BOSS_FIGHT, true)
	ok(await until(func(): return the_card() != null, 5.0), "it plays")
	var boss := {}
	for comb in combat.combatants:
		if comb.has("boss"):
			boss = comb
	ok(not boss.is_empty(), "there is a boss", boss.get("name", ""))
	# Black first, then lit on the sting.
	ok(await until(func(): return boss.sprite.modulate.r < 0.05, 5.0), "a silhouette")
	ok(await until(func(): return boss.sprite.modulate.r > 0.9, 5.0), "lighting up", "%s" % boss.sprite.modulate)
	ok(await until(func(): var card = the_card(); return card != null and card.saying == boss.name, 5.0), "its name comes up", the_card().saying if the_card() != null else "")
	var layer: CanvasLayer = the_card()._layer
	ok(layer.get_node_or_null("Portrait") != null and layer.get_node("Portrait").texture != null, "with a portrait over the dimmed arena")
	ok(layer.get_node_or_null("Dim") != null, "the arena dimmed")
	ok(layer.get_node_or_null("BarTop") != null and layer.get_node_or_null("BarBottom") != null, "between the bars")
	ok(boss.boss.title == "" or layer.get_node_or_null("BossTitle") != null, "and its title")
	ok(await until(func(): var card = the_card(); return card != null and card.saying == "Conflict Endless", 8.0), "then the fight's title")
	the_card().skip()
	await until(func(): return not combat.cards_playing, 5.0)
	ok(Campaign.flag("reveal_seen:%s" % fight.display_name), "it has been seen")
	# Again, shorter: no silhouette.
	var again := FightCards.new()
	again.combat = combat
	combat.add_child(again)
	var went := []
	again.call("_reveal", boss)
	await settle(2)
	ok(boss.sprite.modulate.r > 0.9, "a retry goes straight to who it is")
	again.skip()
	await settle(3)
	again.queue_free()
	log_line("")


func the_closing():
	log_line("======== the closing ========")
	await open_fight(WATCHER, false)
	await settle(4)
	if combat.deployment_active:
		combat.finish_deployment()
		await settle(2)
	FightCards.plays_headless = true
	var finished := [false]
	combat.combat_finished.connect(func(): finished[0] = true)
	combat.groups[Combat.Group.ENEMIES].clear()
	combat.combat_finish()
	ok(await until(func(): return the_card() != null, 2.0), "the end has its card")
	ok(not finished[0], "and what comes after waits for it")
	ok(the_card().saying == "Will Subdued", "won", the_card().saying)
	ok(Engine.time_scale < 1.0, "the last of it slowed", "%s" % Engine.time_scale)
	ok(the_card()._layer.get_node_or_null("Drain") != null, "the colour draining")
	the_card().skip()
	ok(await until(func(): return finished[0], 5.0), "skipped: on to what comes after")
	ok(is_equal_approx(Engine.time_scale, 1.0), "at the ordinary speed", "%s" % Engine.time_scale)
	# Lost.
	await open_fight(WATCHER, false)
	await settle(4)
	if combat.deployment_active:
		combat.finish_deployment()
		await settle(2)
	FightCards.plays_headless = true
	combat.groups[Combat.Group.PLAYERS].clear()
	combat.combat_finish()
	ok(await until(func(): return the_card() != null, 2.0) and the_card().saying == FightCards.DEFEAT_TEXT, "lost, the words for that", the_card().saying if the_card() != null else "")
	the_card().skip()
	await settle(3)
	# Somebody got away.
	await open_fight(WATCHER, false)
	await settle(4)
	if combat.deployment_active:
		combat.finish_deployment()
		await settle(2)
	FightCards.plays_headless = true
	combat.lost_because = "test"
	combat.combat_finish()
	ok(await until(func(): return the_card() != null, 2.0) and the_card().saying == FightCards.FLED_TEXT, "got away, those", the_card().saying if the_card() != null else "")
	the_card().skip()
	await settle(3)
	log_line("")


func arrivals():
	log_line("======== who comes in ========")
	await open_fight(WATCHER, false)
	await settle(4)
	if combat.deployment_active:
		combat.finish_deployment()
		await settle(2)
	ok(CombatantDatabase.combatants.barbarian.entrance_style == CombatantDefinition.EntranceStyle.AUTOMATIC, "each has a style of their own, automatic by default")
	var spawn := SpawnDefinition.new()
	spawn.combatant_key = "barbarian"
	spawn.side = 1
	spawn.position = Vector2i(3, 3)
	spawn.arrives_on_round = combat.round_number + 1
	spawn.warned_by_flag = "read_the_log"
	combat._arriving.append(spawn)
	ok(combat.arrival_warnings().is_empty(), "nobody warned, no tiles marked")
	Campaign.set_flag("read_the_log")
	ok(combat.arrival_warnings() == [Vector2i(3, 3)], "a log read beforehand: marked a turn ahead")
	spawn.arrives_on_round = combat.round_number + 3
	ok(combat.arrival_warnings().is_empty(), "not sooner than that")
	spawn.arrives_on_round = combat.round_number + 1
	Campaign.flags.erase("read_the_log")
	var summoner: Dictionary = {}
	for comb in combat.combatants:
		if comb.side == 1 and comb.alive and not comb.has("object"):
			summoner = comb
			break
	spawn.warned_by_flag = ""
	spawn.warned_by_reading = summoner.combatant_key
	ok(combat.arrival_warnings().is_empty(), "the one who calls them not read: nothing")
	summoner["intent"] = {"skill": "x"}
	ok(combat.arrival_warnings() == [Vector2i(3, 3)], "read by Intuition: marked")
	summoner.erase("intent")
	combat._arriving.erase(spawn)
	# A plate and an entrance, played.
	MoveFeel.plays_headless = true
	FightCards.plays_headless = true
	summoner["entrance_style"] = CombatantDefinition.EntranceStyle.DROPS_IN
	FightCards.entrance(combat, summoner)
	FightCards.plate(combat, summoner)
	await settle(2)
	ok(the_card() != null and the_card().saying == summoner.name, "their name comes up", the_card().saying if the_card() != null else "")
	MoveFeel.plays_headless = false
	FightCards.plays_headless = false
	log_line("")


func falling():
	log_line("======== how they fall ========")
	await open_fight(WATCHER, false)
	await settle(4)
	if combat.deployment_active:
		combat.finish_deployment()
		await settle(2)
	MoveFeel.plays_headless = true
	FightCards.plays_headless = true
	var foe: Dictionary = {}
	for comb in combat.combatants:
		if comb.side == 1 and comb.alive and not comb.has("object"):
			foe = comb
			break
	var enfina: Dictionary = {}
	for comb in combat.combatants:
		if comb.get("combatant_key", "") == "enfina":
			enfina = comb
	foe.hp = 1
	combat.lose_hp(foe, 5, Damage.Type.FIRE, enfina)
	ok(foe.last_hurt.element == Damage.Type.FIRE and foe.last_hurt.from == enfina.position, "what hurt them, and from where", "%s" % [foe.last_hurt])
	var drawn_at: Vector2 = foe.sprite._drawn().position
	combat.combatant_die(foe)
	await settle(4)
	ok(foe.sprite._drawn().position != drawn_at or foe.sprite._drawn().rotation != 0.0, "knocked back and collapsing")
	await get_tree().create_timer(0.7).timeout
	ok(absf(foe.sprite._drawn().rotation) > 0.5, "lying there now", "%s" % foe.sprite._drawn().rotation)
	# One of the party.
	Campaign.current_encounter.last_words = {}
	enfina.hp = 1
	combat.lose_hp(enfina, 5, Damage.Type.PHYSICAL, foe)
	combat.combatant_die(enfina)
	await settle(2)
	ok(the_card() != null and the_card().saying == "Enfina has fallen", "her name across the screen", the_card().saying if the_card() != null else "")
	var layer: CanvasLayer = the_card()._layer if the_card() != null else null
	ok(layer != null and layer.get_node_or_null("LastWords") == null, "and no last words: none written")
	# The crack across her portrait.
	ui.update_combatants(combat.combatants) if ui.has_method("update_combatants") else null
	combat.update_combatants.emit(combat.combatants)
	await settle(2)
	var status = ui._icon_for(ui.get_node("Status"), enfina)
	ok(status != null and status.get_node_or_null("Crack") != null, "a crack across her portrait")
	# Written for this fight, or for her.
	var fight := EncounterDefinition.new()
	fight.last_words = {"enfina": "Keep going."}
	ok(FightCards.last_words_of(fight, enfina) == "Keep going.", "last words written for a fight")
	ok(FightCards.last_words_of(EncounterDefinition.new(), enfina) == CombatantDatabase.combatants.enfina.last_words, "or for her, none by default", "\"%s\"" % FightCards.last_words_of(EncounterDefinition.new(), enfina))
	var cyrus: Dictionary = {}
	for comb in combat.combatants:
		if comb.get("combatant_key", "") == "cyrus":
			cyrus = comb
	combat.encounter.last_words = {"cyrus": "Worth it."}
	cyrus.hp = 1
	combat.lose_hp(cyrus, 5, Damage.Type.PHYSICAL, foe)
	combat.combatant_die(cyrus)
	await settle(2)
	var said := false
	for child in combat.get_children():
		if child is FightCards and child._layer != null and child._layer.get_node_or_null("LastWords") != null:
			said = child._layer.get_node("LastWords").text.contains("Worth it.")
	ok(said, "and then they say them")
	combat.encounter.last_words = {}
	MoveFeel.plays_headless = false
	FightCards.plays_headless = false
	log_line("")
