extends "res://StealthHarness.gd"
## Network play (Net; docs/multiplayer_plan.md Step 2). Two machines are two
## Godots on this one: this one hosts, and starts a second, headless, that plays
## the joiner's half (`--net-client`) and writes its own log - copied into this
## one's at the end, its FAILs counted with these, and its Godot's own output
## read for script errors. The two talk over 127.0.0.1 on ports of their own, so
## a game being played on this machine is left alone, and the beacon goes to
## 127.0.0.1 rather than out over the network.
##
## - the Players panel's network half, which listens for nothing until asked
## - hosting: the host's player is seated on peer 1; another version, another
##   build, an empty hello and a full table are turned away
## - resources as data: an encounter made on the spot goes as data and comes
##   back the same, one from a file goes as its file, and nothing but the game's
##   own data scripts is ever made from what arrives
## - finding and joining while the host is on a map: the joiner hears the
##   beacon, is seated as the second player on its own machine with the same
##   table, and comes straight onto the host's map, its group its own
## - Campaign followed: gold and a flag set on the host reach the joiner
## - the joiner will not change scene by itself, and follows the host's reload
## - aimed on the joiner's own screen: a throw aimed and let go there lands on
##   the host, out of the joiner's leader's bag; a press says which guard its
##   pointer was on, read on the host as that player's pointer; a click there
##   on a guard knocked out drags him on the host, and again puts him down
## - Alithia's familiar called with G on the joiner, on the host's map: steered
##   from the joiner, seen through there, walked there and put where it went on
##   the host; E sends it to her shoulder, G lets it go
## - a hack the joiner's player sets going is played on their screen, and opens
##   the strongbox on the host; a quick time of theirs is played there too
## - a conversation begun on the joiner: its lines pressed on through there, its
##   answer chosen on both - two different picks are both shown, and asked again;
##   the host's camera glides to the joiner's party meanwhile, and back after
## - what a menu on the joiner changes is laid over what the host's player did
##   meanwhile: gold by how much, a bag by its places
## - what each side changed, laid together (Net._merged): a flag both set at once
##   is a clash, a bag changed in two places keeps both, gold never below nothing
## - a picture both search: opened on the joiner by its press, what it finds is
##   on the host at once; the host's player opens it too and sees it found, the
##   same "Noticed", each the other's pointer and what the other's click said;
##   the joiner marked on the host's map meanwhile
## - a lock turned on both: a dial the joiner turns turns on the host, the host
##   turns the other two and it opens on both; the form the joiner takes out is
##   gone from the host's copy and in the bag once
## - one store, both at it: a deal on the joiner made on the host out of the one
##   purse, each store showing what the other bought, the last of the gold bought
##   once and the late one told why
## - a conversation the host's player begins opens its picture on both, the
##   joiner's camera drawn to the host's party; the host closing it closes the
##   joiner's, and the conversation goes on
## - whom to steer, asked of the other player: refused, nothing changes; agreed,
##   it does - either way round, and from the pause menu's Party Management,
##   where the host can kick the joiner out
## - the joiner leaving mid-fight takes its player with it and its characters go
##   back; joining again mid-fight, it plays the fight through from its
##   beginning, fast and its presses held, until it stands where the host's
##   does, then chooses Enfina, who is handed over at once, and the two play it
##   to the same end
## - kicked out, the joiner is told so on its title screen; joining again, it
##   chooses nobody and watches, offered nothing to share out; the host leaving
##   sends it to the title screen too

const TEST_PORT := 24790
const TEST_BEACON := 24791
## A stealth stage with guards, doors and lamps to watch over.
const STAGE := "res://maps/stealth_stages/stealth_5.tscn"

var _joiner_pid := -1
## What the other machine has said (say).
var _heard: Array = []


func suite() -> String:
	return "net_joiner" if joining_half() else "net"


func time_limit() -> float:
	return 1080.0


static func joining_half() -> bool:
	return OS.get_cmdline_user_args().has("--net-client")


func run_sections():
	# The fight the harness starts in is not wanted by either half.
	if get_tree().current_scene != null:
		get_tree().current_scene.queue_free()
	await settle()
	Coop.reset()
	Campaign.controllers.clear()
	Net.discovery_port = TEST_BEACON
	Net.beacon_to = "127.0.0.1"
	if joining_half():
		await joiners_half()
	else:
		await hosts_half()


## --- Between the two machines ---


## A word to the other machine: how far this half has got, for it to wait on.
func say(what: String):
	if multiplayer.has_multiplayer_peer() and Net.active():
		_say.rpc(what)


@rpc("any_peer", "reliable")
func _say(what):
	_heard.append(str(what))


## Until the other machine has said `what`.
func hear(what: String, seconds: float = 20.0) -> bool:
	return await until(func(): return _heard.has(what), seconds)


## What the other machine said that begins with `start`, without it - or "".
func heard_after(start: String) -> String:
	for line in _heard:
		if line.begins_with(start):
			return line.trim_prefix(start)
	return ""


## --- A conversation, mirrored ---


const PROBE := "res://dialogue/_net_probe.dialogue"


func hosts_conversation():
	log_line("======== a conversation, both choosing ========")
	var scene: ExplorationScene = get_tree().current_scene
	# The map set its own cast, and Enfina may have fallen in the fight: Alithia,
	# the joiner's and in no fight yet, joins so the joiner has a group to walk.
	Campaign.add_member("alithia")
	Campaign.controllers["alithia"] = 1
	ok(await until(func(): return scene.groups.has(1), 10.0), "the joiner has a group on the map again")
	ok(await hear("group back"), "  there too")
	if not scene.groups.has(1):
		return
	apart(scene)
	var talk := DialogueInteractable.new()
	talk.dialogue = load(PROBE)
	scene.get_node("Map").add_child(talk)
	talk.global_position = scene.groups[1].leader.global_position
	scene._interactables.append(talk)
	say("talk up")
	ok(await until(func(): return Coop.focus == 1, 15.0), "E pressed on the joiner starts a conversation here - its lines the joiner's to press on through",
		"focus %d" % Coop.focus)
	var theirs: ExplorationParty = scene.groups[1]
	ok(await until(func(): return scene.conversation_shot == 1 and scene.camera.position.distance_to(within_view(scene, theirs.leader.position)) < 12.0, 8.0),
		"  and the camera here glides over to the joiner's party, whose conversation it is",
		"%s, theirs at %s" % [scene.camera.position, theirs.leader.position])
	ok(await until(question_up, 20.0), "  pressed on there, the question comes up here")
	ok(Coop.focus == Coop.ANYONE, "  and its answer is both players': neither is kept from choosing", "focus %d" % Coop.focus)
	var balloon = Net._balloon
	if not question_up():
		return
	balloon._on_responses_menu_response_selected(balloon.dialogue_line.responses[0])
	await settle()
	ok(question_up() and not Campaign.flag("net_went_left"), "the host's player picks Left: nothing is taken until the joiner has picked too")
	ok(balloon._choice_note != null and balloon._choice_note.visible and balloon._choice_note.text.begins_with("Waiting"),
		"  and the balloon says it waits for them", balloon._choice_note.text if balloon._choice_note != null else "(no note)")
	say("host picked")
	ok(await until(func(): return balloon._choice_note.text.contains("choose again"), 15.0),
		"the joiner picks Right - two answers, so both are told what each chose, and choose again", balloon._choice_note.text)
	ok(balloon.responses_menu.visible and not Campaign.flag("net_went_left") and not Campaign.flag("net_went_right"),
		"  the answers back here, and neither taken")
	ok(await hear("picked again"), "the joiner picks Right again")
	balloon._on_responses_menu_response_selected(balloon.dialogue_line.responses[1])
	ok(await until(func(): return Campaign.flag("net_went_right"), 20.0), "  and so does the host's player: the same answer, taken")
	ok(not Campaign.flag("net_went_left"), "  and only that one")
	ok(await until(func(): return Coop.focus == Coop.ANYONE and not scene.is_holding(), 10.0),
		"  and with it over, nobody holds the map")
	ok(await until(func(): return scene.conversation_shot == -1 and scene._gliding_back <= 0.0 \
			and scene.camera.position.distance_to(between(scene)) < 12.0, 5.0),
		"  and the camera glides back to framing both parties", "%s, between them %s" % [scene.camera.position, between(scene)])
	ok(await hear("copy closed"), "  and the joiner's copy of it has closed")
	# Out of the way of whatever the joiner presses E at next.
	scene._interactables.erase(talk)
	talk.queue_free()
	log_line("")


## The host's party put a few tiles from the joiner's, so that the middle of
## the two, which the camera frames, is where neither stands.
## Nothing to do while the host's player steers nobody on the map: the joiner's
## party is the only one then.
func apart(scene: ExplorationScene):
	if not scene.groups.has(0) or not scene.groups.has(1) or scene.groups[0].leader == null or scene.groups[1].leader == null:
		return
	var theirs: Vector2 = scene.groups[1].leader.position
	for tiles in [2.5, 2.0, 1.5]:
		for way in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
			var there: Vector2 = theirs + way * Grid.tiles(tiles)
			if scene.is_walkable(there):
				scene.groups[0].teleport(there)
				scene._follow_camera(there)
				return


## The middle of every party's leader on `scene`'s map - where the camera frames
## them - as far as the camera can go.
func between(scene: ExplorationScene) -> Vector2:
	var box := Rect2()
	var first := true
	for group in scene.all_groups():
		if group.leader == null:
			continue
		box = Rect2(group.leader.position, Vector2.ZERO) if first else box.expand(group.leader.position)
		first = false
	return within_view(scene, box.get_center())


## `at`, as near as the camera can come to it: its middle is kept on the map.
func within_view(scene: ExplorationScene, at: Vector2) -> Vector2:
	var rect: Rect2 = scene.camera.get_map_rect() if scene.camera.has_method("get_map_rect") else Rect2()
	return at.clamp(rect.position, rect.end) if rect.has_area() else at


## A conversation the host's player begins, which opens a picture: both
## players', the joiner's camera drawn to them meanwhile.
func hosts_look():
	log_line("======== a conversation's picture, both players' ========")
	var scene: ExplorationScene = get_tree().current_scene
	apart(scene)
	var talk := DialogueInteractable.new()
	talk.dialogue = load(PROBE)
	talk.dialogue_title = "look"
	scene.get_node("Map").add_child(talk)
	talk.global_position = scene.groups[0].leader.global_position
	scene._interactables.append(talk)
	say("look up")
	ok(await hear("ready to look"), "the joiner is ready")
	await settle(5)
	get_viewport().push_input(key_event(KEY_E))
	ok(await until(func(): return Net._balloon != null and is_instance_valid(Net._balloon), 10.0),
		"E pressed here begins a conversation, this player's")
	# Pressed on until its picture opens: a press may only finish a line typing out.
	var tries := 0
	while tries < 20 and not Pictures.is_open():
		get_viewport().push_input(key_event(KEY_ENTER))
		await wait(0.4)
		tries += 1
	ok(Pictures.is_open() and Pictures.current().picture_id() == DESK, "  pressed on, it opens a picture here")
	ok(await hear("look there"), "  and on the joiner's screen too: both players'")
	ok(scene.conversation_shot == -1, "  this machine's camera left as it was - it is this player's conversation")
	await wait(0.5)
	Pictures.close()
	ok(await hear("closed with it", 15.0), "this player, who began it, closes it: the joiner's closes with it")
	tries = 0
	while tries < 20 and Net._balloon != null and is_instance_valid(Net._balloon):
		get_viewport().push_input(key_event(KEY_ENTER))
		await wait(0.4)
		tries += 1
	ok(Net._balloon == null or not is_instance_valid(Net._balloon), "  and the conversation goes on to its end")
	ok(await hear("camera back"), "  the joiner's camera, drawn to this player's party for it, back again")
	scene._interactables.erase(talk)
	talk.queue_free()
	log_line("")


func joiners_look():
	log_line("======== a conversation's picture, both players' ========")
	var scene: ExplorationScene = get_tree().current_scene
	await hear("look up")
	await close_offers()
	say("ready to look")
	ok(await until(mirror_up, 15.0), "the host's player begins a conversation: shown here")
	var theirs: ExplorationParty = scene.groups.get(0)
	ok(theirs != null and await until(func(): return scene.conversation_shot == 0 \
			and scene.camera.position.distance_to(within_view(scene, theirs.leader.position)) < 12.0, 8.0),
		"  and the camera here glides over to that player's party, whose conversation it is",
		"%s, theirs at %s" % [scene.camera.position, theirs.leader.position if theirs != null else Vector2.ZERO])
	ok(await until(func(): return Pictures.is_open() and Pictures.current().picture_id() == DESK, 20.0),
		"its picture opens here too - both players'")
	ok(await until(func(): return mirror_up() and not Net._mirror.visible, 5.0), "  the conversation stepping aside while it is up")
	say("look there")
	ok(await until(func(): return not Pictures.is_open(), 15.0), "the host's player, who began it, closes theirs: closed here too")
	ok(await until(func(): return mirror_up() and Net._mirror.visible, 10.0), "  and the conversation is back, going on")
	say("closed with it")
	ok(await until(func(): return not mirror_up(), 20.0), "the conversation over there, its copy here closes")
	ok(await until(func(): return scene.conversation_shot == -1 and scene._gliding_back <= 0.0 \
			and scene.camera.position.distance_to(between(scene)) < 12.0, 5.0),
		"  and the camera glides back to framing both parties", "%s, between them %s" % [scene.camera.position, between(scene)])
	say("camera back")
	log_line("")


