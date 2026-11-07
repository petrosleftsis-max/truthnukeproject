extends RefCounted
class_name Light
## Light on the maps (the designer, 2026-11-05 and 06; docs/proposals_2026-11-05.md section 1).
## Every tile is Bright, Dim or Dark, worked out from the map's ambient light and from whatever
## is lighting it: placed lights, things on the map, openings, carried lanterns, burning people
## and ground. Walls stop light. Nothing here rolls, so it comes out the same on both machines.
##
## What each does:
## - Bright: nothing.
## - Dim: somebody who can stealth (CombatantDefinition.stealths) can hide there without cover, and
##   is only made out from close by; a guard's eyes reach Dim Sight Tiles there.
## - Dark: invisible to whoever cannot see in the dark, unless they are right beside them
##   (Combat "In the dark"); a guard makes somebody out only within Dark Sight Tiles.

enum Level { DARK, DIM, BRIGHT }
## Appended only: stored by number.
enum Ambient { AS_THE_MAP, OUTDOORS, INTERIOR, UNDERGROUND }
enum Hour { DAY, DUSK, NIGHT, DAWN }

const TIME_NAMES := ["day", "dusk", "night", "dawn"]
const LEVEL_NAMES := ["Dark", "Dim", "Bright"]

## How much a level of ambient light is, for the look: what the shade over a tile goes by.
const AMOUNTS := [0.0, 0.55, 1.0]

## The whole picture's colour by the hour, outdoors. A tint over everything but the HUD.
const TONES := [Color(1.0, 1.0, 1.0), Color(1.0, 0.82, 0.68), Color(0.56, 0.62, 0.86), Color(0.92, 0.82, 0.86)]
## And under a roof or a rock, where the hour has no say.
const INTERIOR_TONE := Color(0.96, 0.92, 0.84)
const UNDERGROUND_TONE := Color(0.82, 0.84, 0.92)
## How a figure is drawn by the level it stands in.
const FIGURE_TINTS := [Color(0.5, 0.52, 0.66), Color(0.82, 0.82, 0.88), Color(1.0, 1.0, 1.0)]


## The level a tile is by the ambient light alone.
static func base_level(ambient: int, time: int, no_moon: bool = false) -> int:
	match ambient:
		Ambient.UNDERGROUND:
			return Level.DARK
		Ambient.INTERIOR:
			return Level.DIM
	match time:
		Hour.DAY:
			return Level.BRIGHT
		Hour.NIGHT:
			return Level.DARK if no_moon else Level.DIM
	return Level.DIM


## What an opening lets in, by the hour: [bright share, dim share] of what it could.
static func opening_shares(time: int) -> Array:
	match time:
		Hour.DAY:
			return [1.0, 1.0]
		Hour.NIGHT:
			return [0.0, 0.0]
	return [0.0, 1.0]


## The colour over everything, by the ambient light and the hour.
static func tone(ambient: int, time: int) -> Color:
	match ambient:
		Ambient.INTERIOR:
			return INTERIOR_TONE
		Ambient.UNDERGROUND:
			return UNDERGROUND_TONE
	return TONES[clampi(time, 0, TONES.size() - 1)]


## --- By the clock (Campaign "The clock and the calendar") ---
##
## Minutes after midnight. The rule goes by the four parts of the day, and how it looks goes round
## with the clock: what is here eases from one to the next. PROPOSAL, all of it.

