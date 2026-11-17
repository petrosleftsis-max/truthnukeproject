class_name SoundFollows
extends Node
## Sound that follows the picture (the proposals of 2026-11-16, section 9; the designer, 2026-11-16: "do all"). The sounds are the
## designer's; this is what the game does with them, through effects of its own on the Music and SFX buses, so the volume dials
## (Music's) are never touched. A child of the Music autoload, so it is there on every screen.
##
## - **Muffled when it should be**: a low-pass on the music and on everything else, eased: behind a menu (MENU_HZ), in slow motion
##   (SLOW_HZ), indoors while it rains outside (RAIN_INDOORS_HZ), and with the view in the dark (DARK_HZ).
## - **Music that gives way**: it dips (GIVE_WAY_DB) for a line in a bubble, a boss's reveal and somebody falling, and comes back
##   (`give_way`).
## - **Echo by place**: a reverb on everything but the music, wetter underground (a map with no open sky at all) than in a hall
##   (under a roof), none out of doors.
## - **Sound by place**: a bed under it all, the room's hush indoors and drips underground (the sound bank's Indoors and
##   Underground; silent until filled, since a made-up noise looping would be worse than nothing). Out of doors the day's own
##   sound plays already (LightView's "The day").
## - **Music that follows the danger**: on a watched map the music already muffles as a guard grows sure (StealthWatch); with the
##   whole map on edge (Wary, then Alarmed) a low pulse beats under it, faster when Alarmed (the sound bank's Danger, or a stand-in).
## - **A voice for each speaker**: a soft tick as a line of a conversation types out, pitched for who speaks (`voice`, from
##   DialogueBalloon; the sound bank's Voice Tick).
##
## "The view" is the middle of the screen on the map or fight shown (LightView.showing). Only to hear: nothing here changes a rule,
## and headless nothing is played (a suite can still ask `wants`). Every number PROPOSAL.

const CLEAR_HZ := 20000.0
const MENU_HZ := 900.0
const SLOW_HZ := 1500.0
const RAIN_INDOORS_HZ := 2400.0
const DARK_HZ := 3600.0
## How fast the cutoff, the echo and the music's dip ease to what is wanted, a share a second.
const EASE := 6.0
const GIVE_WAY_DB := -9.0
## How long the music stays down at least, and how long it takes to come back.
const GIVE_WAY_HOLD := 0.6
const GIVE_WAY_BACK := 0.7
const FALL_SECONDS := 1.2
const REVEAL_SECONDS := 3.5
## The echo: how wet in a hall and underground, and how big each room sounds.
const ECHO_HALL := 0.12
const ECHO_UNDERGROUND := 0.24
const ROOM_HALL := 0.55
const ROOM_UNDERGROUND := 0.85
const BED_DB := -16.0
## The danger's pulse: a beat every this many seconds when Wary and when Alarmed, this loud.
const DANGER_EVERY := [1.15, 0.72]
const DANGER_DB := -17.0
## A tick every this many letters typed, this loud, and how far apart the voices' pitches go.
const VOICE_EVERY := 2
const VOICE_DB := -20.0
const VOICES := {"Cyrus": 0.86, "Alithia": 1.2, "Enfina": 1.02, "Prometheus": 0.78}

static var plays_headless := false
static var _self: SoundFollows = null

var _music_muffle: AudioEffectLowPassFilter = null
var _world_muffle: AudioEffectLowPassFilter = null
var _give_way: AudioEffectAmplify = null
var _echo: AudioEffectReverb = null
var _bed: AudioStreamPlayer = null
var _bed_slot := &""
var _hold_until := 0.0
var _beat_clock := 0.0
## What is wanted now and what is heard, for a suite.
var wanted := {}
var cutoff := CLEAR_HZ
var dip := 0.0
var wet := 0.0


static func shown() -> bool:
	return plays_headless or DisplayServer.get_name() != "headless"


func _ready():
	_self = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music_muffle = _add(&"Music", AudioEffectLowPassFilter.new())
	_give_way = _add(&"Music", AudioEffectAmplify.new())
	_world_muffle = _add(&"SFX", AudioEffectLowPassFilter.new())
	_hush_world = _add(&"SFX", AudioEffectAmplify.new())
	_echo = _add(&"SFX", AudioEffectReverb.new())
	if _echo != null:
		_echo.dry = 1.0
		_echo.wet = 0.0
		_echo.damping = 0.6
		_echo.hipass = 0.2
	for muffle in [_music_muffle, _world_muffle]:
		if muffle != null:
			muffle.cutoff_hz = CLEAR_HZ
	_bed = AudioStreamPlayer.new()
	_bed.name = "Bed"
	_bed.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
	_bed.volume_db = BED_DB
	add_child(_bed)


