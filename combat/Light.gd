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
const DAWN_TONE := Color(0.82, 0.83, 0.88)
const DUSK_TONE := Color(1.0, 0.78, 0.58)
## [minute, tone, lean of a shadow, its strength, saturation, contrast], in order round the day.
const SKY := [
	[0, NIGHT_TONE, 0.0, 0.12, 0.72, 1.02],
	[300, NIGHT_TONE, 0.0, 0.12, 0.72, 1.02],
	[390, DAWN_TONE, -0.7, 0.3, 0.8, 0.98],
	[540, Color.WHITE, -0.25, 0.35, 1.0, 1.0],
	[900, Color.WHITE, 0.25, 0.35, 1.0, 1.0],
	[1110, DUSK_TONE, 0.7, 0.3, 1.14, 1.05],
	[1230, NIGHT_TONE, 0.0, 0.12, 0.72, 1.02],
	[1440, NIGHT_TONE, 0.0, 0.12, 0.72, 1.02],
]


## Which part of the day `minute` of it falls in.
static func hour_at(minute: int) -> int:
	var at: int = posmod(minute, MINUTES_A_DAY)
	if at >= HOUR_STARTS[Hour.NIGHT] or at < HOUR_STARTS[Hour.DAWN]:
		return Hour.NIGHT
	if at < HOUR_STARTS[Hour.DAY]:
		return Hour.DAWN
	return Hour.DAY if at < HOUR_STARTS[Hour.DUSK] else Hour.DUSK


## How many minutes `hour` lasts.
static func hour_length(hour: int) -> int:
	var next: int = HOUR_STARTS[(hour + 1) % HOUR_STARTS.size()]
	return posmod(next - HOUR_STARTS[hour], MINUTES_A_DAY)


## The sky between the two marks either side of `minute`: [one, other, how far between].
static func _sky_at(minute: int) -> Array:
	var at: int = posmod(minute, MINUTES_A_DAY)
	for i in range(1, SKY.size()):
		if at <= SKY[i][0]:
			var gap: float = maxf(float(SKY[i][0] - SKY[i - 1][0]), 1.0)
			return [SKY[i - 1], SKY[i], float(at - SKY[i - 1][0]) / gap]
	return [SKY[0], SKY[0], 0.0]


## The colour over everything, at `minute` of the day.
static func tone_at(ambient: int, minute: int) -> Color:
	match ambient:
		Ambient.INTERIOR:
			return INTERIOR_TONE
		Ambient.UNDERGROUND:
			return UNDERGROUND_TONE
	var sky := _sky_at(minute)
	return sky[0][1].lerp(sky[1][1], sky[2])


## The grade at `minute` of the day: {"saturation", "contrast"}.
static func grade_at(ambient: int, minute: int) -> Dictionary:
	match ambient:
		Ambient.INTERIOR:
			return {"saturation": 0.95, "contrast": 1.0}
		Ambient.UNDERGROUND:
			return {"saturation": 0.85, "contrast": 1.05}
	var sky := _sky_at(minute)
	return {"saturation": lerpf(sky[0][4], sky[1][4], sky[2]), "contrast": lerpf(sky[0][5], sky[1][5], sky[2])}


## How figures' shadows lie at `minute` of the day: as shadow_of says, easing round with the clock.
static func shadow_at(ambient: int, minute: int) -> Dictionary:
	if ambient == Ambient.UNDERGROUND or ambient == Ambient.INTERIOR:
		return shadow_of(ambient, Hour.DAY)
	var sky := _sky_at(minute)
	return {"lean": lerpf(sky[0][2], sky[1][2], sky[2]), "strength": lerpf(sky[0][3], sky[1][3], sky[2])}


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
static func gather(root: Node, tile_map: TileMap, time: int, no_moon: bool) -> Dictionary:
	var found := {"sources": [], "areas": []}
	if root == null or tile_map == null:
		return found
	for node in root.find_children("*", "LightSource", true, false):
		var source: Dictionary = node.source_now(tile_map, time)
		if not source.is_empty():
			found.sources.append(source)
	for node in root.find_children("*", "AmbientArea", true, false):
		found.areas.append({"rect": node.tile_rect(tile_map), "level": base_level(node.ambient, time, no_moon)})
	return found