const MINUTES_A_DAY := 1440
## When each part of the day begins, by Hour.
const HOUR_STARTS := [480, 1020, 1200, 300]
const NIGHT_TONE := Color(0.5, 0.57, 0.86)
const BLUE_HOUR_TONE := Color(0.6, 0.65, 0.92)
const DAWN_TONE := Color(1.0, 0.84, 0.74)
const DUSK_TONE := Color(1.0, 0.76, 0.55)
## Round the day (the designer's picks of 2026-11-07, docs/proposals_2026-11-07.md section 14; all PROPOSAL): [minute, tone, lean of a shadow,
## its strength, its softness, saturation, contrast, how lit it looks outdoors]. A curve goes through these, so that nothing turns
## sharply at a mark or stands still for hours. Blue hour, first gold, morning, a harder noon, a warmer afternoon, golden hour, red at
## sundown, blue hour, and deep night with a faint moon shadow going round the other way.
const SKY := [
	[0, NIGHT_TONE, 0.05, 0.12, 1.4, 0.72, 1.02, 0.46],
	[240, NIGHT_TONE, 0.5, 0.1, 1.4, 0.72, 1.02, 0.46],
	[330, BLUE_HOUR_TONE, -1.1, 0.06, 1.6, 0.78, 1.0, 0.44],
	[390, DAWN_TONE, -1.0, 0.24, 1.3, 1.02, 1.0, 0.6],
	[480, Color(1.0, 0.95, 0.88), -0.7, 0.32, 1.0, 1.03, 1.0, 0.86],
	[600, Color(1.0, 0.99, 0.97), -0.35, 0.36, 0.8, 1.0, 1.0, 1.0],
	[720, Color.WHITE, 0.0, 0.42, 0.6, 0.98, 1.04, 1.0],
	[870, Color(1.0, 0.98, 0.92), 0.35, 0.38, 0.8, 1.02, 1.01, 1.0],
	[1000, Color(1.0, 0.9, 0.76), 0.72, 0.32, 1.0, 1.1, 1.03, 0.9],
	[1110, DUSK_TONE, 1.0, 0.27, 1.2, 1.18, 1.05, 0.62],
	[1170, Color(0.92, 0.56, 0.56), 1.15, 0.15, 1.4, 1.08, 1.04, 0.5],
	[1230, Color(0.56, 0.6, 0.9), -0.5, 0.06, 1.5, 0.78, 1.01, 0.46],
	[1320, NIGHT_TONE, -0.3, 0.11, 1.4, 0.72, 1.02, 0.46],
	[1440, NIGHT_TONE, 0.05, 0.12, 1.4, 0.72, 1.02, 0.46],
]
const _TONE := 1
const _LEAN := 2
const _STRENGTH := 3
const _SOFT := 4
const _SATURATION := 5
const _CONTRAST := 6
const _AMOUNT := 7