func _exit_tree():
	if _self == self:
		_self = null


func _add(bus_name: StringName, effect: AudioEffect) -> AudioEffect:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus < 0:
		return null
	AudioServer.add_bus_effect(bus, effect)
	return effect


## Holding your breath (StealthWatch "Stealth, felt"; the proposals of 2026-11-17, section 5): the music and the world alike go
## quiet for `seconds`, quickly, and come back over HUSH_BACK. PROPOSAL.
const HUSH_DB := -12.0
const HUSH_SECONDS := 0.7
const HUSH_BACK := 0.8
var _hush_world: AudioEffectAmplify = null
var _hush_until := 0.0
var hush := 0.0
## How many times the world held its breath, for a suite.
static var hushes := 0


static func hush_for(seconds: float = HUSH_SECONDS):
	hushes += 1
	if _self == null or not is_instance_valid(_self):
		return
	_self._hush_until = maxf(_self._hush_until, _self._now() + seconds)


## The music gives way for `seconds` (at least GIVE_WAY_HOLD), and comes back after: a line in a bubble, a boss's reveal, a fall.
static func give_way(seconds: float = 0.0):
	if _self == null or not is_instance_valid(_self):
		return
	_self._hold_until = maxf(_self._hold_until, _self._now() + maxf(seconds, GIVE_WAY_HOLD))


## A tick for the `letter_index`th letter of a line `speaker` is saying, every VOICE_EVERY letters but spaces and marks.
static func voice(speaker: String, letter: String, letter_index: int):
	# Only a letter (one that has a capital), not a space or a mark.
	var a_letter := letter.to_lower() != letter.to_upper()
	if not a_letter or letter_index % VOICE_EVERY != 0:
		return
	MapFeel.sound(&"voice_tick", VOICE_DB, voice_pitch(speaker))


## How high `speaker`'s voice ticks: the party's own, else one of their own made from their name, always the same.
static func voice_pitch(speaker: String) -> float:
	if VOICES.has(speaker):
		return VOICES[speaker]
	return 0.85 + float(abs(hash(speaker)) % 1000) / 1000.0 * 0.4


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


## --- Sound with a place ---
##
## The proposals of 2026-11-17, section 4 (the designer: "From section 4 and on do all"). A sound of a fight or a map that happens
## somewhere is heard from there (`place`): from its side of the screen, panned by the engine (an AudioStreamPlayer2D); as loud as
## ever over most of the screen, falling to PLACE_AT_EDGE at its edge and gone PLACE_FADE_TILES past it, worked out here as it
## starts; and dulled when a wall stands between it and the middle of the view (the bus SFX Behind, made as first needed: a
## low-pass and a little quieter, sending on to SFX so the dial and the rest still hold), as the rain is dulled indoors. The music,
## the interface's sounds and a voice's ticks stay in the middle. PROPOSAL.
const PLACE_PANNING := 1.6
const PLACE_FALLS_FROM := 0.75
const PLACE_AT_EDGE := 0.7
const PLACE_FADE_TILES := 4.0
const BEHIND_BUS := &"SFX Behind"
const BEHIND_HZ := 1100.0
const BEHIND_DB := -4.0
## How many have been placed, and how many of them behind a wall, for a suite.
static var placed := {}


## Readies `player` to play a sound at `at` (in the world) at `volume_db`: where it is, how loud, behind a wall or not. False when
## it is too far off the screen to be heard, and it should not play.
static func place(player: AudioStreamPlayer2D, at: Vector2, volume_db: float) -> bool:
	var loud := loudness_at(at)
	if loud <= 0.0:
		placed[&"unheard"] = int(placed.get(&"unheard", 0)) + 1
		return false
	player.global_position = at
	# How loud is worked out here; the engine only pans.
	player.max_distance = 1.0e7
	player.attenuation = 1.0
	player.panning_strength = PLACE_PANNING
	player.volume_db = volume_db + linear_to_db(loud)
	var behind := behind_wall(at)
	player.bus = _behind_bus() if behind else (&"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master")
	placed[&"behind" if behind else &"heard"] = int(placed.get(&"behind" if behind else &"heard", 0)) + 1
	return true


## The viewport the world is shown in: the root's.
static func _screen() -> Viewport:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root if tree != null else null


