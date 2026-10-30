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
## Who answers, in co-op: the player who steers the one reacting, or whoever
## has the board (Coop.ANYONE).
var _decider := -1
## Over a network: waiting for the other machine's player to answer (Net).
var _asking_afar := false


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
func ask(reactor: Dictionary, target: Dictionary, skill: SkillDefinition, happening: String = "", label: String = "") -> bool:
	_decider = Coop.controller_of(reactor.get("combatant_key", ""))
	if happening == "":
		return await ask_about("%s can react" % reactor.name,
			"%s is leaving range. Use %s on them?\nThis spends %s's one reaction until their next turn." % [
				target.name, skill.name, reactor.name])
	var aimed := "" if is_same(target, reactor) else " on %s" % target.name
	return await ask_about("%s can react" % reactor.name,
		"%s. Use %s%s?\nThis spends %s's one reaction until their next turn." % [
			happening[0].to_upper() + happening.substr(1),
			label if label != "" else skill.name, aimed, reactor.name])


## Which of `skills` to use on `target` as they leave `reactor`'s reach - a
## swing or a grab (Combat "Holding on") - one button each, then Skip. The
## index of the one chosen, or -1 to let them go.
func choose(reactor: Dictionary, target: Dictionary, skills: Array, happening: String = "", labels: Array = []) -> int:
	var row := $Panel/VBox/Buttons
	var use_button: Button = $Panel/VBox/Buttons/UseButton
	var skip_button: Button = $Panel/VBox/Buttons/SkipButton
	use_button.visible = false
	var made: Array = []
	for i in skills.size():
		var button := Button.new()
		button.custom_minimum_size = use_button.custom_minimum_size
		button.text = labels[i] if i < labels.size() else skills[i].name
		button.pressed.connect(func(): _choose(i))
		row.add_child(button)
		row.move_child(button, skip_button.get_index())
		made.append(button)
	FocusLoop.link(made + [skip_button])
	_choice = -1
	_decider = Coop.controller_of(reactor.get("combatant_key", ""))
	var what := "%s is leaving range" % target.name if happening == "" else happening[0].to_upper() + happening.substr(1)
	var used := await _put_up("%s can react" % reactor.name,
		"%s. What does %s do?\nWhichever, it spends %s's one reaction until their next turn." % [
			what, reactor.name, reactor.name], made[0] if not made.is_empty() else skip_button)
	for button in made:
		button.queue_free()
	use_button.visible = true
	FocusLoop.link([use_button, skip_button])
	return _choice if used else -1


## One of `labels`, a button each - which of somebody's containers a Steal
## empties (Combat._choose_container), say. The index picked; Escape takes the
## first, since something has to be chosen.
func pick(title: String, detail: String, labels: Array) -> int:
	var row := $Panel/VBox/Buttons
	var use_button: Button = $Panel/VBox/Buttons/UseButton
	var skip_button: Button = $Panel/VBox/Buttons/SkipButton
	use_button.visible = false
	skip_button.visible = false
	var made: Array = []
	for i in labels.size():
		var button := Button.new()
		button.custom_minimum_size = Vector2(maxf(use_button.custom_minimum_size.x, 150), use_button.custom_minimum_size.y)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.text = labels[i]
		button.pressed.connect(func(): _choose(i))
		row.add_child(button)
		made.append(button)
	FocusLoop.link(made)
	_choice = -1
	var chose := await _put_up(title, detail, made[0] if not made.is_empty() else use_button)
	for button in made:
		button.queue_free()
	use_button.visible = true
	skip_button.visible = true
	FocusLoop.link([use_button, skip_button])
	return _choice if chose else 0


## The same question in other words - a ward (Combat._offer_ward) rather than a
## swing at somebody leaving.
func ask_about(title: String, detail: String) -> bool:
	return await _put_up(title, detail, $Panel/VBox/Buttons/UseButton)


## Shows the question with `first` lit, and waits for the answer. Over a
## network it is put up only on the machine of whoever decides - the other
## waits for what they chose (Net.decided), counted as asking all the while.
func _put_up(title: String, detail: String, first: Control) -> bool:
	var decider := _decider
	_decider = Coop.ANYONE
	var net = get_node_or_null("/root/Net")
	if net == null or not net.in_a_shared_fight():
		return await _ask_here(decider, title, detail, first)
	var who := decider if decider != Coop.ANYONE else (Coop.focus if Coop.focus != Coop.ANYONE else 0)
	_asking_afar = true
	var answer = await net.decided(who, func(): return [await _ask_here(decider, title, detail, first), _choice])
	_asking_afar = false
	if not answer is Array or answer.size() < 2:
		answer = [false, -1]
	_choice = int(answer[1])
	_answer = bool(answer[0])
	return _answer


## The question put up here, and the answer waited for.
func _ask_here(decider: int, title: String, detail: String, first: Control) -> bool:
	# In co-op, theirs to answer alone (Coop.focus) while it is up.
	if decider != Coop.ANYONE:
		Coop.take_focus(decider, self)
		if Coop.on():
			title = "%s - %s" % [title, Coop.name_of(decider)]
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
	Coop.let_go(self)
	return _answer


## Whether a question is up and waiting for an answer right now. CController
## reads this to pause its movement timeouts, rather than being told to, so
## there is no state to be left behind if ask() is interrupted.
func is_asking() -> bool:
	return _waiting or _asking_afar


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
