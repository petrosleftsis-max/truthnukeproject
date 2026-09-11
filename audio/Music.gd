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
	if track == "":
		return
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


## Stops and forgets the current track, so a later play() of the same one
## starts it again rather than treating it as already playing.
func stop():
	_cancel_fade()
	_player.stop()
	_current = ""


## Holds the music where it is. resume() picks it up from the same point.
func pause():
	if _player.playing:
		_player.stream_paused = true


func resume():
	_player.stream_paused = false


## Whether the track keeps repeating. Changing it mid-track takes effect
## without restarting - the loop flag is read when playback reaches the end.
func set_looping(loop: bool):
	if _player.stream != null:
		_apply_loop(_player.stream, loop)


func is_playing() -> bool:
	return _player.playing and not _player.stream_paused


## The track currently loaded, or "" for silence. Handy in a dialogue condition:
## `if Music.current() == "battle"`.
func current() -> String:
	return _current


## Takes the music down to nothing over `seconds` and then stops it, for a
## scene that should end in quiet rather than be cut off.
func fade_out(seconds: float = 1.5):
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
