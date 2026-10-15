extends Node
## Stealth maps: a guard who stands his post and only now and then glances
## round (Guard.glance_every); evidence planted on a guard, found by another,
## and the framed one marched off for good; and what a guard in a disguise's
## small talk can be asked - to go elsewhere, to tell a round, to hand over a
## key. On the stealth demo.

var LOG_PATH := HarnessLog.path_for("sentries")
const DEMO := "res://demos/stealth_demo.tscn"

var _log: FileAccess = null
var _fail = 0
var scene: ExplorationScene = null
var watch: StealthWatch = null


func log_line(t: String):
	if _log:
		_log.store_line(t)
		_log.flush()


func ok(condition: bool, label: String, detail: String = ""):
	if condition:
		log_line("  PASS  %s %s" % [label, detail])
	else:
		_fail += 1
		log_line("  FAIL  %s %s" % [label, detail])


func _ready():
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	get_tree().create_timer(120.0, true, false, true).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	var booted = get_tree().current_scene
	if booted != null:
		booted.queue_free()
		await settle()
	await open_demo()
	await glances()
	planting()
	await talking_in_disguise()
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


func settle(frames: int = 3):
	for i in frames:
		await get_tree().process_frame


func open_demo():
	Campaign.reset()
	Campaign.current_map = DEMO
	scene = load("res://scenes/exploration.tscn").instantiate()
	get_tree().root.add_child(scene)
	await settle(4)
	watch = scene.stealth
	ok(watch != null, "the demo is watched")


func guard_named(name: String) -> Guard:
	for guard in watch.guards:
		if is_instance_valid(guard) and String(guard.name) == name:
			return guard
	return null


func glances():
	log_line("======== a guard at his post, glancing round ========")
	var sentry := guard_named("HallSentry")
	ok(sentry != null and sentry.patrol.is_empty(), "the hall sentry stands his post")
	ok(sentry != null and sentry.glance_every > 0.0, "and only glances round now and then")
	var east := guard_named("EastBarbarian")
	ok(east != null and east.patrol.is_empty() and east.glance_every > 0.0, "so does the guard at the east end")
	if sentry == null:
		return
	var tile_map: TileMap = scene._tile_map
	ok(scene.is_walkable(sentry.global_position), "the sentry is on floor", "%s" % tile_map.local_to_map(tile_map.to_local(sentry.global_position)))
	var rest: Vector2 = sentry._rest_facing
	sentry.glance_every = 0.4
	sentry.glance_seconds = 0.5
	sentry._glance_clock = 0.1
	var widest := 0.0
	var glanced := false
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 1200:
		await get_tree().process_frame
		if sentry.mood != Guard.Mood.PATROLLING:
			break
		glanced = glanced or sentry.glancing()
		widest = maxf(widest, absf(rad_to_deg(rest.angle_to(sentry.facing))))
	ok(glanced, "he glances away")
	ok(widest > 30.0, "far enough to matter", "%.0f degrees" % widest)
	sentry.glance_every = 60.0
	sentry._glance_left = 0.0
	sentry._glance_clock = 60.0
	start = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 1500:
		await get_tree().process_frame
	ok(absf(rad_to_deg(rest.angle_to(sentry.facing))) < 10.0, "and looks back the way he was", "%.0f degrees off" % rad_to_deg(rest.angle_to(sentry.facing)))


func planting():
	log_line("======== evidence planted, found, and the framed one marched off ========")
	var hall := guard_named("HallBarbarian")
	var sentry := guard_named("HallSentry")
	if hall == null or sentry == null:
		ok(false, "the hall barbarian and the sentry are there")
		return
	ok(watch.evidence_key() == "", "with nothing to plant, there is nothing to plant")
	ok(Campaign.give_item("cyrus", "stolen_signet"), "Cyrus has the Stolen Signet")
	ok(ItemDatabase.item("stolen_signet").stealth_only(), "only good for a stealth map")
	ok(watch.evidence_key() == "stolen_signet", "evidence in the bag")
	# Right behind the hall barbarian, where he cannot see.
	hall.active = false
	sentry.active = false
	var behind: Vector2 = hall.global_position - hall.facing.normalized() * Grid.TILE_SIZE
	scene.party.teleport(behind)
	ok(watch.unaware_beside(hall), "Cyrus behind the hall barbarian, unseen")
	ok(watch.pocket_target(hall) == null, "with nothing left to lift there")
	ok(watch.pick_pocket(hall), "the pick-pocket key plants it")
	ok(hall.framed and watch.evidence_key() == "", "on him now, and out of the bag")
	# The sentry has a good look at him.
	sentry.global_position = hall.global_position + Vector2(Grid.TILE_SIZE * 2, 0)
	sentry.facing = Vector2.LEFT
	watch._refresh_seen(sentry)
	var moved := false
	for i in 5:
		watch._check_framed(1.0)
		if hall.on_errand():
			moved = true
			break
	ok(moved, "the sentry finds it on him")
	ok(hall.mood == Guard.Mood.REPORTING and sentry.mood == Guard.Mood.REPORTING, "and marches him off - neither to be drawn aside")
	var id := watch._id_of(hall)
	watch._marched_off(hall)
	ok(not watch.guards.has(hall) and watch.marched_off(id), "the framed one is gone")
	var state: Dictionary = watch.snapshot(load("res://data/encounters/encounter_01_ambush.tres"))
	ok(state.get("framed_away", []).has(id), "and stays gone after a fight")


func talking_in_disguise():
	log_line("======== talking in disguise ========")
	var east := guard_named("EastBarbarian")
	if east == null:
		ok(false, "the east barbarian is there")
		return
	ok(east.small_talk != null and east.small_talk.get_cues().has("east_talk"), "the east barbarian has his own small talk")
	ok(not watch.send_away(5.0), "outside a conversation, nobody is sent anywhere")
	watch._talking_to = east
	ok(watch.send_away(5.0) and east.mood == Guard.Mood.REPORTING, "asked, he goes elsewhere")
	ok(east.errand_at().distance_to(east.global_position) > Grid.TILE_SIZE, "somewhere away from his post")
	ok(watch.tell_patrol("CorridorPriest") and watch.route_known(guard_named("CorridorPriest")), "he tells you another's round")
	var before: Array = Campaign.inventory_of("cyrus").duplicate()
	ok(watch.hand_over() and east.picked and Campaign.flag("east_keys"), "and hands over his keys")
	ok(Campaign.inventory_of("cyrus").count("cure_potion") > before.count("cure_potion"), "with what was in his pockets")
	ok(not watch.hand_over(), "once")
	watch._talking_to = null
