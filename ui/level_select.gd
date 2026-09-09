extends Control
## The menu the game opens on: pick an encounter, see what condition the party
## is in, and reset them when they have been ground down too far.
##
## To add an encounter: make a new EncounterDefinition resource (see that
## script's header) and drop it into the Encounters array on this scene's root
## node in the inspector. Nothing else needs changing - the buttons, keyboard
## navigation and scene loading are all built from this list at runtime.


## Every encounter offered, in the order they appear on screen.
@export var encounters: Array[EncounterDefinition]
## The battle scene loaded once an encounter is picked. One scene plays them
## all; the choice is passed through Campaign.current_encounter.
@export_file("*.tscn") var battle_scene: String = "res://scenes/game.tscn"

@onready var _list: VBoxContainer = $Center/VBox/EncounterList
@onready var _party_status: Label = $Center/VBox/PartyStatus
@onready var _reset_button: Button = $Center/VBox/ResetButton


func _ready():
	_reset_button.pressed.connect(_on_reset_pressed)
	_rebuild()


## Rebuilds the encounter buttons and the party line. Called on load and again
## after a reset, so the screen always reflects the current campaign state
## rather than a snapshot from when it was first opened.
func _rebuild():
	for child in _list.get_children():
		child.queue_free()
		_list.remove_child(child)

	var wiped = Campaign.is_party_wiped()
	var party = Campaign.describe_party()
	if wiped:
		_party_status.text = "Your party has fallen. Reset to fight again."
	elif party == "":
		_party_status.text = "Party at full strength."
	else:
		_party_status.text = "Party: " + party

	var buttons: Array = []
	for encounter in encounters:
		if encounter == null:
			continue
		var button = Button.new()
		button.text = encounter.display_name
		if encounter.description != "":
			button.tooltip_text = encounter.description
		# A wiped party would spawn an encounter with nobody on the player's
		# side, so there would be nothing to play. Reset is the way out.
		button.disabled = wiped
		button.pressed.connect(_on_encounter_pressed.bind(encounter))
		_list.add_child(button)
		if not wiped:
			buttons.append(button)

	buttons.append(_reset_button)
	FocusLoop.link(buttons)
	buttons[0].grab_focus()


func _on_encounter_pressed(encounter: EncounterDefinition):
	Campaign.current_encounter = encounter
	get_tree().change_scene_to_file(battle_scene)


func _on_reset_pressed():
	Campaign.reset()
	_rebuild()