## How loud a sound at `at` (in the world) is heard, 0 to 1, by where it is on the screen: 1 over most of it, PLACE_AT_EDGE at its
## edge, 0 PLACE_FADE_TILES past it.
static func loudness_at(at: Vector2) -> float:
	var viewport := _screen()
	if viewport == null:
		return 1.0
	var screen := viewport.get_visible_rect().size
	if screen.x <= 0.0 or screen.y <= 0.0:
		return 1.0
	var canvas := viewport.get_canvas_transform()
	var half := screen * 0.5
	var off := (canvas * at - half).abs()
	var share := maxf(off.x / half.x, off.y / half.y)
	if share <= PLACE_FALLS_FROM:
		return 1.0
	if share <= 1.0:
		return lerpf(1.0, PLACE_AT_EDGE, (share - PLACE_FALLS_FROM) / (1.0 - PLACE_FALLS_FROM))
	var zoom := maxf(absf(canvas.get_scale().x), 0.0001)
	var past_tiles := maxf(off.x - half.x, off.y - half.y) / zoom / float(Grid.TILE_SIZE)
	return maxf(PLACE_AT_EDGE * (1.0 - past_tiles / PLACE_FADE_TILES), 0.0)


## Whether a wall (Depth's WALL) stands between `at` (in the world) and the middle of the view, on the map or fight shown.
static func behind_wall(at: Vector2) -> bool:
	var view: LightView = LightView.showing
	var viewport := _screen()
	if view == null or not is_instance_valid(view) or view._tile_map == null or viewport == null:
		return false
	var tile_map: TileMap = view._tile_map
	var middle: Vector2 = viewport.get_canvas_transform().affine_inverse() * (viewport.get_visible_rect().size * 0.5)
	return wall_between(tile_map, tile_map.local_to_map(tile_map.to_local(middle)), tile_map.local_to_map(tile_map.to_local(at)))


## Whether a wall (Depth's WALL) of `tile_map` stands on the line between tiles `from` and `to`, a quarter of a tile at a time;
## the tiles at either end do not count.
static func wall_between(tile_map: TileMap, from: Vector2i, to: Vector2i) -> bool:
	var steps := mini(ceili(Vector2(to - from).length() * 4.0), 400)
	for i in range(1, steps):
		var tile := Vector2i(Vector2(from).lerp(Vector2(to), float(i) / float(steps)).round())
		if tile != from and tile != to and Depth.kind_at(tile_map, tile) == Depth.Kind.WALL:
			return true
	return false


