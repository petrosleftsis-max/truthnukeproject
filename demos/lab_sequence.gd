extends Node
## TEMPORARY test harness, not story content: open lab_sequence_conservation.tscn
## or lab_sequence_free_spending.tscn and press F6. Starts the late-Chapter-I
## laboratory sequence (data/dungeons/lab_chapter1_sequence.tres) - three fights,
## no rest between - with every fight logged under this scene's label, to
## docs/lab_runs/ (LabMetrics). Play it the way the label says:
## - conservation: spend as few gates and items as the fights allow
## - free-spending: spend whatever helps, as soon as it helps

## What this run is: "conservation" or "free-spending". Names its files.
@export var run_label: String = "conservation"
@export var dungeon: DungeonDefinition


func _ready():
	if dungeon == null:
		push_error("lab_sequence: no dungeon to run.")
		return
	LabMetrics.begin_run(run_label)
	# Not while this scene is still coming up.
	Campaign.start_dungeon.call_deferred(dungeon)