## Whether the host's balloon shows the probe's question, its two answers.
func question_up() -> bool:
	var balloon = Net._balloon
	return balloon != null and is_instance_valid(balloon) and is_instance_valid(balloon.dialogue_line) \
		and balloon.dialogue_line.responses.size() == 2


func joiners_conversation():
	log_line("======== a conversation, both choosing ========")
	var scene: ExplorationScene = get_tree().current_scene
	ok(await until(func(): return get_tree().current_scene == scene and scene.groups.has(1) and not scene.groups[1].puppet, 15.0),
		"has its own group again - the host's party changed under it, and the map was told",
		"%s %s" % [scene.groups.keys(), Campaign.party_order])
	scene = get_tree().current_scene
	say("group back")
	await hear("talk up")
	get_viewport().push_input(key_event(KEY_E))
	ok(await until(func(): return mirror_up() and Net._mirror.mine and Net._mirror._answers.get_child_count() == 0, 15.0),
		"the host's conversation is shown here - begun here, its lines this machine's player's to press on through")
	ok(scene.is_holding(), "  and holds the party here meanwhile")
	# Enter, pressed until the question comes: the first press may only finish
	# the line typing out there.
	var tries := 0
	while tries < 20 and mirror_up() and Net._mirror._answers.get_child_count() == 0:
		get_viewport().push_input(key_event(KEY_ENTER))
		await wait(0.4)
		tries += 1
	ok(mirror_up() and Net._mirror._answers.get_child_count() == 2, "pressed on, the question comes, its two answers to choose from here too")
	await hear("host picked")
	ok(await until(func(): return mirror_up() and Net._mirror._hint.text.contains("has chosen"), 10.0),
		"  the host's player has chosen, it says - and not what", Net._mirror._hint.text if mirror_up() else "")
	if not mirror_up() or Net._mirror._answers.get_child_count() != 2:
		return
	Net._mirror._answers.get_child(1).pressed.emit()
	ok(await until(func(): return mirror_up() and Net._mirror._hint.text.contains("choose again"), 15.0),
		"picking Right - differently - both are told what each chose, and asked again", Net._mirror._hint.text if mirror_up() else "")
	ok(mirror_up() and not Net._mirror._answers.get_child(1).disabled, "  the answers here again")
	Net._mirror._answers.get_child(1).pressed.emit()
	ok(Net._mirror._answers.get_child(0).disabled and Net._mirror._hint.text.begins_with("Waiting"),
		"picking Right again, the answers wait for the host's player's pick")
	say("picked again")
	ok(await until(func(): return not mirror_up(), 15.0),
		"the host's player picks Right too: the conversation goes on there, and its copy here closes")
	ok(not scene.is_holding(), "  and the party walks again")
	ok(await until(func(): return Campaign.flag("net_went_right"), 10.0), "  and what it set reaches here")
	say("copy closed")
	log_line("")


func mirror_up() -> bool:
	return Net._mirror != null and is_instance_valid(Net._mirror)


## --- Aimed on the joiner's own screen ---


func aimed_there(scene: ExplorationScene, watch: StealthWatch, body: Guard):
	log_line("")
	log_line("======== aimed on the joiner's own screen ========")
	# One of the stage's party the joiner's, to throw with and walk - somebody
	# joining it, if it is one alone.
	var standing := PlayersPanel.party_now()
	if Coop.keys_of(1).is_empty():
		if standing.size() < 2:
			Campaign.add_member("cyrus" if not standing.has("cyrus") else "enfina")
			await settle(5)
			standing = PlayersPanel.party_now()
		Campaign.controllers[standing.back()] = 1
		Coop.players_changed.emit()
	await until(func(): return scene.groups.has(1), 10.0)
	say("stage group")
	await hear("stage group here")
	var thrower: String = Coop.keys_of(1)[0] if not Coop.keys_of(1).is_empty() else ""
	var pebble := ""
	for key in ItemDatabase.items:
		var item: ItemDefinition = ItemDatabase.items[key]
		if pebble == "" and item.distraction_radius > 0 and not item.is_poison():
			pebble = key
	ok(thrower != "" and pebble != "", "the joiner steers somebody here, and there is something to throw", "%s %s" % [thrower, pebble])
	if thrower == "" or pebble == "":
		return
	Campaign.stow_item(thrower, pebble)
	var held := Campaign.count_of(thrower, pebble)
	say("throw:%s|%s" % [thrower, pebble])
	ok(await until(func(): return Campaign.count_of(thrower, pebble) == held - 1, 15.0),
		"a throw the joiner's player aimed and let go on their own screen lands here, theirs - out of %s's bag" % thrower,
		"%d -> %d" % [held, Campaign.count_of(thrower, pebble)])
	ok(await until(func(): return heard_after("pointed:") != "", 15.0), "a press made there, its pointer on a guard")
	var pointed := heard_after("pointed:")
	ok(await until(func(): return str(Net._pointing.get(1, "")) == pointed, 10.0),
		"  says which guard it was, for whatever the press asks of a pointer here", "%s, %s" % [pointed, Net._pointing])
	Coop.acting = 1
	var seen := watch.hovered_guard()
	Coop.acting = Coop.ANYONE
	ok(seen != null and watch._id_of(seen) == pointed, "  read here as that player's pointer, never this machine's own")
	await until(func(): return heard_after("beside:") != "", 15.0)
	ok(await until(func(): return scene.groups.has(1) and scene.groups[1].position_of_leader().distance_to(body.global_position) < Grid.tiles(1.6), 15.0),
		"the joiner's group goes up to the guard knocked out")
	say("seen beside")
	ok(await until(func(): return watch._dragging == body, 15.0), "  and a click on him there drags him here, by that player's group",
		"%s" % [watch._dragging])
	ok(watch._drag_group == scene.groups.get(1) and is_equal_approx(scene.groups[0].pace, 1.0),
		"  dragged behind the joiner's group - this player's own walks on at its own pace", "%s" % scene.groups[0].pace)
	say("dragging")
	ok(await hear("creeping"), "  the joiner creeps, dragging him")
	ok(await until(func(): return scene.groups[1].creeping_there, 10.0), "  and says so: its steps are not heard here either")
	say("heard creeping")
	ok(await until(func(): return watch._dragging == null, 15.0), "  and a click again there puts him down")
	ok(await until(func(): return not scene.groups[1].creeping_there, 10.0), "  creeping no more, said too")
	say("put down")


func aimed_here(scene: ExplorationScene, watch: StealthWatch):
	log_line("")
	log_line("======== aimed on its own screen ========")
	await hear("stage group")
	ok(await until(func(): return scene.groups.has(1) and not scene.groups[1].puppet, 10.0), "one of the stage's party is this player's, to walk")
	# Steering nobody until now, it was offered the party to share out - a
	# menu, which keeps the host's bags from changing here. Done with it.
	for offered in scene.find_children("*", "PlayersPanel", true, false):
		offered.close()
	await settle()
	say("stage group here")
	await until(func(): return heard_after("throw:") != "", 15.0)
	var thrower := heard_after("throw:").get_slice("|", 0)
	var pebble := heard_after("throw:").get_slice("|", 1)
	ok(await until(func(): return Campaign.count_of(thrower, pebble) > 0, 10.0), "what %s has to throw is in the bag here too" % thrower)
	var mine: ExplorationParty = scene.groups.get(1)
	if mine == null or mine.leader == null:
		ok(false, "its own group to throw from")
		return
	Coop.acting = 1
	ok(watch.begin_throw(pebble) and watch.is_aiming(), "aims a throw, on its own screen")
	var from := watch.tile_of(mine.leader.global_position)
	var spot := Vector2i(-99999, -99999)
	for gap in [3, 2, 4]:
		for step in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			if spot.x == -99999 and watch.can_throw_to(from + step * gap):
				spot = from + step * gap
	ok(spot.x != -99999 and watch.throw_at(spot), "  and lets it go", "%s" % spot)
	Coop.acting = Coop.ANYONE
	ok(not watch.is_aiming(), "  done aiming here - the host throws it")
	# A press with the pointer on a guard: Listen, which goes to the host.
	var guard: Guard = null
	var body: Guard = null
	for each in watch.guards:
		if is_instance_valid(each) and each.knocked_out and body == null:
			body = each
		elif is_instance_valid(each) and not each.knocked_out and guard == null:
			guard = each
	if guard == null or body == null:
		ok(false, "a guard up and one knocked out")
		return
	watch._hovered = guard
	get_viewport().push_input(key_event(KEY_Q))
	watch._hovered = null
	say("pointed:%s" % watch._id_of(guard))
	# Up beside the one knocked out, and a click on him.
	var m := {"scene": scene, "tile_map": scene._tile_map, "sight": StealthSight.new(scene._tile_map)}
	var lying := tile_at(m, body.global_position)
	var beside := NOWHERE
	for step in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		if beside == NOWHERE and standable(m, lying + step):
			beside = lying + step
	mine.teleport(at(m, beside if beside != NOWHERE else lying))
	say("beside:%d,%d" % [beside.x, beside.y])
	await hear("seen beside")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = watch.get_canvas_transform() * body.global_position
	watch._click_on_guard(click)
	await hear("dragging")
	ok(await until(func(): return is_equal_approx(mine.pace, StealthWatch.DRAG_PACE), 10.0),
		"dragging a body there, its own group walks at a body's pace here, where it walks", "%s" % mine.pace)
	watch.toggle_creep()
	ok(is_equal_approx(mine.pace, StealthWatch.DRAG_PACE * StealthWatch.CREEP_PACE), "  and creeping, slower still", "%s" % mine.pace)
	say("creeping")
	await hear("heard creeping")
	watch.toggle_creep()
	watch._click_on_guard(click)
	await hear("put down")
	ok(await until(func(): return is_equal_approx(mine.pace, 1.0), 10.0), "  put down, back to its own pace", "%s" % mine.pace)


## --- The familiar, across ---


func hosts_familiar():
	log_line("======== the familiar, across ========")
	var scene: ExplorationScene = get_tree().current_scene
	var keeper: FamiliarKeeper = scene.familiar_keeper
	# Alithia the joiner's, and rested: the first casting since is free.
	Campaign.long_rest()
	Campaign.add_member("alithia")
	Campaign.controllers["alithia"] = 1
	Coop.players_changed.emit()
	await settle(10)
	log_where(scene)
	say("call it")
	ok(await until(func(): return keeper.familiar != null, 15.0), "G pressed on the joiner calls Alithia's familiar - here, on the host's map")
	if keeper.familiar == null:
		return
	ok(keeper.controlling and keeper.steerer == 1 and keeper.familiar.puppet,
		"  steered by the joiner's player: here it goes where it is walked there",
		"%s %d %s" % [keeper.controlling, keeper.steerer, keeper.familiar.puppet])
	ok(keeper._eyes == null or not keeper._eyes.visible, "  and nobody here sees through its eyes")
	ok(scene.groups.has(1) and scene.groups[1].rooted, "  the joiner's group standing while they steer it")
	var her = scene.groups[1].sprite_for("alithia") if scene.groups.has(1) else null
	var called := keeper.familiar.global_position
	ok(her != null and called.distance_to(her.global_position) < Grid.tiles(1.5) and called.length() > Grid.tiles(2.0), "  beside Alithia, where she stands on the map", "%s, she %s" % [called, her.global_position if her != null else Vector2.ZERO])
	ok(await until(func(): return heard_after("familiar at:") != "", 15.0), "the joiner walks it")
	var there := Vector2(float(heard_after("familiar at:").get_slice(",", 0)), float(heard_after("familiar at:").get_slice(",", 1)))
	ok(await until(func(): return keeper.familiar != null and keeper.familiar.global_position.distance_to(there) < Grid.tiles(0.25), 10.0)
			and there.distance_to(called) > Grid.tiles(0.5),
		"  and here it is where it was walked", "%s, wanted %s, called at %s" % [keeper.familiar.global_position if keeper.familiar != null else Vector2.ZERO, there, called])
	say("seen walked")
	ok(await until(func(): return keeper.perched(), 15.0), "E pressed there sends it to Alithia's shoulder, here")
	say("seen perched")
	ok(await until(func(): return keeper.familiar == null, 15.0), "and G pressed there lets it go")
	say("seen gone")
	log_line("")


