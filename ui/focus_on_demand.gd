extends Node
class_name FocusOnDemand
## Keyboard focus that waits until somebody asks for it.
##
## A menu that grabs focus on its first button the moment it opens leaves that
## button lit up under a mouse that is nowhere near it - and lit up in the same
## colours as the hover state, so two options look picked at once and the first
## one looks picked permanently.
##
## Focus still exists, because a menu has to be drivable without a mouse. It
## simply is not claimed until the keyboard is used: press a direction and the
## remembered button lights up and arrow keys work from there; touch the mouse
## and the highlight lets go again.
##
## Attach one per menu:
##
##     FocusOnDemand.attach(self, buttons[0])

## What lights up when somebody reaches for the keyboard.
var _waiting: Control = null

## The actions that mean "I am using the keyboard now".
const NAVIGATION := ["ui_up", "ui_down", "ui_left", "ui_right",
	"ui_focus_next", "ui_focus_prev", "ui_accept"]


## Puts one of these on `host`, holding `first` back until it is wanted.
## Returns it, so a caller that wants to change its mind later can keep it.
static func attach(host: Node, first: Control) -> FocusOnDemand:
	if host == null:
		return null
	var keeper := FocusOnDemand.new()
	keeper.name = "FocusOnDemand"
	keeper._waiting = first
	host.add_child(keeper)
	return keeper


## Which button to light up next time the keyboard is used. Call again when a
## menu swaps panels, so the keyboard starts at the top of the new one.
func remember(first: Control):
	_waiting = first


func _input(event):
	# Mouse motion comes through a Control before _unhandled_input ever sees it,
	# so this listens early rather than politely.
	if event is InputEventMouseMotion:
		_let_go()
		return
	if not (event is InputEventKey or event is InputEventJoypadButton):
		return
	if not event.is_pressed():
		return
	for action in NAVIGATION:
		if event.is_action_pressed(action):
			if _claim():
				# The key that summons the highlight must not also move it, or
				# the first press lands on the second option and the top of the
				# menu can never be reached with one tap.
				get_viewport().set_input_as_handled()
			return


## Lights up the remembered button, if nothing else already has the keyboard.
## True when this press was the one that claimed it.
func _claim() -> bool:
	if _waiting == null or not is_instance_valid(_waiting) or not _waiting.is_inside_tree():
		return false
	var viewport = get_viewport()
	if viewport == null or viewport.gui_get_focus_owner() != null:
		return false
	if not _waiting.is_visible_in_tree():
		return false
	_waiting.grab_focus()
	return true


## Drops the highlight when the mouse takes over, so nothing is left looking
## chosen. Only ever lets go of something inside this menu - a text field or a
## slider elsewhere is not ours to interrupt.
func _let_go():
	var viewport = get_viewport()
	if viewport == null:
		return
	var focused = viewport.gui_get_focus_owner()
	if focused == null:
		return
	var host = get_parent()
	if host != null and not host.is_ancestor_of(focused):
		return
	focused.release_focus()
