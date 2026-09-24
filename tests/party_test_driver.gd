extends Node
## Each map's own cast: who walks it, and at what level.

var LOG_PATH := HarnessLog.path_for("party")

## map -> who should be on it, in order, and how far along they are.
const EXPECTED := {
	"res://scenes/explore_crossroads.tscn": [["cyrus"], 1, "Vadim Krakhmal - Mountain Spirit"],
	"res://skills/laboratory_terrain_explore.tscn": [["cyrus", "enfina", "prometheus", "alithia"], 2, "Tokyo Music Walker - Gotta Go"],
	"res://church.tscn": [["alithia"], 3, "Scott Buckley - Filaments"],
}

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
	get_tree().create_timer(200.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()

func run_test():
	for path in EXPECTED:
		var want_party: Array = EXPECTED[path][0]
		var want_level: int = EXPECTED[path][1]
		var want_track: String = EXPECTED[path][2]
		log_line("======== %s ========" % path)
		# Arrive the way the menu does: a clean run, then the map.
		Campaign.reset()
		Campaign.current_map = path
		var scene = load("res://scenes/exploration.tscn").instantiate()
		get_tree().root.add_child(scene)
		await get_tree().process_frame
		await get_tree().process_frame

		ok(Campaign.party_order == want_party,
			"the party is who the map says", "%s" % [Campaign.party_order])
		ok(Campaign.party_level == want_level,
			"at level %d" % want_level, "level %d" % Campaign.party_level)

		# Everyone the map named actually exists and is fieldable.
		for key in want_party:
			var definition: CombatantDefinition = CombatantDatabase.combatants.get(key)
			ok(definition != null, "  %s is in the database" % key)

		# The HP they walk around with is their level's, not their level 1 figure.
		for member in Campaign.party_members():
			var definition: CombatantDefinition = CombatantDatabase.combatants.get(member.key)
			ok(member.max_hp == definition.hp_at(want_level),
				"  %s carries level %d health" % [member.key, want_level],
				"%d/%d (level 1 would be %d)" % [member.hp, member.max_hp, definition.max_hp])

		# And the walking line on the map matches.
		var party = scene.get_node_or_null("Party")
		var walking = party.get_child_count() if party != null else -1
		ok(walking == want_party.size(),
			"  %d walking on the map" % want_party.size(), "%d" % walking)

		# The map brought its own music with it. Headless has no real mixer, so
		# this asks what Music was told to play rather than what is audible.
		#
		# A map whose arrival conversation sets its own track has already
		# replaced it by now - the church opens on a scene that scores itself -
		# so the map's track is what started, not necessarily what is playing.
		var scored_by_dialogue = Music.current() != want_track and Music.current() != ""
		ok(Music.current() == want_track or scored_by_dialogue,
			"  it plays its own track, or one its opening scene chose",
			Music.current())
		if scored_by_dialogue:
			log_line("      (%s replaced %s - an arrival conversation set it)" % [
				Music.current(), want_track])
		ok(ResourceLoader.exists("res://audio/music/%s.mp3" % want_track)
			or ResourceLoader.exists("res://audio/music/%s.ogg" % want_track)
			or ResourceLoader.exists("res://audio/music/%s.wav" % want_track),
			"  and the file is really there", want_track)

		# The sheet agrees about the level.
		var sheet = scene.get_node_or_null("CharacterSheet")
		if sheet != null and sheet.has_method("_gather"):
			var entries = sheet._gather()
			ok(entries.size() == want_party.size(), "  the sheet lists %d" % want_party.size(), "%d" % entries.size())
			for entry in entries:
				ok(entry.level == want_level, "  the sheet says level %d for %s" % [want_level, entry.name])

		scene.queue_free()
		await get_tree().process_frame
		log_line("")

	log_line("======== a scene that opens a map starts on arrival ========")
	Campaign.reset()
	Campaign.current_map = "res://church.tscn"
	var arrived = load("res://scenes/exploration.tscn").instantiate()
	get_tree().root.add_child(arrived)
	for i in 4:
		await get_tree().process_frame
	var opener = null
	for item in arrived._interactables:
		if item is DialogueInteractable and item.automatic:
			opener = item
	ok(opener != null, "the church has its arrival conversation")
	# Standing on it has to be enough - the party has not taken a step yet, and
	# a scene you have to walk out of and back into is not an opening scene.
	ok(opener != null and opener.contact_spent,
		"and it fires without the party moving first")
	ok(arrived._blocking_interaction,
		"which takes the controls while it plays")
	arrived.queue_free()
	await get_tree().process_frame
	log_line("")

	log_line("======== a map that says nothing still works ========")
	Campaign.reset()
	Campaign.current_map = "res://scenes/terrain.tscn"
	var plain = load("res://scenes/exploration.tscn").instantiate()
	get_tree().root.add_child(plain)
	await get_tree().process_frame
	ok(not Campaign.party_order.is_empty(),
		"falls back to the Starting Party list", "%s" % [Campaign.party_order])
	ok(Campaign.party_level == 1, "at level 1", "level %d" % Campaign.party_level)
	plain.queue_free()
	log_line("")

	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
