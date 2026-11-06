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
	# The designer's own (docs/sound_plan.md): what is heard as a blow lands, and as it is cast.
	var LANDING := {
		"weak_fire_damage": ["fire_burst", "flame_fan", "fire_blast", "kindled_bite", "burn_bottle", "flammable_limb", "trailblaze"],
		"medium_fire_damage": ["burner", "fire_breath", "flame_edge", "wildfire", "tartarus_flame", "stolen_sun"],
		"medium_water_damage": ["water_spike", "river_flow"],
		"weak_wind_damage": ["zephyr_dart", "wind_shot", "gust_blast", "wind_swoon", "wind_vacuum", "gale_bottle"],
		"heavy_electric_damage": ["lightning_bolt", "storm_cloud", "storm_edge", "lightning_breath", "ire_of_sophia", "gnostic_tempest"],
		"weak_idol_damage": ["votive_flame", "holy_splash", "holy_lance", "accusation", "holy_spear"],
		"medium_idol_damage": ["piercing_light", "censure", "judgement_hammer"],
		"heavy_idol_damage": ["judgment", "divine_verdict", "revelation"],
		"seismic_slam": ["ground_pound", "rockfall", "stone_edge"],
		"weak_ice_attack": ["frost_bottle", "frost_round"],
	}
	var CAST := {
		"cyrus_pistol": ["gun", "burning_shot", "combined_load", "corrosive_round", "frost_round", "poison_dart", "venom_fan", "warning_shot", "venomous_shot"],
		"rapier": ["rapier", "blink_strike", "follow_up_attack"],
		"medium_ice_attack": ["frost_edge", "frost_breath", "frozen_river"],
		"heavy_ice_attack": ["glacial_tide"],
		"weak_wind_damage": ["mist_step", "hermes_step", "hover", "growth"],
		"glitch_corrupted_data": ["instahack"],
		"flicking_through_pages": ["study"],
	}
	# Nothing new for these yet: they keep what they had.
	var STILL := {
		"Metal_Strike": ["greatsword_attack", "shield_bash", "sass_club", "sweep_strike", "chain_hook", "disarm"],
		"Debris_Scattering": ["tiny_bomb", "small_bomb", "medium_bomb", "big_bomb", "crystal_bottle", "caucasus_shard", "crystalise", "rock_throw"],
		"Small_Gun_Shot": ["nail_projectile"],
		"SciFi_Water": ["devour"],
	}
	var wrong := []
	for heard in LANDING:
		for key in LANDING[heard]:
			var sound: AudioStream = SkillDatabase.skills[key].impact_sound
			if sound == null or not sound.resource_path.get_file().begins_with(heard):
				wrong.append("%s lands as %s" % [key, sound.resource_path.get_file() if sound != null else "nothing"])
	for heard in CAST:
		for key in CAST[heard]:
			var sound: AudioStream = SkillDatabase.skills[key].sound
			if sound == null or not sound.resource_path.get_file().begins_with(heard):
				wrong.append("%s is cast as %s" % [key, sound.resource_path.get_file() if sound != null else "nothing"])
	for heard in STILL:
		for key in STILL[heard]:
			var sound: AudioStream = SkillDatabase.skills[key].sound
			if sound == null or not sound.resource_path.get_file().begins_with(heard):
				wrong.append("%s should still be %s" % [key, heard])
	ok(wrong.is_empty(), "every move makes the sound planned for it", "%s" % [wrong])
	log_line("")

	log_line("======== the sounds of everything else ========")
	var bank := GameSounds.bank()
	var empty := []
	for property in bank.get_property_list():
		if property.usage & PROPERTY_USAGE_STORAGE and property.type == TYPE_OBJECT and bank.get(property.name) == null:
			empty.append(property.name)
	ok(empty.is_empty(), "every slot in the bank is filled", "%s" % [empty])
	ok(bank.party_falls.resource_path.ends_with("flatline.wav") and bank.enemy_falls.resource_path.ends_with("enemy_die.wav") and bank.boss_falls.resource_path.ends_with("bass_tone_downer_reverb.wav"), "who falls sounds as planned")
	ok(bank.card_opening.resource_path.ends_with("bass_jump_start_drop.wav") and bank.card_victory.resource_path.ends_with("bass_drop_and_downer_fast.wav") and bank.card_defeat.resource_path.ends_with("bass_drop_and_downer_slow.wav"), "the title cards too")
	var glutton: CombatantDefinition = load("res://data/enemies/glutton.tres")
	ok(glutton.boss.reveal_sound.resource_path.ends_with("erysichthon_growl.wav") and glutton.boss.reveal_second_sound.resource_path.ends_with("eerie_revelation_2.wav"), "Erysichthon's reveal is his growl and the eerie revelation")
	ok(glutton.boss.phase_sound != null, "and he growls as a phase begins")
	var bellkeeper: CombatantDefinition = load("res://data/enemies/bellkeeper.tres")
	ok(bellkeeper.boss.reveal_sound.resource_path.ends_with("tiny_bells.wav"), "the Bellkeeper's is the bells")
	ok(load("res://data/conditions/burn.tres").tick_sound.resource_path.ends_with("weak_fire_damage.wav"), "Burn ticks as a small fire")
	var feedback: PictureFeedback = load("res://pictures/feedback.tres")
	ok(feedback.journal.resource_path.ends_with("glossary_page.wav") and feedback.solved.resource_path.ends_with("puzzle_success.wav") and feedback.deduction.resource_path.ends_with("eerie_revelation_1.wav"), "the pictures' slots have theirs")
	# Every button clicks, but one that says it should not.
	var button := Button.new()
	get_tree().root.add_child(button)
	await get_tree().process_frame
	GameSounds._last_at.clear()
	button.pressed.emit()
	ok(GameSounds.heard(&"menu_press"), "a button pressed clicks, wherever it is")
	var hushed := Button.new()
	GameSounds.quiet(hushed)
	get_tree().root.add_child(hushed)
	await get_tree().process_frame
	GameSounds._last_at.clear()
	hushed.pressed.emit()
	ok(not GameSounds.heard(&"menu_press"), "one that makes a sound of its own does not")
	button.queue_free()
	hushed.queue_free()
	# Once, however quickly it is asked for again; and a loop is one loop.
	GameSounds._last_at.clear()
	ok(GameSounds.play(&"coin") != null, "a sound plays")
	ok(GameSounds.play(&"coin") == null, "and asked for again at once, it is the one sound")
	GameSounds.loop(&"hack_clock")
	ok(GameSounds.looping() == &"hack_clock", "the clock loops")
	GameSounds.loop(&"hack_clock_urgent")
	ok(GameSounds.looping() == &"hack_clock_urgent", "and a new one takes its place")
	GameSounds.stop_loop()
	ok(GameSounds.looping() == &"", "and stops")
	var before: int = Campaign.gold
	GameSounds._last_at.clear()
	Campaign.give_gold(5)
	ok(GameSounds.heard(&"coin"), "gold found makes its sound", "%d -> %d" % [before, Campaign.gold])
	Campaign.reset()
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
	Campaign.current_encounter = load("res://data/encounters/encounter_01_ambush.tres")
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
	var second: SkillDefinition = SkillDatabase.skills["wildfire"]
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
	for path in ["res://data/encounters/encounter_01_ambush.tres",
			"res://data/encounters/encounter_02_sappers.tres",
			"res://data/encounters/encounter_03_watcher.tres"]:
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
