extends Node
## What each item is actually worth once Godot has loaded it - which is not
## what the file appears to say when the file names a property the script no
## longer has.

var LOG_PATH := HarnessLog.path_for("power")
var _log: FileAccess

func log_line(t): _log.store_line(t); _log.flush()

func _ready():
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	await get_tree().process_frame
	log_line("======== item_power as the engine sees it ========")
	var all_same := {}
	for key in ItemDatabase.items:
		var item = ItemDatabase.items[key]
		if item == null:
			continue
		log_line("  %-22s item_power %-5d ability %-5s heal/dot dials on effects"
			% [item.name, item.item_power, item.ability_modifier])
		all_same[item.item_power] = true
	log_line("")
	log_line("  distinct item_power values across every item: %d %s"
		% [all_same.size(), all_same.keys()])
	log_line("FAILURES: 0")
	get_tree().quit(0)