func joiners_familiar():
	log_line("======== the familiar, across ========")
	var scene: ExplorationScene = get_tree().current_scene
	var keeper: FamiliarKeeper = scene.familiar_keeper
	await hear("call it")
	log_where(scene)
	ok(await until(func(): return Coop.controller_of("alithia") == 1 and scene.familiar_spell().get("caster", "") == "alithia" \
			and scene.familiar_refusal() == "", 10.0), "Alithia is this player's, and could call her familiar", scene.familiar_refusal())
	# Steering nobody for a moment while whom it steers was asked and answered,
	# it was offered the party to share out - a menu, whose presses are its own.
	await close_offers()
	get_viewport().push_input(key_event(KEY_G))
	ok(await until(func(): return keeper.familiar != null, 15.0), "G pressed here: the host's map calls it, and it is here too")
	if keeper.familiar == null:
		return
	ok(await until(func(): return keeper.controlling and keeper.steerer == 1 and not keeper.familiar.puppet, 10.0),
		"  steered from here, by this player", "%s %d %s" % [keeper.controlling, keeper.steerer, keeper.familiar.puppet])
	ok(keeper._eyes != null and keeper._eyes.visible, "  seeing through its eyes here")
	ok(scene.groups.has(1) and scene.groups[1].rooted, "  this player's group standing meanwhile")
	var her = scene.groups[1].sprite_for("alithia") if scene.groups.has(1) else null
	var called := keeper.familiar.global_position
	ok(her != null and called.distance_to(her.global_position) < Grid.tiles(1.5) and called.length() > Grid.tiles(2.0), "  beside Alithia, where she stands on the map", "%s, she %s" % [called, her.global_position if her != null else Vector2.ZERO])
	# Walked a way it can go - this player's keys, as Familiar._process reads them.
	for way in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
		if keeper.familiar.global_position.distance_to(called) > Grid.tiles(1.0):
			break
		for i in 40:
			keeper.familiar.step(way, 1.0 / 60.0)
	var at_now := keeper.familiar.global_position
	ok(at_now.distance_to(called) > Grid.tiles(0.5), "  and walked from there, here", "%s -> %s" % [called, at_now])
	await settle(5)
	say("familiar at:%f,%f" % [at_now.x, at_now.y])
	await hear("seen walked")
	get_viewport().push_input(key_event(KEY_E))
	ok(await until(func(): return keeper.familiar != null and keeper.familiar.perched_on != null and not keeper.controlling, 15.0),
		"E pressed here: on the host's map it goes back to her shoulder, and so here")
	ok(scene.groups.has(1) and not scene.groups[1].rooted, "  and this player's group walks again")
	await hear("seen perched")
	get_viewport().push_input(key_event(KEY_G))
	ok(await until(func(): return keeper.familiar == null, 15.0), "G pressed here: the host lets it go, and it is gone here too")
	await hear("seen gone")
	log_line("")


## Where everybody stands on `scene`, into the log.
func log_where(scene: ExplorationScene):
	log_line("  where they stand: map %s, return %s %s, groups %s" % [Campaign.current_map, Campaign.return_to_position, Campaign.return_position, scene.groups.keys()])
	for id in scene.groups:
		var group: ExplorationParty = scene.groups[id]
		if not is_instance_valid(group):
			continue
		var said := []
		for sprite in group._members():
			said.append("%s %s" % [sprite.get_meta("combatant_key", "?"), sprite.global_position])
		log_line("    group %d (puppet %s) node %s leader at %s: %s" % [id, group.puppet, group.global_position, group.position_of_leader(), ", ".join(said)])


## --- Played there ---


func played_there():
	log_line("======== a hack and a quick time, the joiner's to play ========")
	var scene: ExplorationScene = get_tree().current_scene
	# Somebody who can hack: Prometheus.
	Campaign.add_member("prometheus")
	await settle(10)
	if not scene.groups.has(1):
		ok(false, "the joiner's group, to stand beside a strongbox")
		return
	var strongbox := ExamineInteractable.new()
	strongbox.text = "A strongbox, humming."
	strongbox.sets_flag = "net_strongbox_open"
	strongbox.hack = load("res://data/hacks/strongbox_hum.tres")
	scene.get_node("Map").add_child(strongbox)
	strongbox.global_position = scene.groups[1].leader.global_position
	scene._interactables.append(strongbox)
	say("strongbox up")
	ok(await until(func(): return Hacking.running(), 15.0), "E pressed on the joiner beside a hack-locked strongbox: its hack begins")
	ok(Hacking.board() == null, "  and its board is not up here - it is the joiner's player's to play, on their screen")
	ok(await until(func(): return Campaign.flag("net_strongbox_open"), 30.0), "  hacked there, the strongbox opens here")
	ok(Hacking.succeeded(strongbox.hack_id()), "  hacked for good, here")
	var quick: QuickTimeDefinition = load("res://data/quick_times/counter_trap.tres")
	say("quick yes")
	ok(await hear("ready yes"), "a quick time for the joiner's player is sent to be played there")
	ok(await Net.quick_time_by(1, quick) == true, "  done in time there, it is here")
	say("quick no")
	await hear("ready no")
	ok(await Net.quick_time_by(1, quick) == false, "  and not, not")
	ok(await Net.quick_time_by(0, quick) == false, "one for this machine's player is played here (headless, too late)")
	say("quick done")
	log_line("")


func played_here():
	log_line("======== a hack and a quick time, its own to play ========")
	await hear("strongbox up")
	await close_offers()
	get_viewport().push_input(key_event(KEY_E))
	ok(await until(func(): return Hacking.running() and Hacking.board() != null, 15.0),
		"E pressed beside the host's strongbox: its board comes up here, for this player to play")
	if Hacking.running() and Hacking.board() != null:
		Hacking._on_solved()
	ok(await until(func(): return not Hacking.running(), 10.0), "  solved here")
	ok(await until(func(): return Campaign.flag("net_strongbox_open"), 15.0), "  and what it opened there is open here too")
	await hear("quick yes")
	QuickTime.answer = 1
	say("ready yes")
	await hear("quick no")
	QuickTime.answer = 0
	say("ready no")
	await hear("quick done")
	QuickTime.answer = -1
	log_line("")


## --- Pictures and a store, both players' ---


const DESK := "res://pictures/clues_desk.tscn"
const CABINET := "res://pictures/clues_cabinet.tscn"


## What each side changed, laid together on the host (Net._merged) - worked out
## here, where the order of two machines cannot muddle it.
func merge_rules():
	log_line("======== what each side changed, laid together ========")
	var took := Net._merged({"took_seal": true}, {"entries": {"took_seal": [[false, null], [true, true]]}})
	ok(not took[0], "a flag set here and there at the same moment - the seal both reached for: a clash, so it is taken once")
	var bag := Net._merged({"cyrus": ["a", "", ""]}, {"entries": {"cyrus": [[true, ["a", "b", ""]], [true, ["a", "b", "c"]]]}})
	ok(bag[0] and bag[1].cyrus == ["a", "", "c"], "one bag changed on both sides, in different places: both kept", "%s" % [bag])
	var same_place := Net._merged({"cyrus": ["a", "x", ""]}, {"entries": {"cyrus": [[true, ["a", "", ""]], [true, ["a", "y", ""]]]}})
	ok(not same_place[0], "  in the same place: a clash")
	var flags := Net._merged({"a": true}, {"entries": {"b": [[false, null], [true, true]]}})
	ok(flags[0] and flags[1].has("a") and flags[1].has("b"), "a flag set there and another here: both", "%s" % [flags])
	var gold := Net._merged(100, {"by": -30})
	ok(gold[0] and gold[1] == 70, "gold goes by how far it went up or down there, over what was spent here", "%s" % [gold])
	var broke := Net._merged(20, {"by": -30})
	ok(broke[0] and broke[1] == 0, "  and never below nothing", "%s" % [broke])
	var typed: Array[String] = ["a", ""]
	var kinds := Net._merged({"cyrus": typed}, {"entries": {"cyrus": [[true, ["a", ""]], [true, ["a", "b"]]]}})
	ok(kinds[0] and kinds[1].cyrus == ["a", "b"], "  a bag typed here is the same bag as the untyped one sent", "%s" % [kinds])
	log_line("")


## Room in the party's bags for `count` more things - whatever is at the back of
## them taken out until there is - and the joiner told.
func make_room(count: int):
	var tries := 0
	while _free_slots() < count and tries < 60:
		tries += 1
		for key in Campaign.living_party():
			var held: Array = Campaign.inventory_of(key).filter(func(item): return item != "")
			if not held.is_empty():
				Campaign.take_item(key, held.back())
				break
	Net.send_now()


func _free_slots() -> int:
	var free := 0
	for key in Campaign.living_party():
		free += Campaign.inventory_of(key).count("")
	return free


## `thing` put on the map where the joiner's group stands, for its E to find.
func beside_the_joiner(scene: ExplorationScene, thing: Interactable) -> Interactable:
	scene.get_node("Map").add_child(thing)
	thing.global_position = scene.groups[1].leader.global_position
	scene._interactables.append(thing)
	return thing


## The first hotspot in `picture` that `wanted` says yes to, or null.
func spot_in(picture: Picture, wanted: Callable) -> Hotspot:
	if picture == null:
		return null
	for spot in picture.hotspots():
		if wanted.call(spot):
			return spot
	return null


func pictures_there():
	log_line("======== a picture, both players' to search ========")
	var scene: ExplorationScene = get_tree().current_scene
	if not scene.groups.has(1):
		ok(false, "the joiner's group, to stand beside a picture")
		return
	# Out of the way: the strongbox, which E would find first.
	for thing in scene._interactables.duplicate():
		if thing is ExamineInteractable and thing.sets_flag == "net_strongbox_open":
			scene._interactables.erase(thing)
			thing.queue_free()
	# Room for what the pictures and the store hand over.
	make_room(6)
	var desk := PictureInteractable.new()
	desk.picture = DESK
	beside_the_joiner(scene, desk)
	var carried_before := _carried("magnifying_glass")
	say("desk up")
	ok(await hear("desk open"), "E pressed on the joiner beside a picture: it opens there, on its screen")
	ok(not Pictures.is_open(), "  and not here - this player may be busy elsewhere")
	ok(not scene.is_holding() and not scene.groups[0].in_a_menu, "  and nothing here is held for it: this player walks on")
	ok(await until(func(): return Net.looking_at_a_picture(1, DESK), 10.0), "  the joiner's player is known here to be looking at it",
		"%s" % [Net.looking_there])
	ok(await until(func(): return scene._looking_marks.has(1) and scene._looking_marks[1].visible, 5.0),
		"  and shown so on the map here, an eye over their head")
	ok(await until(func(): return heard_after("examined:") != "", 20.0), "something in it is clicked there")
	var spot := heard_after("examined:")
	ok(await until(func(): return Campaign.was_examined(spot) and _carried("magnifying_glass") > carried_before, 10.0),
		"  what it found and gave there is here at once, the picture still open there",
		"%d -> %d" % [carried_before, _carried("magnifying_glass")])
	# This machine's player looks too.
	Coop.acting = 0
	Pictures.open(DESK)
	ok(Pictures.is_open() and Pictures.current().picture_id() == DESK, "this player opens the same picture here")
	var glass := spot_in(Pictures.current(), func(each): return each.examined_id() == spot)
	ok(glass != null and glass.was_examined(), "  and what the other found is marked seen here")
	ok(await until(func(): return heard_after("progress:") != "", 10.0) and Pictures.progress_text() == heard_after("progress:"),
		"  so it says it has been gone over as far as there", "%s / %s" % [Pictures.progress_text(), heard_after("progress:")])
	var ledger := spot_in(Pictures.current(), func(each): return each.visible and not each.hidden_detail and not each.was_examined() \
		and each.examine_text != "" and each.gives_item == "" and each.opens_picture == "" and each.goes_to_map == "" \
		and each.hack == null and each.requires_flag == "" and each.dialogue == null)
	ok(ledger != null, "  something still to look at in it")
	if ledger != null:
		Pictures.lens_point = ledger.get_global_rect().get_center()
		say("ledger:%s" % Pictures.current().get_path_to(ledger))
	say("looking too")
	ok(await until(func(): return heard_after("pointing:") != "", 10.0), "the joiner's player points at something in it")
	var pointed := spot_in(Pictures.current(), func(each): return String(Pictures.current().get_path_to(each)) == heard_after("pointing:"))
	ok(pointed != null and await until(func(): return Pictures.other_pointer() != null \
			and Pictures.other_pointer().at.distance_to(pointed.get_global_rect().get_center()) < 24.0, 10.0),
		"  and their pointer is drawn here, over the same thing", "%s" % [Pictures.other_pointer()])
	ok(Pictures.other_pointer() != null and Pictures.other_pointer().name == Coop.name_of(1), "  with their name")
	ok(await hear("pointer seen"), "  as this player's is drawn there")
	if ledger != null:
		Pictures.click(ledger)
		say("clicked:%s" % ledger.examined_id())
	ok(await hear("seen there"), "this player clicks something: it is seen there at once, and what it said said there")
	Pictures.lens_point = null
	Pictures.close()
	say("host closed desk")
	ok(await hear("desk closed", 30.0), "looked at and closed there")
	ok(await until(func(): return not Net.looking_at_a_picture(1) and scene._looking_marks.has(1) \
			and not scene._looking_marks[1].visible, 5.0), "  and the eye over their head gone")
	ok(_carried("magnifying_glass") == carried_before + 1, "  what it gave in the bag here once", "%d" % _carried("magnifying_glass"))
	scene._interactables.erase(desk)
	desk.queue_free()
	await settle(5)

	log_line("======== a lock, turned on both ========")
	var forms := _carried("blank_requisition")
	var cabinet := PictureInteractable.new()
	cabinet.picture = CABINET
	beside_the_joiner(scene, cabinet)
	say("cabinet up")
	ok(await hear("cabinet open"), "the joiner's player opens a cabinet with a lock on it there")
	Coop.acting = 0
	Pictures.open(CABINET)
	var lock: Puzzle = Pictures.current().get_node_or_null("Lock") if Pictures.is_open() else null
	ok(lock != null and not lock.is_solved(), "  and this player here: the lock still shut")
	say("cabinet open here")
	ok(await hear("first turned"), "the joiner's player turns its first dial there")
	var first: PuzzleDial = lock.get_node("First") if lock != null else null
	ok(first != null and await until(func(): return first.value() == first.answer, 10.0), "  and it turns here too",
		first.value() if first != null else "")
	if lock != null:
		for dial_name in ["Second", "Third"]:
			var dial: PuzzleDial = lock.get_node(dial_name)
			var turns := 0
			while dial.value() != dial.answer and turns < 20:
				dial.turn()
				turns += 1
	ok(lock != null and lock.is_solved() and Campaign.flag("demo_cabinet_open"),
		"this player turns the other two: the lock is open, the two having worked it out together")
	say("unlocked here")
	ok(await hear("opened there"), "  and open there")
	ok(await hear("form taken"), "the joiner's player takes the form out of it there")
	var form := spot_in(Pictures.current(), func(each): return each.gives_item == "blank_requisition")
	ok(await until(func(): return Campaign.flag("demo_took_form") and _carried("blank_requisition") == forms + 1 \
			and form != null and not form.visible, 10.0),
		"  and here it is gone from the cabinet, and in the bag - once", "%d -> %d" % [forms, _carried("blank_requisition")])
	Pictures.close()
	say("host closed cabinet")
	ok(await hear("cabinet closed", 20.0), "both closed")
	scene._interactables.erase(cabinet)
	cabinet.queue_free()
	await settle(5)
	await stores_there()


