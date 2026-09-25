extends Node
## A fight that asks before it starts.
##
## The lab's trigger is automatic and reaches a long way, so a party that turns
## it down cannot simply be left standing where they are: it would fire again
## on the spot. Saying no walks them back out of its reach, which also means
## they cannot walk through it while it is still asking.

var LOG_PATH := HarnessLog.path_for("gate")
const MAP = "res://scenes/laboratory_terrain_explore.tscn"

var _log: FileAccess
var _fail = 0

func log_line(t): _log.store_line(t); _log.flush()

func ok(condition: bool, label: String, detail: String = ""):
	if condition:
		log_line("  PASS  %s %s" % [label, detail])
	else:
		_fail += 1
		log_line("  FAIL  %s %s" % [label, detail])

func _ready():
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	get_tree().create_timer(180.0, true, false, true).timeout.connect(func():
		log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


func trigger_in(scene: Node) -> EncounterInteractable:
	for node in scene.get_node(scene.MAP_NODE).get_children():
		if node is EncounterInteractable:
			return node
	return null


func run_test():
	log_line("======== the answer a conversation gives ========")
	Campaign.reset()
	ok(Campaign.take_encounter_answer() == Campaign.EncounterAnswer.UNANSWERED,
		"nothing is assumed before anybody is asked")
	Campaign.accept_encounter()
	ok(Campaign.take_encounter_answer() == Campaign.EncounterAnswer.ACCEPTED, "yes is heard")
	ok(Campaign.take_encounter_answer() == Campaign.EncounterAnswer.UNANSWERED,
		"and reading it clears it, so it cannot be acted on twice")
	Campaign.decline_encounter()
	ok(Campaign.take_encounter_answer() == Campaign.EncounterAnswer.DECLINED, "no is heard")
	Campaign.accept_encounter()
	Campaign.reset()
	ok(Campaign.take_encounter_answer() == Campaign.EncounterAnswer.UNANSWERED,
		"and starting over forgets it")
	log_line("")

	log_line("======== the lab's trigger asks first ========")
	# Both halves: the map has to point at the conversation, and the
	# conversation has to answer. Either one missing and the gate does nothing.
	var written = FileAccess.get_file_as_string("res://Dialogue/lab_prometheus_encounter.dialogue")
	ok(written.contains("do Campaign.accept_encounter()"),
		"one branch of the conversation walks into the fight")
	ok(written.contains("do Campaign.decline_encounter()"),
		"and the other backs away from it")

	Campaign.reset()
	Campaign.current_map = MAP
	var scene = load("res://scenes/exploration.tscn").instantiate()
	get_tree().root.add_child(scene)
	for i in 8:
		await get_tree().process_frame
	var gate = trigger_in(scene)
	ok(gate != null, "the map has an encounter trigger")
	if gate == null:
		log_line("FAILURES: %d" % _fail)
		get_tree().quit(1)
		return
	ok(gate.dialogue != null, "with a conversation in front of it",
		gate.dialogue.resource_path if gate.dialogue else "none")
	ok(gate.automatic, "and it fires on approach, which is why backing off matters")
	log_line("  NOTE  it reaches %d units, %.1f tiles" % [
		gate.interaction_radius, gate.interaction_radius / float(Grid.TILE_SIZE)])
	log_line("")

	log_line("======== turning it down walks them clear ========")
	scene.party.teleport(gate.global_position)
	await get_tree().process_frame
	ok(scene.party_position().distance_to(gate.global_position) < gate.interaction_radius,
		"they start well inside its reach",
		"%.0f units" % scene.party_position().distance_to(gate.global_position))
	await scene.step_party_back_from(gate)
	var after = scene.party_position().distance_to(gate.global_position)
	ok(after >= gate.interaction_radius, "and end up outside it",
		"%.0f units, reach is %.0f" % [after, gate.interaction_radius])
	# Not just barely outside: a single step back in must not re-offer it.
	ok(after > gate.interaction_radius, "with room to spare rather than on the line",
		"%.0f past the edge" % (after - gate.interaction_radius))
	ok(scene.is_walkable(scene.party_position()),
		"on ground they can actually stand on", "%s" % scene.party_position())
	# The retreat drives the line through the same stepping the keys do, so it
	# has to hand it back when it is finished or the player is left a passenger.
	ok(not scene.party._scripted, "and the party is the player's again afterwards")
	var stood = scene.party_position()
	ok(scene.party._step(Vector2.LEFT, 0.1) or scene.party._step(Vector2.RIGHT, 0.1),
		"a step of their own still moves them", "from %s" % stood)
	log_line("")

	log_line("======== and the trigger is not still offering itself ========")
	scene._update_prompt()
	ok(scene._current_target != gate, "nothing is prompting for the fight they declined",
		"%s" % [scene._current_target.name if scene._current_target else "none"])
	log_line("")

	log_line("======== closing the balloon is not a way past ========")
	# No answer at all counts as declining. Otherwise closing the conversation
	# would leave them standing on an automatic trigger with nothing decided.
	Campaign.forget_encounter_answer()
	scene.party.teleport(gate.global_position)
	await get_tree().process_frame
	gate._after_the_talking(null, scene)
	# _after_the_talking does not wait for the walk, so give it room to finish -
	# and wait for the walk itself to end rather than for it to clear the reach,
	# because it deliberately carries on half a tile past that.
	for i in 600:
		await get_tree().process_frame
		if not scene.party._scripted:
			break
	ok(scene.party_position().distance_to(gate.global_position) >= gate.interaction_radius,
		"an unanswered conversation backs them off too",
		"%.0f units" % scene.party_position().distance_to(gate.global_position))
	ok(not Campaign.has_map_to_return_to(), "and no fight was started")
	log_line("")

	ok(not scene.party._scripted, "and the walk finished rather than being left running")
	log_line("")

	log_line("======== saying yes starts the fight ========")
	# Last, because it hands the scene over to a battle.
	Campaign.reset()
	Campaign.current_map = MAP
	Campaign.accept_encounter()
	gate._after_the_talking(null, scene)
	await get_tree().process_frame
	ok(Campaign.current_encounter == gate.encounter, "the encounter is the trigger's own",
		"%s" % [Campaign.current_encounter.display_name if Campaign.current_encounter else "none"])
	ok(Campaign.has_map_to_return_to(), "and the map is waiting to be handed back")
	log_line("")

	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
