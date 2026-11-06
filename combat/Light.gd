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
