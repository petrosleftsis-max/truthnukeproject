extends Node
## Does everything the game loads actually exist?
##
## Renaming art is a normal thing to do, and a scene that still points at the old
## name does not complain until the moment it is needed - which for the HUD's
## portraits was mid-battle, after a scene change, with the errors scrolling past
## in a wall.

var LOG_PATH := HarnessLog.path_for("refs")

## Everything the game itself loads. The addon brings its own and is not ours to
## keep tidy.
const SKIP := ["res://addons/", "res://.godot/"]

var _log: FileAccess = null
var _fail = 0


func log_line(t: String):
	if _log:
		_log.store_line(t)
		_log.flush()


func ok(condition: bool, label: String, detail: String = ""):
	if condition:
		log_line("  PASS  %s %s" % [label, detail])
	else:
		_fail += 1
		log_line("  FAIL  %s %s" % [label, detail])


func _ready():
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	get_tree().create_timer(120.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


## Every .tscn and .tres the project owns.
func project_files() -> Array:
	var found: Array = []
	_walk("res://", found)
	return found


func _walk(path: String, into: Array):
	for skip in SKIP:
		if path.begins_with(skip):
			return
	var dir = DirAccess.open(path)
	if dir == null:
		return
	for name in dir.get_directories():
		_walk(path.path_join(name), into)
	for name in dir.get_files():
		if name.ends_with(".tscn") or name.ends_with(".tres"):
			into.append(path.path_join(name))


func run_test():
	var files = project_files()
	log_line("======== every scene and resource loads ========")
	ok(files.size() > 20, "there is a project to check", "%d scenes and resources" % files.size())
	var broken: Array = []
	for path in files:
		var loaded = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
		if loaded == null:
			broken.append(path)
	ok(broken.is_empty(), "every one of them loads", "%s" % [broken])
	log_line("")

	log_line("======== and everything they point at is there ========")
	var missing: Array = []
	for path in files:
		var text = FileAccess.get_file_as_string(path)
		if text == "":
			continue
		# Every res:// path named in the file, whether by a scene, a resource or
		# a script export.
		var finder := RegEx.new()
		finder.compile('path="(res://[^"]+)"')
		for hit in finder.search_all(text):
			var referenced = hit.get_string(1)
			var skip = false
			for prefix in SKIP:
				if referenced.begins_with(prefix):
					skip = true
			if skip:
				continue
			if not ResourceLoader.exists(referenced) and not FileAccess.file_exists(referenced):
				missing.append("%s -> %s" % [path.get_file(), referenced])
	ok(missing.is_empty(), "nothing points at a file that is not there", "%s" % [missing])
	log_line("")

	log_line("======== the HUD's own pieces, which a rename broke once ========")
	for path in ["res://ui/tq_icon.tscn", "res://ui/status_icon.tscn", "res://ui/ui.tscn",
			"res://ui/dialogue_balloon.tscn", "res://scenes/encounter_editor.tscn"]:
		var scene = load(path)
		ok(scene != null, "%s loads" % path.get_file())
		if scene != null:
			var made = scene.instantiate()
			ok(made != null, "and can be built", path.get_file())
			if made != null:
				made.queue_free()
	log_line("")

	log_line("======== the balloon says its own lines and nothing else ========")
	var balloon = load("res://ui/dialogue_balloon.tscn").instantiate()
	get_tree().root.add_child(balloon)
	await get_tree().process_frame
	var shouting: Array = []
	for node in balloon.find_children("*", "Button", true, false):
		if node.text.to_lower().contains("example balloon") or node.text.to_lower().contains("create your own"):
			shouting.append(node.text)
	ok(shouting.is_empty(), "no notice telling the player to make their own balloon", "%s" % [shouting])
	balloon.queue_free()
	log_line("")

	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
