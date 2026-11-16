class_name Rumble
## A controller's rumble (the proposals of 2026-11-16, section 7; the designer, 2026-11-17). A tap for a hit, a thump for a heavy
## one or a fall, a roll for thunder and a wall coming down, a heartbeat while one of the party is near death. Feel only: nothing
## is rolled or decided here, and nothing happens on a keyboard, with the dial at nothing (Comfort.RUMBLE) or headless.
##
## All strengths and lengths are PROPOSAL. `asked` counts what was asked for and `last` keeps the last of it, whether or not a pad
## was there to feel it, so a suite can check a hook without one.

## The longest any one rumble may last, so a mistake never leaves a pad buzzing.
const LONGEST := 1.2
## The gap between a heartbeat's two beats, and between heartbeats.
const HEART_GAP := 0.16
const HEART_EVERY := 1.05

static var asked := 0
static var last := {}
static var _heart_wait := 0.0


## A light, short buzz: a blow landing, a button refused.
static func tap(strength: float = 0.4, seconds: float = 0.1):
	_go(strength, 0.0, seconds, &"tap")


## A heavy one: a big blow, somebody falling.
static func thump(strength: float = 0.8, seconds: float = 0.22):
	_go(strength * 0.5, strength, seconds, &"thump")


## A long low roll: thunder, a wall coming down.
static func roll(strength: float = 0.6, seconds: float = 0.7):
	_go(strength * 0.3, strength, seconds, &"roll")


## For a blow that took `share` of somebody's health (0 to 1): nothing for a scratch, a tap, or a thump from a third up.
static func blow(share: float, lethal: bool = false):
	if lethal:
		thump(1.0, 0.3)
	elif share >= 0.33:
		thump(lerpf(0.6, 1.0, clampf(inverse_lerp(0.33, 1.0, share), 0.0, 1.0)), 0.2)
	elif share >= 0.04:
		tap(lerpf(0.25, 0.6, clampf(inverse_lerp(0.04, 0.33, share), 0.0, 1.0)), 0.09)


## Called every frame while one of the party is near death: two soft beats, again and again. `delta` in real seconds.
static func heartbeat(delta: float, strength: float = 0.35):
	_heart_wait -= delta
	if _heart_wait > 0.0:
		return
	_heart_wait = HEART_EVERY
	_go(0.0, strength, 0.07, &"heart")
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		tree.create_timer(HEART_GAP, true, false, true).timeout.connect(func(): _go(0.0, strength * 0.7, 0.07, &"heart"))


## Stops every pad now (leaving a fight, a menu opening).
static func stop():
	for device in Input.get_connected_joypads():
		Input.stop_joy_vibration(device)


static func _go(weak: float, strong: float, seconds: float, kind: StringName):
	var share := Comfort.share(Comfort.RUMBLE)
	asked += 1
	last = {"kind": kind, "weak": weak * share, "strong": strong * share, "seconds": minf(seconds, LONGEST)}
	if share <= 0.0 or DisplayServer.get_name() == "headless":
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var pad = tree.root.get_node_or_null("Pad")
	if pad == null or not pad.using_pad:
		return
	for device in Input.get_connected_joypads():
		Input.start_joy_vibration(device, clampf(weak * share, 0.0, 1.0), clampf(strong * share, 0.0, 1.0), minf(seconds, LONGEST))
