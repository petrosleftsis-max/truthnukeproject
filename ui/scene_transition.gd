extends CanvasLayer
## Fades the screen out, swaps the scene, and fades it back in.
##
## A scene change is otherwise a single frame in which everything is replaced -
## the map, the party, the HUD - which reads as a glitch rather than as going
## somewhere. Half a second of black in the middle turns it into a transition.
##
## An autoload, because the thing doing the fading has to outlive the scene
## being faded out. Anything inside that scene is freed halfway through, and the
## screen would snap back to full brightness at exactly the wrong moment.
##
## Call it instead of get_tree().change_scene_to_file:
##
##     SceneTransition.change_scene("res://scenes/game.tscn")
##
## and the fade takes care of itself. It is safe to call from anywhere,
## including from a node that is about to be freed by the change.

## Long enough to register, short enough not to be in the way. The two halves
## are separate because covering up wants to feel decisive and arriving wants
## to feel gentler.
const FADE_OUT = 0.22
const FADE_IN = 0.3

## Above everything - the whole point is to cover the HUD too. The pause menu
## is 10, the reaction prompt 15.
const LAYER = 100

## True while a change is in flight, so a second request cannot land mid-fade
## and leave the screen black over a scene nobody asked for.
var _changing := false

var _screen: ColorRect = null


func _ready():
	layer = LAYER
	# Keeps fading while the tree is paused - the pause menu is a Control like
	# any other and can start a scene change.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_screen = ColorRect.new()
	_screen.color = Color(0, 0, 0, 1)
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Never eats a click: it is only ever fully opaque while the scene is being
	# swapped, and a stray press during a fade should reach whatever is under it.
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.modulate.a = 1.0
	add_child(_screen)
	# The first scene of a session is one nobody faded out of, so it would
	# otherwise snap into existence. Autoloads are ready before it exists, so
	# starting opaque and fading up covers its first frame without any scene
	# needing to know this is here.
	fade_in()


## Fades out, changes to `path`, fades back in.
##
## Returns immediately - the caller is usually a node inside the scene being
## replaced, and awaiting its own destruction is not something to ask of it.
func change_scene(path: String):
	if _changing:
		return
	_changing = true
	_run_change(path)


func _run_change(path: String):
	await fade_out()
	get_tree().change_scene_to_file(path)
	# One frame for the new scene to be built, so the fade back in reveals it
	# rather than the gap where it is about to be.
	await get_tree().process_frame
	await fade_in()
	_changing = false


func fade_out():
	var tween = create_tween()
	tween.tween_property(_screen, "modulate:a", 1.0, FADE_OUT)
	await tween.finished


func fade_in():
	var tween = create_tween()
	tween.tween_property(_screen, "modulate:a", 0.0, FADE_IN)
	await tween.finished


## Fades up from black without changing anything, for the first scene of a
## session - which nobody faded out of, so it would otherwise appear abruptly.
func fade_in_from_black():
	_screen.modulate.a = 1.0
	await fade_in()
