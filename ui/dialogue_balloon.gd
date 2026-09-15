class_name DialogueBalloon extends CanvasLayer
## A basic dialogue balloon for use with Dialogue Manager.


## The dialogue resource
@export var dialogue_resource: DialogueResource

## Start from a given cue when using balloon as a [Node] in a scene.
@export var start_from_cue: String = ""

## If running as a [Node] in a scene then auto start the dialogue.
@export var auto_start: bool = false

## If all other input is blocked as long as dialogue is shown.
@export var will_block_other_input: bool = true

## The action to use for advancing the dialogue
@export var next_action: StringName = &"ui_accept"

## The action to use to skip typing the dialogue. The same key that advances a
## line, so one key reads the conversation: it finishes the line being typed,
## then moves on. Escape is deliberately not this - it opens the pause menu,
## which has to be reachable in the middle of a conversation.
@export var skip_action: StringName = &"ui_accept"

## A sound player for voice lines (if they exist).
@onready var audio_stream_player: AudioStreamPlayer = %AudioStreamPlayer

## Temporary game states
var temporary_game_states: Array = []

## See if we are waiting for the player
var is_waiting_for_input: bool = false

## See if we are running a long mutation and should hide the balloon
var will_hide_balloon: bool = false

## A dictionary to store any ephemeral variables
var locals: Dictionary = {}

var _locale: String = TranslationServer.get_locale()

## The current line
var dialogue_line: DialogueLine:
	set(value):
		if value:
			dialogue_line = value
			apply_dialogue_line()
		else:
			# The dialogue has finished so close the balloon
			if owner == null:
				queue_free()
			else:
				hide()
	get:
		return dialogue_line

## A cooldown timer for delaying the balloon hide when encountering a mutation.
var mutation_cooldown: Timer = Timer.new()

## The base balloon anchor
@onready var balloon: Control = %Balloon

## The label showing the name of the currently speaking character
@onready var character_label: RichTextLabel = %CharacterLabel
## The face beside the line. Hidden whenever there is no portrait to show, so
## a line with none looks exactly like the balloon did before portraits
## existed rather than leaving a gap.
@onready var portrait: TextureRect = %Portrait

## The label showing the currently spoken dialogue
@onready var dialogue_label: DialogueLabel = %DialogueLabel

## The menu of responses
@onready var responses_menu: DialogueResponsesMenu = %ResponsesMenu

## Indicator to show that player can progress dialogue.
@onready var progress: Polygon2D = %Progress

## Gets you out of a conversation you have already read. Built here rather than
## placed in the scene, so the balloon stays as close to the addon's example as
## it can and updating the addon has less to collide with.
var skip_button: Button

## True while the rest of the conversation is being walked through without
## being shown. See skip_conversation().
var _skipping := false


func _ready() -> void:
	balloon.hide()
	Engine.get_singleton("DialogueManager").mutated.connect(_on_mutated)

	# If the responses menu doesn't have a next action set, use this one
	if responses_menu.next_action.is_empty():
		responses_menu.next_action = next_action

	mutation_cooldown.timeout.connect(_on_mutation_cooldown_timeout)
	add_child(mutation_cooldown)
	_build_skip_button()

	if auto_start:
		if not is_instance_valid(dialogue_resource):
			assert(false, DMConstants.get_error_message(DMConstants.ERR_MISSING_RESOURCE_FOR_AUTOSTART))
		start()



func _process(_delta: float) -> void:
	if is_instance_valid(dialogue_line):
		progress.visible = not dialogue_label.is_typing and dialogue_line.responses.size() == 0 and not dialogue_line.has_tag("voice")


func _unhandled_input(event: InputEvent) -> void:
	# Escape is not ours. Everything else that happens on screen stops while a
	# conversation is up, but the pause menu has to be reachable from inside one
	# - a conversation is exactly where somebody wants to turn the music down or
	# leave - so this is the one key that goes past.
	if event.is_action_pressed("ui_cancel"):
		return
	# Only the balloon is allowed to handle input while it's showing
	if will_block_other_input:
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	## Detect a change of locale and update the current dialogue line to show the new language
	if what == NOTIFICATION_TRANSLATION_CHANGED and _locale != TranslationServer.get_locale() and is_instance_valid(dialogue_label):
		_locale = TranslationServer.get_locale()
		var visible_ratio: float = dialogue_label.visible_ratio
		await dialogue_line.refresh()
		if visible_ratio < 1:
			dialogue_label.skip_typing()


## Start some dialogue
func start(with_dialogue_resource: DialogueResource = null, cue: String = "", extra_game_states: Array = []) -> void:
	temporary_game_states = [self] + extra_game_states
	is_waiting_for_input = false
	if is_instance_valid(with_dialogue_resource):
		dialogue_resource = with_dialogue_resource
	if not cue.is_empty():
		start_from_cue = cue
	dialogue_line = await dialogue_resource.get_next_dialogue_line(start_from_cue, temporary_game_states)
	show()