## The kinds of sky a day can have. Only how it looks: the rule goes by the part of the day and the moon. Each says what it does to the
## clear day's: `mix`, how far towards its `tone`; and what it multiplies the rest by. `clouds`, how much of the ground their shadows
## pass over; `rain` and `mist`, how much of each there is; and, only where they say so, `snow`, `hail` (sleet), `lightning`, `wind`,
## `sand`, `ash` falling, `shimmer` (heat off the ground), `aurora` by night, a `rainbow` by day, and an `eclipse` at noon (the designer,
## 2026-11-07: "Add the not included weathers as well").
const WEATHERS := {
	"clear": {"tone": Color.WHITE, "mix": 0.0, "strength": 1.05, "soft": 0.9, "saturation": 1.03, "contrast": 1.02, "amount": 1.0, "clouds": 0.12, "rain": 0.0, "mist": 0.0},
	"haze": {"tone": Color(1.0, 0.95, 0.86), "mix": 0.25, "strength": 0.6, "soft": 1.6, "saturation": 0.9, "contrast": 0.94, "amount": 0.97, "clouds": 0.05, "rain": 0.0, "mist": 0.12},
	"overcast": {"tone": Color(0.84, 0.87, 0.92), "mix": 0.55, "strength": 0.25, "soft": 2.0, "saturation": 0.72, "contrast": 0.92, "amount": 0.86, "clouds": 0.55, "rain": 0.0, "mist": 0.0},
	"rain": {"tone": Color(0.72, 0.77, 0.87), "mix": 0.6, "strength": 0.15, "soft": 2.0, "saturation": 0.65, "contrast": 0.95, "amount": 0.74, "clouds": 0.7, "rain": 0.5, "mist": 0.0},
	"fog": {"tone": Color(0.85, 0.87, 0.9), "mix": 0.5, "strength": 0.2, "soft": 2.2, "saturation": 0.7, "contrast": 0.9, "amount": 0.85, "clouds": 0.0, "rain": 0.0, "mist": 1.0},
	"storm": {"tone": Color(0.55, 0.6, 0.74), "mix": 0.7, "strength": 0.1, "soft": 2.2, "saturation": 0.55, "contrast": 1.0, "amount": 0.58, "clouds": 0.9, "rain": 1.0, "mist": 0.0},
	"snow": {"tone": Color(0.88, 0.92, 1.0), "mix": 0.45, "strength": 0.3, "soft": 1.8, "saturation": 0.78, "contrast": 0.96, "amount": 0.92, "clouds": 0.5, "rain": 0.0, "mist": 0.15, "snow": 0.6},
	"sleet": {"tone": Color(0.74, 0.79, 0.88), "mix": 0.58, "strength": 0.14, "soft": 2.0, "saturation": 0.64, "contrast": 0.95, "amount": 0.75, "clouds": 0.75, "rain": 0.35, "mist": 0.0, "hail": 0.6},
	"thunderstorm": {"tone": Color(0.5, 0.55, 0.7), "mix": 0.72, "strength": 0.08, "soft": 2.3, "saturation": 0.55, "contrast": 1.02, "amount": 0.55, "clouds": 0.95, "rain": 1.0, "mist": 0.0, "lightning": 1.0, "wind": 0.5},
	"wind": {"tone": Color(0.95, 0.97, 1.0), "mix": 0.15, "strength": 0.9, "soft": 1.1, "saturation": 0.98, "contrast": 1.02, "amount": 0.98, "clouds": 0.35, "rain": 0.0, "mist": 0.0, "wind": 1.0},
	"sandstorm": {"tone": Color(1.0, 0.8, 0.55), "mix": 0.62, "strength": 0.12, "soft": 2.3, "saturation": 0.82, "contrast": 0.9, "amount": 0.72, "clouds": 0.0, "rain": 0.0, "mist": 0.0, "sand": 1.0, "wind": 1.0},
	"blizzard": {"tone": Color(0.86, 0.9, 1.0), "mix": 0.68, "strength": 0.06, "soft": 2.4, "saturation": 0.58, "contrast": 0.88, "amount": 0.7, "clouds": 0.85, "rain": 0.0, "mist": 0.45, "snow": 1.0, "wind": 1.0},
	"heat": {"tone": Color(1.0, 0.94, 0.82), "mix": 0.22, "strength": 1.15, "soft": 0.85, "saturation": 1.06, "contrast": 1.05, "amount": 1.03, "clouds": 0.02, "rain": 0.0, "mist": 0.0, "shimmer": 1.0},
	"ash": {"tone": Color(0.82, 0.76, 0.74), "mix": 0.55, "strength": 0.2, "soft": 2.0, "saturation": 0.6, "contrast": 0.95, "amount": 0.7, "clouds": 0.6, "rain": 0.0, "mist": 0.1, "ash": 1.0},
	"aurora": {"tone": Color(0.92, 0.97, 1.0), "mix": 0.1, "strength": 1.0, "soft": 0.95, "saturation": 1.0, "contrast": 1.02, "amount": 1.0, "clouds": 0.05, "rain": 0.0, "mist": 0.0, "aurora": 1.0},
	"rainbow": {"tone": Color(0.95, 0.97, 1.0), "mix": 0.15, "strength": 0.8, "soft": 1.2, "saturation": 1.08, "contrast": 1.0, "amount": 0.97, "clouds": 0.3, "rain": 0.0, "mist": 0.05, "rainbow": 1.0},
	"eclipse": {"tone": Color(0.62, 0.66, 0.86), "mix": 0.5, "strength": 0.6, "soft": 1.2, "saturation": 0.75, "contrast": 1.05, "amount": 1.0, "clouds": 0.0, "rain": 0.0, "mist": 0.0, "eclipse": 1.0},
}
## What else a sky can have beside rain and mist, each 0 to 1 (WEATHERS). Every sky() has all of them.
const SKY_EXTRAS := ["snow", "hail", "lightning", "wind", "sand", "ash", "shimmer", "aurora", "rainbow", "eclipse"]
## Only when a scene says so (Campaign.set_weather): too much to come by itself.
const SCENE_WEATHERS := ["storm", "sandstorm", "blizzard", "ash", "eclipse"]
## How likely each sky is, per season, in thousandths: spring, summer, autumn, winter (season_of). PROPOSAL.
const SEASON_ODDS := [
	{"clear": 450, "haze": 100, "overcast": 180, "rain": 160, "fog": 60, "wind": 50},
	{"clear": 520, "haze": 130, "heat": 110, "overcast": 80, "rain": 60, "thunderstorm": 50, "wind": 30, "rainbow": 20},
	{"clear": 380, "haze": 40, "overcast": 220, "rain": 170, "fog": 110, "wind": 80},
	{"clear": 380, "overcast": 220, "snow": 180, "fog": 80, "sleet": 60, "wind": 50, "aurora": 30},
]
const SEASON_NAMES := ["spring", "summer", "autumn", "winter"]
## A foggy morning has lifted by then.
const FOG_THICK_UNTIL := 480
const FOG_GONE_BY := 600
## What colours a day's sunrise and sunset may lean towards.
const DAY_SKIES := [Color(1.0, 0.5, 0.42), Color(1.0, 0.86, 0.6), Color(1.0, 0.62, 0.72), Color(1.0, 0.68, 0.38)]
const DAY_SKY_MOST := 0.4
## The moon goes round in this many days, and is full on the story's first.
const MOON_DAYS := 30
## Below this much of it there is none, by the rule: a new moon is No Moon.
const NO_MOON_BELOW := 0.1
const NIGHT_LOOKS_LIT := [0.34, 0.54]
## The month moves sunrise and sunset by up to this many minutes either way, in steps.
const SEASON_MOST := 60
const SEASON_STEP := 15


