class_name GameSettings
## Settings that are the player's rather than the game's, kept in the same
## user://settings.cfg the volume levels are (see Music).

const PATH := "user://settings.cfg"
const SECTION := "gameplay"
const SPEED_KEY := "enemy_turn_speed"

## How fast an enemy's turn plays against a player's own. The whole battle runs
## at this speed while an enemy acts - its walk, its swing, the pause before it -
## and at normal speed again the moment the player's turn comes round. Slower
## is for watching what they do; faster is for not waiting on it.
const ENEMY_SPEEDS := [0.5, 0.75, 1.0, 2.0, 3.0]
const ENEMY_SPEED_NAMES := ["Very slow", "Slow", "Normal", "Fast", "Very fast"]
## Where 1.0 sits in ENEMY_SPEEDS.
const NORMAL_SPEED := 2

static var _enemy_speed := -1


static func enemy_speed_index() -> int:
	if _enemy_speed < 0:
		var config := ConfigFile.new()
		var stored = 1.0
		if config.load(PATH) == OK:
			stored = config.get_value(SECTION, SPEED_KEY, 1.0)
		_enemy_speed = _closest(float(stored))
	return _enemy_speed


## Saved as the speed itself rather than its place in the list, so a list that
## grows - the slower speeds came after the faster ones - never turns somebody's
## saved Fast into something else.
static func set_enemy_speed_index(index: int):
	_enemy_speed = clampi(index, 0, ENEMY_SPEEDS.size() - 1)
	var config := ConfigFile.new()
	# Whatever else is in there - the volume levels - is kept.
	config.load(PATH)
	config.set_value(SECTION, SPEED_KEY, ENEMY_SPEEDS[_enemy_speed])
	config.save(PATH)


## What Engine.time_scale is set to while an enemy acts.
static func enemy_time_scale() -> float:
	return ENEMY_SPEEDS[enemy_speed_index()]


## --- The size of the HUD ---

const UI_SCALE_KEY := "ui_scale"
const UI_SCALES := [0.85, 1.0, 1.15, 1.3]
const UI_SCALE_NAMES := ["Small", "Normal", "Large", "Largest"]
static var _ui_scale := -1


static func ui_scale_index() -> int:
	if _ui_scale < 0:
		var config := ConfigFile.new()
		var stored := 1.0
		if config.load(PATH) == OK:
			stored = float(config.get_value(DISPLAY_SECTION, UI_SCALE_KEY, 1.0))
		_ui_scale = 1
		for i in UI_SCALES.size():
			if absf(UI_SCALES[i] - stored) < absf(UI_SCALES[_ui_scale] - stored):
				_ui_scale = i
	return _ui_scale


static func ui_scale() -> float:
	return UI_SCALES[ui_scale_index()]


static func set_ui_scale_index(index: int):
	_ui_scale = clampi(index, 0, UI_SCALES.size() - 1)
	var config := ConfigFile.new()
	config.load(PATH)
	config.set_value(DISPLAY_SECTION, UI_SCALE_KEY, UI_SCALES[_ui_scale])
	config.save(PATH)


## --- The grid in a fight ---
##
## Off, its lines fade away but near the pointer while moving or aiming. On, they stay up, for anybody who likes to count tiles.

const GRID_KEY := "grid_always"
static var _grid_always := -1


static func grid_always() -> bool:
	if _grid_always < 0:
		var config := ConfigFile.new()
		_grid_always = 0
		if config.load(PATH) == OK:
			_grid_always = 1 if config.get_value(SECTION, GRID_KEY, false) else 0
	return _grid_always == 1


static func set_grid_always(on: bool):
	_grid_always = 1 if on else 0
	var config := ConfigFile.new()
	config.load(PATH)
	config.set_value(SECTION, GRID_KEY, on)
	config.save(PATH)


## --- Figures lit as shapes ---
##
## On, the light falls on a figure as on a shape worked out from its picture (CombatantSprite FIGURE_SHADER, "normal maps
## without extra art", the designer, 2026-11-07); off, as on a flat picture, to compare.

const SHAPES_KEY := "figure_shapes"
static var _figure_shapes := -1


static func figure_shapes() -> bool:
	if _figure_shapes < 0:
		var config := ConfigFile.new()
		_figure_shapes = 1
		if config.load(PATH) == OK:
			_figure_shapes = 1 if config.get_value(SECTION, SHAPES_KEY, true) else 0
	return _figure_shapes == 1


