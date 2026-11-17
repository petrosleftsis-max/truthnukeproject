extends Node
## Background music, driven from the dialogue you write.
##
## Registered as a Dialogue Manager state autoload, so a .dialogue file can
## steer it directly with `do` lines, next to the scene they belong to:
##
##     ~ village_gate
##     do Music.play("village")
##     Guard: You'll want to speak to the smith.
##     do Music.pause()
##     Guard: [#worried] ...did you hear that?
##     do Music.resume()
##     do Music.play("battle", false)     # once, no loop
##     do Music.fade_out(2.0)
##     do Music.stop()
##
## Tracks are named, not paths: play("village") finds audio/music/village.ogg.
## A full res:// path works too, for anything kept somewhere else.
##
## An autoload because music is the one thing that should survive a scene
## change - walking from the map into a battle should not restart the score.
## Nothing here fails on a missing track; it warns and carries on, so dialogue
## written ahead of the audio still runs.

const MUSIC_DIR = "res://audio/music"

## Fallbacks tried in order, so a track can be an .ogg, an .mp3 or a .wav
## without the dialogue having to say which.
const EXTENSIONS = ["ogg", "mp3", "wav"]

var _player: AudioStreamPlayer = null
## What is loaded right now, so play() on the track already playing is a no-op
## rather than a restart - dialogue often re-states the music for a scene that
## can be entered from several directions.
var _current := ""
var _fade: Tween = null


func _ready():
	_ensure_player()
	# The sound that follows the picture: muffled, giving way, echoing by place (SoundFollows).
	var follows := SoundFollows.new()
	follows.name = "SoundFollows"
	add_child(follows)


## Builds the player if it is not there yet.
##
## Called from _ready and from everything that touches the player, because
## _ready is not early enough: a scene's _enter_tree runs before it, and
## GameScene asks for its encounter's music from exactly there. Without this
## the first track of a battle opened as the main scene was assigned to
## nothing and the fight was silent.
func _ensure_player():
	if _player != null and is_instance_valid(_player):
		return
	# Music outlives scene changes, and should keep playing through a pause.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.bus = "Music"
	add_child(_player)
	_load_settings()
	for which in BUSES:
		_apply(which)


## Starts `track`, or does nothing if it is already the one playing.
##
## `loop` is true by default, which is what background music almost always
## wants; pass false for a sting that should play once and stop.
func play(track: String, loop: bool = true):
	_ensure_player()
	if track == "":
		return
	Net.music_did("play", [track, loop])
	if track == _current and _player.playing:
		return
	var stream = _load(track)
	if stream == null:
		push_warning("Music.play('%s'): no such track in %s - carrying on in silence." % [track, MUSIC_DIR])
		return
	_cancel_fade()
	_current = track
	_player.volume_db = 0.0
	_player.stream = _with_loop(stream, loop)
	_player.play()
	# Its parts, if it has any, in step under it (Music in layers).
	_start_parts(track, loop)


## Stops and forgets the current track, so a later play() of the same one
## starts it again rather than treating it as already playing.
func stop():
	_ensure_player()
	Net.music_did("stop", [])
	_cancel_fade()
	_player.stop()
	_current = ""
	_start_parts("", false)


## --- Music in layers ---
##
## The proposals of 2026-11-17, section 9 (the designer: "From section 4 and on do all"). A track may come in parts, the designer's:
## beside "village" (calm: the track itself), "village_wary" and "village_fighting" in audio/music, the same length and tempo, played
## in step under it. They come in and go out with how things stand - calm; a watched map Wary (wary); Alarmed, or in a fight (wary
## and fighting) - rather than one track switched for another. In a fight the music turns with it: the other side's last leader
## felled with others still standing, it swells a while (swell); the party down to one, it thins to its fighting part alone (thin).
## A track with no parts beside it plays as it always has, and none of this touches it. PROPOSAL.
const PARTS := ["wary", "fighting"]
const PART_FADE := 1.6
const PART_OUT_DB := -60.0
const SWELL_DB := 3.0
const SWELL_SECONDS := 8.0
const THIN_DB := -30.0
var _parts := {}
var _thin := false
var _swell_until := 0.0


