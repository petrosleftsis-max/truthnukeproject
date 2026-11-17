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

## Above everything - the whole point is to cover the HUD too. The layers under
## it, in order: the hurt vignette 5, the character sheet 8, the reaction prompt
## 15, the result panel 20, the dialogue balloon 30, the inventory 60 and the
## pause menu 70, which has to be over the balloon so that Escape during a
## conversation opens something you can see.
const LAYER = 100

## True while a change is in flight, so a second request cannot land mid-fade
## and leave the screen black over a scene nobody asked for.
var _changing := false

var _screen: ColorRect = null


func _ready():
	# The first autoload with anything to show, so the fonts are on the theme
	# before any screen is built. See GameFonts for why it is done here.
	GameFonts.apply()
	# And in the interface's look, T (SkyLook), before any screen is built for the same reason.
	SkyLook.apply()
	GameSounds.listen(get_tree())
	# And every button and panel moves (UiFeel).
	UiFeel.listen(get_tree())
	Campaign.gold_changed.connect(func(_gold): GameSounds.play(&"coin"))
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
	# The last picture of a map or a fight, held while the scene changes under it (The map becomes the board).
	_carried = TextureRect.new()
	_carried.name = "Carried"
	_carried.set_anchors_preset(Control.PRESET_FULL_RECT)
	_carried.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_carried.stretch_mode = TextureRect.STRETCH_SCALE
	_carried.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_carried.visible = false
	add_child(_carried)
	# The first scene of a session is one nobody faded out of, so it would
	# otherwise snap into existence. Autoloads are ready before it exists, so
	# starting opaque and fading up covers its first frame without any scene
	# needing to know this is here.
	fade_in()


## Fades out, changes to `path`, fades back in.
##
## Returns immediately - the caller is usually a node inside the scene being
## replaced, and awaiting its own destruction is not something to ask of it.
##
## Over a network the joiner goes only where the host goes (Net): a change asked
## for on the joiner by anything else is refused, and one on the host is sent.
func change_scene(path: String):
	if _changing:
		return
	var net = get_node_or_null("/root/Net")
	if net != null and not net.may_change_scene(path):
		return
	_changing = true
	# Into a fight on the ground the party stands on, and back from it won: carried across rather than through black.
	if _carries(path):
		_run_carry(path)
		return
	_run_change(path)


## --- The map becomes the board ---
##
## The proposals of 2026-11-17, section 7 (the designer: "From section 4 and on do all"). Into a fight fought on the very ground of
## the map the party is on (the encounter's terrain is the map's own: a stealth map caught, a fight on the map), and back to that map
## once the fight is won, there is no black: the last picture of the world - its HUD left out - is held over the screen while the
## scene changes under it, the new scene opens its view where the old one's was (`take_carried_view`: the map and its fight share
## their ground and its place), and the picture dissolves into it. Into a fight the view then pushes in to the party and the
## board's lines draw out from them (Combat.go_on_from_carried); back to the map the board's view first pulls back to where the
## party will stand there, at the map's own zoom. Each machine does it for itself, a joiner following the host too. Headless, and
## anywhere else, a change is the fade it always was. PROPOSAL.
const FIGHT_SCENE := "res://scenes/game.tscn"
const MAP_SCENE := "res://scenes/exploration.tscn"
## The map camera's own zoom (scenes/exploration.tscn), which the board's view pulls back to before it is carried back.
const MAP_ZOOM := 0.25
const CARRY_DISSOLVE := 0.55
const CARRY_PULL_BACK_MS := 900
var _carried: TextureRect = null
var _carried_view := {}
## The map a carried fight came from: carried back to it once the fight is won.
var _fought_on := ""
## How many changes were carried, for a suite.
var carries := 0


## The view the scene arriving should open on, {"at" (the middle of the screen, in the world), "zoom"}, once: empty after, or when
## nothing was carried.
func take_carried_view() -> Dictionary:
	var view := _carried_view
	_carried_view = {}
	return view


## Whether going to `path` from here is carried across.
func _carries(path: String) -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	var view: LightView = LightView.showing
	if view == null or not is_instance_valid(view) or view._tile_map == null:
		return false
	if path == FIGHT_SCENE:
		var fight: EncounterDefinition = Campaign.current_encounter
		var ground := _ground_of(view._tile_map)
		return fight != null and fight.terrain_scene != null and ground != "" and fight.terrain_scene.resource_path == ground \
			and Campaign.has_map_to_return_to()
	if path == MAP_SCENE:
		return _fought_on != "" and _fought_on == Campaign.current_map and _won_here()
	return false


## The terrain scene `tile_map` is part of: the map's own ground, or the fight's.
static func _ground_of(tile_map: TileMap) -> String:
	if tile_map.scene_file_path != "":
		return tile_map.scene_file_path
	return tile_map.owner.scene_file_path if tile_map.owner != null else ""


## Whether the fight being left was won.
func _won_here() -> bool:
	var scene := get_tree().current_scene
	var fight = scene.get("combat") if scene != null else null
	return fight is Combat and fight.combat_over and fight.lost_because == "" \
		and fight.groups[Combat.Group.ENEMIES].is_empty() and not fight.groups[Combat.Group.PLAYERS].is_empty()


func _run_carry(path: String):
	carries += 1
	var into_a_fight := path == FIGHT_SCENE
	var scene := get_tree().current_scene
	var camera := get_viewport().get_camera_2d()
	# The world alone: whatever is drawn over it - the HUD, the panels - put away for the picture.
	if scene != null:
		for over in scene.find_children("*", "CanvasLayer", true, false):
			if over.layer > 0:
				over.visible = false
	if not into_a_fight and camera != null and camera.has_method("glide_to"):
		# Back to the map: the view first to where the party will stand there, at the map's own zoom.
		camera.glide_to(Campaign.return_position, MAP_ZOOM)
		var until := Time.get_ticks_msec() + CARRY_PULL_BACK_MS
		while camera.is_inside_tree() and camera.is_gliding() and Time.get_ticks_msec() < until:
			await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var picture := get_viewport().get_texture().get_image()
	_carried_view = {"at": camera.get_screen_center_position(), "zoom": camera.zoom} if camera != null and is_instance_valid(camera) else {}
	_fought_on = Campaign.current_map if into_a_fight else ""
	_carried.texture = ImageTexture.create_from_image(picture)
	_carried.modulate.a = 1.0
	_carried.visible = true
	MenuPause.clear(get_tree())
	var net = get_node_or_null("/root/Net")
	if net != null:
		net.scene_changing(path)
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	# On real time: a map caught slows the world a moment, and the dissolve is not to crawl with it.
	var dissolve := create_tween().set_ignore_time_scale(true)
	dissolve.tween_property(_carried, "modulate:a", 0.0, CARRY_DISSOLVE)
	await dissolve.finished
	_carried.visible = false
	_carried.texture = null
	_carried_view = {}
	_changing = false


## Whether a change is under way - between the fade starting out and the new
## scene faded in. Anything that would set up a different scene has to wait:
## this one is going ahead regardless.
func is_changing() -> bool:
	return _changing


func _run_change(path: String):
	await fade_out()
	# Whoever was holding the game is about to stop existing and can no longer
	# let go of it, so the scene arriving would arrive frozen. See MenuPause.
	MenuPause.clear(get_tree())
	# Sent now rather than when asked: what was asked for has all been set up
	# by the time the screen is dark.
	var net = get_node_or_null("/root/Net")
	if net != null:
		net.scene_changing(path)
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
