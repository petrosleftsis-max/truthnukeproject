extends Control
class_name InfiltrateBoard
## Node Infiltration (HackDefinition.Kind.INFILTRATE): a grid of nodes, some of
## the links between them cut, Prometheus on the left and the core on the right.
## A move is to a linked node, or waiting where he is; after every move the
## sentinels each take a step along their beat, back and forth. Ending a move on
## a sentinel, or passing one on a link, is being caught. The core within the
## moves allowed is in.
##
## Every layout is made fresh and checked to have a way through in the moves it
## allows (_way_through) before it is shown; a hint shows that way and where
## the sentinels go next, and making it simpler takes a sentinel off the board.

signal solved
signal failed_try(reason: String)

const NODE_SIZE := Vector2(40, 40)
const MARGIN := Vector2(36, 28)

var hack: HackDefinition = null
var colours := {}
## grid tile -> the tiles it links to.
var links := {}
var start := Vector2i.ZERO
var core := Vector2i.ZERO
## Each a back-and-forth beat: {"beat": Array of tiles, "offset": int}.
var sentinels: Array = []
var player := Vector2i.ZERO
## Moves made this try.
var moves := 0
var move_limit := 0
## Sentinels a gate has taken off: kept off for every try after.
var removed := 0
## The way through a hint has shown, and the sentinels' next steps.
var shown_way: Array = []
var shown_ahead: Array = []

var _buttons := {}
var _status: Label = null
var _wait: Button = null
var _over := false


func setup(h: HackDefinition, rng: RandomNumberGenerator, palette: Dictionary):
	hack = h
	colours = palette
	custom_minimum_size = Vector2(MARGIN.x * 2 + (h.width - 1) * 92 + NODE_SIZE.x, MARGIN.y * 2 + (h.height - 1) * 70 + NODE_SIZE.y + 44)
	_status = Label.new()
	_status.add_theme_color_override("font_color", colours.dim)
	if colours.has("font"):
		_status.add_theme_font_override("font", colours.font)
	add_child(_status)
	_wait = Button.new()
	_wait.text = "Wait"
	_wait.pressed.connect(func(): move_to(player))
	add_child(_wait)
	reset_try(rng)


## A fresh layout, with a way through it.
func reset_try(rng: RandomNumberGenerator):
	for button in _buttons.values():
		button.queue_free()
	_buttons.clear()
	shown_way = []
	shown_ahead = []
	_over = false
	move_limit = 0
	player = start
	moves = 0
	_hinted_at = Vector3i(-1, -1, -1)
	var guards: int = maxi(hack.sentinels - removed, 0)
	for attempt in 40:
		_lay_out(rng, guards)
		var way := _way_through(0)
		if not way.is_empty():
			move_limit = way.size() - 1 + hack.spare_moves
			break
		if attempt == 39 and guards > 0:
			guards -= 1
	player = start
	moves = 0
	_make_buttons()
	_refresh()


func _lay_out(rng: RandomNumberGenerator, guards: int):
	links.clear()
	for x in hack.width:
		for y in hack.height:
			links[Vector2i(x, y)] = []
	# A tree first, so everything is reached; then the rest of the grid's links,
	# each kept unless cut.
	var tiles: Array = links.keys()
	var seen := {tiles[0]: true}
	var frontier: Array = [tiles[0]]
	while not frontier.is_empty():
		var at: Vector2i = frontier.pop_at(rng.randi() % frontier.size())
		var ways := _grid_neighbours(at)
		ways.shuffle()
		for next in ways:
			if not seen.has(next):
				seen[next] = true
				_link(at, next)
				frontier.append(next)
				frontier.append(at)
				break
	for at in tiles:
		for next in _grid_neighbours(at):
			if not links[at].has(next) and rng.randf() >= hack.cut_links:
				_link(at, next)
	start = Vector2i(0, rng.randi() % hack.height)
	core = Vector2i(hack.width - 1, rng.randi() % hack.height)
	sentinels = []
	for i in guards:
		var from: Vector2i = tiles[rng.randi() % tiles.size()]
		var tries := 0
		while (from == start or from == core or from.x == 0) and tries < 30:
			from = tiles[rng.randi() % tiles.size()]
			tries += 1
		var beat: Array = [from]
		for step in 2 + rng.randi() % 3:
			var options: Array = links[beat.back()].filter(func(t): return t != start and not beat.has(t))
			if options.is_empty():
				break
			beat.append(options[rng.randi() % options.size()])
		# Back and forth along it.
		var there_and_back := beat.duplicate()
		for i2 in range(beat.size() - 2, 0, -1):
			there_and_back.append(beat[i2])
		sentinels.append({"beat": there_and_back, "offset": rng.randi() % there_and_back.size()})


func _grid_neighbours(at: Vector2i) -> Array:
	var found := []
	for way in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		if links.has(at + way):
			found.append(at + way)
	return found


func _link(a: Vector2i, b: Vector2i):
	if not links[a].has(b):
		links[a].append(b)
	if not links[b].has(a):
		links[b].append(a)


## Where sentinel `s` is after `t` moves.
func sentinel_at(s: Dictionary, t: int) -> Vector2i:
	return s.beat[(s.offset + t) % s.beat.size()]


