extends Node
## The track an encounter opens on, chosen in the encounter editor.

var LOG_PATH := HarnessLog.path_for("encmusic")

## Somewhere to put a track that really loads, since the project has no music
## files yet. A full res:// path is one of the two things the field accepts.
const TRACK_PATH = "user://test_track.tres"

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
	get_tree().create_timer(180.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


func make_stream(seconds: float = 2.0) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 8000
	var data := PackedByteArray()
	data.resize(int(8000 * seconds))
	stream.data = data
	return stream


## Boots a battle the way the level select does, and hands back its Combat.
func start_battle(encounter: EncounterDefinition) -> Node:
	Campaign.reset()
	Campaign.current_encounter = encounter
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	return game



## Every file under `root` with one of `extensions`, recursively.
func files_under(root: String, extensions: Array) -> Array:
	var found: Array = []
	var dir = DirAccess.open(root)
	if dir == null:
		return found
	dir.list_dir_begin()
	var name = dir.get_next()
	while name != "":
		var path = root.path_join(name)
		if dir.current_is_dir():
			if not name.begins_with("."):
				found.append_array(files_under(path, extensions))
		elif name.get_extension() in extensions:
			found.append(path)
		name = dir.get_next()
	dir.list_dir_end()
	return found

func run_test():
	log_line("======== an encounter can name its own track ========")
	var encounter: EncounterDefinition = load("res://encounters/encounter_01_ambush.tres")
	ok("music" in encounter, "encounters have a music field")
	# Whatever it is set to is content; that the field exists and is a track name
	# is what matters here.
	ok(encounter.music == "" or Music._load(encounter.music) != null,
		"names a track that exists, or none at all", "'%s'" % encounter.music)
	var shipped_with_music = []
	for path in DirAccess.get_files_at("res://encounters"):
		if not path.ends_with(".tres"):
			continue
		var other: EncounterDefinition = load("res://encounters/%s" % path)
		if other.music != "":
			shipped_with_music.append("%s -> %s" % [path, other.music])
	log_line("  NOTE  encounters that set one: %s" % [shipped_with_music])
	log_line("")

	ResourceSaver.save(make_stream(), TRACK_PATH)
	ok(ResourceLoader.exists(TRACK_PATH), "the test has a track that really loads")
	log_line("")

	log_line("======== an encounter with no music leaves the music alone ========")
	# Something already playing, as if walked in from a scene that set it.
	Music._current = "overworld"
	Music._player.stream = Music._with_loop(make_stream(), true)
	Music._player.play()
	ok(Music.is_playing(), "music is playing before the fight starts")
	var before = Music._player.stream
	encounter.music = ""
	var game = await start_battle(encounter)
	ok(Music.current() == "overworld", "the fight did not touch it", "'%s'" % Music.current())
	ok(Music._player.stream == before, "the same stream is still on")
	# `playing` itself is no use as an assertion here - see below - but stopping
	# or pausing the music would have shown up in the two checks above and this
	# one, all of which stop() and pause() would have changed.
	ok(not Music._player.stream_paused, "and nothing paused it either")
	game.queue_free()
	await get_tree().process_frame
	log_line("")

	log_line("======== an encounter with music starts it ========")
	Music.stop()
	encounter.music = TRACK_PATH
	game = await start_battle(encounter)
	ok(Music.current() == TRACK_PATH, "the encounter's track is the one on", "'%s'" % Music.current())
	ok(Music._player.stream != null and not Music._player.stream_paused,
		"with a stream loaded and running")
	ok(Music._player.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD,
		"looping, since a fight outlasts one pass of the track")
	log_line("")

	log_line("======== the next fight on the same track does not restart it ========")
	# Checked here rather than off the mixer: headless has no audio device, so
	# `playing` and the playback position wander on their own. What is worth
	# testing is the rule - asking for the track that is already on changes
	# nothing - and that is decided in Music.play, before any of it reaches the
	# audio thread.
	var playing_stream = Music._player.stream
	# Nailing playback down first, for the same reason.
	Music._player.play()
	Music.play(TRACK_PATH)
	ok(Music._player.stream == playing_stream,
		"asking for the track already on leaves the very same stream in place")
	game.queue_free()
	await get_tree().process_frame
	game = await start_battle(encounter)
	ok(Music.current() == TRACK_PATH, "and the second fight is still on it", "'%s'" % Music.current())
	game.queue_free()
	await get_tree().process_frame
	log_line("")

	log_line("======== a track that isn't there doesn't take the fight down ========")
	Music.stop()
	encounter.music = "no_such_track"
	game = await start_battle(encounter)
	var combat = game.get_node("VisualCombat")
	combat.finish_deployment()
	await get_tree().process_frame
	ok(is_instance_valid(game), "the battle still built")
	ok(combat.combatants.size() > 0, "with its combatants placed", "%d" % combat.combatants.size())
	ok(not Music.is_playing(), "just without music")
	game.queue_free()
	await get_tree().process_frame
	encounter.music = ""
	log_line("")

	log_line("======== the editor says so before the fight ever runs ========")
	var editor = EncounterEditor.new()
	ok(not editor._music_exists("no_such_track"), "a name with no file behind it is flagged")
	ok(editor._music_exists(TRACK_PATH), "a real path is not")
	ok(Music._load("no_such_track") == null,
		"and it agrees with Music about what is missing")
	var complaint = ""
	editor.encounter = load("res://encounters/encounter_01_ambush.tres")
	editor.encounter.music = "no_such_track"
	for problem in editor._problems_with_layout():
		if "Music" in problem:
			complaint = problem
	ok(complaint != "", "so the status line complains rather than saving it quietly", complaint)
	editor.encounter.music = ""
	ok(not ("Music" in "\n".join(editor._problems_with_layout())),
		"and says nothing about an encounter that sets no track")
	editor.free()
	log_line("")

	log_line("======== nothing plays a track the web build leaves behind ========")
	# Music is looked up by name at run time, so a dialogue naming a track that
	# the export filter drops is silent in the browser and says nothing about it
	# anywhere. This is the only place that would notice.
	var excluded := []
	var presets = FileAccess.get_file_as_string("res://export_presets.cfg")
	if presets == "":
		log_line("  (no export_presets.cfg here - it is gitignored, so this only runs locally)")
	else:
		for line in presets.split("
"):
			if not line.begins_with("exclude_filter="):
				continue
			for entry in line.split(","):
				var trimmed = entry.strip_edges().trim_prefix("exclude_filter=\"").trim_suffix("\"")
				if trimmed.begins_with("audio/music/"):
					excluded.append(trimmed.get_file().get_basename())
		var named := {}
		var dir = DirAccess.open("res://Dialogue")
		for file in dir.get_files():
			if not file.ends_with(".dialogue"):
				continue
			var text = FileAccess.get_file_as_string("res://Dialogue/".path_join(file))
			for piece in text.split("Music.play(\""):
				if piece == text:
					continue
				var track = piece.split("\"")[0]
				if track != "":
					named[track] = file
		for path in files_under("res://encounters", ["tres"]):
			var fight: EncounterDefinition = load(path)
			if fight != null and fight.music != "":
				named[fight.music] = path.get_file()
		var silenced := []
		for track in named:
			if track in excluded:
				silenced.append("%s, played by %s" % [track, named[track]])
		ok(silenced.is_empty(),
			"every track something names is in the web build", "%s" % [silenced])
	log_line("")

	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
