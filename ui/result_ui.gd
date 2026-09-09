extends CanvasLayer
## Shown once a battle ends, so there is a way back to the level select
## instead of the game simply stopping. Before this existed, Combat emitted
## combat_finished and nothing was listening.
##
## The party's carried-over condition is already recorded by then (Combat does
## it in combat_finish, before emitting), so whatever is shown here is exactly
## what the next encounter starts from.


@export var combat: Combat


func _ready():
	$Panel.visible = false
	$Panel/VBox/BackButton.pressed.connect(_on_back_pressed)
	if combat != null:
		combat.combat_finished.connect(_on_combat_finished)
	else:
		push_warning("ResultUI has no Combat assigned - the end of a battle will not be shown.")


func _on_combat_finished():
	var players_left = combat.groups[Combat.Group.PLAYERS].size() > 0
	var enemies_left = combat.groups[Combat.Group.ENEMIES].size() > 0
	if not players_left and not enemies_left:
		$Panel/VBox/Title.text = "Draw"
	elif not enemies_left:
		$Panel/VBox/Title.text = "Victory"
	else:
		$Panel/VBox/Title.text = "Defeat"
	$Panel/VBox/Summary.text = _describe_party()
	$Panel.visible = true
	$Panel/VBox/BackButton.grab_focus()


## What the party is walking away with - the same information the level select
## will show, surfaced here so the cost of the win is visible immediately.
func _describe_party() -> String:
	var party = Campaign.describe_party()
	return "Party: " + party if party != "" else ""


func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/level_select.tscn")