## Whether moving from `from` to `to` as move `t` (1 for the first) is caught.
func caught(from: Vector2i, to: Vector2i, t: int) -> bool:
	for s in sentinels:
		var now := sentinel_at(s, t)
		var before := sentinel_at(s, t - 1)
		if now == to or (now == from and before == to):
			return true
	return false


## The fewest moves from where he is now (after `made` moves) to the core,
## every tile of the way - [] for none within the limit (or within the grid's
## size before there is a limit).
func _way_through(made: int) -> Array:
	var limit := move_limit if move_limit > 0 else hack.width * hack.height * 2
	var from := player if made > 0 else start
	# A state is where he is and how many moves have been made: (x, y, moves).
	var first := Vector3i(from.x, from.y, made)
	var came := {first: first}
	var queue: Array = [first]
	while not queue.is_empty():
		var state: Vector3i = queue.pop_front()
		var at := Vector2i(state.x, state.y)
		if at == core:
			var way: Array = []
			var back := state
			while true:
				way.push_front(Vector2i(back.x, back.y))
				if came[back] == back:
					break
				back = came[back]
			return way
		if state.z >= limit:
			continue
		for next in links[at] + [at]:
			var key := Vector3i(next.x, next.y, state.z + 1)
			if came.has(key) or caught(at, next, state.z + 1):
				continue
			came[key] = state
			queue.append(key)
	return []


## Moves to `to` - a linked node, or where he is to wait. False when it is not
## one he can move to.
func move_to(to: Vector2i) -> bool:
	if _over or (to != player and not links[player].has(to)):
		return false
	moves += 1
	var from := player
	player = to
	shown_way = []
	shown_ahead = []
	if caught(from, to, moves):
		_over = true
		_refresh()
		failed_try.emit("A sentinel caught him.")
		return true
	if player == core:
		_over = true
		_refresh()
		solved.emit()
		return true
	if moves >= move_limit:
		_over = true
		_refresh()
		failed_try.emit("Out of moves - the trace found him.")
		return true
	_refresh()
	return true


## Shows the way through from here, and where the sentinels step next.
## Whether a hint would show anything not on show already: the way from here,
## once for every node he stands on.
func hint_available() -> bool:
	return _hinted_at != Vector3i(player.x, player.y, moves)


## Whether there is no way through from where he stands, in the moves left -
## asked before a hint is paid for.
func dead_end() -> bool:
	return _way_through(moves).is_empty()


## Where he stood, and how many moves in, when the way was last shown.
var _hinted_at := Vector3i(-1, -1, -1)


func hint() -> bool:
	var way := _way_through(moves)
	_hinted_at = Vector3i(player.x, player.y, moves)
	if way.is_empty():
		return false
	shown_way = way
	shown_ahead = []
	for s in sentinels:
		for step in range(1, 4):
			shown_ahead.append(sentinel_at(s, moves + step))
	_refresh()
	return true


## Takes a sentinel off - now, and for every try after.
func simplify():
	removed += 1
	if not sentinels.is_empty():
		sentinels.pop_back()
	_refresh()


func _node_point(tile: Vector2i) -> Vector2:
	return MARGIN + Vector2(tile.x * 92, tile.y * 70) + Vector2(0, 40)


func _make_buttons():
	for tile in links:
		var button := Button.new()
		button.custom_minimum_size = NODE_SIZE
		button.size = NODE_SIZE
		button.position = _node_point(tile)
		button.pressed.connect(func(): move_to(tile))
		add_child(button)
		_buttons[tile] = button


func _refresh():
	for tile in _buttons:
		var button: Button = _buttons[tile]
		button.text = "@" if tile == player else ("◆" if tile == core else "")
		button.disabled = _over or (tile != player and not links[player].has(tile))
		button.modulate = colours.good if tile == core else (colours.bright if tile == player else Color.WHITE)
	_status.text = "Moves %d / %d      %s" % [moves, move_limit, "Reach the core on the right." if not _over else ""]
	_status.position = Vector2(MARGIN.x, 4)
	_wait.position = Vector2(size.x - 90 if size.x > 0 else custom_minimum_size.x - 90, 0)
	_wait.disabled = _over
	queue_redraw()


func _draw():
	var half := NODE_SIZE * 0.5
	for a in links:
		for b in links[a]:
			if a < b:
				var lit := shown_way.has(a) and shown_way.has(b) and absi(shown_way.find(a) - shown_way.find(b)) == 1
				draw_line(_node_point(a) + half, _node_point(b) + half, colours.good if lit else colours.dim, 4.0 if lit else 2.0)
	for tile in shown_ahead:
		draw_circle(_node_point(tile) + half, 24.0, Color(colours.danger, 0.25))
	for s in sentinels:
		var at := sentinel_at(s, moves)
		var c := _node_point(at) + half
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -16), c + Vector2(16, 0), c + Vector2(0, 16), c + Vector2(-16, 0)]), colours.danger)


func first_focus() -> Control:
	for tile in links.get(player, []):
		if _buttons.has(tile):
			return _buttons[tile]
	return _wait
