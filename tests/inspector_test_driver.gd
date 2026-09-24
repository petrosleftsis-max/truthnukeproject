extends Node
## The reorganisation hides inspector fields that the selected effect type
## doesn't use. Hiding must never mean losing: these check that a hidden
## value still saves, still reloads, and comes straight back if the type is
## switched back.

var LOG_PATH := HarnessLog.path_for("inspector")
const SCRATCH = "user://roundtrip.tres"

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
	# A script error aborts run_test but leaves the game running, so without
	# this the suite just hangs until the harness kills it.
	get_tree().create_timer(60.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	run_test()


## Which properties the inspector would actually draw for this resource.
func visible_fields(res: Object) -> Array:
	var shown = []
	for property in res.get_property_list():
		if property.usage & PROPERTY_USAGE_EDITOR:
			shown.append(property.name)
	return shown


func run_test():
	log_line("======== an effect only shows the fields its type uses ========")
	var effect = EffectDefinition.new()
	effect.type = EffectDefinition.EffectType.DAMAGE
	var damage_fields = visible_fields(effect)
	ok("damage_type" in damage_fields, "DAMAGE shows damage_type")
	ok("min_amount" in damage_fields, "DAMAGE shows min_amount")
	ok(not ("knockback_distance" in damage_fields), "DAMAGE hides knockback_distance")
	ok(not ("dispel_scope" in damage_fields), "DAMAGE hides dispel_scope")
	ok(not ("condition" in damage_fields), "DAMAGE hides condition")
	ok(not ("stat_multiplier" in damage_fields), "DAMAGE hides stat_multiplier")

	effect.type = EffectDefinition.EffectType.CONDITION
	var condition_fields = visible_fields(effect)
	ok("condition" in condition_fields, "switching to CONDITION reveals condition")
	ok(not ("min_amount" in condition_fields), "and hides the damage numbers")

	effect.type = EffectDefinition.EffectType.PUSH
	var push_fields = visible_fields(effect)
	ok("knockback_distance" in push_fields, "PUSH shows knockback_distance")
	ok("min_amount" in push_fields, "and its collision damage", "which PULL doesn't")
	effect.type = EffectDefinition.EffectType.PULL
	ok(not ("min_amount" in visible_fields(effect)), "PULL hides the damage numbers")
	log_line("")

	log_line("======== hidden is not lost ========")
	var kept = EffectDefinition.new()
	kept.type = EffectDefinition.EffectType.DAMAGE_OVER_TIME
	kept.min_amount = 7
	kept.max_amount = 9
	kept.duration = 5
	# Now set something the DoT type hides, and switch away and back.
	kept.knockback_distance = 4
	kept.dispel_stat = "movement"
	ok(not ("knockback_distance" in visible_fields(kept)), "knockback is hidden on a DoT")
	ok(kept.knockback_distance == 4, "but the value is still there", "%d" % kept.knockback_distance)
	kept.type = EffectDefinition.EffectType.PUSH
	ok("knockback_distance" in visible_fields(kept), "switching to PUSH shows it again")
	ok(kept.knockback_distance == 4, "with the value intact", "%d" % kept.knockback_distance)
	kept.type = EffectDefinition.EffectType.DAMAGE_OVER_TIME
	log_line("")

	log_line("======== and it survives being saved and reloaded ========")
	var skill = SkillDefinition.new()
	skill.name = "Round Trip"
	var one: Array[EffectDefinition] = [kept]
	skill.effects = one
	var err = ResourceSaver.save(skill, SCRATCH)
	ok(err == OK, "the skill saves", "err=%d" % err)
	var reloaded = ResourceLoader.load(SCRATCH, "", ResourceLoader.CACHE_MODE_IGNORE)
	ok(reloaded != null, "and loads back")
	if reloaded != null and reloaded.effects.size() > 0:
		var back = reloaded.effects[0]
		ok(back.min_amount == 7 and back.max_amount == 9, "visible values round-trip", "%d-%d" % [back.min_amount, back.max_amount])
		ok(back.duration == 5, "so does duration", "%d" % back.duration)
		ok(back.knockback_distance == 4, "and so does the HIDDEN knockback", "%d" % back.knockback_distance)
		ok(back.dispel_stat == "movement", "and the hidden dispel_stat", "'%s'" % back.dispel_stat)
	else:
		ok(false, "the reloaded skill has its effect")
	log_line("")

	log_line("======== a single-target skill isn't asked about beam widths ========")
	var single = SkillDefinition.new()
	single.aoe_radius = 0
	var single_fields = visible_fields(single)
	ok(not ("aoe_shape" in single_fields), "aoe_shape hidden with no area")
	ok(not ("aoe_width" in single_fields), "aoe_width hidden with no area")
	single.aoe_radius = 3
	ok("aoe_shape" in visible_fields(single), "giving it a radius reveals the shape")
	ok(not ("aoe_width" in visible_fields(single)), "but width stays hidden on a DIAMOND")
	single.aoe_shape = SkillDefinition.AoEShape.LINE
	ok("aoe_width" in visible_fields(single), "and appears for a LINE")
	log_line("")

	log_line("======== effects is no longer buried in Area of Effect ========")
	# The group a property belongs to is whatever @export_group preceded it,
	# so the check is positional: effects must come before the AoE group.
	var seen_aoe_group = false
	var effects_after_group = false
	for property in SkillDefinition.new().get_property_list():
		if property.usage & PROPERTY_USAGE_GROUP and property.name == "Area of Effect":
			seen_aoe_group = true
		if property.name == "effects" and seen_aoe_group:
			effects_after_group = true
	ok(not effects_after_group, "effects sits at the top level, not inside the AoE group")
	log_line("")

	log_line("======== every skill is its own file ========")
	# Items are registered in the same lookup so every path that resolves a key
	# handles them too, but they live in res://items - one folder per kind of
	# thing, so the editor's file list is readable.
	var missing = []
	for key in SkillDatabase.skills.keys():
		var folder = "items" if ItemDatabase.is_item(key) else "skills"
		if not ResourceLoader.exists("res://%s/%s.tres" % [folder, key]):
			missing.append(key)
	ok(missing.is_empty(), "all %d skills and items have a file of their own" % SkillDatabase.skills.size(), str(missing))
	for key in SkillDatabase.skills.keys():
		# By the path the database itself holds rather than one built from the key:
		# a key does not have to match its filename, and on Windows a case
		# difference loads the same file as a second, separate resource.
		var registered: SkillDefinition = SkillDatabase.skills[key]
		var from_file = load(registered.resource_path) if registered.resource_path != "" else registered
		if from_file != registered:
			ok(false, "%s in the database is the same object as its file" % key,
				registered.resource_path)
			break
	log_line("")

	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