## The parts of `track` beside it, started in step with it; "" puts any away.
func _start_parts(track: String, loop: bool):
	for part in _parts.values():
		if is_instance_valid(part):
			part.queue_free()
	_parts.clear()
	_thin = false
	_swell_until = 0.0
	if track == "" or track.begins_with("res://") or track.begins_with("user://"):
		return
	for part_name in PARTS:
		var stream := _load("%s_%s" % [track, part_name])
		if stream == null:
			continue
		var part := AudioStreamPlayer.new()
		part.name = "Part_" + part_name
		part.bus = "Music"
		part.volume_db = PART_OUT_DB
		part.stream = _with_loop(stream, loop)
		add_child(part)
		part.play(_player.get_playback_position())
		_parts[part_name] = part


## The parts this track has, for a suite.
func parts() -> Array:
	return _parts.keys()


## How things stand for the parts: 0 calm, 1 wary, 2 fighting.
func standing_now() -> int:
	var scene := get_tree().current_scene if get_tree() != null else null
	var fight = scene.get("combat") if scene != null else null
	if fight is Combat and not fight.combat_over:
		return 2
	var watch = Campaign.get("stealth_watch")
	if watch != null and is_instance_valid(watch) and "alert" in watch:
		if watch.alert >= StealthWatch.ALERT_ALARMED:
			return 2
		if watch.alert >= StealthWatch.ALERT_WARY:
			return 1
	return 0


## The party down to one in a fight, or not: the music thins to its fighting part, or comes back.
func thin(on: bool):
	_thin = on


## The other side's last leader felled: the music swells a while.
func swell():
	_swell_until = Time.get_ticks_msec() / 1000.0 + SWELL_SECONDS


func _process(delta: float):
	if _parts.is_empty() or _player == null:
		return
	var standing := standing_now()
	var swelling := Time.get_ticks_msec() / 1000.0 < _swell_until
	var lift := SWELL_DB if swelling else 0.0
	var share := clampf(delta / PART_FADE, 0.0, 1.0)
	var wanted := {"wary": 0.0 if standing >= 1 and not _thin else PART_OUT_DB, "fighting": lift if standing >= 2 else PART_OUT_DB}
	if _fade != null and _fade.is_valid():
		# Fading out: the parts with it.
		wanted = {"wary": PART_OUT_DB, "fighting": PART_OUT_DB}
		share = clampf(share * 2.0, 0.0, 1.0)
	for part_name in _parts:
		var part: AudioStreamPlayer = _parts[part_name]
		if is_instance_valid(part):
			part.volume_db = _toward(part.volume_db, float(wanted.get(part_name, PART_OUT_DB)), share)
			part.stream_paused = _player.stream_paused
	# The track itself is the calm part: down to nothing while thinned, lifted with a swell - unless it is fading out.
	if _fade == null or not _fade.is_valid():
		_player.volume_db = _toward(_player.volume_db, THIN_DB if _thin else lift, share)


## `from` decibels eased `share` of the way to `to`, evenly to the ear.
static func _toward(from: float, to: float, share: float) -> float:
	return linear_to_db(lerpf(db_to_linear(from), db_to_linear(to), share)) if absf(from - to) > 0.05 else to


## Holds the music where it is. resume() picks it up from the same point.
func pause():
	_ensure_player()
	if _player.playing:
		_player.stream_paused = true


func resume():
	_ensure_player()
	_player.stream_paused = false


## Whether the track keeps repeating. Changing it mid-track takes effect
## without restarting - the loop flag is read when playback reaches the end.
func set_looping(loop: bool):
	_ensure_player()
	if _player.stream != null:
		_apply_loop(_player.stream, loop)


func is_playing() -> bool:
	_ensure_player()
	return _player.playing and not _player.stream_paused


## The track currently loaded, or "" for silence. Handy in a dialogue condition:
## `if Music.current() == "battle"`.
func current() -> String:
	return _current