## Which part of the day `minute` of it falls in, with the sun up earlier and down later by `shift` minutes.
static func hour_at(minute: int, shift: int = 0) -> int:
	var at: int = posmod(minute, MINUTES_A_DAY)
	if at >= hour_start(Hour.NIGHT, shift) or at < hour_start(Hour.DAWN, shift):
		return Hour.NIGHT
	if at < hour_start(Hour.DAY, shift):
		return Hour.DAWN
	return Hour.DAY if at < hour_start(Hour.DUSK, shift) else Hour.DUSK


## When `hour` begins, with the sun up earlier and down later by `shift` minutes.
static func hour_start(hour: int, shift: int = 0) -> int:
	return HOUR_STARTS[hour] + (shift if hour == Hour.DUSK or hour == Hour.NIGHT else -shift)


## How many minutes `hour` lasts.
static func hour_length(hour: int) -> int:
	var next: int = HOUR_STARTS[(hour + 1) % HOUR_STARTS.size()]
	return posmod(next - HOUR_STARTS[hour], MINUTES_A_DAY)


## How much longer the day is than the middle of the year, on `day` of a year of so many days: the first day is at the middle, and
## it comes in steps, so the same few days keep the same sunrise.
static func season_shift(day: int, days_in_a_year: int) -> int:
	if day <= 0 or days_in_a_year <= 0:
		return 0
	var shift: float = sin(TAU * float(day - 1) / float(days_in_a_year)) * float(SEASON_MOST)
	return roundi(shift / float(SEASON_STEP)) * SEASON_STEP


## A share from 0 to 1 worked out from `day` alone: the same on every machine and on every load.
static func day_share(day: int, salt: int) -> float:
	var mixed: int = (day * 2654435 + salt * 40503 + 977) & 0x7FFFFFFF
	mixed = (mixed ^ (mixed >> 13)) & 0x7FFFFFFF
	mixed = (mixed * 127412) & 0x7FFFFFFF
	mixed = (mixed ^ (mixed >> 11)) & 0x7FFFFFFF
	return float(mixed % 1000) / 1000.0


## Which season `day` falls in, of a year `days_in_a_year` long: 0 spring, 1 summer, 2 autumn, 3 winter, each a quarter of it,
## summer's middle where season_shift has the longest days.
static func season_of(day: int, days_in_a_year: int) -> int:
	if days_in_a_year <= 0:
		return 0
	var at: float = fposmod(float(day - 1) / float(days_in_a_year) + 0.125, 1.0)
	return mini(int(at * 4.0), 3)


## The sky `day` has of itself, by the season when the year's length is known. The story's first is clear.
static func weather_of(day: int, days_in_a_year: int = 0) -> String:
	if day <= 1:
		return "clear"
	if days_in_a_year > 0:
		var odds: Dictionary = SEASON_ODDS[season_of(day, days_in_a_year)]
		var roll: float = day_share(day, 1) * 1000.0
		var so_far := 0.0
		for kind in odds:
			so_far += float(odds[kind])
			if roll < so_far:
				return kind
		return "clear"
	var share := day_share(day, 1)
	if share < 0.5:
		return "clear"
	if share < 0.62:
		return "haze"
	if share < 0.82:
		return "overcast"
	return "rain" if share < 0.92 else "fog"


## Where in its round the moon is on `day`: 0 new, 0.5 full.
static func moon_phase(day: int) -> float:
	return fposmod(float(day - 1) / float(MOON_DAYS) + 0.5, 1.0)


