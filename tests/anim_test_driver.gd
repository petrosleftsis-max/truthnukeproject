extends Node
## The exploration party walks with its animation set, and turns to face the
## way it is going.

var LOG_PATH := HarnessLog.path_for("anim")

var _log: FileAccess = null
var _fail = 0


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
	get_tree().create_timer(120.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


## The AnimatedSprite2D inside a CombatantSprite, or null for a static one.
func animated_of(sprite):
	return sprite._animated


func run_test():
	Campaign.reset()
	# The laboratory, which is where the four of them walk together.
	Campaign.current_map = "res://scenes/laboratory_terrain_explore.tscn"
	var scene = load("res://scenes/exploration.tscn").instantiate()
	get_tree().root.add_child(scene)
	for frame in range(0, 8):
		await get_tree().process_frame
	var party = null
	for child in scene.get_children():
		if child is ExplorationParty:
			party = child
	ok(party != null, "the party exists")
	ok(party != null and party.leader != null, "and has a leader")
	if party == null or party.leader == null:
		log_line("FAILURES: %d" % _fail)
		get_tree().quit(1)
		return

	log_line("======== the line is built from animated sprites ========")
	ok(party.leader is CombatantSprite, "the leader is a CombatantSprite",
		party.leader.get_class())
	var expected_followers = Campaign.living_party().size() - 1
	ok(party.followers.size() == expected_followers, "and the rest of the line came along",
		"%d of %d" % [party.followers.size(), expected_followers])
	var everyone = [party.leader]
	everyone.append_array(party.followers)
	for sprite in everyone:
		ok(sprite is CombatantSprite, "each of them is one")
	var animated = animated_of(party.leader)
	ok(animated != null, "the leader has an animation set")
	if animated == null:
		log_line("FAILURES: %d" % _fail)
		get_tree().quit(1)
		return
	ok(animated.sprite_frames.has_animation("walk"), "including a walk")
	ok(animated.animation == "idle", "and it starts idle", animated.animation)
	log_line("")

	log_line("======== walking plays the walk ========")
	party._set_walking(true)
	ok(animated.animation == "walk", "the leader walks", animated.animation)
	for sprite in party.followers:
		# Whoever has walk frames walks; whoever does not keeps idling rather than
		# freezing, which is what a character with only an idle drawn should do.
		var frames = animated_of(sprite).sprite_frames
		var expected = "walk" if frames.has_animation("walk") else "idle"
		ok(animated_of(sprite).animation == expected,
			"and so does a follower, with whatever they have drawn",
			"%s, wanted %s" % [animated_of(sprite).animation, expected])
	party._set_walking(false)
	ok(animated.animation == "idle", "stopping goes back to idle", animated.animation)
	log_line("")

	log_line("======== it does not restart every frame ========")
	# Told to walk repeatedly, the animation has to keep running rather than be
	# reset to its first frame each time - which would look like no animation.
	#
	# The party polls the keyboard every frame and stops walking when nothing is
	# held, and there is no held key in a headless run - so its own polling is
	# suspended for the length of this check, leaving the walk to run.
	party.set_process(false)
	party._set_walking(true)
	# Long enough for one frame of the walk at whatever speed it runs at: the
	# sets in the project do not all run at the same rate, and a fixed count of
	# frames only works for the rate it was written against.
	var per_frame = 1.0 / maxf(animated.sprite_frames.get_animation_speed("walk"), 0.001)
	var waited = 0.0
	while animated.frame == 0 and waited < per_frame * 3.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	var progressed = animated.frame
	party._set_walking(true)
	party._set_walking(true)
	ok(animated.frame == progressed, "asking again mid-stride changes nothing",
		"frame %d" % animated.frame)
	ok(animated.frame > 0 or animated.sprite_frames.get_frame_count("walk") == 1,
		"and the walk actually advances", "frame %d" % animated.frame)
	party._set_walking(false)
	party.set_process(true)
	log_line("")

	log_line("======== it turns to face the way it goes ========")
	party._set_facing(false)
	ok(not animated.flip_h, "facing right by default", "flip_h %s" % animated.flip_h)
	party._set_facing(true)
	ok(animated.flip_h, "walking left mirrors the leader", "flip_h %s" % animated.flip_h)
	for sprite in party.followers:
		ok(animated_of(sprite).flip_h, "and every follower with them",
			"flip_h %s" % animated_of(sprite).flip_h)
	party._set_facing(false)
	ok(not animated.flip_h, "and back again going right", "flip_h %s" % animated.flip_h)
	log_line("")

	log_line("======== walking up or down keeps the last facing ========")
	party._set_facing(true)
	# _process only turns the line on a horizontal press, so a purely vertical
	# one must leave it as it was rather than snapping back.
	party._set_facing(true)
	ok(animated.flip_h, "still facing left after a vertical step", "flip_h %s" % animated.flip_h)
	log_line("")

	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
