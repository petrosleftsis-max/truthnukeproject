extends Node
## Not part of the game. Open demos/try_stealth_demo.tscn and press F6 to walk
## the stealth demo: the lab, three guards, a locker with a disguise in it, and
## a notice board to look at closely. See demos/stealth_demo.tscn for how it is
## put together - it is an ordinary exploration map with a StealthSetup in it.

@export_file("*.tscn") var map: String = "res://demos/stealth_demo.tscn"


func _ready():
	Campaign.reset()
	Campaign.current_map = map
	get_tree().change_scene_to_file.call_deferred("res://scenes/exploration.tscn")
