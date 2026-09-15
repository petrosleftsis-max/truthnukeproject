class_name MenuPause extends RefCounted
## Freezes the game while a menu is over it.
##
## A menu that only stops input still leaves the game running underneath: the
## clock ticks, an animation lands, and a click that misses the panel goes
## through to the map and moves somebody. Pausing the tree stops all of it at
## once, so "the menu is open" and "nothing is happening" are the same state.
##
## Two things can want the game held at the same time - the pause menu and the
## character sheet - and either can be closed first, so this keeps a list of who
## is asking rather than a bool that the second close would clear too early.
##
## Whoever holds it has to keep running while it is held:
##
##     process_mode = Node.PROCESS_MODE_ALWAYS
##     MenuPause.hold(self)     # opening
##     MenuPause.release(self)  # closing
##
## A scene change clears the whole list (see SceneTransition), because a menu
## that is about to be freed cannot release anything and the scene arriving
## would otherwise arrive frozen.

## Instance ids rather than the nodes themselves, so a menu freed without
## releasing is something this can notice rather than something it holds a
## reference to forever.
static var _holders: Array = []


## Asks for the game to be held. Safe to call twice.
static func hold(who: Node) -> void:
	if who == null:
		return
	var id := who.get_instance_id()
	if not _holders.has(id):
		_holders.append(id)
	_apply(who.get_tree())


## Gives it back. The game resumes only once nobody else is still asking.
static func release(who: Node) -> void:
	if who == null:
		return
	_holders.erase(who.get_instance_id())
	_apply(who.get_tree())


## True when something other than `who` is holding the game - what a menu asks
## before acting on a key, so the pause menu's Escape and the sheet's C don't
## answer each other's keypresses.
static func held_by_another(who: Node) -> bool:
	var mine := who.get_instance_id() if who != null else 0
	for id in _live():
		if id != mine:
			return true
	return false


## Drops every hold and lets the game run. For a scene change, where the
## holders are about to stop existing.
static func clear(tree: SceneTree) -> void:
	_holders.clear()
	if tree != null:
		tree.paused = false


static func _apply(tree: SceneTree) -> void:
	if tree == null:
		return
	tree.paused = not _live().is_empty()


## The holders that still exist, forgetting any that were freed while holding.
static func _live() -> Array:
	var kept := []
	for id in _holders:
		var node = instance_from_id(id)
		if node is Node and is_instance_valid(node) and node.is_inside_tree():
			kept.append(id)
	_holders = kept
	return kept