func stores_there():
	log_line("======== one store, both at it ========")
	var scene: ExplorationScene = get_tree().current_scene
	Campaign.gold = 500
	Net.send_now()
	var price := Campaign.price_of("cure_potion")
	var potions := _carried("cure_potion")
	var stall := StoreInteractable.new()
	stall.store = "travelling_merchant"
	beside_the_joiner(scene, stall)
	say("stall up")
	ok(await hear("stall open"), "E pressed on the joiner beside a stall: the store opens there")
	ok(scene.store_screen == null, "  and not here")
	Coop.acting = 0
	scene._on_store_requested("travelling_merchant")
	ok(await until(func(): return scene.store_screen != null, 10.0), "this player opens the same store here, a store of their own")
	say("store here")
	ok(await hear("bought there"), "the joiner's player buys a potion there")
	ok(await until(func(): return _carried("cure_potion") == potions + 1 and Campaign.gold == 500 - price, 10.0),
		"  bought here, by the host, out of the one purse and into the bag", "%d gold, %d potions" % [Campaign.gold, _carried("cure_potion")])
	var screen: StoreScreen = scene.store_screen
	ok(screen != null and screen._gold.text == "%d gold" % Campaign.gold, "  and the store here shows the purse it left",
		screen._gold.text if screen != null else "")
	if screen == null:
		return
	screen._on_buy("cure_potion")
	ok(Campaign.gold == 500 - 2 * price, "this player buys one here too")
	say("bought here:%d" % Campaign.gold)
	ok(await hear("shown there"), "  and the store there shows it at once")
	# The last of the gold, reached for on both: bought once.
	Campaign.gold = price
	Net.send_now()
	say("one left")
	ok(await hear("ready for the last"), "the purse down to one potion's worth, on both")
	screen._on_buy("cure_potion")
	say("spent")
	ok(await hear("told why"), "this player buys it; the joiner's reaches for it a moment later: not bought, and told why there")
	ok(Campaign.gold == 0 and _carried("cure_potion") == potions + 3, "  bought once - the purse empty, and never below",
		"%d gold, %d potions" % [Campaign.gold, _carried("cure_potion")])
	screen.closed.emit()
	ok(await hear("stall closed", 30.0), "left on both")
	scene._interactables.erase(stall)
	stall.queue_free()
	say("shopped")
	log_line("")


func pictures_here():
	log_line("======== a picture, both players' to search ========")
	var scene: ExplorationScene = get_tree().current_scene
	await hear("desk up")
	await close_offers()
	get_viewport().push_input(key_event(KEY_E))
	ok(await until(func(): return Pictures.is_open(), 15.0), "E pressed beside the host's picture: it opens here")
	var mine: ExplorationParty = scene.groups.get(1)
	ok(mine != null and mine.in_a_menu, "  and this player's group stands while it is up, as for a menu")
	say("desk open")
	var glass := spot_in(Pictures.current(), func(each): return each.gives_item == "magnifying_glass")
	ok(glass != null, "  a hotspot in it that gives something")
	if glass != null:
		Pictures.click(glass)
		ok(Campaign.was_examined(glass.examined_id()), "  clicked here: looked at")
		say("progress:%s" % Pictures.progress_text())
		say("examined:%s" % glass.examined_id())
	var progress_then := Pictures.progress_text()
	await hear("looking too")
	var target := spot_in(Pictures.current(), func(each): return each != glass and each.visible)
	ok(target != null, "  something else in it to point at")
	if target != null:
		Pictures.lens_point = target.get_global_rect().get_center()
		say("pointing:%s" % Pictures.current().get_path_to(target))
	var theirs := spot_in(Pictures.current(), func(each): return String(Pictures.current().get_path_to(each)) == heard_after("ledger:"))
	ok(theirs != null and await until(func(): return Pictures.other_pointer() != null and Pictures.other_pointer().name == Coop.name_of(0) \
			and Pictures.other_pointer().at.distance_to(theirs.get_global_rect().get_center()) < 24.0, 10.0),
		"the host's player looks too: their pointer is drawn here, where they point", "%s" % [Pictures.other_pointer()])
	say("pointer seen")
	ok(await until(func(): return heard_after("clicked:") != "", 15.0), "the host's player clicks something there")
	var clicked := heard_after("clicked:")
	ok(await until(func(): return Pictures.other_said().begins_with(Coop.name_of(0) + ": "), 10.0)
			and theirs != null and Pictures.other_said().contains(theirs.examine_text.left(20)),
		"  what it said there is said here, theirs", Pictures.other_said())
	ok(await until(func(): return Campaign.was_examined(clicked) and Pictures.progress_text() != progress_then, 10.0),
		"  and it is seen here at once, the picture still open - gone over further",
		"%s -> %s" % [progress_then, Pictures.progress_text()])
	say("seen there")
	await hear("host closed desk")
	Pictures.lens_point = null
	Pictures.close()
	say("desk closed")

	log_line("======== a lock, turned on both ========")
	await hear("cabinet up")
	await close_offers()
	get_viewport().push_input(key_event(KEY_E))
	ok(await until(func(): return Pictures.is_open() and Pictures.current().picture_id() == CABINET, 15.0),
		"E pressed beside a cabinet: it opens here")
	say("cabinet open")
	await hear("cabinet open here")
	var lock: Puzzle = Pictures.current().get_node_or_null("Lock") if Pictures.is_open() else null
	var first: PuzzleDial = lock.get_node("First") if lock != null else null
	var turns := 0
	while first != null and first.value() != first.answer and turns < 20:
		first.turn()
		turns += 1
	ok(first != null and first.is_right() and not lock.is_solved(), "this player turns its first dial right: the lock still shut")
	say("first turned")
	await hear("unlocked here")
	ok(lock != null and await until(func(): return lock.is_solved() and Campaign.flag("demo_cabinet_open"), 10.0),
		"the host's player turns the other two there: the lock is open here too")
	var doors = Pictures.current().get_node_or_null("Doors") if Pictures.is_open() else null
	ok(doors != null and not doors.visible, "  its doors drawn open")
	say("opened there")
	var form := spot_in(Pictures.current(), func(each): return each.gives_item == "blank_requisition")
	ok(form != null and form.visible, "  and the form inside to take")
	if form != null:
		Pictures.click(form)
	say("form taken")
	await hear("host closed cabinet")
	Pictures.close()
	say("cabinet closed")
	await stores_here()


func stores_here():
	log_line("======== one store, both at it ========")
	var scene: ExplorationScene = get_tree().current_scene
	await hear("stall up")
	await settle(5)
	get_viewport().push_input(key_event(KEY_E))
	ok(await until(func(): return scene.store_screen != null, 15.0), "E pressed beside the host's stall: the store opens here")
	say("stall open")
	await hear("store here")
	var screen: StoreScreen = scene.store_screen
	if screen == null:
		return
	var price := Campaign.price_of("cure_potion")
	var gold := Campaign.gold
	screen._on_buy("cure_potion")
	ok(await until(func(): return Campaign.gold == gold - price and screen._gold.text == "%d gold" % (gold - price), 10.0),
		"bought here: made on the host, and the store here shows the purse it left", screen._gold.text)
	say("bought there")
	ok(await until(func(): return heard_after("bought here:") != "" and screen._gold.text == "%s gold" % heard_after("bought here:"), 10.0),
		"the host's player buys one there: the store here shows it at once", screen._gold.text)
	say("shown there")
	await hear("one left")
	ok(await until(func(): return Campaign.gold == price, 10.0), "  the purse down to one potion's worth here too")
	say("ready for the last")
	await hear("spent")
	screen._on_buy("cure_potion")
	ok(await until(func(): return screen.note() != "", 10.0) and screen.note() == "Not enough gold",
		"reaching for the last of the gold a moment after the other: not bought, and told why", screen.note())
	ok(await until(func(): return Campaign.gold == 0 and screen._gold.text == "0 gold", 10.0), "  the purse empty here too")
	say("told why")
	screen.closed.emit()
	say("stall closed")
	await hear("shopped")
	log_line("")


## Puts away any offer to share the party out - a menu, which keeps this
## machine's presses for itself - and says what still holds a menu, if anything.
func close_offers():
	for offered in get_tree().current_scene.find_children("*", "PlayersPanel", true, false):
		offered.close()
	await settle(5)
	if MenuPause.is_held():
		var holding := []
		for id in MenuPause._holders:
			var holder = instance_from_id(id)
			holding.append(str(holder.name) if holder != null else "(gone)")
		log_line("  still holding a menu here: %s" % [holding])


## How many of `item` the party carries between them.
func _carried(item: String) -> int:
	var total := 0
	for key in Campaign.party_order:
		total += Campaign.count_of(key, item)
	return total


## --- A fight, played on both ---


## Two of the party against a rusher and a ranger from the Sappers' fight.
## Cyrus is the host's player's, Enfina the joiner's. Played to its end on both.
const FIGHT_SOURCE := "res://data/encounters/encounter_02_sappers.tres"
const FIGHT_CAST := [["enfina", 0], ["cyrus", 0], ["barbarian", 1], ["ranger", 1]]
## Taken off everybody's aim, so the rolls decide what lands (as in rolls).
const UNSURE_AIM := 25


## The encounter the host last went into a fight with (into_the_fight).
var _fight_given: EncounterDefinition = null


## The host into a fight of FIGHT_CAST, Enfina the joiner's, the joiner told
## `word` - and the fight, once it is up.
func into_the_fight(word: String) -> Combat:
	# Everybody up and whole - a fight before may have left somebody down.
	Campaign.long_rest()
	Campaign.add_member("enfina")
	Campaign.controllers["enfina"] = 1
	var source: EncounterDefinition = load(FIGHT_SOURCE)
	var fight := EncounterDefinition.new()
	fight.display_name = "Net fight"
	fight.terrain_scene = source.terrain_scene
	var spawns: Array[SpawnDefinition] = []
	var used := []
	for wanted in FIGHT_CAST:
		for spawn in source.spawns:
			if spawn.combatant_key == wanted[0] and spawn.side == wanted[1] and not used.has(spawn):
				used.append(spawn)
				spawns.append(spawn.duplicate())
				break
	fight.spawns = spawns
	_fight_given = fight
	Campaign.current_encounter = fight
	GameSettings._enemy_speed = GameSettings.ENEMY_SPEEDS.size() - 1
	# The seed the host picks comes from the global generator: seeded, the fight
	# is the same one every run, and as long.
	seed(20261030)
	say(word)
	SceneTransition.change_scene(Net.FIGHT_SCENE)
	await until(func(): return get_tree().current_scene is GameScene and not SceneTransition.is_changing(), 20.0)
	return get_tree().current_scene.combat if get_tree().current_scene is GameScene else null


