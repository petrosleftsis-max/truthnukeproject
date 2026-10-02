extends RefCounted
class_name ClueBook
## Every clue in the game, keyed by file name: everything in res://clues/.
##
## Read from the folder rather than listed anywhere, so a clue is added by
## saving a ClueDefinition there and nothing else. What the party has learned
## is Campaign's business (Campaign.learn_clue); this only says what exists.

const FOLDER := "res://clues/"

static var _clues: Dictionary = {}
static var _loaded := false


## key -> ClueDefinition.
static func all() -> Dictionary:
	if not _loaded:
		_load()
	return _clues


## The clue for `key`, or null.
static func clue(key: String) -> ClueDefinition:
	return all().get(key)


## The deduction worked out by connecting `a` and `b`, in either order, or "".
static func deduced_from(a: String, b: String) -> String:
	if a == b:
		return ""
	for key in all():
		var found: ClueDefinition = _clues[key]
		if found.is_deduction() and found.from_clues.size() == 2 \
				and found.from_clues.has(a) and found.from_clues.has(b):
			return key
	return ""


## Puts a clue in by hand - for tests, and anything building clues in code.
static func add(key: String, definition: ClueDefinition):
	all()[key] = definition


## Reads the folder again, dropping anything added by hand.
static func reload():
	_loaded = false
	_clues.clear()
	_load()


static func _load():
	_loaded = true
	if not DirAccess.dir_exists_absolute(FOLDER):
		return
	# list_directory knows an exported game's files by their original names;
	# a plain DirAccess listing there sees "x.tres.remap".
	for file in ResourceLoader.list_directory(FOLDER):
		if not (file.ends_with(".tres") or file.ends_with(".res")):
			continue
		var found = load(FOLDER + file)
		if found is ClueDefinition:
			_clues[file.get_basename()] = found
		else:
			push_warning("ClueBook: %s is not a ClueDefinition." % (FOLDER + file))