## The bus a sound behind a wall plays on: made the first time, a low-pass sending on to SFX.
static func _behind_bus() -> StringName:
	if AudioServer.get_bus_index(BEHIND_BUS) >= 0:
		return BEHIND_BUS
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, BEHIND_BUS)
	AudioServer.set_bus_send(index, &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master")
	AudioServer.set_bus_volume_db(index, BEHIND_DB)
	var dull := AudioEffectLowPassFilter.new()
	dull.cutoff_hz = BEHIND_HZ
	AudioServer.add_bus_effect(index, dull)
	return BEHIND_BUS


## What the picture asks of the sound right now: {"hz", "dip", "wet", "room", "bed", "danger"}.
func wants() -> Dictionary:
	var hz := CLEAR_HZ
	var why := []
	if MenuPause.is_held() or (get_tree() != null and get_tree().paused):
		hz = minf(hz, MENU_HZ)
		why.append("menu")
	if Engine.time_scale < 0.95:
		hz = minf(hz, SLOW_HZ)
		why.append("slow")
	var view := _view()
	var place := &"outside"
	if not view.is_empty():
		if not view.open:
			place = &"underground" if not view.any_sky else &"indoors"
		if view.raining and not view.open:
			hz = minf(hz, RAIN_INDOORS_HZ)
			why.append("rain outside")
		if view.dark:
			hz = minf(hz, DARK_HZ)
			why.append("dark")
	var danger := 0
	var watch = Campaign.get("stealth_watch")
	if watch != null and is_instance_valid(watch) and "alert" in watch:
		var on_edge: float = watch.alert
		danger = 2 if on_edge >= StealthWatch.ALERT_ALARMED else (1 if on_edge >= StealthWatch.ALERT_WARY else 0)
	return {
		"hz": hz, "why": why, "dip": GIVE_WAY_DB if _now() < _hold_until else 0.0,
		"wet": {&"outside": 0.0, &"indoors": ECHO_HALL, &"underground": ECHO_UNDERGROUND}[place],
		"room": ROOM_UNDERGROUND if place == &"underground" else ROOM_HALL,
		"bed": &"" if place == &"outside" else place, "danger": danger,
	}


## Where the view is: whether that tile is under the open sky, whether the map has any open sky at all, whether it is raining on
## the map and whether the tile is dark. Empty with no map or fight shown.
func _view() -> Dictionary:
	var view: LightView = LightView.showing
	if view == null or not is_instance_valid(view) or view.light == null or view._tile_map == null:
		return {}
	# The camera of the scene shown, not merely the viewport's: in the tests the game's own fight is behind the map being tested.
	var camera := get_viewport().get_camera_2d()
	if camera == null or not Depth.same_scene(camera, view):
		camera = _camera_of(view)
	if camera == null:
		return {}
	# Where the screen's middle is (limits and smoothing taken in); headless nothing is drawn, and the camera's own place stands in.
	var middle := camera.get_screen_center_position() if DisplayServer.get_name() != "headless" else camera.global_position
	var tile: Vector2i = view._tile_map.local_to_map(view._tile_map.to_local(middle))
	var map: LightMap = view.light
	var open: bool = map.under_the_sky(tile)
	var any_sky: bool = open or _has_sky(view)
	# A place indoors or underground as a whole (the fight's or the map's own ambient) has no sky anywhere, ambient areas or none.
	match _ambient_of(view):
		Light.Ambient.INTERIOR:
			open = false
			any_sky = true
		Light.Ambient.UNDERGROUND:
			open = false
			any_sky = false
	var sky: Dictionary = view._sky_shown
	var raining: bool = not sky.is_empty() and float(sky.get("rain", 0.0)) + float(sky.get("hail", 0.0)) > 0.1
	return {"open": open, "any_sky": any_sky, "raining": raining, "dark": map.level_at(tile) == Light.Level.DARK}


## The ambient of the place `view` shows: its fight's, else the map's (Campaign.map_ambient).
func _ambient_of(view: LightView) -> int:
	var top: Node = view
	while top.get_parent() != null and top.get_parent() != get_tree().root:
		top = top.get_parent()
	var fight = top.get("combat")
	if fight is Combat:
		return fight._light_ambient
	return Campaign.map_ambient


## Whether any of the map shown is under the open sky (kept, as a map does not change it): a map with none is underground.
func _has_sky(view: LightView) -> bool:
	var key := view.get_instance_id()
	if _sky_of.has(key):
		return _sky_of[key]
	var any := false
	for tile in view._tile_map.get_used_cells(0):
		if view.light.under_the_sky(tile):
			any = true
			break
	_sky_of[key] = any
	return any


var _sky_of := {}


## The first camera in the scene `view` is part of.
func _camera_of(view: LightView) -> Camera2D:
	var top: Node = view
	while top.get_parent() != null and top.get_parent() != get_tree().root:
		top = top.get_parent()
	var cameras := top.find_children("*", "Camera2D", true, false)
	return cameras[0] if not cameras.is_empty() else null


func _process(delta: float):
	if not shown():
		return
	wanted = wants()
	var share := clampf(delta * EASE, 0.0, 1.0)
	# The cutoff eases in octaves, so a muffle comes on and goes off evenly to the ear.
	cutoff = pow(2.0, lerpf(log(cutoff) / log(2.0), log(float(wanted.hz)) / log(2.0), share))
	var back := clampf(delta / GIVE_WAY_BACK, 0.0, 1.0) if wanted.dip > dip else share
	dip = lerpf(dip, float(wanted.dip), back)
	var hushed := HUSH_DB if _now() < _hush_until else 0.0
	hush = lerpf(hush, hushed, clampf(delta / HUSH_BACK, 0.0, 1.0) if hushed > hush else clampf(share * 3.0, 0.0, 1.0))
	wet = lerpf(wet, float(wanted.wet), share * 0.5)
	for muffle in [_music_muffle, _world_muffle]:
		if muffle != null:
			muffle.cutoff_hz = cutoff
	if _give_way != null:
		_give_way.volume_db = dip + hush
	if _hush_world != null:
		_hush_world.volume_db = hush
	if _echo != null:
		_echo.wet = wet
		_echo.room_size = float(wanted.room)
	_keep_the_bed(wanted.bed)
	_keep_the_pulse(int(wanted.danger), delta)


## The place's own bed under everything, if the designer has given one.
func _keep_the_bed(slot: StringName):
	if slot == _bed_slot:
		return
	_bed_slot = slot
	var stream: AudioStream = GameSounds.stream(slot) if slot != &"" else null
	if stream == null:
		_bed.stop()
		return
	_bed.stream = stream
	_bed.play()


## The danger's pulse: nothing while the map is calm.
func _keep_the_pulse(danger: int, delta: float):
	if danger <= 0:
		_beat_clock = 0.0
		return
	_beat_clock += delta
	var every: float = DANGER_EVERY[mini(danger, 2) - 1]
	if _beat_clock >= every:
		_beat_clock = 0.0
		MapFeel.sound(&"danger", DANGER_DB)