## How much moon there is, at `phase`: 0 to 1.
static func moon_light(phase: float) -> float:
	return 1.0 - absf(phase - 0.5) * 2.0


## The name of it, for the clock's tooltip.
static func moon_name(phase: float) -> String:
	var light := moon_light(phase)
	if light < NO_MOON_BELOW:
		return "new moon"
	if light > 0.9:
		return "full moon"
	return "waxing moon" if phase < 0.5 else "waning moon"


## `minute` on a clock with its sunrise and sunset moved by `shift`, as the same point of the day on the SKY's clock.
static func _on_the_sky_clock(minute: int, shift: int) -> float:
	var at := float(posmod(minute, MINUTES_A_DAY))
	if shift == 0:
		return at
	var marks := [[0.0, 0.0], [300.0 - shift, 300.0], [720.0, 720.0], [1200.0 + shift, 1200.0], [1440.0, 1440.0]]
	for i in range(1, marks.size()):
		if at <= marks[i][0]:
			return lerpf(marks[i - 1][1], marks[i][1], (at - marks[i - 1][0]) / maxf(marks[i][0] - marks[i - 1][0], 1.0))
	return at


## One number off the SKY at `at`, a curve through the marks. Hermite, with each mark's slope from those either side of it.
static func _curve(at: float, read: Callable) -> float:
	var last: int = SKY.size() - 1
	var i := 1
	while i < last and at > float(SKY[i][0]):
		i += 1
	var from: float = float(SKY[i - 1][0])
	var to: float = float(SKY[i][0])
	var gap: float = maxf(to - from, 1.0)
	var t: float = clampf((at - from) / gap, 0.0, 1.0)
	var one: float = read.call(SKY[i - 1])
	var two: float = read.call(SKY[i])
	# Round the end of the day into its beginning: the first and the last are the same moment.
	var before: float = read.call(SKY[i - 2]) if i >= 2 else read.call(SKY[last - 1])
	var before_at: float = float(SKY[i - 2][0]) if i >= 2 else float(SKY[last - 1][0]) - float(MINUTES_A_DAY)
	var after: float = read.call(SKY[i + 1]) if i < last else read.call(SKY[1])
	var after_at: float = float(SKY[i + 1][0]) if i < last else float(SKY[1][0]) + float(MINUTES_A_DAY)
	var slope_one: float = (two - before) / maxf(to - before_at, 1.0) * gap
	var slope_two: float = (after - one) / maxf(after_at - from, 1.0) * gap
	var t2: float = t * t
	var t3: float = t2 * t
	return one * (2.0 * t3 - 3.0 * t2 + 1.0) + slope_one * (t3 - 2.0 * t2 + t) + two * (-2.0 * t3 + 3.0 * t2) + slope_two * (t3 - t2)


## How much of a day's sunrise or sunset colour there is at `at`, on the SKY's clock.
static func _low_sun_share(at: float) -> float:
	var morning: float = smoothstep(340.0, 400.0, at) * (1.0 - smoothstep(420.0, 520.0, at)) * 0.6
	var evening: float = smoothstep(960.0, 1100.0, at) * (1.0 - smoothstep(1170.0, 1250.0, at))
	return maxf(morning, evening)


