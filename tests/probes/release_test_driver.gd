extends Node
## The release check (docs/itch_release_proposals.md, way 3; the designer, 2026-11-19: "Go with all five suggestions"). A probe:
## tools/release.sh --release runs it before building, and `tests/run.sh release` runs it by hand. It plays nothing. What a release
## build leaves out it reads from the export presets themselves ("Windows Desktop Release"'s Exclude Filter), and then:
## - fails on anything the release keeps that still points at what it leaves out: a scene or a resource depending on it, or a
##   script or a conversation naming it - but the title screen's, which shows that only outside a release (MainMenu, Release);
## - fails on anything still showing the stand-in picture (art/placeholders/), unless MOT_ALLOW_STAND_INS is set (--allow-stand-ins);
## - lists, for the artist and the designer, every sound slot still empty (the SoundBank's, and the moves with no sound of their
##   own, which play a stand-in) and every picture slot still empty (skills and items with no icon, and pictures the code names
##   that are not there).
## The lists are written beside the log, as release_report.md.

var LOG_PATH := HarnessLog.path_for("release")
const PRESETS := "res://export_presets.cfg"
const RELEASE_PRESET := "Windows Desktop Release"
const STAND_IN_FOLDER := "res://art/placeholders/"
## Scripts that name what a release leaves out, and why that is all right.
const NAMES_ALLOWED := {
	"res://ui/main_menu.gd": "the title screen shows the stages and demos only outside a release (Release.on)",
}

var _log: FileAccess = null
var _fail := 0
var _patterns: Array[String] = []


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
	get_tree().create_timer(280.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	run_check()
	log_line("")
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)


func run_check():
	log_line("The release check: what a release build leaves out, what still points at it, and what is still to draw and record")
	_patterns = _left_out_patterns()
	ok(not _patterns.is_empty(), "the release preset says what it leaves out", "%s" % [_patterns])
	var files := _files_in("res://")
	var kept: Array[String] = []
	var left := 0
	for path in files:
		if _left_out(path):
			left += 1
		else:
			kept.append(path)
	log_line("  %d files in the project, %d left out of a release" % [files.size(), left])
	ok(left > 0 and _left_out("res://maps/stealth_stages/wander.tscn") and _left_out("res://demos/stealth_demo.tscn"),
		"the stages and the demos are among them")
	ok(not _left_out("res://scenes/main_menu.tscn") and not _left_out("res://maps/church.tscn"), "and the game is not")

	var pointing := []
	var stand_ins := []
	var broken := []
	for path in kept:
		var extension := path.get_extension()
		if extension in ["tscn", "tres", "scn", "res"]:
			for dependency in ResourceLoader.get_dependencies(path):
				var on := _path_in(dependency)
				if on == "":
					continue
				if _left_out(on):
					pointing.append("%s depends on %s" % [path, on])
				elif on.begins_with(STAND_IN_FOLDER):
					stand_ins.append(path)
				elif not ResourceLoader.exists(on) and not FileAccess.file_exists(on):
					broken.append("%s depends on %s, which is not there" % [path, on])
		if extension in ["gd", "dialogue"]:
			var text := FileAccess.get_file_as_string(path)
			for named in _paths_named_in(text):
				if _left_out(named) and not NAMES_ALLOWED.has(path):
					pointing.append("%s names %s" % [path, named])
				elif named.begins_with(STAND_IN_FOLDER) and not path.begins_with("res://tests/"):
					stand_ins.append(path)
	log_line("")
	log_line("======== nothing kept points at what is left out ========")
	ok(pointing.is_empty(), "nothing a release keeps depends on, or names, a file it leaves out", "%s" % [pointing])
	for allowed in NAMES_ALLOWED:
		log_line("  (allowed: %s - %s)" % [allowed, NAMES_ALLOWED[allowed]])
	ok(broken.is_empty(), "and nothing depends on a file that is not there at all", "%s" % [broken])

	log_line("")
	log_line("======== stand-ins ========")
	var allowing := OS.get_environment("MOT_ALLOW_STAND_INS") != ""
	if allowing:
		log_line("  stand-ins allowed this time (MOT_ALLOW_STAND_INS): %d" % stand_ins.size())
	else:
		ok(stand_ins.is_empty(), "nothing still shows the stand-in picture", "%s" % [stand_ins])

	var sounds := _empty_sound_slots()
	var pictures := _empty_picture_slots(kept)
	_write_report(pointing, stand_ins, sounds, pictures, allowing)
	log_line("")
	log_line("  empty sound slots: %d, empty picture slots: %d (release_report.md)" % [sounds.size(), pictures.size()])


## The release preset's Exclude Filter, as res:// patterns (a pattern with no folder in it matches its name in any folder).
func _left_out_patterns() -> Array[String]:
	var found: Array[String] = []
	var presets := ConfigFile.new()
	if presets.load(PRESETS) != OK:
		return found
	for section in presets.get_sections():
		if section.ends_with(".options") or presets.get_value(section, "name", "") != RELEASE_PRESET:
			continue
		for part in String(presets.get_value(section, "exclude_filter", "")).split(","):
			var pattern := part.strip_edges()
			if pattern != "":
				found.append("res://" + pattern if pattern.contains("/") else "*/" + pattern)
	return found


