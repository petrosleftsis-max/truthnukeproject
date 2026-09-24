extends Node
## A combatant drawn taller than its tile stands on the tile rather than
## sinking into it, and whoever is nearer the bottom of the screen draws in
## front.
##
## Both are about to matter: the art is going to double in height while the
## tiles stay as they are. Neither could show while a sprite was exactly one
## tile, because then nothing overlapped and nothing needed lifting.

var LOG_PATH := HarnessLog.path_for("tallsprite")
var _log: FileAccess
var _fail = 0

func log_line(t): _log.store_line(t); _log.flush()

func ok(condition: bool, label: String, detail: String = ""):
	if condition:
		log_line("  PASS  %s %s" % [label, detail])
	else:
		_fail += 1
		log_line("  FAIL  %s %s" % [label, detail])


func _ready():
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	get_tree().create_timer(180.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


## A SpriteFrames whose idle frame is `height` tall, to stand a sprite up with.
func frames_of_height(height: int) -> SpriteFrames:
	var image = Image.create(Grid.TILE_SIZE, height, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var frames = SpriteFrames.new()
	frames.add_animation("idle")
	frames.add_frame("idle", ImageTexture.create_from_image(image))
	return frames


func run_test():
	log_line("======== feet land on the tile, whatever the frame height ========")
	# Worked out from Grid rather than from the numbers that happen to be right
	# today, so changing the tile size cannot quietly break this.
	for height in [Grid.TILE_SIZE, Grid.TILE_SIZE * 2, int(Grid.TILE_SIZE * 1.5)]:
		var sprite = CombatantSprite.new()
		add_child(sprite)
		sprite.setup(frames_of_height(height), null, false)
		await get_tree().process_frame
		var drawn: AnimatedSprite2D = sprite._animated
		# Where the bottom edge of the frame ends up, relative to the tile
		# centre the sprite is positioned on. Half a tile down is the floor.
		var feet = drawn.offset.y + float(height) / 2.0
		ok(is_equal_approx(feet, Grid.HALF_TILE.y),
			"a frame %d tall stands its feet on the tile floor" % height,
			"feet at %.0f, floor at %.0f" % [feet, Grid.HALF_TILE.y])
		ok(is_equal_approx(sprite.head_height(), maxf(height - Grid.TILE_SIZE, 0.0)),
			"and reports how far it reaches above the tile",
			"%.0f" % sprite.head_height())
		sprite.queue_free()
	log_line("")

	log_line("======== the combatant layer sorts by where feet are ========")
	Campaign.reset()
	Campaign.current_encounter = load("res://encounters/encounter_02_sappers.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	for i in 6:
		await get_tree().process_frame
	var combat = game.get_node("VisualCombat")
	if combat.deployment_active:
		combat.finish_deployment()
		await get_tree().process_frame

	var layer = combat.combatant_layer()
	ok(layer != null, "there is a layer for them to live on")
	ok(layer != null and layer.y_sort_enabled,
		"and it is y-sorted, so spawn order stops deciding who is in front")
	ok(layer != null and layer.name == "Combatants", "named for what it holds",
		layer.name if layer != null else "-")
	# Asked twice, because it is built on demand and a second one would put
	# half the cast on a layer that does not sort against the other half.
	ok(is_same(layer, combat.combatant_layer()), "and there is only ever one of it")

	var strays := []
	for comb in combat.combatants:
		var sprite = comb.get("sprite")
		if sprite != null and is_instance_valid(sprite) and sprite.get_parent() != layer:
			strays.append(comb.name)
	ok(strays.is_empty(), "everybody in the fight is on it", "%s" % [strays])
	ok(not combat.combatants.is_empty(), "and there is somebody in the fight",
		"%d" % combat.combatants.size())

	# Sorting reads position, which is the tile centre - the lift lives on the
	# sprite's offset. If position ever drifted to the drawn middle, a tall
	# combatant would sort as though standing a tile further back.
	var off := []
	for comb in combat.combatants:
		var sprite = comb.get("sprite")
		if sprite != null and is_instance_valid(sprite) \
				and sprite.position != Grid.tile_to_world(comb.position):
			off.append("%s %s vs %s" % [comb.name, sprite.position, Grid.tile_to_world(comb.position)])
	ok(off.is_empty(), "and every sprite sits on its own tile centre", "%s" % [off])
	log_line("")

	log_line("======== a damage number clears the head ========")
	var someone = combat.combatants[0]
	var their_sprite = someone.get("sprite")
	ok(their_sprite != null, "somebody to hurt")
	if their_sprite != null:
		var before = their_sprite.get_parent().get_child_count()
		combat.float_number(someone, "7", Color.WHITE)
		# Read before yielding: a floater starts drifting upward the moment it
		# is in the tree, so a frame later it has already left where it began
		# and the lift measures two pixels more than it was given.
		var after = their_sprite.get_parent().get_child_count()
		ok(after > before, "a number is put on the field", "%d -> %d" % [before, after])
		var floater = their_sprite.get_parent().get_child(after - 1)
		var lift = their_sprite.position.y - floater.position.y
		ok(is_equal_approx(lift, their_sprite.head_height()),
			"raised by exactly how far the sprite reaches above its tile",
			"%.0f lifted, %.0f tall" % [lift, their_sprite.head_height()])

		# Which so far only says zero equals zero, because the art is still one
		# tile. Stand somebody twice as tall in their place and ask again - the
		# case this exists for, and the one nobody can check by eye yet.
		var tall = CombatantSprite.new()
		layer.add_child(tall)
		tall.position = their_sprite.position
		tall.setup(frames_of_height(Grid.TILE_SIZE * 2), null, false)
		someone["sprite"] = tall
		await get_tree().process_frame
		ok(is_equal_approx(tall.head_height(), float(Grid.TILE_SIZE)),
			"a double-height combatant reaches a whole tile above their own",
			"%.0f" % tall.head_height())
		var was = layer.get_child_count()
		combat.float_number(someone, "7", Color.WHITE)
		var tall_floater = layer.get_child(layer.get_child_count() - 1)
		ok(layer.get_child_count() > was, "a number is put on the field for them too")
		var tall_lift = tall.position.y - tall_floater.position.y
		ok(is_equal_approx(tall_lift, float(Grid.TILE_SIZE)),
			"and the number clears their head rather than sitting at their knees",
			"lifted %.0f, which is %.1f tiles" % [tall_lift, tall_lift / Grid.TILE_SIZE])
		someone["sprite"] = their_sprite

	game.queue_free()
	await get_tree().process_frame
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