## The whole sky, by the clock. Everything about how the time of day looks comes from here, and none of it decides anything; none of
## it rolls, so the same day and minute are the same on every machine. `day` 0 is a day with nothing of its own. `moon` is
## moon_phase's. Campaign.sky_now fills it all in for now:
## {"tone", "lean", "strength", "soft", "saturation", "contrast", "amount", "clouds", "rain", "mist", "colour", "life", "sound"}.
## `amount` below 0: under a roof or a rock, where the sun has no say.
static func sky(ambient: int, minute: int, day: int = 0, weather: String = "", place: Color = Color.WHITE, moon: float = 0.5, shift: int = 0) -> Dictionary:
	match ambient:
		Ambient.INTERIOR:
			return _without_extras({"tone": INTERIOR_TONE, "lean": 0.0, "strength": 0.25, "soft": 1.0, "saturation": 0.95, "contrast": 1.0, "amount": -1.0,
				"clouds": 0.0, "rain": 0.0, "mist": 0.0, "colour": Color.BLACK, "life": "", "sound": &""})
		Ambient.UNDERGROUND:
			return _without_extras({"tone": UNDERGROUND_TONE, "lean": 0.0, "strength": 0.15, "soft": 1.0, "saturation": 0.85, "contrast": 1.05, "amount": -1.0,
				"clouds": 0.0, "rain": 0.0, "mist": 0.0, "colour": Color.BLACK, "life": "", "sound": &""})
	var at: float = _on_the_sky_clock(minute, shift)
	var tone := Color(clampf(_curve(at, func(mark): return mark[_TONE].r), 0.0, 1.0), clampf(_curve(at, func(mark): return mark[_TONE].g), 0.0, 1.0),
		clampf(_curve(at, func(mark): return mark[_TONE].b), 0.0, 1.0))
	var lean: float = _curve(at, func(mark): return mark[_LEAN])
	var strength: float = maxf(_curve(at, func(mark): return mark[_STRENGTH]), 0.0)
	var soft: float = maxf(_curve(at, func(mark): return mark[_SOFT]), 0.2)
	var saturation: float = _curve(at, func(mark): return mark[_SATURATION])
	var contrast: float = _curve(at, func(mark): return mark[_CONTRAST])
	var amount: float = clampf(_curve(at, func(mark): return mark[_AMOUNT]), 0.0, 1.0)
	# How far into the day it is, against the night.
	var daylight: float = clampf((amount - 0.46) / 0.54, 0.0, 1.0)
	# The moon, by night: a little brighter and with more of a shadow when it is full.
	var moon_is: float = moon_light(moon)
	var night_share: float = 1.0 - daylight
	amount = lerpf(amount, lerpf(NIGHT_LOOKS_LIT[0], NIGHT_LOOKS_LIT[1], moon_is), night_share * night_share)
	strength *= lerpf(1.0, lerpf(0.25, 1.35, moon_is), night_share * night_share)
	# The day's own sunrise and sunset.
	if day > 0:
		var low: float = _low_sun_share(at)
		if low > 0.0:
			var leaning: Color = DAY_SKIES[int(day_share(day, 2) * float(DAY_SKIES.size())) % DAY_SKIES.size()]
			tone = tone.lerp(leaning, low * day_share(day, 3) * DAY_SKY_MOST)
	# The day's own weather, less of it by night, when there is less to see of it.
	var kind: Dictionary = WEATHERS.get(weather, WEATHERS.clear) if weather != "" else {}
	var clouds := 0.0
	var rain := 0.0
	var mist := 0.0
	var extras := {}
	for extra in SKY_EXTRAS:
		extras[extra] = 0.0
	if not kind.is_empty():
		var thick := 1.0
		if weather == "fog":
			thick = 1.0 - smoothstep(float(FOG_THICK_UNTIL), float(FOG_GONE_BY), at)
		var how_much: float = thick * lerpf(0.5, 1.0, daylight)
		tone = tone.lerp(kind.tone, kind.mix * how_much)
		strength *= lerpf(1.0, kind.strength, thick)
		soft *= lerpf(1.0, kind.soft, thick)
		saturation *= lerpf(1.0, kind.saturation, how_much)
		contrast *= lerpf(1.0, kind.contrast, how_much)
		amount *= lerpf(1.0, kind.amount, thick)
		clouds = kind.clouds * thick * daylight
		rain = kind.rain * thick
		mist = kind.mist * thick
		for extra in SKY_EXTRAS:
			extras[extra] = float(kind.get(extra, 0.0)) * thick
		# Heat off the ground at midday; an aurora by night; a rainbow in the afternoon light; the eclipse darkest at noon.
		extras.shimmer *= daylight * smoothstep(600.0, 760.0, at) * (1.0 - smoothstep(900.0, 1060.0, at))
		extras.aurora *= night_share * night_share
		extras.rainbow *= daylight * smoothstep(780.0, 900.0, at) * (1.0 - smoothstep(1020.0, 1140.0, at))
		extras.eclipse *= daylight * smoothstep(560.0, 720.0, at) * (1.0 - smoothstep(720.0, 880.0, at))
		amount *= 1.0 - 0.62 * extras.eclipse
		strength *= 1.0 - 0.7 * extras.eclipse
		tone = tone.lerp(Color(0.5, 0.55, 0.8), 0.45 * extras.eclipse)
	# A place's own sky: green under trees, grey-blue by the sea.
	tone = Color(tone.r * place.r, tone.g * place.g, tone.b * place.b)
	# Mist low on the ground at dawn, dust in the air at noon, insects at dusk; what is heard goes with them.
	var life := ""
	var sound: StringName = &""
	if rain > 0.0 or extras.hail > 0.0:
		sound = &"rain_falling"
	elif extras.wind > 0.5:
		sound = &"wind_blowing"
	else:
		if at >= 300.0 and at < 540.0:
			mist = maxf(mist, 0.45 * smoothstep(300.0, 380.0, at) * (1.0 - smoothstep(440.0, 540.0, at)))
			sound = &"birds_at_dawn"
		elif at >= 600.0 and at < 900.0:
			life = "dust"
		elif at >= 1020.0 and at < 1230.0:
			life = "insects"
			sound = &"insects_at_dusk"
		elif at >= 1230.0 or at < 300.0:
			sound = &"crickets_at_night"
	# Blue-black at night, warm at dusk: the sky's own colour, nearly gone.
	var colour := Color(tone.r * 0.12, tone.g * 0.1, tone.b * 0.14)
	var whole := {"tone": tone, "lean": lean, "strength": strength, "soft": soft, "saturation": saturation, "contrast": contrast, "amount": amount,
		"clouds": clouds, "rain": rain, "mist": mist, "colour": colour, "life": life, "sound": sound}
	whole.merge(extras)
	return whole


