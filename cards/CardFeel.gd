extends RefCounted
class_name CardFeel
## How the card game feels (docs/card_game.md "How it feels"; the designer, 2026-11-26: all of
## docs/proposals_2026-11-26_card_juice.md but section 11, the enemies alive by their own idle animations, slower when hurt): the
## pace things play at, its sounds, how hard a blow stops and shakes the screen. Only to look at and hear: nothing here is rolled on
## a fight's own numbers or decides anything, and headless nothing moves (but for a suite that sets plays_headless), so the suite
## still plays a whole fight in a frame. Every timing is PROPOSAL.

## The share of every gap and flight that Fast plays at (Options, "Card game: fast"; Comfort.card_fast).
const FAST := 0.5
## At or under this share of their most health, the player feels a heartbeat (the tactics fights' CombatUI.NEAR_DEATH, 0.2).
const NEAR_DEATH := 0.2

## Set by a suite that wants to see it all played with nobody watching.
static var plays_headless := false
## What was played, counted whether or not it was seen, for a suite.
static var seen := {}


## Whether anything moves: never headless, unless a suite asks.
static func shown() -> bool:
	return DisplayServer.get_name() != "headless" or plays_headless


## `seconds` at the pace chosen in Options: half at Fast.
static func time(seconds: float) -> float:
	return seconds * (FAST if Comfort.card_fast() else 1.0)


static func note(what: StringName):
	seen[what] = int(seen.get(what, 0)) + 1


## Plays the sound bank's slot `slot` (SoundBank "The card game"), or its stand-in while it is empty (PlaceholderSounds).
static func sound(slot: StringName, volume_db: float = -6.0, pitch: float = 1.0):
	note(slot)
	MapFeel.sound(slot, volume_db, pitch)


## How long a blow that took `lost` off somebody of `most` health stops the screen, by the tactics fights' own thresholds
## (Combat.hit_stop_for): nothing for a scratch, a moment from HIT_STOP_FROM of their health, a full beat from HEAVY_SHARE, the
## longest for the blow that fells them.
static func stop_for(lost: int, most: int, lethal: bool = false) -> float:
	if lost <= 0 or most <= 0:
		return 0.0
	if lethal:
		return Combat.HIT_STOP_KILL
	var share := clampf(float(lost) / float(most), 0.0, 1.0)
	if share < Combat.HIT_STOP_FROM:
		return 0.0
	if share < Combat.HEAVY_SHARE:
		return Combat.HIT_STOP_MINIMUM
	return lerpf(Combat.HIT_STOP_HEAVY, Combat.HIT_STOP_MAXIMUM, inverse_lerp(Combat.HEAVY_SHARE, 1.0, share))


## How many pixels such a blow shakes the screen (Combat.shake_for): none under HEAVY_SHARE, more the more it took, SHAKE_KILL for
## the blow that fells them. The Screen shake dial (Comfort) is the caller's to apply.
static func shake_for(lost: int, most: int, lethal: bool = false) -> float:
	if lethal:
		return Combat.SHAKE_KILL
	if lost <= 0 or most <= 0:
		return 0.0
	var share := clampf(float(lost) / float(most), 0.0, 1.0)
	if share < Combat.HEAVY_SHARE:
		return 0.0
	return lerpf(Combat.SHAKE_HEAVY, Combat.SHAKE_MOST, inverse_lerp(Combat.HEAVY_SHARE, 1.0, share))


## Whether a blow is heavy enough for the heavy sound: a quarter of their health (Combat.HEAVY_SHARE), or the last.
static func heavy(lost: int, most: int, lethal: bool = false) -> bool:
	return lethal or (most > 0 and float(lost) / float(most) >= Combat.HEAVY_SHARE)


## A tween on `node` that a blow's stop does not freeze when `steady` (the interface's own answers), else one that it does.
static func tween_on(node: Node, steady: bool = false) -> Tween:
	var tween := node.create_tween()
	if steady:
		tween.set_ignore_time_scale(true)
	return tween
