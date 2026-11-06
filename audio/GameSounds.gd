extends RefCounted
class_name GameSounds
## Plays the sounds in audio/sound_bank.tres (SoundBank). Static, so a tool script and anything
## else can ask without an autoload; the players live under the root, made as first needed, and
## carry on through a pause and a change of scene. Nothing here touches a fight's rolls.

const BANK := "res://audio/sound_bank.tres"
const VOICES := 6
## The same sound asked for again within this long is the one sound.
const SAME_MS := 70
const SLICE_FADE_SECONDS := 0.25

static var _bank: SoundBank = null
static var _holder: Node = null
static var _players: Array = []
static var _next := 0
static var _looping: AudioStreamPlayer = null
static var _looping_slot: StringName = &""
static var _last_at := {}


## The bank.
static func bank() -> SoundBank:
	if _bank == null:
		_bank = load(BANK)
	return _bank


## What fills `slot`, or null.
static func stream(slot: StringName) -> AudioStream:
	return bank().get(slot) if bank() != null else null


## Plays what fills `slot`, if anything does.
static func play(slot: StringName, volume_db: float = 0.0) -> AudioStreamPlayer:
	var sound := stream(slot)
	if sound == null:
		return null
	var now := Time.get_ticks_msec()
	if now - int(_last_at.get(slot, -SAME_MS - 1)) <= SAME_MS:
		return null
	_last_at[slot] = now
	return _start(sound, volume_db)


## Plays `sound`, whatever it is, on the bank's players.
static func play_stream(sound: AudioStream, volume_db: float = 0.0):
	if sound != null:
		_start(sound, volume_db)


## `seconds` of what fills `slot`, from anywhere in it, fading out: for a long sound where a
## moment of it is all that happened (rummaging through a bag).
static func play_slice(slot: StringName, seconds: float, volume_db: float = 0.0):
	var sound := stream(slot)
	if sound == null:
		return
	var player := _start(sound, volume_db, randf() * maxf(sound.get_length() - seconds, 0.0))
	if player == null:
		return
	var fade := player.create_tween()
	fade.tween_interval(maxf(seconds - SLICE_FADE_SECONDS, 0.0))
	fade.tween_property(player, "volume_db", volume_db - 40.0, SLICE_FADE_SECONDS)
	fade.tween_callback(player.stop)


## Loops what fills `slot` until stop_loop: one at a time, a new one in its place.
static func loop(slot: StringName, volume_db: float = 0.0):
	if _looping_slot == slot and _looping != null and is_instance_valid(_looping) and _looping.playing:
		return
	stop_loop()
	var sound := stream(slot)
	if sound == null:
		return
	if sound is AudioStreamWAV:
		var wave: AudioStreamWAV = sound
		wave.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wave.loop_begin = 0
		wave.loop_end = int(wave.get_length() * wave.mix_rate)
	_looping = _start(sound, volume_db)
	_looping_slot = slot


static func stop_loop():
	if _looping != null and is_instance_valid(_looping):
		_looping.stop()
	_looping = null
	_looping_slot = &""


## What is looping now, for a test.
static func looping() -> StringName:
	return _looping_slot


## Whether it was the last slot asked for, within `ms`: for a test.
static func heard(slot: StringName, ms: int = 2000) -> bool:
	return Time.get_ticks_msec() - int(_last_at.get(slot, -ms - 1)) <= ms


## Keeps `button` from clicking: it makes a sound of its own, or none is wanted.
static func quiet(button: BaseButton):
	button.set_meta(&"quiet_press", true)


## Every button in the game clicks from now on, and gold makes its sound. Once, from an autoload.
static func listen(tree: SceneTree):
	if not tree.node_added.is_connected(_on_node_added):
		tree.node_added.connect(_on_node_added)


static func _on_node_added(node: Node):
	if node is BaseButton:
		node.pressed.connect(_pressed.bind(node))


static func _pressed(button: BaseButton):
	if not button.has_meta(&"quiet_press"):
		play(&"menu_press")


static func _start(sound: AudioStream, volume_db: float, from: float = 0.0) -> AudioStreamPlayer:
	var player := _free_player()
	if player == null:
		return null
	player.stream = sound
	player.volume_db = volume_db
	player.play(from)
	return player


static func _free_player() -> AudioStreamPlayer:
	if _holder == null or not is_instance_valid(_holder):
		var tree := Engine.get_main_loop() as SceneTree
		if tree == null or tree.root == null:
			return null
		_holder = Node.new()
		_holder.name = "GameSounds"
		_holder.process_mode = Node.PROCESS_MODE_ALWAYS
		tree.root.add_child.call_deferred(_holder)
		_players = []
		for i in VOICES:
			var made := AudioStreamPlayer.new()
			if AudioServer.get_bus_index(&"SFX") >= 0:
				made.bus = &"SFX"
			_holder.add_child(made)
			_players.append(made)
	if not _holder.is_inside_tree():
		return null
	for player in _players:
		if not player.playing:
			return player
	_next = (_next + 1) % _players.size()
	var oldest: AudioStreamPlayer = _players[_next]
	return null if oldest == _looping else oldest