## Apply any changes to the balloon given a new [DialogueLine].
func apply_dialogue_line() -> void:
	# Being skipped past. Whatever this line does has already been done by the
	# time it arrives here - what is skipped is the reading of it, not the
	# doing. See skip_conversation().
	if _skipping:
		return
	mutation_cooldown.stop()

	progress.hide()
	if skip_button != null:
		skip_button.visible = true
	is_waiting_for_input = false
	balloon.focus_mode = Control.FOCUS_ALL
	balloon.grab_focus()

	character_label.visible = not dialogue_line.character.is_empty()
	character_label.text = tr(dialogue_line.character, "dialogue")

	var face = _portrait_for(dialogue_line)
	portrait.texture = face
	portrait.visible = face != null

	dialogue_label.hide()
	dialogue_label.dialogue_line = dialogue_line

	responses_menu.hide()
	responses_menu.responses = dialogue_line.responses

	# Show our balloon
	balloon.show()
	will_hide_balloon = false

	dialogue_label.show()
	if not dialogue_line.text.is_empty():
		dialogue_label.type_out()
		await dialogue_label.finished_typing

	# Skipping began while this line was typing. The skip is walking the
	# conversation now, and this must not walk it as well.
	if _skipping:
		return

	# Wait for next line
	if dialogue_line.has_tag("voice"):
		audio_stream_player.stream = load(dialogue_line.get_tag_value("voice"))
		audio_stream_player.play()
		await audio_stream_player.finished
		next(dialogue_line.next_id)
	elif dialogue_line.responses.size() > 0:
		balloon.focus_mode = Control.FOCUS_NONE
		if skip_button != null:
			skip_button.visible = false
		responses_menu.show()
	elif dialogue_line.time != "":
		var time: float = dialogue_line.text.length() * 0.02 if dialogue_line.time == "auto" else dialogue_line.time.to_float()
		await get_tree().create_timer(time).timeout
		next(dialogue_line.next_id)
	else:
		is_waiting_for_input = true
		balloon.focus_mode = Control.FOCUS_ALL
		balloon.grab_focus()


## Go to the next line
func next(next_id: String) -> void:
	# The one place every way of advancing ends up - a click, Enter, a voice
	# line finishing, a timed line running out, an answer being picked. While a
	# skip is walking the conversation it is the only thing allowed to, or two
	# walkers race each other and lines get stepped over twice.
	if _skipping:
		return
	dialogue_line = await dialogue_resource.get_next_dialogue_line(next_id, temporary_game_states)


#region Signals


func _on_mutation_cooldown_timeout() -> void:
	if will_hide_balloon:
		will_hide_balloon = false
		balloon.hide()


func _on_mutated(mutation: Dictionary) -> void:
	if not mutation.is_inline:
		is_waiting_for_input = false
		will_hide_balloon = true
		mutation_cooldown.start(0.1)


func _on_balloon_gui_input(event: InputEvent) -> void:
	# Not while the game is held. A paused Control can still be handed a click,
	# and a conversation advancing behind the pause menu is not what pressing
	# Escape asked for.
	if get_tree().paused:
		return

	# See if we need to skip typing of the dialogue
	if dialogue_label.is_typing:
		var mouse_was_clicked: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed()
		var skip_button_was_pressed: bool = event.is_action_pressed(skip_action)
		if mouse_was_clicked or skip_button_was_pressed:
			get_viewport().set_input_as_handled()
			dialogue_label.skip_typing()
			return

	if not is_waiting_for_input: return
	if dialogue_line.responses.size() > 0: return

	# Escape is not ours either way round: the balloon holds the keyboard while
	# a line is up, so a key reaches this before it reaches anything else, and
	# swallowing it here is what made the pause menu unreachable during a
	# conversation. See _unhandled_input.
	if event.is_action_pressed("ui_cancel"):
		return

	# When there are no response options the balloon itself is the clickable thing
	get_viewport().set_input_as_handled()

	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		next(dialogue_line.next_id)
	elif event.is_action_pressed(next_action) and get_viewport().gui_get_focus_owner() == balloon:
		next(dialogue_line.next_id)


func _on_responses_menu_response_selected(response: DialogueResponse) -> void:
	next(response.next_id)


#endregion

## --- Skipping ---
##
## A conversation you have read before is a conversation you should be able to
## get out of. What it does is not skippable, though - if a line adds somebody
## to the party, or sets a flag, or lines up the fight that follows, skipping
## has to leave the game in the state reading it would have. So the lines are
## still walked, one after another, exactly as pressing through them would walk
## them: get_next_dialogue_line() runs everything on the way past. Only the
## showing is dropped.


## The button in the corner.
func _build_skip_button() -> void:
	skip_button = Button.new()
	skip_button.name = "SkipButton"
	skip_button.text = "Skip  >>"
	skip_button.tooltip_text = "Skip to the end of the conversation. Everything it does still happens."
	# Never takes the keyboard. Advancing a line is "is the balloon focused",
	# so a button that grabbed focus on click would stop Enter working for the
	# rest of the conversation.
	skip_button.focus_mode = Control.FOCUS_NONE
	skip_button.anchor_left = 1.0
	skip_button.anchor_right = 1.0
	skip_button.offset_left = -136
	skip_button.offset_right = -18
	skip_button.offset_top = 18
	skip_button.offset_bottom = 54
	skip_button.pressed.connect(skip_conversation)
	_dress(skip_button)
	# Last, so it is over the response menu's full-rect container rather than
	# under it, and gets the click.
	balloon.add_child(skip_button)


