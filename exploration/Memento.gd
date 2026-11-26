extends RefCounted
class_name Memento
## Things that remember (the proposals of 2026-11-19; the designer: "Do all"): ordinary objects charged with a memory, each with one
## strange rule, used out of a fight from the Items tab by whoever carries them (OutsideMoves STOP_TIME, LOOK_BACK, FIND_THE_WAY) and
## never used up - a breath between uses, as any move with no gate. Kept out of fights (keepsakes). PROPOSAL.
## - The stopped clock (STOP_TIME): every guard within STOP_TILES stands blind and still a moment, every roamer too.
## - The lighthouse lens (LOOK_BACK): every hidden mark within LENS_TILES shows a while, whatever the light (HiddenMark).
## - The child's shoe (FIND_THE_WAY): small prints glow on the ground from the party towards the newest pin, or the goal.

const STOP_TILES := 5.0
const STOP_SECONDS := 4.0
const LENS_TILES := 7.0
const LENS_SECONDS := 10.0
const WAY_TILES := 12
const WAY_EVERY_TILES := 0.8

## For a suite: how many times each has been used.
static var used := {}


## Uses memento `skill` of `key`'s on the map `scene`, as `kind` says. True when it did anything.
static func use(scene: Node, key: String, skill: SkillDefinition, kind: int) -> bool:
	var who := Campaign.display_name_of(key)
	var at: Vector2 = scene.party_position()
	var said := ""
	match kind:
		OutsideMoves.Use.STOP_TIME:
			var held := 0
			var watch = scene.get("stealth")
			if watch != null and is_instance_valid(watch):
				for guard in watch.guards:
					if is_instance_valid(guard) and not guard.knocked_out and guard.global_position.distance_to(at) <= Grid.tiles(STOP_TILES):
						watch.spellbind(guard, Guard.Mood.BLINDED, STOP_SECONDS, key)
						held += 1
			var map: Node = scene.get_node_or_null("Map")
			if map != null:
				for roamer in map.find_children("*", "Roamer", true, false):
					if roamer.global_position.distance_to(at) <= Grid.tiles(STOP_TILES):
						roamer.hold_still(STOP_SECONDS)
						held += 1
			MapFeel.sound(&"shift", -2.0, 1.6, at)
			said = "[color=yellow]%s[/color] winds the stopped clock back a breath: %s." % [who,
					"for a moment nothing near moves" if held > 0 else "nothing near to hold"]
		OutsideMoves.Use.LOOK_BACK:
			HiddenMark.lens_at = at
			HiddenMark.lens_until = Time.get_ticks_msec() + int(LENS_SECONDS * 1000.0)
			MapFeel.sound(&"mark_seen", -2.0, 0.8, at)
			said = "[color=yellow]%s[/color] looks through the lighthouse lens: the room as it was shows a while." % who
		OutsideMoves.Use.FIND_THE_WAY:
			var target: Vector2 = scene.memory.way_target() if scene.get("memory") != null else Vector2.INF
			if not target.is_finite():
				said = "[color=yellow]%s[/color] holds the child's shoe: it knows no way to go - put a pin on the map." % who
			else:
				var way := (target - at).normalized()
				var reach := minf(at.distance_to(target), Grid.tiles(WAY_TILES))
				var step := Grid.tiles(WAY_EVERY_TILES)
				var place := step
				while place < reach:
					LightView.leave_print(at + way * place, way)
					place += step
				MapFeel.sound(&"secret_found", -6.0, 1.3, at)
				said = "[color=yellow]%s[/color] sets the child's shoe down: small prints glow, leading the way." % who
		_:
			return false
	used[kind] = int(used.get(kind, 0)) + 1
	if scene.has_method("log_message"):
		scene.log_message(said + "\n")
	return true
