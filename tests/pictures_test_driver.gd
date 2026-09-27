extends Node
## Point-and-click pictures: hotspots that light up and say what they are, say
## a line, set flags, take an item, change the picture, open another picture
## and send the party to a map - opened from a map interactable, or held open
## by the call that opened it.

var LOG_PATH := HarnessLog.path_for("pictures")
const INNER := "user://pictures_test_drawer.tscn"
const ART := "res://imagese/skills/stealth_skill.png"

var _log: FileAccess = null
var _fail = 0


func log_line(t: String):
	if _log:
		_log.store_line(t)
		_log.flush()


func ok(condition: bool, label: String, detail: String = ""):
	if condition:
		log_line("  PASS  %s %s" % [label, detail])
	else:
		_fail += 1
		log_line("  FAIL  %s %s" % [label, detail])


func _ready():
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	get_tree().create_timer(120.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


func settle(frames: int = 3):
	for i in frames:
		await get_tree().process_frame


func hotspot(called: String, at: Vector2, extent: Vector2) -> Hotspot:
	var spot := Hotspot.new()
	spot.name = called
	spot.display_name = called
	spot.position = at
	spot.size = extent
	return spot


## The desk: a letter to read and take, a lock that takes a particular item, and
## a drawer that opens a picture of its own once the lock is open.
func desk() -> Picture:
	var picture := Picture.new()
	picture.title = "The desk"
	picture.size = Vector2(1280, 720)
	var background := TextureRect.new()
	background.texture = load(ART)
	picture.add_child(background)
	var opened := PictureLayer.new()
	opened.name = "DrawerOpen"
	opened.texture = load(ART)
	opened.position = Vector2(600, 400)
	opened.shown_while_flag = "pic_drawer_open"
	picture.add_child(opened)
	var letter = hotspot("Letter", Vector2(100, 100), Vector2(200, 120))
	letter.examine_text = "An old letter, addressed to nobody."
	letter.sets_flag = "pic_took_letter"
	letter.hidden_once_flag = "pic_took_letter"
	picture.add_child(letter)
	var lock = hotspot("Lock", Vector2(400, 400), Vector2(120, 120))
	lock.takes_item = "medicine"
	lock.item_sets_flag = "pic_drawer_open"
	lock.item_text = "It clicks open."
	lock.wrong_item_text = "That won't fit the lock."
	picture.add_child(lock)
	var drawer = hotspot("Drawer", Vector2(600, 400), Vector2(300, 150))
	drawer.requires_flag = "pic_drawer_open"
	drawer.locked_text = "The drawer is locked."
	drawer.opens_picture = INNER
	picture.add_child(drawer)
	var door = hotspot("Door", Vector2(1000, 100), Vector2(200, 500))
	door.goes_to_map = "res://scenes/explore_crossroads.tscn"
	door.arrives_at = "Nowhere"
	picture.add_child(door)
	return picture


## What is inside the drawer, saved so the desk's hotspot can open it by path.
func save_inner():
	var inside := Picture.new()
	inside.name = "InsideTheDrawer"
	inside.title = "Inside the drawer"
	inside.size = Vector2(640, 360)
	var background := TextureRect.new()
	background.texture = load(ART)
	inside.add_child(background)
	background.owner = inside
	var packed := PackedScene.new()
	packed.pack(inside)
	ResourceSaver.save(packed, INNER)
	inside.free()


func escape():
	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	Pictures._input(event)
	await settle()


func run_test():
	Campaign.reset()
	Campaign.seed_party(["cyrus"])
	save_inner()
	Pictures.leave_for_map = false

	log_line("======== open, and held open ========")
	var picture := desk()
	var came_back := [false]
	var watch_it = func():
		await Pictures.open(picture_scene(picture))
		came_back[0] = true
	watch_it.call()
	await settle()
	ok(Pictures.is_open() and Pictures.current() != null and Pictures.current().title == "The desk", "the desk is open")
	ok(not came_back[0], "and whoever opened it is waiting on it")
	var shown: Picture = Pictures.current()
	ok(Pictures._title.text == "The desk", "its title above it")
	ok(shown.scale.x > 0.0 and shown.scale.x <= 1.01, "scaled to fit the screen", "%.2f" % shown.scale.x)

	log_line("======== hover, look, take ========")
	var letter: Hotspot = shown.get_node("Letter")
	letter._set_hovered(true)
	ok(Pictures._hover_label.text == "Letter" and Pictures._hover_label.get_parent().visible, "hovering names it")
	letter._set_hovered(false)
	Pictures.click(letter)
	await settle()
	ok(Pictures.caption() == "An old letter, addressed to nobody.", "clicking says its line", Pictures.caption())
	ok(Campaign.flag("pic_took_letter"), "and sets its flag")
	ok(not letter.visible, "which takes it off the desk")

	log_line("======== locked, and the item that opens it ========")
	var drawer: Hotspot = shown.get_node("Drawer")
	var lock: Hotspot = shown.get_node("Lock")
	var opened: PictureLayer = shown.get_node("DrawerOpen")
	ok(not opened.visible, "the drawer is drawn shut")
	Pictures.click(drawer)
	ok(Pictures.caption() == "The drawer is locked." and Pictures.current() == shown, "locked, it says so and opens nothing")
	Campaign.give_item("cyrus", "tiny_bomb")
	Campaign.give_item("cyrus", "medicine")
	var bombs = Campaign.count_of("cyrus", "tiny_bomb")
	Pictures._refresh_bag()
	ok(Pictures._bag.get_child_count() >= 2, "the bag along the bottom holds what the party carries",
		"%d kinds" % Pictures._bag.get_child_count())
	Pictures.hold("tiny_bomb")
	lock._set_hovered(true)
	ok(Pictures._hover_label.text == "Use Tiny Bomb on Lock", "holding an item, hovering says what it would do",
		Pictures._hover_label.text)
	lock._set_hovered(false)
	Pictures.click(lock)
	ok(Pictures.caption() == "That won't fit the lock." and not Campaign.flag("pic_drawer_open"), "the wrong one is refused")
	ok(Campaign.count_of("cyrus", "tiny_bomb") == bombs and Pictures.holding() == "", "kept, and put down again")
	var medicine_before = Campaign.count_of("cyrus", "medicine")
	Pictures.hold("medicine")
	Pictures.click(lock)
	await settle()
	ok(Pictures.caption() == "It clicks open." and Campaign.flag("pic_drawer_open"), "the right one works")
	ok(Campaign.count_of("cyrus", "medicine") == medicine_before - 1, "and is used up")
	ok(opened.visible, "the picture changes - the drawer drawn open")

	log_line("======== a picture inside a picture ========")
	Pictures.click(drawer)
	await settle()
	ok(Pictures.current() != shown and Pictures.current().title == "Inside the drawer", "the drawer opens its own picture")
	ok(not shown.visible, "over the desk, not beside it")
	await escape()
	ok(Pictures.current() == shown and shown.visible, "Escape goes back to the desk")
	Pictures.hold("tiny_bomb")
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	Pictures._input(right)
	ok(Pictures.holding() == "" and Pictures.is_open(), "right-click puts an item down before it goes back anywhere")

	log_line("======== out to a map ========")
	Pictures.click(shown.get_node("Door"))
	await settle()
	ok(not Pictures.is_open(), "the door closes the pictures")
	ok(Campaign.current_map == "res://scenes/explore_crossroads.tscn" and Campaign.target_entry == "Nowhere",
		"and sends the party to its map", "%s at '%s'" % [Campaign.current_map, Campaign.target_entry])
	ok(came_back[0], "and whoever opened them carries on")
	log_line("")

	log_line("======== from an interactable on a map ========")
	Campaign.reset()
	Campaign.current_map = "res://scenes/explore_crossroads.tscn"
	var scene: ExplorationScene = load("res://scenes/exploration.tscn").instantiate()
	get_tree().root.add_child(scene)
	await settle(4)
	scene.end_blocking_interaction()
	var look := PictureInteractable.new()
	look.picture = INNER
	scene.get_node("Map").add_child(look)
	look.use(scene)
	await settle()
	ok(Pictures.is_open() and Pictures.current().title == "Inside the drawer", "pressing E on it opens its picture")
	ok(scene.party.frozen, "and the party waits where it stands")
	await escape()
	await settle()
	ok(not Pictures.is_open() and not scene.party.frozen, "closing it hands the map back")
	scene.queue_free()
	await settle()
	log_line("")

	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


## `picture` as a scene of its own, the form open() takes.
func picture_scene(picture: Picture) -> PackedScene:
	for child in picture.get_children():
		child.owner = picture
	var packed := PackedScene.new()
	packed.pack(picture)
	return packed