func _left_out(path: String) -> bool:
	for pattern in _patterns:
		if path.matchn(pattern):
			return true
	return false


## Every file under `folder` the export would see: none in a folder with a .gdignore, nor .godot, nor anything hidden.
func _files_in(folder: String) -> Array[String]:
	var found: Array[String] = []
	var dir := DirAccess.open(folder)
	if dir == null or dir.file_exists(".gdignore"):
		return found
	for file in dir.get_files():
		if file.begins_with(".") or file.ends_with(".import") or file.ends_with(".uid"):
			continue
		# What the test harness puts in its copy of the project is not the game's (tests/run.sh).
		if folder == "res://" and (file.ends_with("_test_driver.gd") or file == "HarnessLog.gd"):
			continue
		found.append(folder.path_join(file))
	for sub in dir.get_directories():
		if not sub.begins_with(".") and sub != "export":
			found.append_array(_files_in(folder.path_join(sub)))
	return found


## The res:// path in one of get_dependencies' entries ("uid::type::path"), or "".
func _path_in(dependency: String) -> String:
	for slice in dependency.split("::"):
		if slice.begins_with("res://"):
			return slice
	return ""


## Every whole res:// path written in `text`, but those with a % to be filled in.
func _paths_named_in(text: String) -> Array[String]:
	var named: Array[String] = []
	var finder := RegEx.create_from_string("res://[A-Za-z0-9_./-]+\\.[A-Za-z0-9]+")
	for found in finder.search_all(text):
		var path := found.get_string()
		if not named.has(path):
			named.append(path)
	return named


## The SoundBank's slots with nothing in them, and the moves with no sound of their own: each plays a stand-in meanwhile (in a
## release, silence, but Release.STAND_INS_KEPT).
func _empty_sound_slots() -> Array[String]:
	var empty: Array[String] = []
	var bank: Resource = load("res://audio/sound_bank.tres")
	if bank != null:
		for property in bank.get_property_list():
			if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and String(property.hint_string) == "AudioStream" and bank.get(property.name) == null:
				empty.append("sound bank: %s" % property.name)
	var moves := []
	for key in SkillDatabase.skills:
		var skill: SkillDefinition = SkillDatabase.skills[key]
		if skill != null and skill.get("sound") == null and not skill is ItemDefinition:
			moves.append(skill.name)
	moves.sort()
	if not moves.is_empty():
		empty.append("moves with no sound of their own (%d): %s" % [moves.size(), ", ".join(moves)])
	return empty


## Skills and items with no icon, and the pictures the code names that are not there.
func _empty_picture_slots(kept: Array[String]) -> Array[String]:
	var empty: Array[String] = []
	var no_icon := []
	for key in SkillDatabase.skills:
		var skill: SkillDefinition = SkillDatabase.skills[key]
		if skill != null and skill.icon == null:
			no_icon.append(skill.name)
	for key in ItemDatabase.items:
		var item: ItemDefinition = ItemDatabase.items[key]
		if item != null and item.icon == null:
			no_icon.append(item.name)
	no_icon.sort()
	if not no_icon.is_empty():
		empty.append("skills and items with no icon (%d): %s" % [no_icon.size(), ", ".join(no_icon)])
	var missing := []
	for path in kept:
		if path.get_extension() != "gd" or path.begins_with("res://tests/"):
			continue
		for named in _paths_named_in(FileAccess.get_file_as_string(path)):
			if named.begins_with("res://art/") and named.get_extension() in ["png", "svg", "jpg", "webp"] \
					and not ResourceLoader.exists(named) and not missing.has(named):
				missing.append(named)
	missing.sort()
	for named in missing:
		empty.append("a picture the code looks for: %s" % named)
	return empty


func _write_report(pointing: Array, stand_ins: Array, sounds: Array[String], pictures: Array[String], allowing: bool):
	var report := FileAccess.open(LOG_PATH.get_base_dir().path_join("release_report.md"), FileAccess.WRITE)
	if report == null:
		return
	report.store_line("# The release check")
	report.store_line("")
	report.store_line("Left out of a release: %s" % ", ".join(_patterns))
	report.store_line("")
	report.store_line("## Still pointing at what is left out (each one stops a release)")
	report.store_line("")
	for line in (pointing if not pointing.is_empty() else ["Nothing."]):
		report.store_line("- %s" % line)
	report.store_line("")
	report.store_line("## Showing the stand-in picture%s" % (" (allowed this time)" if allowing else " (each one stops a release)"))
	report.store_line("")
	for line in (stand_ins if not stand_ins.is_empty() else ["Nothing."]):
		report.store_line("- %s" % line)
	report.store_line("")
	report.store_line("## Sounds still to record")
	report.store_line("")
	for line in (sounds if not sounds.is_empty() else ["Nothing."]):
		report.store_line("- %s" % line)
	report.store_line("")
	report.store_line("## Pictures still to draw")
	report.store_line("")
	for line in (pictures if not pictures.is_empty() else ["Nothing."]):
		report.store_line("- %s" % line)
	report.close()