static func set_figure_shapes(on: bool):
	_figure_shapes = 1 if on else 0
	var config := ConfigFile.new()
	config.load(PATH)
	config.set_value(SECTION, SHAPES_KEY, on)
	config.save(PATH)


## --- How the game sits on the screen ---

const DISPLAY_SECTION := "display"
const WINDOW_MODE_KEY := "window_mode"

enum WindowMode { FULLSCREEN, FAKE_FULLSCREEN, WINDOWED }
const WINDOW_MODE_NAMES := ["Fullscreen", "Fake fullscreen", "Windowed"]
const WINDOW_MODE_TIPS := [
	"The game takes the screen over - switching to another window takes a moment",
	"A borderless window covering the whole screen - switching away is instant",
	"A window, at whichever size is picked below",
]
## Saved as a word rather than a place in the list, for the reason the speed
## is saved as a speed.
const WINDOW_MODE_WORDS := ["fullscreen", "fake_fullscreen", "windowed"]
## Godot's exclusive fullscreen is the real thing; its plain fullscreen is a
## borderless window the size of the screen, which is what fake fullscreen is.
const _DISPLAY_MODES := [
	DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN,
	DisplayServer.WINDOW_MODE_FULLSCREEN,
	DisplayServer.WINDOW_MODE_WINDOWED,
]

static var _window_mode := -1
## The window's size when it last was one, to go back to from fullscreen.
static var _window_size := Vector2i.ZERO
static var _restored := false


static func window_mode() -> int:
	if _window_mode < 0:
		var config := ConfigFile.new()
		var stored = WINDOW_MODE_WORDS[WindowMode.WINDOWED]
		if config.load(PATH) == OK:
			stored = config.get_value(DISPLAY_SECTION, WINDOW_MODE_KEY, stored)
		var found := WINDOW_MODE_WORDS.find(stored)
		_window_mode = found if found >= 0 else WindowMode.WINDOWED
	return _window_mode


## Switches to it and remembers it.
static func set_window_mode(mode: int):
	_window_mode = clampi(mode, 0, WINDOW_MODE_WORDS.size() - 1)
	_apply_window_mode()
	var config := ConfigFile.new()
	config.load(PATH)
	config.set_value(DISPLAY_SECTION, WINDOW_MODE_KEY, WINDOW_MODE_WORDS[_window_mode])
	config.save(PATH)


## Puts the window back the way the player left it last time. Once a run, from
## the title screen. Not on the web, where a page may only go fullscreen when
## somebody clicks for it.
static func restore_window_mode():
	if _restored or OS.has_feature("web"):
		return
	_restored = true
	_apply_window_mode()


## A window of `size`, in the middle of the screen. A size means a window, so
## picking one in fullscreen goes back to a window to have it.
static func set_window_size(size: Vector2i):
	_window_size = size
	if window_mode() != WindowMode.WINDOWED:
		set_window_mode(WindowMode.WINDOWED)
	_resize_window(size)


static func _apply_window_mode():
	var wanted: DisplayServer.WindowMode = _DISPLAY_MODES[window_mode()]
	var now := DisplayServer.window_get_mode()
	if now == wanted:
		return
	if now == DisplayServer.WINDOW_MODE_WINDOWED:
		_window_size = DisplayServer.window_get_size()
	DisplayServer.window_set_mode(wanted)
	if wanted == DisplayServer.WINDOW_MODE_WINDOWED and _window_size != Vector2i.ZERO:
		_resize_window(_window_size)


## Window.size can't be trusted for this: with canvas_items stretching it goes
## through Godot's content-scale bookkeeping rather than resizing the real
## window. DisplayServer works on the real window.
static func _resize_window(size: Vector2i):
	DisplayServer.window_set_size(size)
	# The project has window/size/resizable=false, which on some platforms
	# blocks resizing from code too, not just dragging the edge - so there it
	# is lifted for the moment it takes. Only there: on Windows lifting it
	# brings the draggable edge back while the size is set, and putting it
	# back leaves the window ten pixels bigger than asked.
	if DisplayServer.window_get_size() != size:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, false)
		DisplayServer.window_set_size(size)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, true)
	var screen := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	DisplayServer.window_set_position(screen.position + (screen.size - size) / 2)


static func _closest(speed: float) -> int:
	var best := NORMAL_SPEED
	for i in ENEMY_SPEEDS.size():
		if absf(ENEMY_SPEEDS[i] - speed) < absf(ENEMY_SPEEDS[best] - speed):
			best = i
	return best