## The same dark blue the menus and the glossary are built in, so a button that
## is made here rather than placed in the scene still looks like it belongs to
## the game it sits on top of.
func _dress(button: Button) -> void:
	const INK := Color("dce8f5")
	const CARD := Color("1c2531")
	const CARD_LIT := Color("24344a")
	const CARD_EDGE := Color("2b3947")
	button.add_theme_font_size_override("font_size", 15)
	for role in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(role, INK)
	button.add_theme_color_override("font_disabled_color", INK.darkened(0.45))
	button.add_theme_stylebox_override("normal", _plate(CARD, CARD_EDGE))
	button.add_theme_stylebox_override("hover", _plate(CARD_LIT, CARD_EDGE))
	button.add_theme_stylebox_override("pressed", _plate(CARD_LIT, CARD_EDGE))
	button.add_theme_stylebox_override("disabled", _plate(CARD, CARD_EDGE))


func _plate(fill: Color, edge: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(1)
	box.set_corner_radius_all(6)
	return box


## Walks the rest of the conversation without showing any of it.
##
## Stops at a question: choosing an answer for somebody is not skipping, so the
## conversation comes back to them there and carries on normally.
func skip_conversation() -> void:
	if _skipping or not is_inside_tree() or get_tree().paused:
		return
	if not is_instance_valid(dialogue_line):
		return
	if dialogue_line.responses.size() > 0:
		return
	_skipping = true
	skip_button.disabled = true
	dialogue_label.skip_typing()

	# A conversation that loops back on itself would otherwise be skipped for
	# ever. Far more lines than any conversation in the game has.
	var remaining := 5000
	while _skipping and is_instance_valid(dialogue_line) and remaining > 0:
		remaining -= 1
		if dialogue_line.responses.size() > 0:
			break
		var line = await dialogue_resource.get_next_dialogue_line(dialogue_line.next_id, temporary_game_states)
		# One of the lines just walked past may have closed this down - a
		# command that changes scene, for one - and there is nothing left to
		# come back to.
		if not is_inside_tree():
			return
		# Assigning null is how this balloon closes itself; get_next_dialogue_line
		# has already said the conversation ended.
		dialogue_line = line
		if line == null:
			return

	_skipping = false
	skip_button.disabled = false
	# Whatever we stopped at has not been shown yet, so show it now.
	if is_instance_valid(dialogue_line):
		apply_dialogue_line()


## --- Portraits ---
##
## Which face shows is written in the dialogue itself, as a tag on the line:
##
##   Cyrus: I don't like this.              -> imagese/portraits/cyrus.png
##   Cyrus: [#worried] I really don't.      -> imagese/portraits/cyrus_worried.png
##   Cyrus: [#portrait=armoured] Ready.     -> imagese/portraits/cyrus_armoured.png
##   Cyrus: [#noportrait] ...               -> no face at all
##   Narrator: The door creaks open.        -> none, unless narrator.png exists
##
## So a portrait is chosen per line, next to the line it belongs to, rather
## than in a table somewhere else that has to be kept in step with the script.
##
## Anything with no matching file simply shows no portrait. That way the whole
## feature degrades to exactly the old balloon while the art is still being
## drawn, instead of erroring or showing a blank box.

const PORTRAIT_DIR = "res://imagese/portraits"

## Tags that mean something other than "this is the expression". #noportrait
## suppresses the face for a line; #portrait=x names one explicitly, for an
## expression whose name would read badly as a bare tag.
const NO_PORTRAIT_TAG = "noportrait"
const PORTRAIT_TAG = "portrait"


## The portrait for the line being shown, or null for none.
func _portrait_for(line) -> Texture2D:
	if line == null or line.character.is_empty():
		return null
	if line.has_tag(NO_PORTRAIT_TAG):
		return null
	var who = _file_safe(line.character)
	if who == "":
		return null

	# An explicit [#portrait=name] wins, then the first tag that names a file
	# that exists, then the character's plain portrait.
	var wanted: Array[String] = []
	var named = line.get_tag_value(PORTRAIT_TAG)
	if named != "":
		wanted.append("%s_%s" % [who, _file_safe(named)])
	for tag in line.tags:
		if tag.contains("="):
			continue
		wanted.append("%s_%s" % [who, _file_safe(tag)])
	wanted.append(who)

	for name in wanted:
		var path = "%s/%s.png" % [PORTRAIT_DIR, name]
		if ResourceLoader.exists(path):
			return load(path)
	return null


## A character or expression name as it appears in a filename: lowercase, and
## spaces joined up, so "Old Man" finds old_man.png.
func _file_safe(text: String) -> String:
	return text.strip_edges().to_lower().replace(" ", "_")
