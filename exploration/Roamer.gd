@tool
@icon("res://art/editor_icons/interactable.svg")
extends EncounterInteractable
class_name Roamer
## A foe on the roam on an open map (the proposals of 2026-11-19, "Foes that roam"; the designer: "Do all"). A placed fight that
## walks: it wanders its ground, Wander Tiles about where it was put, resting now and then; sees the party within Sight Tiles along a
## line no wall cuts and comes for them, faster; out of sight for Gives Up Seconds it goes back. Meeting the party starts its fight
## as any placed fight does, so an ambush from afar opens it too (OutsideMoves), and beaten it is gone (its trigger cleared). Drawn
## as its encounter's first foe. Nothing here is rolled from a fight's dice. PROPOSAL.

@export var wander_tiles: float = 4.0
@export var sight_tiles: float = 5.0
## Tiles a second, walking its ground and coming for the party.
@export var walk_speed: float = 1.4
@export var chase_speed: float = 2.8
@export var gives_up_seconds: float = 3.0
## How near it has to come to start the fight, in tiles.
@export var meets_within: float = 0.75

enum Mood { WANDERING, CHASING, GOING_BACK }

var mood := Mood.WANDERING
var _home := Vector2.ZERO
var _aim := Vector2.ZERO
var _resting := 0.0
var _unseen := 0.0
var _figure: CombatantSprite = null
var _rng := RandomNumberGenerator.new()
var _met := false
## For a suite: how many times it has seen the party and come for them.
var chases := 0


func _init():
	prompt = "Fight"


func _ready():
	super()
	if Engine.is_editor_hint() or not visible:
		return
	_home = global_position
	_aim = global_position
	_rng.seed = hash(trigger_id)
	_resting = _rng.randf_range(0.2, 1.5)
	var definition := _first_foe()
	if definition != null:
		_figure = CombatantSprite.new()
		add_child(_figure)
		_figure.setup(definition.sprite_frames, definition.map_sprite, false)


func _first_foe() -> CombatantDefinition:
	if encounter == null:
		return null
	for spawn in encounter.spawns:
		if spawn != null and spawn.side != 0:
			return CombatantDatabase.combatants.get(spawn.combatant_key)
	return null


func _scene() -> Node:
	var up := get_parent()
	while up != null:
		if up.has_method("is_walkable") and up.has_method("party_position"):
			return up
		up = up.get_parent()
	return null


## Held still a while (the stopped clock, Memento): it neither walks nor sees nor meets anybody.
func hold_still(seconds: float):
	_held = maxf(_held, seconds)


var _held := 0.0


func _process(delta: float):
	if Engine.is_editor_hint() or not visible or _met or not is_available():
		return
	if _held > 0.0:
		_held -= delta
		return
	var scene := _scene()
	if scene == null or scene.get("stealth") != null or scene.is_holding():
		return
	var party: Vector2 = scene.party_position()
	var sees := sees_party(scene)
	match mood:
		Mood.WANDERING, Mood.GOING_BACK:
			if sees:
				mood = Mood.CHASING
				chases += 1
				_unseen = 0.0
				MapFeel.sound(&"roamer_sees", -4.0, 1.0, global_position)
				MapFeel.spawn(get_parent(), &"ring", position, {"colour": Color(0.95, 0.4, 0.3)})
			elif mood == Mood.GOING_BACK and global_position.distance_to(_home) < Grid.tiles(0.3):
				mood = Mood.WANDERING
			elif mood == Mood.WANDERING:
				if global_position.distance_to(_aim) < Grid.tiles(0.15):
					_resting -= delta
					if _resting <= 0.0:
						_aim = _wander_point(scene)
						_resting = _rng.randf_range(1.0, 3.0)
		Mood.CHASING:
			_aim = party
			_unseen = 0.0 if sees else _unseen + delta
			if _unseen >= gives_up_seconds:
				mood = Mood.GOING_BACK
	if mood == Mood.GOING_BACK:
		_aim = _home
	var speed := chase_speed if mood == Mood.CHASING else walk_speed
	_walk_towards(scene, _aim, Grid.tiles(speed) * delta)
	if global_position.distance_to(party) <= Grid.tiles(meets_within):
		_met = true
		use(scene)


## Whether it sees the party: near enough, and no wall across the line between.
func sees_party(scene: Node) -> bool:
	var party: Vector2 = scene.party_position()
	if global_position.distance_to(party) > Grid.tiles(sight_tiles):
		return false
	var tile_map: TileMap = scene.get("_tile_map")
	if tile_map == null:
		return true
	var walls: Dictionary = scene.get("_blocking_fliers")
	var steps := int(ceil(global_position.distance_to(party) / Grid.tiles(0.25)))
	for i in range(1, steps):
		var at := global_position.lerp(party, float(i) / float(steps))
		if walls.has(tile_map.local_to_map(tile_map.to_local(at))):
			return false
	return true


func _wander_point(scene: Node) -> Vector2:
	for attempt in 8:
		var angle := _rng.randf() * TAU
		var reach := _rng.randf_range(1.0, wander_tiles)
		var at := _home + Vector2(cos(angle), sin(angle)) * Grid.tiles(reach)
		if scene.is_walkable(at):
			return at
	return _home


## A step along the way, each axis apart, as the party walks: sliding along a wall rather than stopping dead.
func _walk_towards(scene: Node, target: Vector2, most: float):
	var way := target - global_position
	if way.length() < 1.0:
		return
	var step := way.limit_length(most)
	var moved := global_position
	if scene.is_walkable(moved + Vector2(step.x, 0)):
		moved.x += step.x
	if scene.is_walkable(moved + Vector2(0, step.y)):
		moved.y += step.y
	if _figure != null:
		if absf(step.x) > 0.5:
			_figure.set_facing(step.x < 0.0)
		if moved != global_position:
			_figure.play_walk()
		else:
			_figure.play_idle()
	global_position = moved


func _draw():
	super()
	if Engine.is_editor_hint():
		draw_arc(Vector2.ZERO, Grid.tiles(wander_tiles), 0.0, TAU, 48, Color(0.9, 0.4, 0.3, 0.5), 2.0)
		draw_arc(Vector2.ZERO, Grid.tiles(sight_tiles), 0.0, TAU, 48, Color(0.95, 0.75, 0.3, 0.35), 2.0)
