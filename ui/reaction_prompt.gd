extends CanvasLayer
class_name ReactionPrompt
## Asks the player whether to spend a combatant's one reaction when it
## triggers, instead of it firing automatically.
##
## A reaction is a scarce resource - one per combatant between their own turns -
## so spending it on the first enemy to walk past is rarely the right call.
## This hands that judgement to the player.
##
## Only for the player's own combatants. Enemies still react on their first
## opportunity, so the AI needs no decision-making for it.
##
## Combat awaits ask(), which parks the mover mid-step until an answer comes
## back - the same await that already lets a reaction's animation play out
## before movement continues.


## True if the player chose to use it, false if they passed. Not a signal,
## because the caller wants the answer inline rather than as an event.
var _answer := false
var _waiting := false


func _ready():
	$Panel.visible = false
	$Panel/VBox/Buttons/UseButton.pressed.connect(func(): _answer_with(true))
	$Panel/VBox/Buttons/SkipButton.pressed.connect(func(): _answer_with(false))
	FocusLoop.link([$Panel/VBox/Buttons/UseButton, $Panel/VBox/Buttons/SkipButton])


## Puts the question up and waits for an answer. Returns true to use the
## reaction, false to pass on it.
##
## Passing is only "not this time": the reaction stays unspent, so the next
## enemy to break away this round asks again.
func ask(reactor: Dictionary, target: Dictionary, skill: SkillDefinition) -> bool:
	$Panel/VBox/Title.text = "%s can react" % reactor.name
	$Panel/VBox/Detail.text = "%s is leaving range. Use %s on them?\nThis spends %s's one reaction until their next turn." % [
		target.name, skill.name, reactor.name
	]
	$Panel.visible = true
	$Panel/VBox/Buttons/UseButton.grab_focus()
	_waiting = true
	while _waiting:
		await get_tree().process_frame
	$Panel.visible = false
	# Hand focus back, or the camera stays frozen thinking a menu is open.
	var focused = get_viewport().gui_get_focus_owner()
	if focused != null:
		focused.release_focus()
	return _answer


## Whether a question is up and waiting for an answer right now. CController
## reads this to pause its movement timeouts, rather than being told to, so
## there is no state to be left behind if ask() is interrupted.
func is_asking() -> bool:
	return _waiting


func _answer_with(use_it: bool):
	if not _waiting:
		return
	_answer = use_it
	_waiting = false


func _unhandled_input(event):
	if not _waiting or not event is InputEventKey or not event.pressed or event.is_echo():
		return
	# Escape passes, matching every other "get me out of here" in the game.
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_answer_with(false)