## `sky` with every one of SKY_EXTRAS at 0.
static func _without_extras(sky: Dictionary) -> Dictionary:
	for extra in SKY_EXTRAS:
		sky[extra] = 0.0
	return sky


## The colour over everything, at `minute` of the day, on a day with nothing of its own.
static func tone_at(ambient: int, minute: int) -> Color:
	return sky(ambient, minute).tone


## The grade at `minute` of the day: {"saturation", "contrast"}.
static func grade_at(ambient: int, minute: int) -> Dictionary:
	return sky(ambient, minute)


## How figures' shadows lie at `minute` of the day: {"lean", "strength", "colour", "soft"}.
static func shadow_at(ambient: int, minute: int) -> Dictionary:
	return sky(ambient, minute)


## Whether a light that goes by the clock is lit at `minute`, with its sunrise and sunset moved by `shift`: on around dusk and out
## around dawn, each a little apart from the others by its own `seed`, so that they don't all go at once.
static func lamp_lit_at(minute: int, seed: int, shift: int = 0) -> bool:
	var apart: int = posmod(seed, 61)
	var on: int = hour_start(Hour.DUSK, shift) + 30 + apart
	var off: int = hour_start(Hour.DAY, shift) - 60 + apart
	var at: int = posmod(minute, MINUTES_A_DAY)
	return at >= on or at < off


## The middle of `time`, for something set to a part of the day and no particular minute.
static func minute_of_hour(time: int) -> int:
	return HOUR_STARTS[time] + hour_length(time) / 2


## How figures' shadows lie: how far they lean, in tiles (to the right is positive), and how dark they
## are. Outdoors they lean with the hour; under a roof or a rock they lie straight under them.
static func shadow_of(ambient: int, time: int) -> Dictionary:
	match ambient:
		Ambient.UNDERGROUND:
			return {"lean": 0.0, "strength": 0.15}
		Ambient.INTERIOR:
			return {"lean": 0.0, "strength": 0.25}
	match time:
		Hour.DUSK:
			return {"lean": 0.7, "strength": 0.3}
		Hour.NIGHT:
			return {"lean": 0.0, "strength": 0.12}
		Hour.DAWN:
			return {"lean": -0.7, "strength": 0.3}
	return {"lean": 0.12, "strength": 0.35}


## The lights and ambient areas placed under `root`, as light_map wants them, with `tile_map` saying
## which tile each stands on. Lamps are the stealth map's own (StealthWatch).
static func gather(root: Node, tile_map: TileMap, time: int, no_moon: bool, minute: int = -1, shift: int = 0) -> Dictionary:
	var found := {"sources": [], "areas": []}
	if root == null or tile_map == null:
		return found
	for node in root.find_children("*", "LightSource", true, false):
		var source: Dictionary = node.source_now(tile_map, time, minute, shift)
		if not source.is_empty():
			found.sources.append(source)
	for node in root.find_children("*", "AmbientArea", true, false):
		found.areas.append({"rect": node.tile_rect(tile_map), "level": base_level(node.ambient, time, no_moon)})
	return found
