extends Node
## Skill sounds fired by the skill database, and music driven from dialogue.

var LOG_PATH := HarnessLog.path_for("audio")

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


## A short silent tone, so playback can be exercised with no audio assets in
## the project. Looping is what the tests actually read off it.
func make_stream(seconds: float = 1.0) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 8000
	var frames = int(8000 * seconds)
	var data := PackedByteArray()
	data.resize(frames)
	stream.data = data
	return stream


func run_test():
	log_line("======== the mixer has somewhere to send each kind ========")
	var buses = []
	for i in AudioServer.bus_count:
		buses.append(AudioServer.get_bus_name(i))
	ok("Music" in buses, "there is a Music bus", "%s" % [buses])
	ok("SFX" in buses, "and an SFX bus")
	log_line("")

	log_line("======== every skill makes the right noise ========")
	# The rule, as given: by element, by the condition it inflicts, and two
	# named sets that sound like what they are rather than what they hit for -
	# guns bang, and bombs scatter debris even though they hit as physical.
	var GUNS := ["gun", "burning_shot", "poison_dart", "warning_shot", "nail_projectile", "venomous_shot"]
	var BOMBS := ["tiny_bomb", "small_bomb", "medium_bomb", "big_bomb"]
	var BY_ELEMENT := {
		Damage.Type.EARTH: "Debris_Scattering",
		Damage.Type.FIRE: "Gas_Fire_Swoosh",
		Damage.Type.PHYSICAL: "Metal_Strike",
		Damage.Type.WATER: "SciFi_Water",
		Damage.Type.WIND: "Wind_Howl",
	}
	var BY_CONDITION := {
		"Crystallised": "Debris_Scattering",
		"Burn": "Gas_Fire_Swoosh",
		"Frozen": "SciFi_Water",
		"Windswept": "Wind_Howl",
	}
	var silent := []
	for key in SkillDatabase.skills:
		var skill: SkillDefinition = SkillDatabase.skills[key]
		var wanted = ""
		if key in GUNS:
			wanted = "Small_Gun_Shot"
		elif key in BOMBS:
			wanted = "Debris_Scattering"
		else:
			for effect in skill.all_effects():
				if effect.type == EffectDefinition.EffectType.CONDITION and effect.condition != null:
					if BY_CONDITION.has(effect.condition.display_name):
						wanted = BY_CONDITION[effect.condition.display_name]
			if wanted == "" and skill.deals_damage and BY_ELEMENT.has(skill.damage_type):
				wanted = BY_ELEMENT[skill.damage_type]
		if wanted == "":
			if skill.sound == null:
				silent.append(skill.name)
			continue
		var heard = skill.sound.resource_path.get_file() if skill.sound != null else "nothing"
		ok(skill.sound != null and heard.begins_with(wanted),
			"%s (%s) plays %s" % [skill.name, key, wanted], heard)
	log_line("  NOTE  no rule covers these, so they are silent: %s" % [silent])
	log_line("")

	log_line("======== a skill can name its own sound ========")
	var melee: SkillDefinition = SkillDatabase.skills["greatsword_attack"]
	ok("sound" in melee, "skills have a sound field")
	ok("sound_volume_db" in melee, "and a per-skill trim")
	# A skill nobody has given a noise to, found rather than assumed: skills have
	# real sounds now, and which ones do is content.
	var quiet: SkillDefinition = null
	for key in SkillDatabase.skills:
		if SkillDatabase.skills[key].sound == null:
			quiet = SkillDatabase.skills[key]
			break
	ok(quiet != null, "a skill with no sound of its own still works", quiet.name if quiet else "none")
	log_line("")

	Campaign.reset()
	Campaign.current_encounter = load("res://encounters/encounter_01_ambush.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	var combat = game.get_node("VisualCombat")
	combat.finish_deployment()
	await get_tree().process_frame

	log_line("======== a silent skill plays nothing ========")
	combat.play_skill_sound(quiet)
	var playing = 0
	for player in combat._sound_players:
		if player.playing:
			playing += 1
	ok(playing == 0, "no voice was spent on a skill with no sound", "%d playing" % playing)
	ok(combat.play_skill_sound(null) == null, "and a null skill is harmless")
	log_line("")

	log_line("======== a skill with a sound plays it ========")
	melee.sound = make_stream()
	melee.sound_volume_db = -6.0
	combat.play_skill_sound(melee)
	var heard = null
	for player in combat._sound_players:
		if player.playing:
			heard = player
	ok(heard != null, "a voice picked it up")
	if heard != null:
		ok(heard.stream == melee.sound, "playing the skill's own stream")
		ok(is_equal_approx(heard.volume_db, -6.0), "at the skill's trim", "%s dB" % heard.volume_db)
		ok(heard.bus == "SFX", "on the SFX bus", heard.bus)
	log_line("")

	log_line("======== overlapping sounds do not cut each other ========")
	var second: SkillDefinition = SkillDatabase.skills["fireball"]
	second.sound = make_stream()
	combat.play_skill_sound(second)
	var both = 0
	for player in combat._sound_players:
		if player.playing:
			both += 1
	ok(both >= 2, "two skills close together both sound", "%d voices busy" % both)
	ok(combat._sound_players.size() == Combat.SOUND_VOICES, "there are %d voices" % Combat.SOUND_VOICES)
	melee.sound = null
	second.sound = null
	log_line("")

	log_line("======== music is reachable from dialogue ========")
	var shortcuts = ProjectSettings.get_setting("dialogue_manager/runtime/state_autoload_shortcuts")
	ok("Music" in shortcuts, "Music is a dialogue autoload shortcut, so `do Music.play(...)` works",
		"%s" % [shortcuts])
	ok(Music != null, "and it is an autoload")
	for method in ["play", "stop", "pause", "resume", "set_looping", "fade_out", "is_playing", "current"]:
		ok(Music.has_method(method), "Music.%s() exists" % method)
	log_line("")

	log_line("======== music that does not exist yet is survivable ========")
	# From silence, so what is being measured is the missing track rather than
	# whatever the last encounter left playing.
	Music.stop()
	Music.play("no_such_track")
	ok(not Music.is_playing(), "a missing track leaves it silent rather than erroring")
	ok(Music.current() == "", "and nothing is remembered as current", "'%s'" % Music.current())
	log_line("")

	log_line("======== playing, pausing, resuming, looping ========")
	# Driven with a stream directly, since there is no music in the project yet.
	Music._current = "test"
	Music._player.stream = Music._with_loop(make_stream(2.0), true)
	Music._player.play()
	ok(Music.is_playing(), "it plays")
	ok(Music.current() == "test", "and reports what is on", Music.current())
	Music.pause()
	ok(not Music.is_playing(), "pause stops it counting as playing")
	ok(Music._player.stream_paused, "by holding it rather than stopping it")
	Music.resume()
	ok(Music.is_playing(), "resume picks it back up")
	ok(Music._player.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "and it is looping",
		"%s" % Music._player.stream.loop_mode)
	Music.set_looping(false)
	ok(Music._player.stream.loop_mode == AudioStreamWAV.LOOP_DISABLED, "looping can be turned off")
	Music.stop()
	ok(not Music.is_playing(), "stop stops it")
	ok(Music.current() == "", "and forgets the track, so playing it again restarts it")
	log_line("")

	log_line("======== looping is set on a copy, not the shared file ========")
	var shared = make_stream()
	var looped = Music._with_loop(shared, true)
	ok(looped != shared, "the stream is copied before its loop flag is set")
	ok(shared.loop_mode == AudioStreamWAV.LOOP_DISABLED,
		"so the original is untouched and other uses of it are unaffected")
	log_line("")

	log_line("======== a looping track has something to loop ========")
	# Headless cannot hear, so this checks the rule rather than the sound: a
	# WAV set to loop with loop_end at or before loop_begin has a loop region of
	# no length, and plays silence. Every encounter track is a WAV, and all
	# three were silent until this was fixed.
	for path in ["res://encounters/encounter_01_ambush.tres",
			"res://encounters/encounter_02_sappers.tres",
			"res://encounters/encounter_03_watcher.tres"]:
		var encounter: EncounterDefinition = load(path)
		if encounter.music == "":
			continue
		var raw = Music._load(encounter.music)
		ok(raw != null, "%s's track loads" % encounter.display_name, encounter.music)
		if raw == null:
			continue
		var for_loop = Music._with_loop(raw, true)
		if for_loop is AudioStreamWAV:
			ok(for_loop.loop_mode == AudioStreamWAV.LOOP_FORWARD,
				"  and is set to loop")
			ok(for_loop.loop_end > for_loop.loop_begin,
				"  over a region with length in it",
				"%d..%d of %.0f frames" % [for_loop.loop_begin, for_loop.loop_end,
					for_loop.get_length() * for_loop.mix_rate])
		else:
			ok(for_loop.get("loop") == true, "  and is set to loop", for_loop.get_class())
	log_line("")

	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