func hosts_fight():
	log_line("======== a fight, played on both ========")
	var combat := await into_the_fight("to the fight")
	ok(combat != null, "the host goes into a fight")
	if combat == null:
		return
	ok(combat.encounter.has_meta("seed") and combat.fight_seed == int(combat.encounter.get_meta("seed")),
		"  rolling from a seed it gave the encounter", "%d" % combat.fight_seed)
	ok(not _fight_given.has_meta("seed") and combat.encounter != _fight_given,
		"  on a copy - the encounter it was given carries none into a fight played alone")
	say("seed:%d" % combat.fight_seed)
	ok(await hear("in the fight", 30.0), "  and the joiner comes into it too, from the same seed")
	var prompt: ReactionPrompt = combat.reaction_prompt
	combat.reaction_prompt = null
	for comb in combat.combatants:
		comb["accuracy"] = comb.get("accuracy", 0) - UNSURE_AIM

	# A question for the joiner's character: put up there, waited for here.
	var enfina := party_member(combat, "enfina")
	var foe := nearest_foe(combat, enfina)
	var said := []
	var asking := func(): said.append(await prompt.ask(enfina, foe, SkillDatabase.skills["greatsword_attack"]))
	asking.call()
	var shown := false
	var waited := 0.0
	while said.is_empty() and waited < 20.0:
		shown = shown or prompt.get_node("Panel").visible
		await get_tree().process_frame
		waited += get_process_delta_time()
	ok(not shown, "a question for the joiner's player is never put up here")
	ok(not said.is_empty() and said[0] == true, "  and the answer given there is the one taken here", "%s" % [said])

	combat.finish_deployment()
	ok(not combat.deployment_active, "the host places the party and begins")
	var turns := await play_my_turns(combat)
	ok(combat.combat_over, "each plays its own player's turns, to the end of the fight",
		"%d turns, %d of them played here" % [Net.fight_turn, turns])
	ok(await until(func(): return heard_after("over:") != "", 60.0), "  and the joiner's fight ends too")
	var theirs := heard_after("over:")
	ok(int(theirs.get_slice("|", 0)) == Net.fight_turn and int(theirs.get_slice("|", 1)) == hash(combat.fight_state()),
		"  the same - as many turns, and the same to the last condition", "%s, here %d|%d" % [theirs, Net.fight_turn, hash(combat.fight_state())])
	ok(Net.parted.is_empty() and Net.checked_turns >= 6, "  and the same at the start of every turn on the way",
		"%d turns checked, parted at %s" % [Net.checked_turns, Net.parted])
	log_line("  how it ended:")
	for line in combat.fight_state().split("\n"):
		log_line("    " + line)

	# Out of it, back onto a map for what is left - at its own way in: no fight
	# here was walked into from where the party stood.
	Campaign.current_map = MAP
	Campaign.return_to_position = false
	SceneTransition.change_scene(Campaign.EXPLORATION_SCENE)
	ok(await on_a_map(), "the host leaves the fight for a map")
	get_tree().current_scene.end_blocking_interaction()
	ok(await hear("off the fight"), "  and the joiner comes too")
	log_line("")


func joiners_fight():
	log_line("======== a fight, played on both ========")
	await hear("to the fight")
	ok(await until(func(): return get_tree().current_scene is GameScene and not SceneTransition.is_changing(), 30.0),
		"follows the host into a fight")
	var combat: Combat = get_tree().current_scene.combat
	await until(func(): return heard_after("seed:") != "", 10.0)
	ok(combat.fight_seed == int(heard_after("seed:")), "  rolling from the host's seed", "%d" % combat.fight_seed)
	ok(combat.deployment_active, "  waiting for the host to place the party")
	var prompt: ReactionPrompt = combat.reaction_prompt
	combat.reaction_prompt = null
	for comb in combat.combatants:
		comb["accuracy"] = comb.get("accuracy", 0) - UNSURE_AIM
	GameSettings._enemy_speed = GameSettings.ENEMY_SPEEDS.size() - 2
	combat.finish_deployment()
	ok(combat.deployment_active, "  and its own Begin does not begin it")
	say("in the fight")

	var enfina := party_member(combat, "enfina")
	var foe := nearest_foe(combat, enfina)
	var said := []
	var asking := func(): said.append(await prompt.ask(enfina, foe, SkillDatabase.skills["greatsword_attack"]))
	asking.call()
	ok(await until(func(): return prompt.get_node("Panel").visible, 10.0), "a question for its own character is put up here")
	prompt._answer_with(true)
	ok(await until(func(): return not said.is_empty(), 5.0) and said[0] == true, "  and answered here")

	ok(await until(func(): return not combat.deployment_active, 30.0), "the host's placing begins the fight here")
	var turns := await play_my_turns(combat)
	ok(combat.combat_over, "it plays its own player's turns, to the end of the fight",
		"%d turns, %d of them played here" % [Net.fight_turn, turns])
	say("over:%d|%d" % [Net.fight_turn, hash(combat.fight_state())])
	ok(await until(func(): return get_tree().current_scene is ExplorationScene and not SceneTransition.is_changing(), 30.0),
		"follows the host out of the fight")
	say("off the fight")
	log_line("")


## Plays this machine's player's turns in `combat` - through the board, as a
## player's clicks would go, so the other machine is sent each move - until
## the fight is over. How many it played.
func play_my_turns(combat: Combat) -> int:
	var played := 0
	while not combat.combat_over:
		var mine := await until(func(): return combat.combat_over or my_turn(combat), 90.0)
		if not mine or combat.combat_over:
			break
		await move_on_the_board(combat, combat.get_current_combatant())
		played += 1
	return played


## Whether `combat` stands waiting on one of this machine's player's characters.
func my_turn(combat: Combat) -> bool:
	var current: Dictionary = combat.get_current_combatant()
	return combat.controller.player_turn and not combat.deployment_active and combat.controller.is_idle() \
		and not combat.controller.action_locked and combat.plays_for_party(current) and Coop.is_local(combat.player_of(current))


## `comb`'s turn, played on the board: the first attack that reaches the
## nearest of the other side - walking towards them first when none does - and
## the turn ended with the End Turn button.
func move_on_the_board(combat: Combat, comb: Dictionary):
	var controller: CController = combat.controller
	var foe := nearest_foe(combat, comb)
	if not foe.is_empty() and attack_for(combat, comb, foe) == "":
		controller.find_path(combat.nearest_tile_of(foe, comb.position))
		controller.move_player()
		await until(func(): return controller.is_idle() or not is_same(combat.get_current_combatant(), comb), 15.0)
	foe = nearest_foe(combat, comb)
	if is_same(combat.get_current_combatant(), comb) and not foe.is_empty():
		var key := attack_for(combat, comb, foe)
		if key != "":
			controller.set_selected_skill(key)
			await controller.confirm_skill_target(combat.nearest_tile_of(foe, comb.position))
	if not combat.combat_over and is_same(combat.get_current_combatant(), comb):
		await until(func(): return controller.is_idle(), 15.0)
		combat.game_ui._on_end_turn_button_pressed()
	await settle()


## The first of `comb`'s attacks that reaches `foe` from where they stand, or "".
func attack_for(combat: Combat, comb: Dictionary, foe: Dictionary) -> String:
	var aim: Vector2i = combat.nearest_tile_of(foe, comb.position)
	var gap: int = combat.distance_to(comb, aim)
	for key in combat._ai_main_keys(comb):
		var skill: SkillDefinition = SkillDatabase.skills.get(key)
		if skill == null or not combat._hostile(skill) or combat.wasted_on(comb, skill) != "":
			continue
		if gap < skill.min_range or gap > combat.effective_max_range(comb, skill):
			continue
		if skill.respects_blocking and not combat.sees_tile(comb, aim, foe):
			continue
		if combat.refusal_for(comb, skill, aim) == "":
			return key
	return ""


func nearest_foe(combat: Combat, comb: Dictionary) -> Dictionary:
	var best := {}
	var best_gap := 1 << 30
	for other in combat.combatants:
		if not other.get("alive", false) or other.get("side", 0) == comb.get("side", 0) \
				or other.has("object") or other.get("illusion", false):
			continue
		var gap: int = combat.distance_to(comb, combat.nearest_tile_of(other, comb.position))
		if gap < best_gap:
			best_gap = gap
			best = other
	return best


func party_member(combat: Combat, key: String) -> Dictionary:
	for comb in combat.combatants:
		if comb.get("combatant_key", "") == key and comb.get("side", 1) == 0:
			return comb
	return {}


## The guard on `watch`'s map known as `id`, or null.
func guard_called(watch: StealthWatch, id: String) -> Guard:
	return thing_called(watch, watch.guards, id)


func thing_called(watch: StealthWatch, things: Array, id: String):
	for thing in things:
		if is_instance_valid(thing) and watch._id_of(thing) == id:
			return thing
	return null


