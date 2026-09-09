@tool
extends Interactable
class_name ExamineInteractable
## Scenery with something to say: a sign, a chest, a body by the road.
##
## Prints to the same Information log the combat UI already uses, rather than
## opening a conversation. For anything with branches or replies, use a
## DialogueInteractable instead.


@export_multiline var text: String = ""
## Shown before the text, in yellow, the way speaker names appear in combat
## messages. Leave empty for a plain line.
@export var speaker: String = ""
## When false the message only ever appears the first time.
@export var repeatable: bool = true

var _examined := false


func _init():
	prompt = "Examine"


func is_available() -> bool:
	return repeatable or not _examined


func interact(scene: Node):
	if text == "":
		return
	_examined = true
	if speaker != "":
		scene.log_message("[color=yellow]%s[/color]: %s\n" % [speaker, text])
	else:
		scene.log_message("%s\n" % text)
