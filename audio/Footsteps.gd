extends RefCounted
class_name Footsteps
## A step heard as somebody walks (the designer, 2026-11-07: "have their footstep be louder when walking on tiles where its
## rainy"): the SoundBank's "Steps" slots, or a stand-in made on the spot (PlaceholderSounds "step", "step_wet"). Louder, and
## the wet one, where it is raining under the open sky (LightView.rainy_at). Only to hear: nothing here is a rule, so how far a
## guard hears steps is as it was. Headless nothing plays, but `last` still says what would have.

## How loud a step is, on dry ground and on wet, and softly (creeping).
const DRY_DB := -20.0
const WET_DB := -11.0
const SOFTLY_DB := -9.0
## Not more often than this, however many are walking.
const GAP_MS := 90
## How far apart steps fall, in tiles.
const STRIDE_TILES := 0.55

## What was played last: {"wet", "db"} - for a test.
static var last := {}
static var _last_at := -GAP_MS


## A step at `at`, a place in the world.
static func step(at: Vector2, softly: bool = false):
	var now := Time.get_ticks_msec()
	if now - _last_at < GAP_MS:
		return
	_last_at = now
	var wet := LightView.rainy_at(at)
	var db: float = (WET_DB if wet else DRY_DB) + (SOFTLY_DB if softly else 0.0)
	last = {"wet": wet, "db": db}
	if DisplayServer.get_name() == "headless":
		return
	var sound: AudioStream = GameSounds.stream(&"footstep_wet" if wet else &"footstep")
	if sound == null:
		sound = PlaceholderSounds.make("step_wet" if wet else "step")
	GameSounds.play_stream(sound, db)
