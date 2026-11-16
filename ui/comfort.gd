class_name Comfort
## How much of what moves the player wants (the proposals of 2026-11-16, section 12; the designer, 2026-11-17: "Add all"). As more
## moves, some will want less: one group in Options, on the title screen and the pause menu alike, kept in the settings file the
## volume levels are in (GameSettings.PATH).
##
## Everything that shakes the view, flashes the screen, slows the world or rumbles a pad asks here first, so a new effect is born
## with its dial: `Comfort.share(Comfort.SHAKE)` and the like give 0 to 1 to multiply by, and `Comfort.slow_motion()` says whether
## the world may slow at all. View and feel only: nothing here is rolled, sent to another machine or saved with a run.

const SECTION := "comfort"

const SHAKE := &"shake"
const FLASHES := &"flashes"
const RUMBLE := &"rumble"
## The map's camera trailing and looking ahead, and a fight's leaning after a blow: 0 pins the view where it was pinned before.
const SWAY := &"sway"

## The sliders, in the order Options shows them.
const DIALS := [
	{"key": SHAKE, "name": "Screen shake", "tip": "How hard a heavy blow, a blast or thunder rattles the view"},
	{"key": FLASHES, "name": "Flashes", "tip": "How bright the screen's flashes are: lightning, a killing blow, a white-out"},
	{"key": SWAY, "name": "Camera sway", "tip": "How much the view trails behind the party, looks ahead and leans into a blow"},
	{"key": RUMBLE, "name": "Rumble", "tip": "How hard a controller rumbles. Nothing on a keyboard"},
]

const SLOW_KEY := "slow_motion"

static var _shares := {}
static var _slow := -1


## 0 to 1: how much of `key`'s effect to show.
static func share(key: StringName) -> float:
	if not _shares.has(key):
		var config := ConfigFile.new()
		var stored := 1.0
		if config.load(GameSettings.PATH) == OK:
			stored = float(config.get_value(SECTION, String(key), 1.0))
		_shares[key] = clampf(stored, 0.0, 1.0)
	return _shares[key]


static func set_share(key: StringName, value: float):
	_shares[key] = clampf(value, 0.0, 1.0)
	var config := ConfigFile.new()
	# Whatever else is in there is kept.
	config.load(GameSettings.PATH)
	config.set_value(SECTION, String(key), _shares[key])
	config.save(GameSettings.PATH)


## Whether the world may slow for a last blow, a boss felled, a stagger.
static func slow_motion() -> bool:
	if _slow < 0:
		var config := ConfigFile.new()
		_slow = 1
		if config.load(GameSettings.PATH) == OK:
			_slow = 1 if config.get_value(SECTION, SLOW_KEY, true) else 0
	return _slow == 1


static func set_slow_motion(on: bool):
	_slow = 1 if on else 0
	var config := ConfigFile.new()
	config.load(GameSettings.PATH)
	config.set_value(SECTION, SLOW_KEY, on)
	config.save(GameSettings.PATH)


## Forgets what was read, so the next ask reads the file again (the tests, after writing one).
static func forget():
	_shares.clear()
	_slow = -1
