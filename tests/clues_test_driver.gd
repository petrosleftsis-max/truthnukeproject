extends Node
## Clues and the journal: learning them, connecting two into a deduction,
## showing one to somebody in a conversation. And what a picture can do with
## them: a hidden detail found with a lens, a lock's dials, a torn letter's
## pieces, two things in the bag put together, what the cursor says a click
## will do, how much of a picture has been gone over - and the sounds and
## animations that stand in until real ones are dropped in.

var LOG_PATH := HarnessLog.path_for("clues")

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
	get_tree().create_timer(150.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


func settle(frames: int = 3):
	for i in frames:
		await get_tree().process_frame


func fresh_party():
	Campaign.reset()
	Campaign.set_party(["cyrus"])
	Campaign.empty_inventory("cyrus")


func run_test():
	Pictures.leave_for_map = false
	ClueBook.reload()
	fresh_party()
	await clue_book()
	await journal()
	await showing()
	await in_conversation()
	await office_and_desk()
	await cabinet_and_bag()
	await torn_letter()
	await quiet_pictures()
	await own_animations()
	await sounds_and_cursors()
	await sheets_opened()


func clue_book():
	log_line("======== the clue book ========")
	var book = ClueBook.all()
	for key in ["duty_roster", "ledger_count", "captain_claim", "pressed_numbers", "torn_letter", "skimming", "unwatched_ditch"]:
		ok(book.has(key), "%s is read from res://clues/" % key)
	ok(ClueBook.deduced_from("ledger_count", "captain_claim") == "skimming", "two clues name the deduction they make")
	ok(ClueBook.deduced_from("captain_claim", "ledger_count") == "skimming", "either way round")
	ok(ClueBook.deduced_from("ledger_count", "duty_roster") == "", "and two that make nothing make nothing")
	ok(ClueBook.clue("skimming").is_deduction() and not ClueBook.clue("ledger_count").is_deduction(),
		"a deduction knows it is one")
	log_line("")


func journal():
	log_line("======== learning a clue ========")
	var heard := []
	Campaign.clue_learned.connect(func(key, deduced): heard.append([key, deduced]))
	ok(Campaign.learn_clue("duty_roster"), "a clue is learned")
	ok(Campaign.knows_clue("duty_roster") and Campaign.known_clues() == ["duty_roster"], "and known")
	ok(not Campaign.learn_clue("duty_roster"), "but not twice")
	ok(heard == [["duty_roster", false]], "the journal hears of it, once", "%s" % [heard])
	ok(Journal.toast_text().contains("The duty roster"), "and a note across the top says so", Journal.toast_text())
	ok(not Campaign.learn_clue("no_such_clue"), "a clue that does not exist is not learned")
	log_line("")

	log_line("======== the journal ========")
	Journal.open()
	await settle()
	ok(Journal.is_open() and get_tree().paused, "it opens, and the game waits while it is")
	ok(Journal.listed() == ["duty_roster"], "listing what is known", "%s" % [Journal.listed()])
	Journal.close()
	await settle()
	ok(not Journal.is_open() and not get_tree().paused, "closing it lets the game go on")
	var pause_menu := Node.new()
	add_child(pause_menu)
	MenuPause.hold(pause_menu)
	Journal.open()
	ok(not Journal.is_open(), "it does not open over the pause menu")
	MenuPause.release(pause_menu)
	pause_menu.queue_free()
	ok(not get_tree().paused, "(the game let go again)")
	Campaign.learn_clue("ledger_count")
	Journal.open()
	Journal.pick("ledger_count")
	Journal.pick("duty_roster")
	ok(Journal.connect_picked() == "", "connecting two that make nothing works out nothing")
	ok(Journal.result_text().contains("don't connect"), "and says so", Journal.result_text())
	ok(not Campaign.knows_clue("skimming"), "nothing is learned")
	Journal.close()
	Campaign.learn_clue("captain_claim")
	Journal.open()
	Journal.pick("ledger_count")
	Journal.pick("captain_claim")
	ok(Journal.connect_picked() == "skimming", "connecting two that go together works out what they make")
	ok(Campaign.knows_clue("skimming") and heard.back() == ["skimming", true], "it is learned, as a deduction")
	ok(Journal.result_text().contains("Ten crates missing"), "and named", Journal.result_text())
	Journal.pick("ledger_count")
	Journal.pick("captain_claim")
	ok(Journal.connect_picked() == "skimming" and Journal.result_text().contains("Already"), "again, it is already known")
	Journal.pick("a")
	Journal.pick("b")
	Journal.pick("c")
	ok(Journal._picked.size() == 2, "no more than two are picked at once")
	Journal.close()
	log_line("")


func showing():
	log_line("======== showing somebody something ========")
	Campaign.give_item("cyrus", "pebble")
	Journal.present("What do you show?")
	await settle()
	ok(Journal.is_open() and get_tree().paused, "asked to show something, it opens")
	ok(Journal.listed().has("skimming") and Journal.listed().has("pebble"), "offering the bag as well as the clues",
		"%s" % [Journal.listed()])
	Journal.choose("skimming")
	await settle()
	ok(Journal.presented == "skimming" and Journal.presented_kind == "clue", "a clue shown is a clue shown")
	ok(not Journal.is_open() and not get_tree().paused, "and it closes")
	Journal.present("Again")
	await settle()
	Journal.choose("pebble")
	ok(Journal.presented == "pebble" and Journal.presented_kind == "item", "an item can be shown too")
	Journal.present("Once more")
	await settle()
	Journal.cancel()
	ok(Journal.presented == "" and not Journal.is_open(), "backing out shows nothing")
	Campaign.take_item("cyrus", "pebble")
	log_line("")


func _ask(talk: Resource, key: String, into: Dictionary):
	into["line"] = await DialogueManager.get_next_dialogue_line(talk, key)


func in_conversation():
	log_line("======== in a conversation ========")
	var talk: Resource = load("res://Dialogue/clues_demo.dialogue")
	ok(talk != null, "the demo conversation loads")
	if talk == null:
		return
	var line = await DialogueManager.get_next_dialogue_line(talk, "captain")
	ok(line != null and line.text.contains("closed"), "the captain answers", line.text if line != null else "nothing")
	var show_him = null
	var about_oil = null
	for response in (line.responses if line != null else []):
		if response.text.contains("Show him"):
			show_him = response
		if response.text.contains("lamp oil"):
			about_oil = response
	ok(show_him != null and about_oil != null, "offering to ask him, or to show him something")
	if show_him == null:
		return
	var answer := {}
	_ask(talk, show_him.next_id, answer)
	await settle()
	ok(Journal.is_open(), "showing him something opens the journal from the conversation")
	Journal.choose("skimming")
	await settle(6)
	ok(answer.has("line") and answer.line != null and answer.line.text.contains("Where did you get that"),
		"and the conversation goes on according to what was shown",
		answer.line.text if answer.has("line") and answer.line != null else "nothing")
	answer.clear()
	_ask(talk, show_him.next_id, answer)
	await settle()
	Journal.choose("ledger_count")
	await settle(6)
	ok(answer.has("line") and answer.line != null and answer.line.text.contains("supposed to prove"),
		"something else gets something else",
		answer.line.text if answer.has("line") and answer.line != null else "nothing")
	Campaign.clear_flag("demo_vell_confessed")
	log_line("")


func office_and_desk():
	log_line("======== the office ========")
	fresh_party()
	Pictures.open("res://pictures/clues_office.tscn")
	await settle()
	var office: Picture = Pictures.current()
	ok(office != null and office.title == "The Quartermaster's Office", "the demo office opens")
	var roster: Hotspot = office.get_node("RosterSpot")
	ok(roster.verb_name() == "look" and office.get_node("CaptainSpot").verb_name() == "talk"
		and office.get_node("DeskSpot").verb_name() == "go", "what a click does is worked out: look, talk, go")
	ok(Pictures.progress_text() == "Noticed 0 of 5", "how much of it has been gone over", Pictures.progress_text())
	Pictures.hover(roster)
	ok(Pictures._badge.visible and Pictures._badge.verb == "look", "the cursor says what a click will do")
	Pictures.click(roster)
	ok(Campaign.knows_clue("duty_roster"), "clicking the roster puts it in the journal")
	ok(roster.was_examined(), "and remembers it was looked at")
	ok(Pictures.progress_text() == "Noticed 1 of 5", "which the count says", Pictures.progress_text())
	ok(Pictures._hover_label.text.contains("(seen)"), "and so does its name", Pictures._hover_label.text)
	Pictures.hover(null)
	log_line("")

	log_line("======== the desk, and a lens ========")
	Pictures.click(office.get_node("DeskSpot"))
	ok(Pictures._intro < 1.0 and Pictures._intro_from.has_area(), "a closer look grows out of what was clicked")
	await settle()
	var desk: Picture = Pictures.current()
	ok(desk.title == "The Desk" and desk.hover_hints == Picture.HoverHints.NAME_ONLY, "the desk opens, naming things without outlining them")
	var numbers: Hotspot = desk.get_node("NumbersSpot")
	ok(not numbers.can_be_pointed_at() and numbers.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"a hidden detail cannot be found by eye")
	ok(Pictures.progress_text() == "Noticed 0 of 4", "though the count knows it is there", Pictures.progress_text())
	var glass: Hotspot = desk.get_node("GlassSpot")
	var glass_art: PictureLayer = desk.get_node("Glass")
	ok(glass.verb_name() == "take", "something to pick up says so")
	var layers_before = desk.get_child_count()
	Pictures.click(glass)
	ok(Campaign.count_of("cyrus", "magnifying_glass") == 1, "taking the glass puts it in the bag")
	ok(not glass.visible and not glass_art.visible, "and it is gone from the desk at once")
	ok(desk.get_child_count() == layers_before + 1, "a copy left behind fades it out")
	await get_tree().create_timer(PictureFeedback.current().fade_seconds + 0.2).timeout
	ok(desk.get_child_count() == layers_before, "and then goes too")
	Pictures.hold("magnifying_glass")
	ok(Pictures.lens_held(), "holding the glass is holding a lens")
	Pictures.lens_point = numbers.get_global_rect().get_center()
	await settle()
	var digits: PictureLayer = desk.get_node("PressedNumbers")
	ok(numbers.lens_lit and numbers.can_be_pointed_at(), "held over the blotter, it finds what was pressed into it")
	ok(digits.material is ShaderMaterial and digits.material.get_shader_parameter("lens_radius") > 0.0,
		"and draws the hidden writing inside it")
	Pictures.click(numbers)
	ok(Campaign.knows_clue("pressed_numbers"), "clicking through a lens is looking, not using the lens on it")
	ok(Pictures.lens_held(), "and the lens is still in hand")
	Pictures.lens_point = Vector2(-5000, -5000)
	await settle()
	ok(not numbers.lens_lit and numbers.can_be_pointed_at(), "found once, it stays found")
	Pictures.hold("magnifying_glass")
	await settle()
	ok(not Pictures.lens_held() and digits.material.get_shader_parameter("lens_radius") == 0.0,
		"put down, the hidden writing is hidden again")
	Pictures.lens_point = null
	Pictures.back()
	await settle()
	log_line("")


func cabinet_and_bag():
	log_line("======== the cabinet's lock ========")
	var office: Picture = Pictures.current()
	Pictures.click(office.get_node("CabinetSpot"))
	await settle()
	var cabinet: Picture = Pictures.current()
	var lock: Puzzle = cabinet.get_node("Lock")
	var first: PuzzleDial = lock.get_node("First")
	var second: PuzzleDial = lock.get_node("Second")
	var third: PuzzleDial = lock.get_node("Third")
	ok(lock.dials().size() == 3 and not lock.is_solved(), "a lock with three dials, shut")
	ok(first.verb_name() == "turn", "a dial is for turning")
	first.turn(4)
	second.turn(1)
	ok(first.value() == "4" and second.value() == "1" and not lock.is_solved(), "two right of three is still shut")
	third.turn(-3)
	ok(third.value() == "7", "turned back past nothing it comes round to 7")
	ok(lock.is_solved() and Campaign.flag("demo_cabinet_open"), "all three right, it opens")
	ok(Pictures.caption() == lock.solved_text, "and says so", Pictures.caption())
	ok(not cabinet.get_node("Doors").visible and cabinet.get_node("Inside").visible and not lock.visible,
		"the doors and the lock go, the inside shows")
	first.turn(1)
	ok(first.value() == "4", "solved, it holds still")
	ok(first.mouse_filter == Control.MOUSE_FILTER_IGNORE, "and no longer offers to be turned")
	Pictures.click(cabinet.get_node("SealSpot"))
	Pictures.click(cabinet.get_node("FormSpot"))
	ok(Campaign.count_of("cyrus", "seal_of_office") == 1 and Campaign.count_of("cyrus", "blank_requisition") == 1,
		"the seal and the form are taken")
	ok(Pictures.progress_text() == "Noticed 3 of 3", "everything in it gone over, the doors no longer there to count",
		Pictures.progress_text())
	log_line("")

	log_line("======== putting things together ========")
	Pictures.hold("magnifying_glass")
	Pictures.hold("seal_of_office")
	ok(Pictures.caption() == Pictures.NO_COMBINATION and Pictures.holding() == "", "two that make nothing say so, and go back in the bag",
		Pictures.caption())
	ok(Campaign.count_of("cyrus", "magnifying_glass") == 1 and Campaign.count_of("cyrus", "seal_of_office") == 1, "both kept")
	Pictures.hold("blank_requisition")
	Pictures.hold("seal_of_office")
	ok(Campaign.count_of("cyrus", "sealed_requisition") == 1, "the form and the seal make a sealed order")
	ok(Campaign.count_of("cyrus", "seal_of_office") == 0 and Campaign.count_of("cyrus", "blank_requisition") == 0, "using both up")
	ok(Pictures.caption() == ItemDatabase.item("sealed_requisition").combine_text, "and say what happened", Pictures.caption())
	ok(Campaign.combination_of("seal_of_office", "blank_requisition") == "sealed_requisition", "either way round")
	# In the party's bags (I): one slot, then the other.
	Campaign.give_item("cyrus", "seal_of_office")
	Campaign.give_item("cyrus", "blank_requisition")
	var slots: Array = Campaign.inventory_of("cyrus")
	var seal_at = slots.find("seal_of_office")
	var form_at = slots.find("blank_requisition")
	ok(Campaign.combine_slots("cyrus", seal_at, "cyrus", form_at) == "sealed_requisition", "the bags put them together too")
	ok(Campaign.inventory_of("cyrus")[seal_at] == "" and Campaign.inventory_of("cyrus")[form_at] == "sealed_requisition",
		"leaving what they made where the second was")
	var glass_at = Campaign.inventory_of("cyrus").find("magnifying_glass")
	ok(Campaign.combine_slots("cyrus", glass_at, "cyrus", form_at) == "" and Campaign.inventory_of("cyrus")[glass_at] == "magnifying_glass",
		"two that make nothing are left alone, for the bags to swap")
	Pictures.back()
	await settle()
	log_line("")


func torn_letter():
	log_line("======== the torn letter ========")
	var office: Picture = Pictures.current()
	Pictures.click(office.get_node("BinSpot"))
	await settle()
	var bin: Picture = Pictures.current()
	var letter: Puzzle = bin.get_node("Letter")
	var pieces := []
	var slots := []
	for i in 4:
		pieces.append(letter.get_node("Piece%d" % (i + 1)))
		slots.append(letter.get_node("Slot%d" % (i + 1)))
	ok(pieces[0].verb_name() == "move", "a piece is for moving")
	pieces[0].drop_at(slots[1].centre())
	ok(pieces[0].sits_in == slots[1] and not pieces[0].is_right(), "dropped near a slot it snaps in, right or not")
	pieces[1].drop_at(slots[1].centre())
	ok(pieces[1].sits_in == null, "a slot already taken takes nothing else")
	pieces[0].drop_at(Vector2(1100, 600))
	ok(pieces[0].sits_in == null, "dropped far from any, it lies where it fell")
	ok(not letter.is_solved(), "and the letter is not mended")
	for i in 4:
		pieces[i].drop_at(slots[i].centre())
	ok(letter.is_solved() and Campaign.flag("demo_letter_mended"), "every piece in its place mends it")
	ok(Campaign.knows_clue("torn_letter"), "and what it says goes in the journal")
	ok(Campaign.connect_clues("torn_letter", "duty_roster") == "unwatched_ditch" and Campaign.flag("demo_ditch_unwatched"),
		"working out what it means sets the flag the rest of the game can wait on")
	Pictures.back()
	await settle()
	Pictures.click(Pictures.current().get_node("BinSpot"))
	await settle()
	var again: Puzzle = Pictures.current().get_node("Letter")
	var all_home := true
	for piece in again.pieces():
		all_home = all_home and piece.is_right()
	ok(again.is_solved() and all_home, "opened again, it is still mended")
	Pictures.close()
	await settle()
	log_line("")


func quiet_pictures():
	log_line("======== a picture meant to be searched ========")
	var picture := Picture.new()
	picture.name = "Searched"
	picture.size = Vector2(1280, 720)
	picture.hover_hints = Picture.HoverHints.NONE
	var spot := Hotspot.new()
	spot.name = "Loose brick"
	spot.display_name = "Loose brick"
	spot.position = Vector2(100, 100)
	spot.size = Vector2(100, 60)
	picture.add_child(spot)
	Pictures.show_picture(picture)
	await settle()
	ok(spot.mouse_default_cursor_shape == Control.CURSOR_ARROW, "the cursor does not change over things")
	Pictures.hover(spot)
	ok(not Pictures._badge.visible and not Pictures._hover_label.get_parent().visible, "and nothing is named")
	Pictures.click(spot)
	ok(spot.was_examined(), "but clicking still finds it")
	ok(Pictures.progress_text() == "Noticed 1 of 1", "and the count still helps", Pictures.progress_text())
	Pictures.close()
	await settle()
	log_line("")


func own_animations():
	log_line("======== your own animations ========")
	var picture := Picture.new()
	picture.name = "Hooks"
	picture.size = Vector2(1280, 720)
	var layer := PictureLayer.new()
	layer.name = "Light"
	layer.shown_while_flag = "hooks_lit"
	layer.size = Vector2(100, 100)
	var lights := AnimationPlayer.new()
	lights.name = "Anim"
	var library := AnimationLibrary.new()
	for called in ["appear", "disappear"]:
		var made := Animation.new()
		made.length = 0.3
		library.add_animation(called, made)
	lights.add_animation_library("", library)
	layer.add_child(lights)
	picture.add_child(layer)
	var lever := Hotspot.new()
	lever.name = "Lever"
	lever.display_name = "Lever"
	lever.position = Vector2(400, 100)
	lever.size = Vector2(80, 80)
	lever.sets_flag = "hooks_lit"
	var pull := AnimationPlayer.new()
	pull.name = "Pull"
	var pull_library := AnimationLibrary.new()
	var pulled := Animation.new()
	pulled.length = 0.3
	pull_library.add_animation("pull", pulled)
	pull.add_animation_library("", pull_library)
	lever.add_child(pull)
	lever.animation_player = NodePath("Pull")
	lever.click_animation = "pull"
	var own_sound := AudioStreamWAV.new()
	lever.click_sound = own_sound
	picture.add_child(lever)
	Pictures.show_picture(picture)
	await settle()
	ok(not layer.visible, "the light starts off")
	Pictures.click(lever)
	ok(layer.visible and lights.is_playing() and lights.current_animation == "appear", "turned on, it plays your \"appear\"")
	ok(pull.is_playing() and pull.current_animation == "pull", "the lever plays your \"pull\"")
	var played := false
	for player in Pictures._players:
		played = played or (player.stream == own_sound)
	ok(played, "and its own sound rather than the usual one")
	var count_before = picture.get_child_count()
	Campaign.clear_flag("hooks_lit")
	picture.refresh()
	ok(not layer.visible and picture.get_child_count() == count_before + 1, "turned off it is gone at once, a copy left behind")
	var ghost = picture.get_child(layer.get_index() - 1) if layer.get_index() > 0 else null
	var ghost_plays := false
	for child in picture.get_children():
		if child != layer and child is PictureLayer:
			var anim = child.get_node_or_null("Anim")
			ghost_plays = ghost_plays or (anim != null and anim.current_animation == "disappear")
	ok(ghost_plays, "playing your \"disappear\"")
	await get_tree().create_timer(0.5).timeout
	ok(picture.get_child_count() == count_before, "and the copy goes when it is done")
	Pictures.close()
	await settle()
	log_line("")


func sounds_and_cursors():
	log_line("======== sounds and cursors to replace ========")
	var feedback := PictureFeedback.current()
	ok(feedback.resource_path == PictureFeedback.PATH, "the settings in res://pictures/feedback.tres are the ones used")
	var blip = feedback.sound("solved")
	ok(blip is AudioStreamWAV and blip.data.size() > 1000, "an empty sound slot plays a generated stand-in",
		"%d bytes" % (blip.data.size() if blip != null else 0))
	var missing := []
	for property in feedback.get_property_list():
		if property.get("hint_string", "") == "AudioStream" and not PlaceholderSounds.RECIPES.has(property.name):
			missing.append(property.name)
	ok(missing.is_empty(), "every sound slot has a stand-in of its own", "%s" % [missing])
	ok(feedback.cursor("look") == null, "an empty cursor slot is drawn")
	var mine := PictureFeedback.new()
	var custom := AudioStreamWAV.new()
	mine.look = custom
	var art := ImageTexture.create_from_image(Image.create(8, 8, false, Image.FORMAT_RGBA8))
	mine.take_cursor = art
	PictureFeedback.use(mine)
	ok(PictureFeedback.current().sound("look") == custom, "a sound dropped in replaces the stand-in")
	ok(PictureFeedback.current().cursor("take") == art, "and so does a cursor")
	mine.placeholder_sounds = false
	ok(mine.sound("dial") == null, "stand-ins can be turned off, for silence")
	PictureFeedback.use(feedback)
	log_line("")


func sheets_opened():
	log_line("======== a clue that opens a sheet in a fight ========")
	for knows in [true, false]:
		Campaign.reset()
		if knows:
			Campaign.learn_clue("duty_roster")
		Campaign.current_encounter = load("res://encounters/encounter_02_sappers.tres")
		var game = load("res://scenes/game.tscn").instantiate()
		get_tree().root.add_child(game)
		await settle(4)
		var combat: Combat = game.get_node("VisualCombat")
		var barbarians := 0
		var opened := 0
		var others_opened := 0
		for comb in combat.combatants:
			if comb.side != 1:
				continue
			if comb.get("combatant_key", "") == "barbarian":
				barbarians += 1
				if comb.get("studied", false):
					opened += 1
				ok(comb.get("studied_by", []).is_empty(), "nobody gets Study's edge for it")
			elif comb.get("studied", false):
				others_opened += 1
		if knows:
			ok(barbarians > 0 and opened == barbarians, "knowing the roster, every Barbarian's sheet is open from the start",
				"%d of %d" % [opened, barbarians])
			ok(others_opened == 0, "and nobody else's")
		else:
			ok(opened == 0, "not knowing it, none is")
		game.queue_free()
		await settle()
	log_line("")
