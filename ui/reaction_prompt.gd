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
## Which of choose()'s skills was picked, or -1.
var _choice := -1


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
	return await ask_about("%s can react" % reactor.name,
		"%s is leaving range. Use %s on them?\nThis spends %s's one reaction until their next turn." % [
			target.name, skill.name, reactor.name])


## Which of `skills` to use on `target` as they leave `reactor`'s reach - a
## swing or a grab (Combat "Holding on") - one button each, then Skip. The
## index of the one chosen, or -1 to let them go.
func choose(reactor: Dictionary, target: Dictionary, skills: Array) -> int:
	var row := $Panel/VBox/Buttons
	var use_button: Button = $Panel/VBox/Buttons/UseButton
	var skip_button: Button = $Panel/VBox/Buttons/SkipButton
	use_button.visible = false
	var made: Array = []
	for i in skills.size():
		var button := Button.new()
		button.custom_minimum_size = use_button.custom_minimum_size
		button.text = skills[i].name
		button.pressed.connect(func(): _choose(i))
		row.add_child(button)
		row.move_child(button, skip_button.get_index())
		made.append(button)
	FocusLoop.link(made + [skip_button])
	_choice = -1
	var used := await _put_up("%s can react" % reactor.name,
		"%s is leaving range. What does %s do?\nWhichever, it spends %s's one reaction until their next turn." % [
			target.name, reactor.name, reactor.name], made[0] if not made.is_empty() else skip_button)
	for button in made:
		button.queue_free()
	use_button.visible = true
	FocusLoop.link([use_button, skip_button])
	return _choice if used else -1


## The same question in other words - a ward (Combat._offer_ward) rather than a
## swing at somebody leaving.
func ask_about(title: String, detail: String) -> bool:
	return await _put_up(title, detail, $Panel/VBox/Buttons/UseButton)


## Shows the question with `first` lit, and waits for the answer.
func _put_up(title: String, detail: String, first: Control) -> bool:
	$Panel/VBox/Title.text = title
	$Panel/VBox/Detail.text = detail
	$Panel.visible = true
	first.grab_focus()
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


## One of choose()'s buttons.
func _choose(index: int):
	if not _waiting:
		return
	_choice = index
	_answer_with(true)


func _unhandled_input(event):
	if not _waiting or not event.is_pressed() or event.is_echo():
		return
	# Escape passes, matching every other "get me out of here" in the game.
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_answer_with(false)
