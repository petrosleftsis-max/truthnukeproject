extends Node
## Runs the encounter editor's own placement rules over the markers currently
## sitting in scenes/encounter_editor.tscn, so the layout can be checked
## without opening the editor.

var LOG_PATH := HarnessLog.path_for("placement")

var _log: FileAccess = null
var _problems = 0


func log_line(t: String):
	if _log:
		_log.store_line(t)
		_log.flush()


func _ready():
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	await get_tree().process_frame
	run_check()


func run_check():
	var editor_scene = load("res://scenes/encounter_editor.tscn")
	# Outside the editor, EncounterEditor._ready() leaves the saved preview
	# alone, so instantiating gives back exactly the markers as they sit in
	# the file.
	var editor_root = editor_scene.instantiate()
	add_child(editor_root)

	var terrain = load("res://scenes/terrain.tscn").instantiate()
	add_child(terrain)
	var tile_map: TileMap = terrain.get_node("TileMap")
	var rect = tile_map.get_used_rect()
	var tile_size = tile_map.tile_set.tile_size.x
	log_line("map: %s, %d px tiles" % [rect, tile_size])

	var database = load("res://databases/combatant_database.tscn").instantiate()
	var definitions: Dictionary = database.combatants

	var spawns_container = editor_root.get_node_or_null("Spawns")
	var container_offset = spawns_container.position if spawns_container != null else Vector2.ZERO
	if container_offset != Vector2.ZERO:
		log_line("NOTE: the Spawns container is offset by %s - folded in below" % container_offset)

	var markers = []
	if spawns_container != null:
		for child in spawns_container.get_children():
			markers.append({
				"key": child.combatant_key,
				"side": child.side,
				"position": child.position,
				"display_name": child.display_name,
			})

	log_line("%d markers in the scene" % markers.size())
	log_line("")

	var claimed = {}
	var players = 0
	var enemies = 0
	for entry in markers:
		var world = entry.position + container_offset
		var tile = Vector2i(floori(world.x / tile_size), floori(world.y / tile_size))
		var label = entry.display_name if entry.display_name != "" else entry.key
		if label == "":
			label = "(no combatant)"
		var side_name = "player" if entry.side == 0 else "enemy"
		if entry.side == 0:
			players += 1
		else:
			enemies += 1

		var problem = ""
		if entry.key == "":
			problem = "has no combatant chosen"
		elif not definitions.has(entry.key):
			problem = "uses unknown combatant key '%s'" % entry.key
		elif not rect.has_point(tile):
			problem = "is at %s, off the edge of the map %s" % [tile, rect]
		else:
			var data = tile_map.get_cell_tile_data(0, tile)
			if data == null:
				problem = "is at %s, on an unpainted hole" % tile
			else:
				var blocks = data.get_custom_data("Blocks")
				var movement_class = definitions[entry.key].class_m
				if movement_class in blocks:
					problem = "is at %s, on terrain movement class %d can't enter" % [tile, movement_class]
		if problem == "" and claimed.has(tile):
			problem = "shares %s with %s" % [tile, claimed[tile]]
		if problem == "":
			claimed[tile] = label

		if problem == "":
			log_line("  OK    %-10s %-7s at %s" % [label, side_name, tile])
		else:
			_problems += 1
			log_line("  BAD   %-10s %-7s %s" % [label, side_name, problem])

	log_line("")
	log_line("%d players, %d enemies" % [players, enemies])
	if players == 0:
		_problems += 1
		log_line("  BAD   no player-side combatants")
	if enemies == 0:
		_problems += 1
		log_line("  BAD   no enemies")

	# What the encounter resource assigned to the editor currently holds - the
	# markers are only a layout until Save writes them into this.
	log_line("")
	var assigned = editor_root.encounter
	if assigned == null:
		log_line("assigned encounter: none")
	else:
		var where = assigned.resource_path if assigned.resource_path != "" else "<built into the editor scene - cannot be saved to>"
		log_line("assigned encounter: %s" % where)
		log_line("  it currently stores %d spawns:" % assigned.spawns.size())
		for spawn in assigned.spawns:
			var key = spawn.combatant_key if spawn.combatant_key != "" else "(none)"
			log_line("    %-10s side %d at %s" % [key, spawn.side, spawn.position])

	log_line("")
	log_line("PROBLEMS: %d" % _problems)
	get_tree().quit(0 if _problems == 0 else 1)