## Takes the music down to nothing over `seconds` and then stops it, for a
## scene that should end in quiet rather than be cut off.
func fade_out(seconds: float = 1.5):
	_ensure_player()
	Net.music_did("fade_out", [seconds])
	if not _player.playing:
		return
	_cancel_fade()
	_fade = create_tween()
	# -60dB is silence for practical purposes; tweening to -80 spends most of
	# the time inaudible.
	_fade.tween_property(_player, "volume_db", -60.0, maxf(seconds, 0.01))
	_fade.tween_callback(stop)


func _cancel_fade():
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = null


## Finds a track by name, or takes a full path as given.
func _load(track: String) -> AudioStream:
	if track.begins_with("res://") or track.begins_with("user://"):
		return load(track) if ResourceLoader.exists(track) else null
	for extension in EXTENSIONS:
		var path = "%s/%s.%s" % [MUSIC_DIR, track, extension]
		if ResourceLoader.exists(path):
			return load(path)
	return null


## A copy of `stream` set to loop or not.
##
## Copied rather than set in place: the stream is a shared resource, so
## switching looping off for one sting would switch it off for every other use
## of the same file, including one already playing.
func _with_loop(stream: AudioStream, loop: bool) -> AudioStream:
	var copy = stream.duplicate()
	_apply_loop(copy, loop)
	return copy


## Each stream type spells looping differently, and a type that cannot loop at
## all is left alone rather than warned about - it simply plays once.
func _apply_loop(stream: AudioStream, loop: bool):
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
		if loop and stream.loop_end <= stream.loop_begin:
			# A WAV imported with no loop point of its own has loop_begin and
			# loop_end both at zero. Turning looping on then asks the player to
			# repeat a region of no length, and it plays silence rather than
			# looping - which is how three encounters ended up fighting in
			# total quiet while the .mp3 maps were fine, an .mp3 having a plain
			# loop flag with no region to get wrong.
			#
			# The whole file is the loop unless the import says otherwise.
			stream.loop_begin = 0
			stream.loop_end = int(stream.get_length() * stream.mix_rate)
	elif "loop" in stream:
		stream.loop = loop


## --- How loud everything is ---
##
## Two dials, one per bus, because music and effects want balancing against each
## other rather than together - and kept here because this is already the node
## that owns the mixer.
##
## Stored as a fraction from 0 to 1, which is what a slider is, and converted to
## decibels on the way to the bus, which is what a mixer is. Remembered between
## runs: a player who turns the music down means it, and having to do it again
## every launch is how a setting becomes an annoyance.

const SETTINGS_PATH := "user://settings.cfg"
const BUSES := {"music": "Music", "sfx": "SFX"}

var _levels := {"music": 1.0, "sfx": 1.0}


## How loud `which` ("music" or "sfx") is, from 0 to 1.
func volume(which: String) -> float:
	return _levels.get(which, 1.0)


## Sets it, applies it, and remembers it.
func set_volume(which: String, level: float):
	if not BUSES.has(which):
		return
	_levels[which] = clampf(level, 0.0, 1.0)
	_apply(which)
	_save_settings()


func _apply(which: String):
	var index = AudioServer.get_bus_index(BUSES[which])
	if index < 0:
		return
	var level: float = _levels[which]
	# Silence is its own case: linear_to_db(0) is -inf, which some platforms
	# handle badly, and muting the bus says the same thing unambiguously.
	AudioServer.set_bus_mute(index, level <= 0.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(level, 0.0001)))


func _load_settings():
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	for which in BUSES:
		_levels[which] = clampf(config.get_value("audio", which, 1.0), 0.0, 1.0)


func _save_settings():
	var config := ConfigFile.new()
	# Loaded first so writing one setting cannot drop the others, now or when
	# there is more in here than volume.
	config.load(SETTINGS_PATH)
	for which in BUSES:
		config.set_value("audio", which, _levels[which])
	config.save(SETTINGS_PATH)
