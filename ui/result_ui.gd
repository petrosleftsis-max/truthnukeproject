extends CanvasLayer
## Shown once a battle ends, so there is a way back to the level select
## instead of the game simply stopping. Before this existed, Combat emitted
## combat_finished and nothing was listening.
##
## The party's carried-over condition is already recorded by then (Combat does
## it in combat_finish, before emitting), so whatever is shown here is exactly
## what the next encounter starts from.
##
## An encounter can have the last word: set victory_dialogue (or
## defeat_dialogue) on it and that conversation plays first, with the panel
## held back until it has finished.


## The balloon this game talks through - the same one the maps use, so a line
## spoken over a battlefield looks like every other line in the game.
const BALLOON_SCENE = "res://ui/dialogue_balloon.tscn"

@export var combat: Combat


func _ready():
	$Panel.visible = false
	$Panel/VBox/BackButton.pressed.connect(_on_back_pressed)
	$Panel/VBox/MainMenuButton.pressed.connect(_on_main_menu_pressed)
	if combat != null:
		combat.combat_finished.connect(_on_combat_finished)
	else:
		push_warning("ResultUI has no Combat assigned - the end of a battle will not be shown.")


func _on_combat_finished():
	var players_left = combat.groups[Combat.Group.PLAYERS].size() > 0
	var enemies_left = combat.groups[Combat.Group.ENEMIES].size() > 0
	var won = not enemies_left and players_left
	if not players_left and not enemies_left:
		$Panel/VBox/Title.text = "Draw"
	elif not enemies_left:
		$Panel/VBox/Title.text = "Victory"
	else:
		$Panel/VBox/Title.text = "Defeat"
	# A battle started from an exploration map retires its trigger on a win, so
	# the same fight isn't waiting there when the party walks back past it.
	if Campaign.has_map_to_return_to():
		Campaign.finish_battle_from_exploration(not enemies_left)
		$Panel/VBox/BackButton.text = "Continue"
	$Panel/VBox/Summary.text = _describe_party()
	# Whatever this encounter has to say about how it went, before the panel.
	if _speak_for(won):
		return
	_show_panel()


## Plays the encounter's own closing conversation, if it has one for this
## outcome. True when something is being said and the panel should wait.
##
## The panel is held back rather than shown underneath, because a result screen
## sitting behind a balloon reads as the game having already moved on from
## whatever is being said over the bodies.
func _speak_for(won: bool) -> bool:
	var encounter: EncounterDefinition = combat.encounter if combat != null else null
	if encounter == null:
		return false
	var dialogue: Resource = encounter.victory_dialogue if won else encounter.defeat_dialogue
	if dialogue == null:
		return false
	var title: String = encounter.victory_dialogue_title if won else encounter.defeat_dialogue_title
	var manager = Engine.get_singleton("DialogueManager") if Engine.has_singleton("DialogueManager") else get_node_or_null("/root/DialogueManager")
	if manager == null:
		push_warning("There is no DialogueManager to speak through - showing the result instead.")
		return false
	# dialogue_ended fires however the conversation finishes, including being
	# skipped, so the panel always arrives.
	manager.dialogue_ended.connect(_on_closing_words_ended, CONNECT_ONE_SHOT)
	manager.show_dialogue_balloon_scene(BALLOON_SCENE, dialogue, title if title != "" else "start")
	return true


func _on_closing_words_ended(_resource = null):
	_show_panel()


func _show_panel():
	$Panel.visible = true
	$Panel/VBox/BackButton.grab_focus()


## What the party is walking away with - the same information the level select
## will show, surfaced here so the cost of the win is visible immediately.
func _describe_party() -> String:
	var party = Campaign.describe_party()
	return "Party: " + party if party != "" else ""


## Back to wherever the battle came from: the exploration map the party was
## standing in, or the level select if the fight was picked from the menu.
func _on_back_pressed():
	if Campaign.has_map_to_return_to():
		SceneTransition.change_scene("res://scenes/exploration.tscn")
	else:
		SceneTransition.change_scene("res://scenes/level_select.tscn")


## Out of the run entirely. Offered whichever way the battle went and wherever
## it came from: finishing a fight is the natural moment to stop playing, and
## before this the only way out of a map's battle was to carry on with the map.
func _on_main_menu_pressed():
	Campaign.to_main_menu()
