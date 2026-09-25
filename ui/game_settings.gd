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


static func _closest(speed: float) -> int:
	var best := NORMAL_SPEED
	for i in ENEMY_SPEEDS.size():
		if absf(ENEMY_SPEEDS[i] - speed) < absf(ENEMY_SPEEDS[best] - speed):
			best = i
	return best
