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

## Whether the battle just over was won.
var _won := false
## The rest between a dungeon's fights, once it is up.
var rest: RestPanel = null
## The prisoners being questioned, while they are (InterrogationPanel).
var prisoners_panel: InterrogationPanel = null
var _questioned := false


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
	# Somebody who must not get away got away: lost, whoever is left standing.
	var lost_anyway: bool = combat.lost_because != ""
	var won = not enemies_left and players_left and not lost_anyway
	if lost_anyway:
		$Panel/VBox/Title.text = "Defeat"
	elif not players_left and not enemies_left:
		$Panel/VBox/Title.text = "Draw"
	elif not enemies_left:
		$Panel/VBox/Title.text = "Victory"
	else:
		$Panel/VBox/Title.text = "Defeat"
	# A battle started from an exploration map retires its trigger on a win, so
	# the same fight isn't waiting there when the party walks back past it.
	if Campaign.has_map_to_return_to():
		Campaign.finish_battle_from_exploration(not enemies_left and not lost_anyway, combat.arriving())
		$Panel/VBox/BackButton.text = "Continue"
		# A milestone fight, won in the story: the party goes up a level.
		if won and not Campaign.in_dungeon() and combat.encounter != null and combat.encounter.party_reaches_level > 0:
			Campaign.reach_level(combat.encounter.party_reaches_level)
	# Paid for winning, wherever the party has a purse: the story and dungeons.
	if won and (Campaign.has_map_to_return_to() or Campaign.in_dungeon()) and combat.encounter != null:
		Campaign.give_gold(combat.encounter.gold_reward)
	# A fight that finishes its story offers the title screen and nothing else.
	# The encounter says so itself - see EncounterDefinition.victory_ends_the_run
	# - rather than this knowing which fights are last.
	$Panel/VBox/BackButton.visible = not (won and _ends_the_run())
	_won = won
	if Campaign.in_dungeon():
		# A dungeon goes on to its next fight, not back to the map - or, lost,
		# starts again from the top.
		$Panel/VBox/BackButton.visible = not won or Campaign.on_last_dungeon_stage()
		$Panel/VBox/BackButton.text = "Finish" if won else "Start the dungeon again"
		if won and Campaign.on_last_dungeon_stage():
			$Panel/VBox/Title.text = "%s cleared" % Campaign.dungeon.display_name
	$Panel/VBox/Summary.text = _describe_party()
	# Whatever this encounter has to say about how it went, before the panel.
	if _speak_for(won):
		return
	_show_panel()


## Whether winning this battle is the end of what it belongs to.
func _ends_the_run() -> bool:
	var encounter: EncounterDefinition = combat.encounter if combat != null else null
	return encounter != null and encounter.victory_ends_the_run


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
	var dungeon_rest: bool = Campaign.in_dungeon() and _won and not Campaign.on_last_dungeon_stage()
	# Between a dungeon's fights the rest takes the panel's place, so anybody
	# worth questioning is questioned first; anywhere else it is a button on
	# the panel, for the player to take up or not.
	if dungeon_rest and not _questioned and not prisoners_to_question().is_empty():
		question_prisoners(_show_panel)
		return
	_refresh_prisoners_button()
	if dungeon_rest:
		_rest()
		return
	$Panel.visible = true
	# Offered to the keyboard, not pressed into its hand - see FocusOnDemand.
	# Whichever button is actually on the panel is where the keyboard starts.
	var first = $Panel/VBox/BackButton
	if not first.visible:
		first = $Panel/VBox/MainMenuButton
	FocusOnDemand.attach(self, first)


## Between a dungeon's fights: everyone rested, and the rest's own panel - with
## its offer of gates back - in place of this one. Continue goes on to the next
## stage.
func _rest():
	Campaign.rest_party()
	# The battle stays where it was behind, dimmed: it is over, and the rest is
	# what is being read.
	var dim := ColorRect.new()
	dim.name = "RestDim"
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	rest = RestPanel.new()
	rest.name = "Rest"
	rest.continued.connect(Campaign.next_dungeon_stage)
	add_child(rest)


## What the party is walking away with - the same information the level select
## will show, surfaced here so the cost of the win is visible immediately.
func _describe_party() -> String:
	var party = Campaign.describe_party()
	return "Party: " + party if party != "" else ""


## Back to wherever the battle came from: the exploration map the party was
## standing in, or the level select if the fight was picked from the menu.
func _on_back_pressed():
	if Campaign.in_dungeon():
		if _won:
			Campaign.next_dungeon_stage()
		else:
			Campaign.start_dungeon(Campaign.dungeon)
		return
	if Campaign.has_map_to_return_to():
		SceneTransition.change_scene("res://scenes/exploration.tscn")
	else:
		SceneTransition.change_scene("res://scenes/level_select.tscn")


## Out of the run entirely. Offered whichever way the battle went and wherever
## it came from: finishing a fight is the natural moment to stop playing, and
## before this the only way out of a map's battle was to carry on with the map.
func _on_main_menu_pressed():
	Campaign.to_main_menu()


## --- Prisoners ---
##
## Whoever of the other side was taken alive (Combat.prisoners) - one of each
## kind that still has something to tell (Campaign.has_something_to_tell) - is
## for the player to question (InterrogationPanel): from a button on the panel,
## or before the rest between a dungeon's fights.

var _prisoners_button: Button = null


## Whether the encounter's own Victory Dialogue decides what becomes of the
## prisoners (EncounterDefinition.dialogue_decides_prisoners) - then there is
## nobody here to question.
func _dialogue_decides() -> bool:
	return combat != null and combat.encounter != null and combat.encounter.dialogue_decides_prisoners


## One taken prisoner of each kind with something left to tell, and how many of
## each kind were taken: [prisoners, counts]. None when the encounter's own
## conversation deals with them.
func prisoners_to_question() -> Array:
	if _dialogue_decides():
		_prisoner_counts = {}
		return []
	var firsts := []
	var counts := {}
	if combat == null or not _won:
		return firsts
	for prisoner in combat.prisoners():
		var key: String = prisoner.get("combatant_key", "")
		counts[key] = counts.get(key, 0) + 1
		if counts[key] == 1 and Campaign.has_something_to_tell(key):
			firsts.append(prisoner)
	_prisoner_counts = counts
	return firsts

var _prisoner_counts: Dictionary = {}


## Puts the prisoners up to question, and `after` once they are done with.
func question_prisoners(after: Callable = Callable()):
	_questioned = true
	var prisoners := prisoners_to_question()
	prisoners_panel = InterrogationPanel.new()
	prisoners_panel.name = "Prisoners"
	add_child(prisoners_panel)
	prisoners_panel.show_prisoners(prisoners, _prisoner_counts)
	prisoners_panel.done.connect(func():
		prisoners_panel.queue_free()
		prisoners_panel = null
		_refresh_prisoners_button()
		if after.is_valid():
			after.call()
		elif $Panel.visible:
			FocusOnDemand.attach(self, $Panel/VBox/BackButton if $Panel/VBox/BackButton.visible else $Panel/VBox/MainMenuButton))


func _refresh_prisoners_button():
	if _prisoners_button == null:
		_prisoners_button = Button.new()
		_prisoners_button.name = "PrisonersButton"
		_prisoners_button.pressed.connect(func(): question_prisoners())
		$Panel/VBox.add_child(_prisoners_button)
		$Panel/VBox.move_child(_prisoners_button, $Panel/VBox/BackButton.get_index())
	var waiting := prisoners_to_question() if not _questioned else []
	_prisoners_button.visible = not waiting.is_empty()
	_prisoners_button.text = "Question the prisoners (%d)" % waiting.size()
