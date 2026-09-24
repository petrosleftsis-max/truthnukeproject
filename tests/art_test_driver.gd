extends Node
## Who wears what: every combatant's own artwork, and animations that resolve.

var LOG_PATH := HarnessLog.path_for("art")

## The characters art has actually been drawn for. Everyone else is still
## wearing Cyrus's, which is a fact worth reporting rather than failing on.
const DRAWN := ["cyrus", "enfina", "alithia", "prometheus"]

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


func run_test():
	log_line("======== everyone drawn wears their own art ========")
	var seen := {}
	for key in DRAWN:
		var definition: CombatantDefinition = CombatantDatabase.combatants.get(key)
		ok(definition != null, "%s is in the database" % key)
		if definition == null:
			continue
		ok(definition.sprite_frames != null, "%s has an animation set" % key)
		ok(definition.icon != null and definition.map_sprite != null, "%s has a portrait and a map sprite" % key)
		if definition.sprite_frames != null:
			var path = definition.sprite_frames.resource_path
			ok(path.contains(key), "%s's animations are their own" % key, path)
			ok(not seen.has(path), "and nobody else is wearing them", path)
			seen[path] = key
		if definition.icon != null:
			ok(definition.icon.resource_path.contains(key), "%s's still is their own" % key,
				definition.icon.resource_path)
	log_line("")

	log_line("======== nobody wears somebody else's face ========")
	var faces := {}
	for key in CombatantDatabase.combatants:
		var definition: CombatantDefinition = CombatantDatabase.combatants[key]
		var face = definition.portrait()
		ok(face != null, "%s has a portrait" % key)
		if face == null:
			continue
		# A portrait taken from their own animation cannot be anyone else's; one
		# set by hand can be, and that is the case worth catching.
		if definition.sprite_frames != null and definition.icon == null:
			ok(face == definition.first_frame(),
				"%s's portrait is the first frame of their own animation" % key)
		var path = face.resource_path
		if path != "":
			if faces.has(path):
				log_line("  NOTE  %s and %s share a portrait: %s" % [key, faces[path], path])
			else:
				faces[path] = key
	log_line("")

	log_line("======== the animations combat asks for are there ========")
	for key in DRAWN:
		var definition: CombatantDefinition = CombatantDatabase.combatants.get(key)
		if definition == null or definition.sprite_frames == null:
			continue
		var frames: SpriteFrames = definition.sprite_frames
		var has := []
		for anim in frames.get_animation_names():
			has.append("%s x%d" % [anim, frames.get_frame_count(anim)])
		ok(frames.has_animation("idle") and frames.get_frame_count("idle") > 0,
			"%s has an idle to stand in" % key, "%s" % [has])
		# Every frame has to load, or the character flickers through gaps.
		for anim in frames.get_animation_names():
			var blank = 0
			for i in frames.get_frame_count(anim):
				if frames.get_frame_texture(anim, i) == null:
					blank += 1
			ok(blank == 0, "%s's %s has no missing frames" % [key, anim], "%d blank" % blank)
		ok(frames.get_animation_loop("idle"), "%s's idle loops" % key)
		if frames.has_animation("walk"):
			ok(frames.get_animation_loop("walk"), "%s's walk loops" % key)
		if frames.has_animation("attack"):
			ok(not frames.get_animation_loop("attack"), "%s's attack plays once" % key)
	log_line("")

	log_line("======== a sprite built from it shows the right thing ========")
	for key in DRAWN:
		var definition: CombatantDefinition = CombatantDatabase.combatants.get(key)
		if definition == null:
			continue
		var sprite = CombatantSprite.new()
		add_child(sprite)
		sprite.setup(definition.sprite_frames, definition.map_sprite, false)
		await get_tree().process_frame
		var animated: AnimatedSprite2D = null
		for child in sprite.get_children():
			if child is AnimatedSprite2D:
				animated = child
		ok(animated != null, "%s is drawn as an animation, not a still" % key)
		if animated != null:
			ok(animated.animation == "idle", "%s starts idling" % key, animated.animation)
			sprite.play_walk()
			var expected = "walk" if definition.sprite_frames.has_animation("walk") else "idle"
			ok(animated.animation == expected, "%s walks with what they have" % key, animated.animation)
		sprite.queue_free()
	log_line("")

	log_line("======== everyone else, still borrowing ========")
	var borrowed := []
	for key in CombatantDatabase.combatants:
		if key in DRAWN:
			continue
		var definition: CombatantDefinition = CombatantDatabase.combatants[key]
		if definition.sprite_frames != null and definition.sprite_frames.resource_path.contains("cyrus"):
			borrowed.append(key)
	log_line("  NOTE  wearing Cyrus's art until their own is drawn: %s" % [borrowed])
	ok(true, "which is not a failure, just what is left to draw")
	log_line("")

	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
