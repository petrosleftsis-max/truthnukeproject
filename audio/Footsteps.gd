extends RefCounted
class_name Footsteps
## A step heard as somebody walks (the designer, 2026-11-07: "have their footstep be louder when walking on tiles where its
## rainy"): the SoundBank's "Steps" slots, or a stand-in made on the spot (PlaceholderSounds "step", "step_wet"). Louder, and
## the wet one, where it is raining under the open sky (LightView.rainy_at) or they wade through a map's water (in_water). Only to hear: nothing here is a rule, so how far a
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
## Where the last step was, for which way the next print points.
static var _stepped_from := Vector2.INF
static var _last_at := -GAP_MS
## Coming out of water, the next few steps leave dark prints, each fainter (the proposals of 2026-11-16, section 1). PROPOSAL.
const WET_PRINTS := 7
static var _wet_left := 0


## Told as they walk, every frame they move (ExplorationParty): whoever is at `at` is in water now, so their next steps out of
## it are wet. A step is heard only every stride, and by then they may be out of the water they crossed.
static func walked_through(at: Vector2):
	if LightView.in_water(at):
		_wet_left = WET_PRINTS


## --- A guard heard before seen ---
##
## The proposals of 2026-11-17, section 4. A guard's step (Guard, as they walk) is heard from where they are (SoundFollows "Sound with
## a place": from their side of the screen, gone a few tiles past its edge, dulled behind a wall), quietly, and only while they are
## within GUARD_HEARD_TILES of where the party last stepped: so somebody coming round a corner is heard first. The sound bank's
## Guard Step, a stand-in meanwhile. Only heard: nothing a guard does changes for it. PROPOSAL.
const GUARD_STEP_TILES := 0.6
const GUARD_HEARD_TILES := 9.0
const GUARD_STEP_DB := -17.0
## How many guards' steps there have been, for a suite.
static var guard_steps := 0


## A guard's step at `at`, a place in the world.
static func guard_step(at: Vector2):
	if _stepped_from != Vector2.INF and at.distance_to(_stepped_from) > Grid.tiles(GUARD_HEARD_TILES):
		return
	guard_steps += 1
	if DisplayServer.get_name() == "headless":
		return
	var sound: AudioStream = GameSounds.stream(&"guard_step")
	if sound == null:
		sound = PlaceholderSounds.make("guard_step")
	GameSounds._start_at(sound, at, GUARD_STEP_DB)


## A step at `at`, a place in the world.
static func step(at: Vector2, softly: bool = false):
	var now := Time.get_ticks_msec()
	if now - _last_at < GAP_MS:
		return
	_last_at = now
	# A print and a splash, where the ground takes them (LightView "The weather on the ground").
	var way: Vector2 = at - _stepped_from if _stepped_from != Vector2.INF and at.distance_to(_stepped_from) < Grid.tiles(3.0) else Vector2.ZERO
	_stepped_from = at
	LightView.leave_print(at, way)
	LightView.splash(at)
	if LightView.in_water(at):
		_wet_left = WET_PRINTS
	elif _wet_left > 0:
		LightView.leave_wet_print(at, way, float(_wet_left) / float(WET_PRINTS))
		_wet_left -= 1
	var wet := LightView.rainy_at(at) or LightView.in_water(at)
	var db: float = (WET_DB if wet else DRY_DB) + (SOFTLY_DB if softly else 0.0)
	last = {"wet": wet, "db": db}
	if DisplayServer.get_name() == "headless":
		return
	var sound: AudioStream = GameSounds.stream(&"footstep_wet" if wet else &"footstep")
	if sound == null:
		sound = PlaceholderSounds.make("step_wet" if wet else "step")
	GameSounds._start_at(sound, at, db)