## A key going down, from this machine's keyboard.
func key_event(physical: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = physical
	event.keycode = physical
	event.pressed = true
	return event


## Until this machine shows a map, settled.
func on_a_map(seconds: float = 20.0) -> bool:
	return await until(func(): return get_tree().current_scene is ExplorationScene and not SceneTransition.is_changing(), seconds)


func on_the_title_screen(seconds: float = 20.0) -> bool:
	return await until(func(): return get_tree().current_scene != null \
		and get_tree().current_scene.scene_file_path == Campaign.MAIN_MENU and not SceneTransition.is_changing(), seconds)


## --- The host's half ---


func hosts_half():
	log_line("======== the Players panel's network half ========")
	var panel := PlayersPanel.new()
	get_tree().root.add_child(panel)
	await settle()
	ok(panel.network is NetPanel and panel.network.get_node_or_null("Host") != null and panel.network.get_node_or_null("Look") != null,
		"the Players panel has Host, Look for games and an address to join")
	ok(not Net.looking(), "  and opening it listens for nothing - no firewall question for a game on one screen")
	panel.queue_free()
	await settle()
	Coop.reset()
	log_line("")

	log_line("======== hosting ========")
	ok(Net.host(TEST_PORT, "127.0.0.1") == OK, "hosts a game")
	ok(Net.is_host() and Coop.networked and Coop.local_peer == 1, "  and is the host, on peer 1")
	ok(Coop.players.size() == 1 and Coop.players[0].peer == 1 and Coop.is_local(0),
		"  its own player seated on its own machine", "%s" % [Coop.players])
	ok(Net.refusal_for(Net.PROTOCOL + 1, Net.build_key(), [Coop.KEYBOARD]) != "", "  another version is turned away")
	ok(Net.refusal_for(Net.PROTOCOL, "another build", [Coop.KEYBOARD]) != "", "  and another build")
	ok(Net.refusal_for(Net.PROTOCOL, Net.build_key(), []) != "", "  and a hello naming nothing to play with")
	ok(Net.refusal_for(Net.PROTOCOL, Net.build_key(), [Coop.KEYBOARD]) == "", "  and the same version is let in")
	MenuPause.hold(self)
	ok(get_tree().paused, "hosting with nobody joined yet, a menu holds the game as it always has")
	MenuPause.release(self)
	ok(not get_tree().paused, "  and lets it go")
	log_line("")

	log_line("======== over the internet ========")
	ok(Net.router == Net.Router.UNASKED, "hosting on one address only asks no router to open anything")
	var shown := NetPanel.new()
	get_tree().root.add_child(shown)
	await settle()
	Net.router = Net.Router.ASKING
	shown.refresh()
	ok(shown.get_node("Status").text.contains("Asking the router"), "  the Players panel says while the router is being asked")
	Net.router = Net.Router.OPEN
	Net.public_address = "203.0.113.5"
	shown.refresh()
	ok(shown.get_node("Status").text.contains("203.0.113.5:%d" % TEST_PORT), "  and, opened, the address to give over the internet",
		shown.get_node("Status").text)
	Net.router = Net.Router.CLOSED
	shown.refresh()
	ok(shown.get_node("Status").text.contains("Tailscale") and shown.get_node("Status").text.contains("ZeroTier"),
		"  and, not, what to do instead: a virtual LAN app")
	Net.router = Net.Router.UNASKED
	Net.public_address = ""
	shown.queue_free()
	await settle()
	log_line("")

	resources_as_data()

	log_line("======== the host on a map ========")
	Campaign.reset()
	Campaign.current_map = MAP
	SceneTransition.change_scene(Campaign.EXPLORATION_SCENE)
	ok(await on_a_map(), "the host walks onto the crossroads")
	var scene: ExplorationScene = get_tree().current_scene
	scene.end_blocking_interaction()
	# Somebody joins on the way - as a conversation would have them - so the
	# party is no longer what the map's arriving made it.
	Campaign.add_member("enfina")
	Campaign.add_member("alithia")
	await settle()
	var party := Array(Campaign.party_order)
	ok(party.size() >= 3, "  with a party to share, two of them joined since arriving", "%s" % [party])
	# All but the first are the joiner's from the moment it is seated - two, so
	# that one of them can stay behind while the other leads.
	for key in party.slice(1):
		Campaign.controllers[key] = 1
	ok(Net.is_plain(Campaign.net_state()), "  and Campaign as it stands is plain data, to send")
	start_joiner()
	log_line("")

	log_line("======== joining a game under way ========")
	ok(await until(func(): return Coop.players.size() == 2, 40.0), "the joiner is seated", "%s" % [Coop.players])
	if Coop.players.size() == 2:
		ok(Coop.players[1].peer > 1 and not Coop.is_local(1) and Coop.is_local(0),
			"  as the second player, on its own machine", "%s" % [Coop.players])
		ok(Net.refusal_for(Net.PROTOCOL, Net.build_key(), [Coop.KEYBOARD]) == "That game is full.",
			"  and with two seated, a third is turned away: the table is full")
	say("party:" + ",".join(party))
	ok(await hear("on the map"), "and it comes straight onto the host's map")
	ok(scene.groups.has(1) and scene.groups[1].puppet and not scene.groups[0].puppet,
		"  here its group is walked from there, and the host's from here", "%s" % [scene.groups.keys()])
	log_line("")

	log_line("======== Campaign followed ========")
	Campaign.gold += 25
	Campaign.set_flag("net_probe")
	say("gold:%d" % Campaign.gold)
	ok(await hear("state followed", 15.0), "gold and a flag set on the host reach the joiner", "%s" % [_heard])
	ok(await hear("stayed"), "the joiner will not change scene by itself")
	log_line("")

	log_line("======== walking together ========")
	var m := {"scene": scene, "tile_map": scene._tile_map, "sight": StealthSight.new(scene._tile_map)}
	var home := tile_at(m, scene._main_party.position_of_leader())
	var theirs := find_tile(m, func(tile): return gap(tile, home) >= 4.0 and gap(tile, home) <= 6.0)
	var mine := find_tile(m, func(tile): return gap(tile, home) >= 2.0 and gap(tile, home) <= 3.0 and gap(tile, theirs) >= 2.0)
	var wall := NOWHERE
	for x in range(home.x - 8, home.x + 8):
		for y in range(home.y - 8, home.y + 8):
			if wall == NOWHERE and not standable(m, Vector2i(x, y)) and gap(Vector2i(x, y), home) >= 2.0:
				wall = Vector2i(x, y)
	say("walk:%d,%d" % [theirs.x, theirs.y])
	ok(await until(func(): return scene.groups.has(1) and scene.groups[1].position_of_leader().distance_to(at(m, theirs)) < Grid.tiles(1.0), 10.0),
		"the joiner's group, walked over there, shows here where it went")
	scene._main_party.teleport(at(m, mine))
	say("host at:%d,%d" % [mine.x, mine.y])
	ok(await hear("saw the host"), "  and the host's, moved here, shows there")
	var joiners_place: Vector2 = scene.groups[1].position_of_leader()
	say("wall:%d,%d" % [wall.x, wall.y])
	ok(await hear("claimed the wall"), "the joiner says its group is in a wall")
	await settle(10)
	ok(wall != NOWHERE and scene.groups[1].position_of_leader().distance_to(at(m, wall)) > Grid.tiles(0.5),
		"  and the host does not put it there", "%s %s" % [wall, joiners_place])
	log_line("")

	log_line("======== a press on the joiner, done here ========")
	var sign := ExamineInteractable.new()
	sign.text = "A notice, nailed up."
	sign.sets_flag = "net_sign_read"
	scene.get_node("Map").add_child(sign)
	sign.global_position = scene.groups[1].leader.global_position
	scene._interactables.append(sign)
	say("sign up")
	ok(await until(func(): return Campaign.flag("net_sign_read"), 10.0),
		"E pressed on the joiner examines what is beside the joiner's group here: its flag is set")
	say("read")
	var joiners_leader: String = Coop.keys_of(1)[0] if not Coop.keys_of(1).is_empty() else ""
	ok(await hear("stayed here"), "Stay Here is pressed on the joiner")
	ok(await until(func(): return scene.staying.has(joiners_leader), 5.0), "  and done here too: their leader stays",
		"%s %s" % [joiners_leader, scene.staying.keys()])
	log_line("")

	log_line("======== pings ========")
	Pings.clear()
	Pings.ping(0, scene._main_party.position_of_leader())
	say("pinged")
	ok(await hear("saw the ping"), "a ping made here shows on the joiner's screen")
	ok(await until(func(): return Pings.pings.any(func(ping): return ping.player == 1), 10.0),
		"  and one made there shows here, the joiner's", "%s" % [Pings.pings])
	log_line("")

	log_line("======== a reload, followed ========")
	# A map coming up again sets its own cast again - Enfina goes, as she would
	# through a door - and does the same on the joiner.
	var before := scene.get_instance_id()
	say("reloading")
	scene.reload_map()
	ok(await until(func(): return get_tree().current_scene is ExplorationScene and get_tree().current_scene.get_instance_id() != before \
		and not SceneTransition.is_changing(), 20.0), "the host reloads the map")
	scene = get_tree().current_scene
	scene.end_blocking_interaction()
	ok(await hear("followed the reload"), "  and the joiner comes too")
	log_line("")

	log_line("======== a menu over a network ========")
	# The map has just offered to share the party out - the joiner steers nobody
	# of it now - and that panel is a menu too. Done with it first.
	for offered in scene.find_children("*", "PlayersPanel", true, false):
		offered.close()
	await settle()
	MenuPause.hold(self)
	await settle()
	ok(not get_tree().paused, "a menu open here stops nothing")
	ok(scene._main_party.in_a_menu and (not scene.groups.has(1) or not scene.groups[1].in_a_menu),
		"  but this machine's own group stands for it, and not the other's")
	MenuPause.release(self)
	await settle()
	ok(not scene._main_party.in_a_menu, "  and walks again once it closes")
	log_line("")

	log_line("======== guards, run by the host ========")
	Campaign.current_map = STAGE
	before = scene.get_instance_id()
	say("to the stage")
	scene.reload_map()
	ok(await until(func(): return get_tree().current_scene is ExplorationScene and get_tree().current_scene.get_instance_id() != before \
		and not SceneTransition.is_changing(), 20.0), "the host goes on to a watched map, a stealth stage")
	scene = get_tree().current_scene
	scene.end_blocking_interaction()
	var watch: StealthWatch = scene.stealth
	ok(watch != null and not watch.puppet and watch.guards.size() >= 2,
		"  where the host's watch decides, over its guards", "%d" % (watch.guards.size() if watch != null else 0))
	ok(await hear("on the stage"), "  and the joiner comes too")
	if watch != null and watch.guards.size() >= 2:
		# Everybody held, so that nothing moves but what is moved here.
		for group in scene.all_groups():
			group.frozen = true
		await settle()
		var guard: Guard = watch.guards[0]
		var spot := guard.global_position + Vector2(Grid.tiles(1.0), 0.0)
		guard.global_position = spot
		guard.facing = Vector2.LEFT
		say("guard:%s|%d,%d" % [watch._id_of(guard), int(spot.x), int(spot.y)])
		ok(await hear("guard followed"), "a guard moved here stands there, facing the same way")
		var door: StealthDoor = watch._doors[0] if not watch._doors.is_empty() else null
		if door != null:
			door.set_open(not door.is_open)
			watch._apply_door(door)
			say("door:%s|%s" % [watch._id_of(door), "open" if door.is_open else "shut"])
			ok(await hear("door followed"), "a door opened or shut here is so there")
		var lamp: Lamp = null
		for each in watch._lamps:
			if lamp == null and each.lit and each.can_be_put_out:
				lamp = each
		if lamp != null:
			watch.put_out(lamp)
			say("lamp:%s" % watch._id_of(lamp))
			ok(await hear("lamp followed"), "a lamp put out here is out there")
		watch.alert = 0.6
		watch.suspicion[guard] = 0.7
		say("alert:%s" % watch._id_of(guard))
		ok(await hear("alert followed"), "the alert, and how sure a guard is, are the same there")
		var other: Guard = watch.guards[1]
		other.knock_out()
		say("out:%s" % watch._id_of(other))
		ok(await hear("out followed"), "a guard knocked out here is down there")
		for group in scene.all_groups():
			group.frozen = false
		await aimed_there(scene, watch, other)
	log_line("")

	log_line("======== what a menu on the joiner changes ========")
	var gold_before := Campaign.gold
	var host_key: String = Coop.keys_of(0)[0] if not Coop.keys_of(0).is_empty() else Campaign.party_order[0]
	var host_potions := Campaign.count_of(host_key, "cure_potion")
	say("menu")
	ok(await hear("menu open"), "a menu opens on the joiner")
	# Meanwhile this player spends some and is handed something, as at a store.
	Campaign.gold -= 5
	var handed := Campaign.give_item(host_key, "cure_potion")
	Net.send_now()
	say("host spent")
	ok(await until(func(): return Campaign.gold == gold_before - 5 + 7, 15.0),
		"gold the joiner's player came by in a menu there is had here too - by as much, over what was spent here meanwhile",
		"%d -> %d" % [gold_before, Campaign.gold])
	ok(not handed or Campaign.count_of(host_key, "cure_potion") == host_potions + 1,
		"  and what was put in a bag here meanwhile is still there", "%d -> %d" % [host_potions, Campaign.count_of(host_key, "cure_potion")])
	var joiner_key := heard_after("joiner given:")
	ok(joiner_key == "" or Campaign.count_of(joiner_key, "cure_potion") == int(heard_after("joiner has:")),
		"  as is what the menu there put in one of its own", "%s: %d" % [joiner_key, Campaign.count_of(joiner_key, "cure_potion")])
	ok(await hear("menu back"), "  and so it stands there once the host's Campaign comes back")
	log_line("")

	await hosts_fight()
	await hosts_conversation()

	log_line("======== whom to steer, asked and answered ========")
	# Everybody up, and Enfina back in the party as the joiner's - two of theirs,
	# so that giving one up leaves them somebody.
	Campaign.long_rest()
	Campaign.add_member("enfina")
	Campaign.controllers["enfina"] = 1
	Coop.players_changed.emit()
	await settle(10)
	var joiners: Array = Coop.keys_of(1)
	ok(joiners.size() >= 2, "the joiner's player steers some of the party", "%s" % [joiners])
	var wanted: String = joiners[0] if not joiners.is_empty() else ""
	Net.ask_for(wanted, 0)
	say("asked:" + wanted)
	ok(await hear("refused"), "the host's player asks for %s, the joiner's - and the joiner's player refuses" % wanted)
	await settle(10)
	ok(Coop.controller_of(wanted) == 1, "  so nothing changes", "%s" % [Campaign.controllers])
	Net.ask_for(wanted, 0)
	ok(await until(func(): return Coop.controller_of(wanted) == 0, 15.0),
		"asked again, the joiner's player agrees, and %s is the host's player's" % wanted, "%s" % [Campaign.controllers])
	say("given")
	ok(await hear("table agrees"), "  and the joiner's table says the same", "%s" % [_heard])
	ok(await until(func(): return Net._request != null and is_instance_valid(Net._request), 15.0),
		"the joiner's player asks for %s back, and the question is put to the host's player" % wanted)
	ok(Coop.controller_of(wanted) == 0, "  nothing changing until it is answered")
	if Net._request != null and is_instance_valid(Net._request):
		Net._request.answer(true)
	ok(await until(func(): return Coop.controller_of(wanted) == 1, 5.0), "  agreed here, %s is the joiner's again" % wanted)
	say("given back")
	log_line("")

	log_line("======== Party Management ========")
	scene = get_tree().current_scene
	var pause: Node = scene.get_node("PauseUI")
	var button: Button = pause.get_node("PausePanel/VBox/PlayersButton")
	pause._offer_restart()
	ok(button.text == "Party Management" and button.visible, "the pause menu has Party Management, on a map")
	button.pressed.emit()
	await settle()
	var managing: PlayersPanel = null
	for each in scene.find_children("*", "PlayersPanel", true, false):
		managing = each
	ok(managing != null and managing.management and managing.get_node("Title").text == "Party Management",
		"  which opens the Players panel as Party Management")
	if managing != null:
		var their_row := managing.get_node_or_null("Rows/Player2")
		ok(their_row != null and their_row.get_node_or_null("Kick") != null and their_row.get_node_or_null("Leave") == null,
			"  where the host - who leads - can kick the joiner out")
		managing.choose(wanted, 0)
		ok(Coop.controller_of(wanted) == 1 and Net._request == null, "  and a character pressed there is asked for, not taken")
		say("asked from the panel")
		ok(await hear("refused again"), "  the joiner's player answers it there")
		managing.close()
	await settle()
	log_line("")

	await hosts_familiar()
	await played_there()
	merge_rules()
	await pictures_there()
	await hosts_look()

	log_line("======== leaving mid-fight ========")
	var combat := await into_the_fight("to the second fight")
	ok(await hear("in the second fight", 30.0), "the two go into another fight")
	combat.reaction_prompt = null
	combat.finish_deployment()
	# The host's player's turns played as they come, until the joiner - which
	# plays two of its own first - goes.
	var waited := 0.0
	while Coop.players.size() == 2 and waited < 120.0 and not combat.combat_over:
		if my_turn(combat):
			await move_on_the_board(combat, combat.get_current_combatant())
		await get_tree().process_frame
		waited += get_process_delta_time()
	ok(Coop.players.size() == 1, "the joiner leaves in the middle of it, taking its player with it", "%s" % [Coop.players])
	ok(Coop.controller_of("enfina") == 0 and not Campaign.controllers.has("enfina"),
		"  and Enfina is the host's player's from then on", "%s" % [Campaign.controllers])
	ok(await until(func(): return combat.combat_over or (my_turn(combat) and combat.get_current_combatant().get("combatant_key", "") == "enfina"), 30.0),
		"  her turn, the one the joiner was to play, is the host's player's to play now",
		"%s, focus %d" % [combat.get_current_combatant().get("name", ""), Coop.focus])
	ok(Net.is_host(), "  while the host hosts on")
	log_line("")

	log_line("======== joining a fight under way ========")
	# Standing on Enfina's turn, the host's player's now and nothing done in it,
	# until the joiner is back.
	var standing_at := Net.fight_turn
	ok(Net._history.size() >= 3 and Net._history.any(func(move): return move[2] == "deployed") \
			and Net._history.any(func(move): return move[2] == "steer"),
		"the fight here keeps what was done in it - the placing, the turns, and Enfina changing hands as the joiner left",
		"%s" % [Net._history.map(func(move): return move[2])])
	ok(await until(func(): return Coop.players.size() == 2, 40.0), "the joiner joins again, while the host is in the fight", "%s" % [Coop.players])
	ok(Net.fight_turn == standing_at and not combat.combat_over, "  and the fight stands where it was")
	ok(await until(func(): return heard_after("caught up:") != "", 120.0),
		"  the joiner comes into the fight, and plays it through from its beginning until it stands here too")
	ok(int(heard_after("caught up:")) == standing_at, "  at the same turn", "%s, here %d" % [heard_after("caught up:"), standing_at])
	ok(Net.parted.is_empty(), "  and the same at every turn it played through", "parted at %s" % [Net.parted])
	ok(await until(func(): return Coop.controller_of("enfina") == 1, 30.0),
		"it chose Enfina, and she is the joiner's at once: her turn, the one standing, had nothing done in it yet", "%s" % [Campaign.controllers])
	ok(await until(func(): return not my_turn(combat) or combat.get_current_combatant().get("combatant_key", "") != "enfina", 10.0),
		"  and her turn is the joiner's to play now")
	var played := await play_my_turns(combat)
	ok(combat.combat_over, "each plays its own player's turns, to the end of the fight", "%d turns, %d of them played here" % [Net.fight_turn, played])
	ok(await until(func(): return heard_after("over again:") != "", 90.0), "  and the joiner's fight ends too")
	var ending := heard_after("over again:")
	ok(int(ending.get_slice("|", 0)) == Net.fight_turn and int(ending.get_slice("|", 1)) == hash(combat.fight_state()),
		"  the same - as many turns, and the same to the last condition", "%s, here %d|%d" % [ending, Net.fight_turn, hash(combat.fight_state())])
	ok(Net.parted.is_empty(), "  and the same at the start of every turn checked", "%d checked, parted at %s" % [Net.checked_turns, Net.parted])
	Campaign.current_map = MAP
	Campaign.return_to_position = false
	SceneTransition.change_scene(Campaign.EXPLORATION_SCENE)
	ok(await on_a_map(), "the host leaves the fight for a map")
	get_tree().current_scene.end_blocking_interaction()
	ok(await hear("off the second fight", 30.0), "  and the joiner comes too")
	log_line("")

	log_line("======== kicked out ========")
	Net.kick(1)
	ok(await until(func(): return Coop.players.size() == 1, 15.0), "the host kicks the joiner out", "%s" % [Coop.players])
	ok(await hear("kicked"), "  and the joiner is told so, on its title screen")
	ok(await until(func(): return Coop.players.size() == 2, 40.0), "the joiner joins again", "%s" % [Coop.players])
	ok(await hear("watching"), "  comes onto the map, and chooses nobody to play - watching")
	await settle(20)
	var share := get_tree().current_scene.find_children("*", "PlayersPanel", true, false)
	ok(share.is_empty() and Coop.keys_of(1).is_empty(), "  and nobody is offered the party to share out for it")
	Net.leave()
	ok(not Net.active() and not Coop.networked and Coop.players.size() == 1 and Coop.players[0].peer == 0,
		"stopping, the host plays on alone", "%s" % [Coop.players])
	ok(get_tree().current_scene is ExplorationScene, "  on its map")
	log_line("")
	await joiner_finished()


func resources_as_data():
	log_line("======== resources as data ========")
	var fight := EncounterDefinition.new()
	fight.display_name = "Caught at the crossroads"
	fight.terrain_scene = load(TERRAIN)
	var spawn := SpawnDefinition.new()
	spawn.combatant_key = "barbarian"
	spawn.side = 1
	spawn.position = Vector2i(4, 5)
	fight.spawns.append(spawn)
	fight.set_meta("seed", 4242)
	var data = Net.resource_to_data(fight)
	ok(Net.is_plain(data), "an encounter made on the spot goes as plain data")
	var back := Net.data_to_resource(data) as EncounterDefinition
	ok(back != null and back.display_name == fight.display_name and back.terrain_scene == fight.terrain_scene
		and back.spawns.size() == 1 and back.spawns[0].combatant_key == "barbarian" and back.spawns[0].side == 1
		and back.spawns[0].position == Vector2i(4, 5) and back.get_meta("seed", 0) == 4242,
		"  and comes back the same: its name, its map, who stands where, its seed")
	var from_file: EncounterDefinition = load("res://data/encounters/encounter_02_sappers.tres")
	ok(Net.data_to_resource(Net.resource_to_data(from_file)) == from_file, "  one from a file goes as its file")
	ok(Net.data_to_resource({"script": "res://multiplayer/Net.gd", "props": {}, "meta": {}}) == null
		and Net.data_to_resource({"script": "res://campaign/Campaign.gd", "props": {}, "meta": {}}) == null
		and Net.data_to_resource({"path": "user://anything.tres", "meta": {}}) == null,
		"  and nothing but the game's own data is ever made from what arrives")
	log_line("")


## Starts the second Godot, on this same copy of the project, to join.
func start_joiner():
	DirAccess.remove_absolute(HarnessLog.path_for("net_joiner"))
	var args := ["--headless", "--path", ProjectSettings.globalize_path("res://")]
	var dir := OS.get_environment("MOT_TEST_LOG_DIR")
	if dir != "":
		DirAccess.remove_absolute(dir.path_join("net_joiner_godot.log"))
		args += ["--log-file", dir.path_join("net_joiner_godot.log")]
	args += ["--", "--net-client"]
	_joiner_pid = OS.create_process(OS.get_executable_path(), args)
	ok(_joiner_pid > 0, "starts a second Godot to join it", "pid %d" % _joiner_pid)


## Waits for the joiner's Godot to end, then copies its log into this one.
func joiner_finished():
	if _joiner_pid <= 0:
		return
	var ended := await until(func(): return not OS.is_process_running(_joiner_pid), 40.0)
	if not ended:
		OS.kill(_joiner_pid)
	ok(ended, "the joiner's Godot finished by itself")
	log_line("======== the joiner's half, from its own log ========")
	var text := FileAccess.get_file_as_string(HarnessLog.path_for("net_joiner"))
	ok(text.contains("FAILURES: 0"), "the joiner's half came through", "" if text != "" else "(no log)")
	for line in text.split("\n"):
		if line.strip_edges() == "" or line.begins_with("FAILURES:"):
			continue
		if line.contains("  FAIL  "):
			_fail += 1
		log_line("  | " + line)
	var dir := OS.get_environment("MOT_TEST_LOG_DIR")
	if dir != "":
		var errors := []
		for line in FileAccess.get_file_as_string(dir.path_join("net_joiner_godot.log")).split("\n"):
			if line.contains("SCRIPT ERROR"):
				errors.append(line.strip_edges())
		ok(errors.is_empty(), "and its Godot had no script errors", "%s" % [errors])
	log_line("")


## --- The joiner's half ---


func joiners_half():
	log_line("======== finding the host ========")
	ok(Net.look_for_games("127.0.0.1") == OK, "listens for games on the network")
	ok(await until(func(): return not Net.found.is_empty(), 20.0), "hears the host's beacon", "%s" % [Net.found])
	var game: Dictionary = Net.found.values()[0] if not Net.found.is_empty() else {}
	ok(game.get("port", 0) == TEST_PORT and game.get("protocol", -1) == Net.PROTOCOL and game.get("address", "") == "127.0.0.1",
		"  which says where it is, its port and its version", "%s" % [game])
	log_line("")

	log_line("======== joining a game under way ========")
	ok(Net.join(game.get("address", "127.0.0.1"), game.get("port", TEST_PORT)) == OK, "joins it")
	ok(await until(func(): return Net.joined(), 20.0), "  and is seated")
	ok(Coop.networked and Coop.players.size() == 2 and Coop.is_local(1) and not Coop.is_local(0),
		"  as the second player, the first on the host's machine", "%s, this machine %d" % [Coop.players, Coop.local_peer])
	ok(not Net.looking(), "  and has stopped listening")
	ok(await on_a_map(), "comes straight onto the host's map")
	await until(func(): return heard_after("party:") != "", 10.0)
	var party := heard_after("party:").split(",")
	ok(Campaign.current_map == MAP and Array(Campaign.party_order) == Array(party),
		"  the crossroads, with the host's party", "%s %s" % [Campaign.current_map, Campaign.party_order])
	var scene: ExplorationScene = get_tree().current_scene
	ok(party.size() >= 2 and Coop.controller_of(party[1]) == 1 and scene.groups.has(1) and not scene.groups[1].puppet
		and scene.groups.has(0) and scene.groups[0].puppet,
		"  its own group walked here, the host's from there", "%s" % [scene.groups.keys()])
	say("on the map")
	log_line("")

	log_line("======== Campaign followed ========")
	await until(func(): return heard_after("gold:") != "", 10.0)
	var gold := int(heard_after("gold:"))
	ok(await until(func(): return Campaign.gold == gold and Campaign.flag("net_probe"), 10.0),
		"gold and a flag set on the host arrive", "%d of %d" % [Campaign.gold, gold])
	if Campaign.gold == gold and Campaign.flag("net_probe"):
		say("state followed")
	SceneTransition.change_scene(Campaign.MAIN_MENU)
	await settle(20)
	ok(get_tree().current_scene == scene and not SceneTransition.is_changing(), "asked to change scene by itself, it stays")
	say("stayed")
	log_line("")

	log_line("======== walking together ========")
	var m := {"scene": scene, "tile_map": scene._tile_map, "sight": StealthSight.new(scene._tile_map)}
	await until(func(): return heard_after("walk:") != "", 10.0)
	var going := Vector2i(int(heard_after("walk:").get_slice(",", 0)), int(heard_after("walk:").get_slice(",", 1)))
	var mine: ExplorationParty = scene.groups.get(1)
	ok(mine != null and not mine.puppet, "its own group, walked here")
	if mine != null:
		mine.teleport(at(m, going))
	say("walked")
	await until(func(): return heard_after("host at:") != "", 10.0)
	var hosts := Vector2i(int(heard_after("host at:").get_slice(",", 0)), int(heard_after("host at:").get_slice(",", 1)))
	ok(await until(func(): return scene.groups.has(0) and scene.groups[0].position_of_leader().distance_to(at(m, hosts)) < Grid.tiles(1.0), 10.0),
		"the host's group, moved there, shows here where it went")
	say("saw the host")
	await until(func(): return heard_after("wall:") != "", 10.0)
	var wall := Vector2i(int(heard_after("wall:").get_slice(",", 0)), int(heard_after("wall:").get_slice(",", 1)))
	Net._walked.rpc_id(1, 1, at(m, wall), false, false, false)
	say("claimed the wall")
	log_line("")

	log_line("======== a press on the joiner, done on the host ========")
	await hear("sign up")
	# The same notice here, to see that nothing here is the one examined.
	var sign := ExamineInteractable.new()
	sign.text = "A notice, nailed up."
	scene.get_node("Map").add_child(sign)
	sign.global_position = mine.leader.global_position
	scene._interactables.append(sign)
	get_viewport().push_input(key_event(KEY_E))
	ok(await until(func(): return Campaign.flag("net_sign_read"), 10.0),
		"E pressed here is done on the host - the flag the notice there leaves arrives")
	ok(not sign.contact_spent, "  and nothing here is examined")
	await hear("read")
	var leader: String = Coop.keys_of(1)[0] if not Coop.keys_of(1).is_empty() else ""
	get_viewport().push_input(key_event(KEY_X))
	await settle()
	ok(scene.staying.has(leader), "Stay Here pressed here is done here", "%s %s" % [leader, scene.staying.keys()])
	say("stayed here")
	log_line("")

	log_line("======== pings ========")
	await hear("pinged")
	ok(await until(func(): return Pings.pings.any(func(ping): return ping.player == 0), 10.0),
		"the host's ping shows here, the host's", "%s" % [Pings.pings])
	say("saw the ping")
	# The group as it is now: staying rebuilt the line.
	Pings.ping(1, scene.groups[1].position_of_leader() if scene.groups.has(1) else Vector2.ZERO)
	log_line("")

	log_line("======== a reload, followed ========")
	await hear("reloading")
	ok(await until(func(): return get_tree().current_scene is ExplorationScene and get_tree().current_scene != scene \
		and not SceneTransition.is_changing(), 20.0), "follows the host through a reload of the map")
	scene = get_tree().current_scene
	say("followed the reload")
	log_line("")

	log_line("======== guards, run by the host ========")
	await hear("to the stage")
	ok(await until(func(): return get_tree().current_scene is ExplorationScene and get_tree().current_scene != scene \
		and not SceneTransition.is_changing(), 20.0) and Campaign.current_map == STAGE, "follows the host onto a watched map")
	scene = get_tree().current_scene
	var watch: StealthWatch = scene.stealth
	ok(watch != null and watch.puppet and watch.guards.all(func(guard): return guard.puppet),
		"  its watch only shows the host's, and so does every guard on it")
	MenuPause.hold(self)
	await settle()
	ok(not get_tree().paused, "a menu open here stops nothing - the guards go on")
	MenuPause.release(self)
	say("on the stage")
	if watch == null:
		return
	await until(func(): return heard_after("guard:") != "", 15.0)
	var guard := guard_called(watch, heard_after("guard:").get_slice("|", 0))
	var spot := Vector2(float(heard_after("guard:").get_slice("|", 1).get_slice(",", 0)), float(heard_after("guard:").get_slice("|", 1).get_slice(",", 1)))
	ok(guard != null and await until(func(): return guard.global_position.distance_to(spot) < 2.0 and guard.facing.x < 0.0, 10.0),
		"a guard the host moved stands here where it does, facing the same way", "%s at %s" % [guard, guard.global_position if guard != null else Vector2.ZERO])
	say("guard followed")
	if await until(func(): return heard_after("door:") != "", 10.0):
		var door: StealthDoor = thing_called(watch, watch._doors, heard_after("door:").get_slice("|", 0))
		var wanted := heard_after("door:").get_slice("|", 1) == "open"
		ok(door != null and await until(func(): return door.is_open == wanted, 10.0), "a door the host opened or shut is so here", "%s" % wanted)
		say("door followed")
	if await until(func(): return heard_after("lamp:") != "", 10.0):
		var lamp: Lamp = thing_called(watch, watch._lamps, heard_after("lamp:"))
		ok(lamp != null and await until(func(): return not lamp.lit, 10.0), "a lamp the host put out is out here")
		say("lamp followed")
	await until(func(): return heard_after("alert:") != "", 10.0)
	ok(await until(func(): return absf(watch.alert - 0.6) < 0.01 and guard != null and absf(watch.suspicion.get(guard, 0.0) - 0.7) < 0.01, 10.0),
		"the host's alert, and how sure its guard is, are the same here", "%.2f %.2f" % [watch.alert, watch.suspicion.get(guard, 0.0)])
	say("alert followed")
	await until(func(): return heard_after("out:") != "", 10.0)
	var other := guard_called(watch, heard_after("out:"))
	ok(other != null and await until(func(): return other.knocked_out, 10.0), "a guard the host knocked out is down here")
	say("out followed")
	await aimed_here(scene, watch)
	log_line("")

	log_line("======== what a menu here changes ========")
	await hear("menu")
	# Steering nobody on the stage, this machine was offered the party to share
	# out - a menu too. Done with it first.
	for offered in get_tree().current_scene.find_children("*", "PlayersPanel", true, false):
		offered.close()
	await settle()
	var gold_before := Campaign.gold
	MenuPause.hold(self)
	await settle()
	say("menu open")
	await hear("host spent")
	# As the inventory or the character sheet would, while it is open.
	Campaign.gold += 7
	var mine_key: String = Coop.keys_of(1)[0] if not Coop.keys_of(1).is_empty() else ""
	if mine_key != "" and Campaign.give_item(mine_key, "cure_potion"):
		say("joiner has:%d" % Campaign.count_of(mine_key, "cure_potion"))
		say("joiner given:%s" % mine_key)
	await wait(0.6)
	ok(Campaign.gold == gold_before + 7, "while a menu is open here, the host's Campaign does not undo what it does")
	MenuPause.release(self)
	ok(await until(func(): return Campaign.gold == gold_before - 5 + 7, 10.0),
		"  and once it closes, what it did is laid over what the host's player did meanwhile",
		"%d -> %d" % [gold_before, Campaign.gold])
	say("menu back")
	log_line("")

	await joiners_fight()
	await joiners_conversation()

	log_line("======== whom to steer, asked and answered ========")
	await until(func(): return heard_after("asked:") != "", 15.0)
	var wanted := heard_after("asked:")
	ok(await until(request_up, 15.0), "the host's player asks for %s, and the question is put to this machine's player" % wanted)
	ok(request_up() and Net._request.key == wanted and Net._request.to == 0, "  %s to the host's player" % wanted)
	if request_up():
		Net._request.answer(false)
	say("refused")
	ok(await until(request_up, 15.0), "  asked again")
	if request_up():
		Net._request.answer(true)
	await hear("given")
	ok(await until(func(): return Coop.controller_of(wanted) == 0, 10.0), "agreed, and the host's table says %s is the host's player's" % wanted,
		"%s" % [Campaign.controllers])
	say("table agrees" if Coop.controller_of(wanted) == 0 else "table disagrees")
	Net.ask_for(wanted, 1)
	await hear("given back")
	ok(await until(func(): return Coop.controller_of(wanted) == 1, 10.0),
		"asking for %s back, once the host's player agrees, they are this one's again" % wanted, "%s" % [Campaign.controllers])
	log_line("")

	log_line("======== Party Management ========")
	await hear("asked from the panel")
	ok(await until(request_up, 15.0), "the host's player asks again, from Party Management - the question is put here")
	if request_up():
		Net._request.answer(false)
	say("refused again")
	log_line("")

	await joiners_familiar()
	await played_here()
	await pictures_here()
	await joiners_look()

	log_line("======== leaving mid-fight ========")
	await hear("to the second fight")
	ok(await until(func(): return get_tree().current_scene is GameScene and not SceneTransition.is_changing(), 30.0),
		"follows the host into another fight")
	var combat: Combat = get_tree().current_scene.combat
	combat.reaction_prompt = null
	say("in the second fight")
	# Two of its own turns played, so that the fight's record has this
	# machine's moves in it as well as the host's.
	var own_turns := 0
	while own_turns < 2 and not combat.combat_over:
		if not await until(func(): return combat.combat_over or my_turn(combat), 60.0) or combat.combat_over:
			break
		await move_on_the_board(combat, combat.get_current_combatant())
		own_turns += 1
	ok(own_turns == 2, "plays two of its own player's turns in it")
	ok(await until(func(): return my_turn(combat), 60.0), "comes to its own player's turn again")
	Net.leave()
	ok(not Net.active() and not Coop.networked and Coop.players.size() == 1 and Coop.is_local(0) and Campaign.controllers.is_empty(),
		"leaves there and then, and plays on alone: one player, here, steering everybody", "%s %s" % [Coop.players, Campaign.controllers])
	ok(await on_the_title_screen(), "  and, out of the host's story, is on the title screen")
	log_line("")

	log_line("======== joining a fight under way ========")
	# Not a question for anybody: the host's fight asks none either.
	get_tree().node_added.connect(_no_questions)
	ok(Net.join("127.0.0.1", TEST_PORT) == OK and await until(func(): return Net.joined(), 20.0), "joins again, the host in the middle of the fight")
	ok(await until(func(): return get_tree().current_scene is GameScene and not SceneTransition.is_changing(), 30.0),
		"  and comes into it")
	combat = get_tree().current_scene.combat
	ok(Net.catching_up() and Net._curtain != null, "  playing it through from its beginning, behind a curtain")
	ok(Engine.time_scale >= Net.CATCH_UP_SPEED * 0.5, "  fast", "%.1f" % Engine.time_scale)
	ok(Net.drops(key_event(KEY_E)), "  this machine's own presses held meanwhile")
	ok(Net._choice == null, "  and nobody asked whom to play yet")
	ok(await until(func(): return not Net.catching_up(), 120.0), "caught up", "turn %d of %d" % [Net.fight_turn, Net._catch_up_turn])
	ok(Engine.time_scale < Net.CATCH_UP_SPEED and Net._curtain == null and not Net.drops(key_event(KEY_E)),
		"  and all is as ever: the pace, the curtain gone, its presses its own")
	say("caught up:%d" % Net.fight_turn)
	ok(await until(func(): return Net._choice != null and is_instance_valid(Net._choice), 10.0),
		"then it asks whom this player plays - steering nobody, since leaving")
	var choice: CharacterChoice = Net._choice
	if choice != null and is_instance_valid(choice):
		ok(choice._buttons.has("enfina"), "  the party there to choose from", "%s" % [choice._buttons.keys()])
		for key in choice._buttons:
			choice._buttons[key].button_pressed = true
		ok(choice.picked().size() == choice._buttons.size() - 1 and choice._note.text.contains("keeps"),
			"  everybody but one: the host keeps somebody", "%s" % [choice.picked()])
		for key in choice._buttons:
			choice._buttons[key].button_pressed = key == "enfina"
		choice._done()
	ok(await until(func(): return Coop.controller_of("enfina") == 1, 30.0), "it chooses Enfina, and she is this player's",
		"%s" % [Campaign.controllers])
	var played := await play_my_turns(combat)
	ok(combat.combat_over, "it plays its own player's turns, to the end of the fight", "%d turns, %d of them played here" % [Net.fight_turn, played])
	say("over again:%d|%d" % [Net.fight_turn, hash(combat.fight_state())])
	get_tree().node_added.disconnect(_no_questions)
	ok(await until(func(): return get_tree().current_scene is ExplorationScene and not SceneTransition.is_changing(), 30.0),
		"follows the host out of the fight")
	say("off the second fight")
	log_line("")

	log_line("======== kicked out ========")
	ok(await until(func(): return not Net.active(), 20.0), "the host kicks it out")
	ok(await on_the_title_screen(), "  which sends it to the title screen")
	ok(get_tree().current_scene.find_children("*", "Label", true, false).any(func(label): return label.text.contains("sent you out")),
		"  saying so")
	ok(Net.join("127.0.0.1", TEST_PORT) == OK and await until(func(): return Net.joined(), 20.0), "joins again")
	say("kicked")
	ok(await on_a_map(40.0), "  and is back on the host's map")
	ok(await until(func(): return Net._choice != null and is_instance_valid(Net._choice), 10.0), "  asked whom to play")
	if Net._choice != null and is_instance_valid(Net._choice):
		Net._choice._done()
	await settle(20)
	ok(Coop.keys_of(1).is_empty() and get_tree().current_scene.find_children("*", "PlayersPanel", true, false).is_empty(),
		"choosing nobody, it watches - not offered the party to share out for it")
	say("watching")
	ok(await until(func(): return not Net.active(), 20.0), "the host leaves")
	ok(await on_the_title_screen(), "  and that sends it to the title screen")
	log_line("")


func request_up() -> bool:
	return Net._request != null and is_instance_valid(Net._request)


## A fight coming up here asks nobody anything (Combat.reaction_prompt) - as
## the host's does not.
func _no_questions(node: Node):
	if node is Combat:
		node.reaction_prompt = null
