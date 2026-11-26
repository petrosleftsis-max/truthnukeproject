@tool
@icon("res://art/editor_icons/interactable.svg")
extends Interactable
class_name Rehearsal
## Fights rehearsed in the dream-place (the proposals of 2026-11-19, "A dream-place"; the designer: "Do all"): a run of its
## Encounters, one each time it is stepped into, back to the dream between them. As a run begins one blessing is drawn at random
## from Blessings and lies on everybody of the party for the whole run (Campaign.run_blessing; Combat adds it to each of them); after
## its last fight the blessing is gone and the next run draws again. Nothing of the campaign is put by for it, unlike a dungeon.
## Locked as any interactable is until its Requires Flag (the dream's lamps). A placeholder doorway of light until it has a picture.
## PROPOSAL.

@export var encounters: Array[EncounterDefinition] = []
## Passives' file names (data/passives) to draw the blessing from.
@export var blessings: Array[String] = ["blessing_swift", "blessing_iron", "blessing_patient"]

## Every blessing there is. Nobody holds one, so this is how the glossary reaches them in an exported build, where a scan of
## data/passives finds nothing (GlossaryPanel.passives). A new blessing goes here too.
const BLESSINGS := [
	preload("res://data/passives/blessing_swift.tres"),
	preload("res://data/passives/blessing_iron.tres"),
	preload("res://data/passives/blessing_patient.tres"),
]

const STEP_FLAG := "rehearsal_step"
const LAST_FLAG := "rehearsal_last"


func _init():
	prompt = "Rehearse"


func interact(scene: Node):
	if encounters.is_empty() or blessings.is_empty():
		push_warning("Rehearsal '%s' has no encounters or no blessings." % name)
		return
	var step := int(Campaign.flags.get(STEP_FLAG, 0)) % encounters.size()
	if step == 0 or Campaign.run_blessing == "":
		Campaign.run_blessing = blessings[randi() % blessings.size()]
		var passive = load("res://data/passives/%s.tres" % Campaign.run_blessing)
		scene.log_message("The dream gives you the %s for this run.\n" % (passive.name if passive != null else Campaign.run_blessing))
	Campaign.flags[STEP_FLAG] = step + 1
	if step + 1 >= encounters.size():
		Campaign.flags[STEP_FLAG] = 0
		Campaign.set_flag(LAST_FLAG)
	MapFeel.sound(&"dream", -2.0, 1.2, global_position)
	Campaign.begin_battle_from_exploration(encounters[step], scene.map_path(), scene.party_position(), "")
	SceneTransition.change_scene(scene.battle_scene)


## Back from a run's last fight: the blessing is gone (ExplorationScene, as a map comes up).
static func end_run_if_over():
	if Campaign.flag(LAST_FLAG):
		Campaign.flags.erase(LAST_FLAG)
		Campaign.run_blessing = ""


func _draw():
	super()
	if texture != null or sprite_frames != null:
		return
	var tile := float(Grid.TILE_SIZE)
	var locked := not Engine.is_editor_hint() and not is_unlocked()
	var colour := Color(0.6, 0.5, 0.8, 0.5) if locked else Color(0.95, 0.85, 1.0, 0.85)
	draw_rect(Rect2(-tile * 0.3, -tile * 0.9, tile * 0.6, tile * 1.2), colour)
	draw_rect(Rect2(-tile * 0.3, -tile * 0.9, tile * 0.6, tile * 1.2), Color("3c3550"), false, 5.0)
