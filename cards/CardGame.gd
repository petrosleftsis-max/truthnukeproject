extends Control
class_name CardGame
## The card game's screen (docs/card_game.md): a run of CardRun shown as a map, its fights (CardStage, over a CardBattle), rewards,
## rests, shops, events and treasure, with the health, gold, relics and deck carried along the top. Everything is built here in
## code, in the interface's own look; the rules are in CardRun and CardBattle, so a suite can play them with no screen at all.
##
## How it feels (docs/card_game.md "How it feels"; the designer, 2026-11-26: all of docs/proposals_2026-11-26_card_juice.md but
## section 11): a short wipe into each room and back, the map's way inked in and walked, reward cards dealt face down and turned
## over, gold flying into the purse as it counts, relics rising out of a glow into the bar and lighting up as they work, a chest's
## lid flying open, an event's words typing out, a rest's fire, and the fight's own (CardStage). Headless none of it moves and
## every room opens at once.

const SCENE := "res://scenes/card_game.tscn"
const TITLE_SCREEN := "res://scenes/main_menu.tscn"
const INK := Color("dce8f5")
const INK_DIM := Color("c2ceda")
const MUTED := Color("8296a9")
const ACCENT := Color("4a86c8")
const PANEL := Color("19212c")
const CARD := Color("1c2531")
const CARD_LIT := Color("24344a")
const CARD_EDGE := Color("2b3947")
const HEALTH := Color("c0453a")
const GOLD := Color("e8c872")
const MEND := Color("8fd6a0")
const BACKGROUND := Color("10151c")
## How long the end of a fight stays on the screen before the rewards, in seconds (after the fight's own ending has played).
const FIGHT_OVER_SECONDS := 0.8
## Map spacing, in pixels.
const MAP_ROW := 82.0
const MAP_COLUMN := 118.0
## How long the way to a room takes to walk on the map, and the wipe into a room (each half).
const WALK_SECONDS := 0.45
const WIPE_SECONDS := 0.17
## How long a reward card waits before it is turned over, and between one and the next.
const REWARD_FIRST := 0.3
const REWARD_EVERY := 0.25
## How many letters a second an event's words type out.
const LETTERS_A_SECOND := 70.0

## Where to go when the run is left or over (a map that opened it); empty for the title screen.
static var return_scene := ""
## For a suite: the next run's seed (0: any).
static var seed_for_next := 0
## The Challenge the last run was given, offered again for the next (CardRun.challenge).
static var challenge_chosen := 0
## For a suite or a hack: the next run's characters (data/card_characters/ keys) and length, straight to its map. With none (and
## no seed), the screen asks who plays first (_show_characters); a seed alone is the first card game as it was, one layer.
static var characters_for_next: Array = []
static var layers_for_next := 0
static var floors_for_next := 0
## How many players the character choice asks for (1, or 2 on one screen), as last chosen.
static var players_chosen := 1
## Every gate open on the title screen's card game, to try them all (the choice's Practice box). Never in a hack.
static var practice := false

## The card game played as a hack (CardHack): over the world, not as a scene of its own; it reports how it went and goes.
signal hack_done(won: bool, left: bool)
var hacking: CardHack = null

var run: CardRun = null
var battle: CardBattle = null
## Which view is showing: map, battle, rewards, rest, shop, event, treasure, pick, end.
var view := ""
## The effects layer over everything (CardFx).
var fx: CardFx
## The fight on the screen, while there is one.
var stage: CardStage = null
## The chosen card's place in the fight's hand, or -1 (for a suite; the stage keeps it by the card's id).
var _selected: int:
	get:
		return stage.selected_index() if stage != null and is_instance_valid(stage) else -1

var _hp_label: Label
var _gold_label: Label
var _floor_label: Label
## The trace (twist 3), coloured by how near the system's next answer it is.
var _trace_label: Label
const TRACE_INK := Color("8fd6a0")
const TRACE_WORDS := "The trace: how much the system has noticed you. Every fight raises it, an elite more, a long fight and a loud card more again; Cover Tracks at a rest lowers it. From 25 and from 50 its programs hit harder, from 50 they are tougher too, at 75 a Glitch goes into every deck, and at 100 you are traced: the hack fails."
## The players' own colours (co-op): who chooses, who voted where.
const PLAYER_INKS := [Color("9cc8f0"), Color("f0c070")]
## Who votes next on the map (co-op).
var _voter := 0
var _scanlines: Control
const SCANLINE_SHADER := """shader_type canvas_item;
uniform float strength = 0.07;
void fragment() {
	float line = step(0.5, fract(FRAGCOORD.y / 3.0));
	float roll = 0.5 + 0.5 * sin(FRAGCOORD.y * 0.012 - TIME * 1.3);
	COLOR = vec4(0.0, 0.0, 0.0, strength * line * (0.7 + 0.3 * roll));
}"""
## The deeper the layer, the more the map comes apart into pixels (twist 1): a screen-reading shade over it, each layer a bigger
## pixel, rows slipping now and then. Only to look at.
const PIXEL_SHADER := """shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform float pixel = 2.0;
uniform float tear = 0.0;
void fragment() {
	vec2 cells = 1.0 / SCREEN_PIXEL_SIZE / pixel;
	vec2 uv = (floor(SCREEN_UV * cells) + 0.5) / cells;
	float row = floor(SCREEN_UV.y * cells.y / 6.0);
	float slip = step(0.97, fract(sin(row * 12.9898 + floor(TIME * 1.5) * 78.233) * 43758.5453)) * tear;
	COLOR = vec4(textureLod(screen, uv + vec2(slip, 0.0), 0.0).rgb, 1.0);
}"""
var _relic_row: HBoxContainer
var _deck_button: Button
var _challenge_button: Button
const CHALLENGE_WORDS := "How hard the run is, chosen before its first room. 0: as the fights are made. 1: enemies choose as in a harder fight. 2: and have a tenth more health. 3: and start each fight with 1 Might."
var _body: Control
var _overlay: Control = null
var _keyword_panel: PanelContainer
var _keyword_label: Label
## The card the panel explains, and where it will be when that was given (a card of the hand rising).
var _keyword_card: CardView = null
var _keyword_rect := Rect2()
var _wipe: ColorRect
var _wiping := false
var _walking := false
var _relic_icons := {}
var _relic_hidden := {}
## While a chest opens: any relic coming onto the bar now waits there unseen until it has flown in.
var _hide_new_relics := false
var _gold_held := false
var _coins_left := 0
var _hp_shown := -1
var _deck_shown := -1
var _map_scroll := -1
var _map_canvas: _MapLines = null
var _typing: Tween = null
var _typed: Label = null
var _typed_then: Array = []
var _typed_column: Control = null
var _shop_views := {}
var _pick_views := {}
var _music_now := &""


## Opens the card game from wherever the player is; `back_to` is the scene to go back to afterwards (empty: the title screen).
static func play(back_to: String = ""):
	return_scene = back_to
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var transition = tree.root.get_node_or_null("/root/SceneTransition")
	if transition != null:
		transition.change_scene(SCENE)
	else:
		tree.change_scene_to_file(SCENE)


func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_frame()
	# The title screen's card game with two machines joined: played together, the joiner following the host into it (Net).
	var net = get_node_or_null("/root/Net")
	if hacking == null and net != null and net.with_another() and characters_for_next.is_empty() and seed_for_next == 0:
		if net.is_host():
			net.begin_card_game(self, {"seed": randi() | 1})
		else:
			_waiting_for_the_host()
			net.card_game_opened(self)
		return
	if hacking != null:
		# A hack: its own length and fight; who plays it is chosen first unless the hack says.
		if not hacking.characters.is_empty():
			_start_hack(hacking.characters)
		else:
			_show_characters()
	elif not characters_for_next.is_empty() or seed_for_next != 0:
		# A suite's run: straight to its map, no Blessing asked for.
		var length := layers_for_next if layers_for_next > 0 else (1 if characters_for_next.is_empty() else CardRun.MOST_LAYERS)
		start_run(seed_for_next, characters_for_next, length, floors_for_next if floors_for_next > 0 else CardRun.FLOORS, false)
		_show_map()
	else:
		_show_characters()
	seed_for_next = 0
	characters_for_next = []
	layers_for_next = 0
	floors_for_next = 0


## Over a network, the joiner come into the card game before the host's word of it: waiting.
func _waiting_for_the_host():
	view = "waiting"
	_clear_body()
	var column := _centred_column()
	_heading(column, "The Card Game, Together")
	_text(column, "Waiting for the host's game...", MUTED)
	_button(column, "Leave", leave_game)


## A run for `characters` (one or two; none: the first card game's start), `layer_count` layers of `floor_count` floors; `then_show`
## goes on to its Blessings and map (a hack shows what it shows itself).
func start_run(with_seed: int = 0, characters: Array = [], layer_count: int = 1, floor_count: int = CardRun.FLOORS, then_show: bool = true):
	if hacking == null:
		CardUnlocks.all_open = practice
	run = CardRun.new(with_seed, characters, layer_count, floor_count)
	run.challenge = challenge_chosen if hacking == null else hacking.challenge
	run.changed.connect(_refresh_bar)
	run.relic_used.connect(_relic_used)
	_share_devices()
	battle = null
	_relic_icons.clear()
	_relic_hidden.clear()
	for child in _relic_row.get_children():
		child.queue_free()
	_hp_shown = -1
	_deck_shown = -1
	_map_scroll = -1
	_gold_held = false
	_coins_left = 0
	_turns_left = []
	_refresh_bar()
	if then_show:
		_after_start()


## Once a run is made: each player's Blessing first (twist 15), then the map.
func _after_start():
	if run.blessings_due():
		_begin_turns(_show_blessings, _show_map)
	else:
		_show_map()


## --- The Blessings: the run's first choice, after the gate (twist 15; the designer will add more) ---


func _show_blessings():
	view = "blessings"
	_clear_body()
	_refresh_bar()
	var column := _centred_column(900.0)
	_heading(column, "A Blessing")
	_whose(column)
	_text(column, "Given in a dream, for this run. Choose one, whatever your gate.")
	# Side by side, wrapping on a half of the screen.
	var row := HFlowContainer.new()
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("h_separation", 18)
	row.add_theme_constant_override("v_separation", 10)
	column.add_child(row)
	var across := 170.0 if _half >= 0 else 240.0
	for key in run.players[run.me].blessing_offers:
		var relic := CardDatabase.relic(key)
		if relic == null:
			continue
		var choice := VBoxContainer.new()
		choice.custom_minimum_size = Vector2(across, 0)
		choice.add_theme_constant_override("separation", 6)
		var icon := CardIcon.new()
		icon.custom_minimum_size = Vector2(96, 96)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.show_icon(&"blessing", relic.picture if relic.picture != null else CardLooks.picture(&"blessing"), Color("e0d0ff"), "*")
		choice.add_child(icon)
		var words := _text(choice, "%s\n%s" % [relic.name, relic.describe()], INK)
		words.custom_minimum_size = Vector2(across, 0)
		var take := _button(choice, "Take it", _bless.bind(key))
		take.name = "Blessing_" + key
		take.custom_minimum_size = Vector2(minf(200.0, across), 40)
		row.add_child(choice)
	_button(column, "None", _bless.bind(""))
	_focus_first(column)


## Blessing `key` taken ("" for none): it rises into the bar, and on.
func _bless(key: String):
	if _sending(&"bless", [key]):
		return
	if not run.choose_blessing(key):
		return
	if key != "":
		CardFeel.sound(&"card_blessing", -6.0)
		var button := _room().find_child("Blessing_" + key, true, false) as Control
		if button != null and CardFeel.shown():
			_relic_hidden[key] = true
			_refresh_relics()
			_relic_arrives(key, button.global_position + button.size / 2.0)
		else:
			_refresh_bar()
	if not CardFeel.shown():
		_done_here()
		return
	var wait := create_tween()
	wait.tween_interval(CardFeel.time(0.6))
	wait.tween_callback(_here0(_done_here))


## --- Who plays: the gates' decks (CardCharacterDefinition; the designer, 2026-11-27) ---


## The characters chosen so far, one a player.
var _chosen_characters: Array = []


## The gates to choose from, by gate: one for each player (two on one screen, in turn). A locked one shows how many of its code
## fragments have been found (CardUnlocks); its tooltip says how it plays.
func _show_characters():
	_chosen_characters = []
	_build_character_choice()


func _build_character_choice():
	view = "characters"
	_clear_body()
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 30
	column.offset_right = -30
	column.offset_top = 14
	column.offset_bottom = -14
	column.add_theme_constant_override("separation", 10)
	_body.add_child(column)
	UiFeel.arrive(column)
	var who := _chosen_characters.size()
	_heading(column, "Who Hacks?" if _players_wanted() == 1 else "Player %d: Who Hacks?" % (who + 1), 30)
	_text(column, "Each gate is a deck of its own, as strong as the others and played its own way. A locked gate opens as its code fragments are found: a layer's boss, a Memento, a hack in the world.")
	# Over a network: each chooses their own gate, on their own screen.
	if networked():
		var mine := int(local_players[0]) if not local_players.is_empty() else 0
		var lines: Array[String] = []
		for p in CardBattle.MOST_PLAYERS:
			var chosen := str(_net_characters[p]) if p < _net_characters.size() else ""
			var definition := CardDatabase.character(chosen)
			lines.append("%s: %s" % ["You" if p == mine else "Your partner", definition.name if definition != null else "choosing..."])
		var said := _text(column, "Played together over the network.   " + "   ".join(lines), PLAYER_INKS[mine % PLAYER_INKS.size()])
		said.name = "Together"
	if who == 0 and not networked():
		# How many play (a hack's count is the game's: two when it has two players here).
		if hacking == null:
			var options := HBoxContainer.new()
			options.alignment = BoxContainer.ALIGNMENT_CENTER
			options.add_theme_constant_override("separation", 12)
			column.add_child(options)
			for count in [1, 2]:
				var choice := Button.new()
				choice.text = "One player" if count == 1 else "Two players, one screen"
				choice.toggle_mode = true
				choice.button_pressed = players_chosen == count
				choice.name = "Players%d" % count
				choice.pressed.connect(_set_players.bind(count))
				options.add_child(choice)
			var box := CheckBox.new()
			box.text = "Practice: every gate open"
			box.button_pressed = practice
			box.toggled.connect(_set_practice)
			options.add_child(box)
		# Two on one screen: both hands at once (each on their own device), or one at a time with Swap; the rooms together or in turn.
		if _players_wanted() == 2:
			var two := HBoxContainer.new()
			two.alignment = BoxContainer.ALIGNMENT_CENTER
			two.add_theme_constant_override("separation", 12)
			column.add_child(two)
			var hands := CheckBox.new()
			hands.name = "BothHands"
			hands.text = "Both hands at once"
			hands.button_pressed = both_hands
			hands.tooltip_text = "Each player's hand on their own half of the screen, played at the same time; else one hand at a time, with Swap (Tab)."
			hands.toggled.connect(_set_both_hands)
			two.add_child(hands)
			var rooms := CheckBox.new()
			rooms.name = "RoomsTogether"
			rooms.text = "Rooms together"
			rooms.button_pressed = rooms_together
			rooms.tooltip_text = "Rewards, rests, shops, events and chests for both at once, each on their half of the screen; else one after the other."
			rooms.toggled.connect(_set_rooms_together)
			two.add_child(rooms)
			var pads: Array = Input.get_connected_joypads()
			var said := "Player 1: the keyboard and mouse%s. Player 2: %s." % [", and a pad" if pads.size() >= 2 else "",
				"a pad" if not pads.is_empty() else "the keyboard and mouse too (connect a pad to play on your own)"]
			if Coop.players.size() >= 2 and Coop.local_players().size() >= 2:
				said = "Each player on their own device, as in the game."
			var devices_line := _text(column, said, MUTED)
			devices_line.name = "Devices"
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var centre := CenterContainer.new()
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(centre)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	centre.add_child(grid)
	for key in CardDatabase.characters_in_order():
		grid.add_child(_character_card(key))
	if CardDatabase.characters().is_empty():
		_button(column, "Play", _character_chosen.bind(""))
	_button(column, "Back" if who > 0 else "Leave", _character_back)
	_focus_first(column)


## A gate to choose: its colour, name, gate and how it plays, or how much of its code has been found.
func _character_card(key: String) -> Control:
	var definition := CardDatabase.character(key)
	var open := CardUnlocks.unlocked(key)
	var colour := definition.colour()
	var button := Button.new()
	button.name = "Character_" + key
	button.custom_minimum_size = Vector2(224, 236)
	button.disabled = not open
	button.tooltip_text = definition.playstyle if open else "Locked: %d of its %d code fragments found." % [CardUnlocks.fragments(key), definition.fragments_needed]
	button.pressed.connect(_character_chosen.bind(key))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = CARD_LIT if state in ["hover", "focus"] else (Color("141a22") if state == "disabled" else CARD)
		box.border_color = colour if state != "disabled" else colour.darkened(0.6)
		box.set_border_width_all(3 if state in ["hover", "focus", "pressed"] else 2)
		box.set_corner_radius_all(8)
		button.add_theme_stylebox_override(state, box)
	var inside := VBoxContainer.new()
	inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inside.set_anchors_preset(Control.PRESET_FULL_RECT)
	inside.offset_left = 10
	inside.offset_right = -10
	inside.offset_top = 8
	inside.offset_bottom = -8
	inside.add_theme_constant_override("separation", 4)
	button.add_child(inside)
	var title := Label.new()
	title.text = definition.name
	title.theme_type_variation = GameFonts.HEADER
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", colour.lightened(0.25) if open else MUTED)
	inside.add_child(title)
	var gate := Label.new()
	gate.text = "Gate %d" % definition.gate
	gate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gate.add_theme_font_size_override("font_size", 12)
	gate.add_theme_color_override("font_color", MUTED)
	inside.add_child(gate)
	if definition.picture != null:
		var picture := TextureRect.new()
		picture.texture = definition.picture
		picture.custom_minimum_size = Vector2(0, 70)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not open:
			picture.modulate = Color(0.3, 0.3, 0.35)
		inside.add_child(picture)
	var words := Label.new()
	words.text = definition.playstyle.get_slice("\n", 0) if open else "Locked.\n%d of %d code fragments found." % [CardUnlocks.fragments(key), definition.fragments_needed]
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.size_flags_vertical = Control.SIZE_EXPAND_FILL
	words.add_theme_font_size_override("font_size", 13)
	words.add_theme_color_override("font_color", INK_DIM if open else MUTED)
	inside.add_child(words)
	var taken_by: int = (_net_characters if networked() else _chosen_characters).find(key)
	if taken_by >= 0:
		var taken := Label.new()
		taken.text = "Player %d's" % (taken_by + 1)
		taken.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		taken.add_theme_color_override("font_color", PLAYER_INKS[taken_by % PLAYER_INKS.size()])
		inside.add_child(taken)
	return button


func _set_players(count: int):
	players_chosen = clampi(count, 1, CardBattle.MOST_PLAYERS)
	_build_character_choice()


func _set_practice(on: bool):
	practice = on
	CardUnlocks.all_open = on
	_build_character_choice()


func _set_both_hands(on: bool):
	both_hands = on


func _set_rooms_together(on: bool):
	rooms_together = on


## Gate `key` chosen for the next player: the next player's choice, or the run. Over a network, this machine's player's choice, a
## move (_character_move).
func _character_chosen(key: String):
	if networked():
		if key != "" and not local_players.is_empty() and not (int(local_players[0]) < _net_characters.size() and str(_net_characters[int(local_players[0])]) != ""):
			act(&"character", int(local_players[0]), [key])
		return
	if key != "":
		_chosen_characters.append(key)
	if _chosen_characters.size() < _players_wanted() and key != "":
		_build_character_choice()
		return
	if hacking != null:
		_start_hack(_chosen_characters)
	else:
		start_run(0, _chosen_characters, CardRun.MOST_LAYERS)


func _character_back():
	if not _chosen_characters.is_empty() and not networked():
		_chosen_characters.pop_back()
		_build_character_choice()
		return
	leave_game()


## --- Each player's turn in a room (co-op: the rewards, a rest, a shop, an event, a chest, the long rest, one after the other) ---


## The players still to choose in this room after the one choosing now (run.me), what shows a player's turn, and what comes once
## they all have (the map, unless said).
var _turns_left: Array = []
var _turn_view: Callable = Callable()
var _after_turns: Callable = Callable()


## A room's choosing begins: the first player's (then the other's, in co-op), each shown by `builder`; `after`, once all have. With
## the rooms together (or over a network), both at once, each on their half of the screen.
func _begin_turns(builder: Callable, after: Callable = Callable()):
	_turn_view = builder
	_after_turns = after
	if _rooms_now():
		_turns_left = []
		_together(builder)
		return
	_turns_left = range(1, run.players.size())
	run.me = 0
	builder.call()


## The player choosing now is done: the next one's turn of the room, or what comes after (the map, the long rest, the end). With
## the rooms together, their half waits for the other's.
func _done_here():
	if _half >= 0 and not _halves.is_empty():
		_half_done(_half)
		return
	if not _turns_left.is_empty() and not run.over and _turn_view.is_valid():
		run.me = int(_turns_left.pop_front())
		_go(_turn_view)
		return
	_after_room()


## Everybody is done with the room: what comes after it.
func _after_room():
	run.me = 0
	var after := _after_turns
	_after_turns = Callable()
	_turn_view = Callable()
	_turns_left = []
	if run.over:
		_go(_show_end)
	elif after.is_valid():
		after.call()
	elif run.long_rest_due:
		_go(_begin_long_rest)
	else:
		_go(_show_map)


## --- Rooms together: each player's half of the screen (the designer's "try them all", 2026-11-27) ---
##
## Rewards, rests, shops, events, chests, the Blessings and the long rest for both at once, each built on its player's half by the
## same builders as one at a time: while a half is built or played (`_half`), `_room()` is that half and `run.me` its player, and
## every button and later callback made there carries its half (_here0, _here1). Over a network the other machine's player's half
## shows what they are doing (_show_elsewhere).

## Rewards, rests, shops and the rest for both at once, as last chosen on the character choice.
static var rooms_together := true
## The half being built or played now (-1: the whole room), each half's root, and which halves are done.
var _half := -1
var _halves: Array = []
var _halves_done: Array = []


func _rooms_now() -> bool:
	return run != null and run.together() and (rooms_together or networked())


## Where a room is built now: the half being built, else the whole room.
func _room() -> Control:
	if _half >= 0 and _half < _halves.size() and is_instance_valid(_halves[_half]):
		return _halves[_half]
	return _body


## `call` (no arguments) as it will be called later: in the half it was made in (itself outside the halves).
func _here0(call: Callable) -> Callable:
	return _in_half.bind(_half, call) if _half >= 0 else call


## `call` with one argument, as _here0.
func _here1(call: Callable) -> Callable:
	return _in_half_with.bind(_half, call) if _half >= 0 else call


## `call` done in half `p` (its player the run's now), unless the halves are gone or that one is done.
func _in_half(p: int, call: Callable):
	if p < 0 or p >= _halves.size() or bool(_halves_done[p]):
		return
	var was_half := _half
	var was_me := run.me
	_half = p
	run.me = p
	call.call()
	_half = was_half
	run.me = was_me


func _in_half_with(argument, p: int, call: Callable):
	_in_half(p, call.bind(argument))


## Both players' halves of the room at once, each built by `builder` as theirs (over a network, the other machine's shows what they
## do).
func _together(builder: Callable):
	_half = -1
	_clear_body()
	var row := HBoxContainer.new()
	row.name = "Halves"
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 0)
	_body.add_child(row)
	for p in run.players.size():
		var half := Control.new()
		half.name = "Half%d" % p
		half.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		half.clip_contents = true
		half.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(half)
		_halves.append(half)
		_halves_done.append(false)
	var line := ColorRect.new()
	line.color = CARD_EDGE
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.set_anchors_preset(Control.PRESET_CENTER_TOP)
	line.anchor_bottom = 1.0
	line.offset_left = -1
	line.offset_right = 1
	_body.add_child(line)
	for p in run.players.size():
		_in_half(p, builder if plays_here(p) else _show_elsewhere)


## Half `p` done: waiting for the other's, or, both done (or the run over), what comes after the room.
func _half_done(p: int):
	_halves_done[p] = true
	if run.over or _halves_done.all(func(done): return bool(done)):
		_end_together()
		return
	_clear_body()
	var column := _centred_column()
	var others: Array = []
	for q in run.players.size():
		if q != p and not bool(_halves_done[q]):
			others.append(run.players[q].name)
	_text(column, "Done. Waiting for %s." % " and ".join(others), PLAYER_INKS[p % PLAYER_INKS.size()])


## Where each half's keys and pad last were (rooms together, with devices shared out): player -> the control.
var _focus_in_half := {}


## Rooms together on one screen, each on their own device: a press of the keys' or a pad's (moving or pressing) from a player whose
## half the focus is not in brings it there - where they left it, else to its first button - and is spent on that.
func _input(event: InputEvent):
	if _halves.is_empty() or devices.is_empty() or event.is_echo() or not event.is_pressed():
		return
	if not (event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return
	if not [&"ui_up", &"ui_down", &"ui_left", &"ui_right", &"ui_accept"].any(func(action): return event.is_action_pressed(action)):
		return
	var p := player_of_event(event)
	if p < 0 or p >= _halves.size() or not is_instance_valid(_halves[p]):
		return
	var owner := get_viewport().gui_get_focus_owner()
	if owner != null and _halves[p].is_ancestor_of(owner):
		_focus_in_half[p] = owner
		return
	if owner != null:
		for q in _halves.size():
			if is_instance_valid(_halves[q]) and _halves[q].is_ancestor_of(owner):
				_focus_in_half[q] = owner
	var to: Control = _focus_in_half.get(p)
	if to == null or not is_instance_valid(to) or not to.is_visible_in_tree() or not _halves[p].is_ancestor_of(to):
		to = null
		for button in _halves[p].find_children("*", "Button", true, false):
			if button.is_visible_in_tree() and not button.disabled and button.focus_mode != Control.FOCUS_NONE:
				to = button
				break
	if to != null:
		to.grab_focus()
		get_viewport().set_input_as_handled()


## Both halves done: the room is over.
func _end_together():
	_half = -1
	_halves = []
	_halves_done = []
	_after_room()


## The other machine's player's half: what they are doing (`said`: what they last did), until they are done (over a network).
func _show_elsewhere(said: String = ""):
	_clear_body()
	var column := _centred_column()
	_whose(column)
	if said != "":
		_text(column, "%s %s" % [run.players[run.me].name, said], INK)
	_text(column, "%s is choosing, on their own screen." % run.players[run.me].name, MUTED)


## A key for a view kept by index (the shop's cards, the deck's picked) in the half it is in, so the two halves' never meet.
func _view_key(index: int) -> int:
	return index + 1000 * maxi(_half, 0) if _half >= 0 else index


## Forgets the views of `views` kept for the half being built (all of them outside the halves).
func _forget_views(views: Dictionary):
	if _half < 0:
		views.clear()
		return
	for key in views.keys():
		if int(key) / 1000 == _half:
			views.erase(key)


## In co-op, whose turn of the room it is, in their colour (with the rooms together, whose half this is).
func _whose(parent: Control):
	if run != null and run.together():
		if _half >= 0:
			var name_line := _heading(parent, run.players[run.me].name, 22)
			name_line.add_theme_color_override("font_color", PLAYER_INKS[run.me % PLAYER_INKS.size()])
			return
		_text(parent, "%s chooses." % run.players[run.me].name, PLAYER_INKS[run.me % PLAYER_INKS.size()])


## How wide a column is in a half of the screen.
const HALF_WIDTH := 600.0


## --- Two on one screen: both hands at once, each on their own device (the designer's "try them all", 2026-11-27) ---

## Both players' hands at once in a fight, side by side (else one at a time, with Swap), as last chosen on the character choice.
static var both_hands := true
## A press from a device nobody here plays with (player_of_event).
const NOBODY_HERE := -3
## Each player's devices on one screen: Coop.KEYBOARD (the keyboard and mouse) and pads' numbers; empty, the keys and pads are
## anybody's (one hand at a time: the shown one's). Set as a run for two starts (_share_devices).
var devices: Array = []


## Whether a fight shows both hands at once: two players, and both hands chosen (always over a network: each sees their own).
func hands_together() -> bool:
	return run != null and run.together() and (both_hands or networked())


## Whether player `p` plays on this machine (over a network, only this machine's player does; on one screen, everybody).
func plays_here(p: int) -> bool:
	return not networked() or local_players.has(p)


## The player a press came from, by its device (devices); -1 with no devices shared out, NOBODY_HERE for a device nobody plays with.
func player_of_event(event: InputEvent) -> int:
	if devices.is_empty():
		return -1
	var device := Coop.device_of(event)
	for p in devices.size():
		if devices[p].has(device):
			return p
	return NOBODY_HERE


## Shares out the devices for a run of two on one screen: the main game's two players' own when it has them (Coop); else the first
## player the keyboard and mouse (and the first pad, with two), the second the last pad. With no pad at all, nothing is shared out:
## the keyboard and mouse play either hand.
func _share_devices():
	devices = []
	if run == null or not run.together() or networked():
		return
	var here: Array = Coop.local_players()
	if Coop.players.size() >= 2 and here.size() >= 2:
		for p in run.players.size():
			devices.append([Coop.device_of_player(here[p])] if p < here.size() else [])
		return
	var pads: Array = Input.get_connected_joypads()
	if pads.is_empty():
		return
	devices = [[Coop.KEYBOARD] + ([pads[0]] if pads.size() >= 2 else []), [pads[-1]]]


## How player `p` says Ready, in words (their own device's button, with devices shared out).
func ready_key_words(p: int) -> String:
	if devices.is_empty() or p >= devices.size() or devices[p].is_empty():
		return Pad.key(&"end_turn")
	return Pad.key_on(not devices[p].has(Coop.KEYBOARD), &"end_turn")


## --- Moves: what a player does, done here at once, or over a network in the order the host gives (docs/card_game.md) ---

## The players of the run who play on this machine (over a network); empty: all of them.
var local_players: Array = []


## Whether this run is played over a network, two machines playing it together.
func networked() -> bool:
	return net_session != ""


## Over a network: the session this run is (Net's), "" on one machine.
var net_session := ""


## Player `p` does `kind` with `args`: a fight's move (play, ready, let_go: CardStage.apply_move). On one machine it is done at once;
## over a network it is sent, and done when it comes back in the host's order (Net.card_move). Whether it was taken.
func act(kind: StringName, p: int, args: Array = []) -> bool:
	if networked():
		var net = get_node_or_null("/root/Net")
		if net != null and net.has_method("card_move"):
			return net.card_move(net_session, kind, p, args)
	return apply_move(kind, p, args)


## A move done (here, or come back over a network in order). A fight's goes to the stage; a room's is done by its player's own half
## here (as if pressed) when they play on this machine, else by the rules alone, their half saying what they did.
func apply_move(kind: StringName, p: int, args: Array) -> bool:
	match kind:
		&"play", &"ready", &"let_go":
			return stage != null and is_instance_valid(stage) and stage.apply_move(kind, p, args)
		&"character":
			return _character_move(p, str(args[0]) if not args.is_empty() else "")
		&"vote":
			return _vote_move(p, int(args[0]) if not args.is_empty() else -1)
		&"leave":
			_leaving_together = true
			leave_game()
			return true
		&"challenge":
			_applying = true
			next_challenge()
			_applying = false
			return true
	if run == null or p < 0 or p >= run.players.size():
		return false
	if plays_here(p):
		var press := _press_for(kind, args)
		if not press.is_valid():
			return false
		_applying = true
		if p < _halves.size():
			_in_half(p, press)
		else:
			var was := run.me
			run.me = p
			press.call()
			run.me = was
		_applying = false
		return true
	_in_half(p, _rules_only.bind(kind, args))
	return true


## What pressing does for a room's move of this machine's player: the half's own function, with what was chosen.
func _press_for(kind: StringName, args: Array) -> Callable:
	var first = args[0] if not args.is_empty() else null
	match kind:
		&"bless":
			return _bless.bind(str(first))
		&"take":
			return _take_and_leave.bind(str(first))
		&"skip":
			return _leave_rewards
		&"patch":
			return _rest_and_leave
		&"cover":
			return _cover_and_leave
		&"mend":
			return _mend_and_leave
		&"upgrade":
			return _upgrade_and_leave.bind(int(first))
		&"remove":
			return _remove_and_leave.bind(int(first))
		&"transform":
			return _transform_and_leave.bind(int(first))
		&"buy_card":
			return _buy_card.bind(int(first))
		&"buy_relic":
			return _buy_relic.bind(int(first))
		&"buy_removal":
			return _remove_in_shop.bind(int(first))
		&"event":
			var options := run.event_options(_event_key)
			return _event_chosen.bind(options[int(first)]) if int(first) >= 0 and int(first) < options.size() else Callable()
		&"grow":
			return _grow_message.bind(int(first))
		&"leave_room":
			return _leave_here
	return Callable()


## Over a network, the other machine's player's room move here: what the rules make of it, and their half says so (their own
## screen shows it played).
func _rules_only(kind: StringName, args: Array):
	var first = args[0] if not args.is_empty() else null
	var said := ""
	var done := true
	match kind:
		&"bless":
			run.choose_blessing(str(first))
			said = "takes a Blessing." if str(first) != "" else "takes no Blessing."
		&"take":
			run.take_card(str(first))
			var card := CardDatabase.card(str(first))
			said = "takes %s." % (card.name if card != null else str(first))
		&"skip":
			said = "takes nothing."
		&"patch":
			run.rest()
			said = "patches up."
		&"cover":
			run.rest_with(CardRun.Rest.COVER_TRACKS)
			said = "covers their tracks."
		&"mend":
			run.rest_with(CardRun.Rest.MEND)
			said = "mends you."
		&"upgrade":
			run.upgrade(int(first))
			said = "makes a card better."
		&"remove":
			run.remove_card(int(first))
			said = "takes a card out."
		&"transform":
			run.transform_card(int(first))
			said = "has a card rewritten."
		&"buy_card", &"buy_relic", &"buy_removal":
			done = false
			if kind == &"buy_card":
				run.buy_card(int(first))
			elif kind == &"buy_relic":
				run.buy_relic(int(first))
			else:
				run.buy_removal(int(first))
			said = "buys something."
		&"event":
			done = false
			var options := run.event_options(_event_key)
			if int(first) >= 0 and int(first) < options.size():
				run.choose(options[int(first)])
				said = "chooses: %s" % options[int(first)].label
		&"grow":
			run.grow_message(int(first))
			said = "gives the Message a word." if int(first) >= 0 else "lets the Message be."
		&"leave_room":
			said = "is done."
	_refresh_bar()
	if done:
		_done_here()
	else:
		_show_elsewhere(said)


## Whether a room's choice of the player now's goes over the network instead (sent; done here when it comes back in order).
var _applying := false


func _sending(kind: StringName, args: Array = []) -> bool:
	if not networked() or _applying:
		return false
	if run == null or not plays_here(run.me):
		return true
	act(kind, run.me, args)
	# Nothing more is pressed in that half until it comes back.
	for button in _room().find_children("*", "Button", true, false):
		(button as Button).disabled = true
	return true


## A player done with the room by their own choice (Continue, Skip, Rest only, Back from a pick): over a network, a move.
func _leave_here():
	if _sending(&"leave_room"):
		return
	_done_here()


## Over a network: whether leaving was the other machine's doing (or agreed), so it is not sent back.
var _leaving_together := false


## --- Played together over a network (Net "The card game, played together") ---
##
## Both machines play the same run from the same seed; every choice is a move (act) numbered by the host and done on both in that
## order (take_move), each once this screen is where it fits (_move_fits). Each machine plays its own player (local_players: the
## host's is the run's first, the joiner's its second): their seat in a fight, their half of a room, their vote, their gate.

## The run's seed, the same on both machines.
var net_seed := 0
## The moves come in and not done yet ([number, kind, player, args]), and how many have been done.
var _moves_waiting: Array = []
var _moves_done := 0
## Each player's gate as they choose it (over a network, on their own screen), and how many runs have begun together.
var _net_characters: Array = []
var _runs_begun := 0


## This game played together with the other machine (Net.begin_card_game, Net._card_begin): its session and seed, this machine's
## player; then each chooses their gate.
func play_together(setup: Dictionary, player_here: int):
	net_session = str(setup.get("session", ""))
	net_seed = int(setup.get("seed", 0))
	local_players = [player_here]
	_voter = player_here
	_moves_waiting = []
	_moves_done = 0
	_net_characters = []
	pass
	_show_characters()


## A move come in over a network, numbered by the host: done in order, as soon as this screen can.
func take_move(number: int, kind: StringName, p: int, args: Array):
	_moves_waiting.append([number, kind, p, args])
	_moves_waiting.sort_custom(func(a, b): return int(a[0]) < int(b[0]))
	_take_moves()


func _take_moves():
	while not _moves_waiting.is_empty():
		var next: Array = _moves_waiting[0]
		if int(next[0]) > _moves_done + 1 or not _move_fits(next[1]):
			return
		_moves_waiting.pop_front()
		if int(next[0]) <= _moves_done:
			continue
		_moves_done = int(next[0])
		apply_move(next[1], int(next[2]), next[3])


## Whether a move of `kind` can be done on this screen now: not mid-wipe or mid-walk; a fight's in the fight (one come after it is
## over is let through, and does nothing); a vote on the map; a gate on the choice; a room's while its halves are up.
func _move_fits(kind: StringName) -> bool:
	if _wiping or _walking:
		return false
	match kind:
		&"play", &"ready", &"let_go":
			return true
		&"vote":
			return view == "map"
		&"character":
			return view == "characters"
		&"leave", &"challenge":
			return true
	return not _halves.is_empty()


## A gate chosen by player `p` (over a network, each on their own screen): once both have, the run, the same on both.
func _character_move(p: int, key: String) -> bool:
	if p < 0 or p >= CardBattle.MOST_PLAYERS or key == "":
		return false
	while _net_characters.size() < CardBattle.MOST_PLAYERS:
		_net_characters.append("")
	_net_characters[p] = key
	if _net_characters.all(func(chosen): return str(chosen) != ""):
		var chosen: Array = _net_characters.duplicate()
		_net_characters = []
		if hacking != null:
			_start_hack(chosen)
		else:
			# A new run's seed: the session's, one on for every run begun (the same count on both machines).
			_runs_begun += 1
			start_run(net_seed + _runs_begun - 1, chosen, CardRun.MOST_LAYERS)
	else:
		_build_character_choice()
	return true


## Player `p`'s vote for room `id` (a move): once both have voted, the way walked and the room opened, on both machines.
func _vote_move(p: int, id: int) -> bool:
	if run == null or view != "map":
		return false
	var from := run.at
	var voted := run.votes.duplicate()
	var went := run.vote(p, id)
	if went < 0:
		if run.choices().has(id):
			CardFeel.sound(&"card_terminal_beep", -10.0)
			_show_map()
		return true
	if voted.values().any(func(other): return int(other) != id) and CardFeel.shown():
		fx.number(size / 2.0, "By lot: %s" % CardRun.room_name(run.rooms[went].room), INK, 28, 40.0, 1.3)
	_walk_and_open(from, went)
	return true


## Over a network: the other machine gone. The run goes on here, both players this screen's now (their half and seat with it).
func _played_alone():
	net_session = ""
	local_players = []
	if not _halves.is_empty() and _turn_view.is_valid():
		for p in _halves.size():
			if not bool(_halves_done[p]):
				_in_half(p, _turn_view)
	elif view == "characters":
		_build_character_choice()
	if stage != null and is_instance_valid(stage):
		stage._refresh_pair()
		stage._refresh_cards()
	_bubble_text("The other player has gone: both are yours to play now.")


## A line over the screen for a moment.
func _bubble_text(text: String):
	if CardFeel.shown():
		fx.number(size / 2.0 + Vector2(0, -120), text, INK, 22, 30.0, 2.0)


## --- The frame: the top bar, the room below it, and what flies over both ---


func _build_frame():
	var back := ColorRect.new()
	back.color = BACKGROUND
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 0)
	add_child(column)
	var bar_panel := PanelContainer.new()
	var bar_box := StyleBoxFlat.new()
	bar_box.bg_color = PANEL
	bar_box.border_color = CARD_EDGE
	bar_box.border_width_bottom = 2
	bar_box.content_margin_left = 14
	bar_box.content_margin_right = 14
	bar_box.content_margin_top = 6
	bar_box.content_margin_bottom = 6
	bar_panel.add_theme_stylebox_override("panel", bar_box)
	column.add_child(bar_panel)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 18)
	bar_panel.add_child(bar)
	_hp_label = _bar_label(bar, HEALTH)
	_gold_label = _bar_label(bar, GOLD)
	_floor_label = _bar_label(bar, INK_DIM)
	_trace_label = _bar_label(bar, TRACE_INK)
	_trace_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_trace_label.tooltip_text = TRACE_WORDS
	_relic_row = HBoxContainer.new()
	_relic_row.add_theme_constant_override("separation", 6)
	_relic_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(_relic_row)
	_challenge_button = Button.new()
	_challenge_button.focus_mode = Control.FOCUS_NONE
	_challenge_button.tooltip_text = CHALLENGE_WORDS
	_challenge_button.pressed.connect(next_challenge)
	bar.add_child(_challenge_button)
	_deck_button = Button.new()
	_deck_button.focus_mode = Control.FOCUS_NONE
	_deck_button.pressed.connect(_show_deck)
	bar.add_child(_deck_button)
	var leave := Button.new()
	leave.text = "Leave"
	leave.focus_mode = Control.FOCUS_NONE
	leave.tooltip_text = "Leave the card game. The run is lost."
	leave.pressed.connect(leave_game)
	bar.add_child(leave)
	_body = Control.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(_body)
	fx = CardFx.new()
	add_child(fx)
	_keyword_panel = PanelContainer.new()
	_keyword_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_keyword_panel.visible = false
	_keyword_panel.set_meta(UiFeel.NO_FEEL, true)
	var words_box := StyleBoxFlat.new()
	words_box.bg_color = Color(0.07, 0.09, 0.12, 0.96)
	words_box.border_color = ACCENT
	words_box.set_border_width_all(1)
	words_box.set_corner_radius_all(6)
	words_box.content_margin_left = 10
	words_box.content_margin_right = 10
	words_box.content_margin_top = 8
	words_box.content_margin_bottom = 8
	_keyword_panel.add_theme_stylebox_override("panel", words_box)
	_keyword_label = Label.new()
	_keyword_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_keyword_label.custom_minimum_size = Vector2(210, 0)
	_keyword_label.add_theme_font_size_override("font_size", 13)
	_keyword_label.add_theme_color_override("font_color", INK)
	_keyword_panel.add_child(_keyword_label)
	add_child(_keyword_panel)
	# The hacking juice: a faint scanline over the whole screen (CardLooks' Scanlines, tiled; else drawn). Only to look at.
	var lines := CardLooks.picture(&"scanlines")
	if lines != null:
		var tiled := TextureRect.new()
		tiled.texture = lines
		tiled.stretch_mode = TextureRect.STRETCH_TILE
		tiled.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_scanlines = tiled
	else:
		var drawn := ColorRect.new()
		var shading := ShaderMaterial.new()
		var shader := Shader.new()
		shader.code = SCANLINE_SHADER
		shading.shader = shader
		drawn.material = shading
		_scanlines = drawn
	_scanlines.name = "Scanlines"
	_scanlines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scanlines.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_scanlines)
	_wipe = ColorRect.new()
	_wipe.color = BACKGROUND
	_wipe.mouse_filter = Control.MOUSE_FILTER_STOP
	_wipe.visible = false
	add_child(_wipe)


## The run's Challenge one higher (round to 0 after the most), before its first room only (docs/proposals_2026-11-27_card_ai.md
## item 22).
func next_challenge():
	if run == null or run.at >= 0:
		return
	# Over a network, a move: the same on both machines.
	if networked() and not _applying:
		act(&"challenge", int(local_players[0]) if not local_players.is_empty() else 0, [])
		return
	run.challenge = (run.challenge + 1) % (CardRun.CHALLENGE_MOST + 1)
	challenge_chosen = run.challenge
	_refresh_bar()


func _bar_label(bar: HBoxContainer, colour: Color) -> Label:
	var label := Label.new()
	label.add_theme_color_override("font_color", colour)
	label.add_theme_font_size_override("font_size", 18)
	bar.add_child(label)
	return label


func _refresh_bar():
	if run == null:
		return
	var fighting := stage != null and is_instance_valid(stage) and stage.player_view != null and battle != null
	if run.together():
		# Both players' health, the fight's as it shows it.
		var parts: Array[String] = []
		for p in run.players.size():
			var now := int(run.players[p].hp)
			if fighting and p < stage.player_views.size():
				now = stage.player_views[p].hp
			parts.append("%s %d/%d" % [run.players[p].name, now, int(run.players[p].max_hp)])
		_hp_label.text = "   ".join(parts)
	else:
		var hp := run.hp
		# In a fight, the health the fight shows (it is played back after the rules), to its very end.
		if fighting:
			hp = stage.player_view.hp
		var most := run.max_hp
		if _hp_shown >= 0 and hp != _hp_shown and CardFeel.shown():
			_tint(_hp_label, MEND if hp > _hp_shown else Color("ff6a5a"), HEALTH)
		_hp_shown = hp
		UiFeel.count_to(_hp_label, hp, func(n: int): return "Health %d/%d" % [n, most])
	if not _gold_held:
		if run.together():
			# Both purses (co-op): each their own.
			var purses: Array[String] = []
			for each in run.players:
				purses.append("%s %d" % [each.name, int(each.gold)])
			_gold_label.text = "Gold: " + "   ".join(purses)
		else:
			UiFeel.count_to(_gold_label, run.gold, func(n: int): return "Gold %d" % n)
	_floor_label.text = ("Layer %d of %d   " % [run.layer, run.layers] if run.layers > 1 else "") \
		+ "Floor %d of %d" % [maxi(run.floor_here() + 1, 0), run.floors + 1]
	var trace := run.trace + (battle.trace_gained if battle != null else 0)
	_trace_label.text = "Trace %d" % mini(trace, CardRun.TRACE_MOST)
	_trace_label.add_theme_color_override("font_color", _trace_colour(trace))
	_challenge_button.text = "Challenge %d" % run.challenge
	_challenge_button.disabled = run.at >= 0
	_challenge_button.visible = hacking == null
	_deck_button.text = "Deck (%d)" % run.deck.size()
	if _deck_shown >= 0 and run.deck.size() != _deck_shown:
		UiFeel.pop(_deck_button)
	_deck_shown = run.deck.size()
	_refresh_relics()


## The trace's colour: green while quiet, yellow, orange, red as the system's answers come (CardRun.TRACE_MARKS).
static func _trace_colour(trace: int) -> Color:
	if trace >= CardRun.TRACE_GLITCH:
		return Color("ff6a5a")
	if trace >= 50:
		return Color("f0a070")
	if trace >= 25:
		return Color("e8c872")
	return TRACE_INK


## A loud card raised the trace in a fight (CardStage's "trace" beat): the meter flashes and says by how much.
func trace_rose(gained: int):
	_refresh_bar()
	if gained <= 0 or not CardFeel.shown() or _trace_label == null:
		return
	_tint(_trace_label, Color("ff6a5a"), _trace_colour(run.trace + (battle.trace_gained if battle != null else 0)))
	fx.number(_trace_label.global_position + Vector2(_trace_label.size.x / 2.0, _trace_label.size.y + 12.0), "+%d" % gained,
		Color("ff8a7a"), 16, 18.0, 0.8)


## A label lit `colour` a moment, back to `rest`.
func _tint(label: Label, colour: Color, rest: Color):
	label.add_theme_color_override("font_color", colour)
	var tween := label.create_tween()
	tween.tween_interval(0.35)
	tween.tween_method(func(value: Color): label.add_theme_color_override("font_color", value), colour, rest, 0.4)


## The relics along the top as their pictures (a relic's own Picture, else its first letter on gold), one kept for each.
func _refresh_relics():
	for key in _relic_icons.keys():
		if not run.relics.has(key):
			_relic_icons[key].queue_free()
			_relic_icons.erase(key)
	for key in run.relics:
		if _relic_icons.has(key):
			continue
		var relic := CardDatabase.relic(key)
		if relic == null:
			continue
		var icon := CardIcon.new()
		icon.custom_minimum_size = Vector2(28, 28)
		icon.pivot_offset = Vector2(14, 14)
		icon.mouse_filter = Control.MOUSE_FILTER_STOP
		icon.tooltip_text = "%s\n%s%s" % [relic.name, relic.describe(), ("\n" + relic.flavour) if relic.flavour != "" else ""]
		icon.show_icon(&"relic", relic.picture, GOLD, relic.name.substr(0, 1))
		icon.modulate.a = 0.0 if _relic_hidden.has(key) or _hide_new_relics else 1.0
		_relic_row.add_child(icon)
		_relic_icons[key] = icon


## Where relic `key` sits on the bar (or would), global.
func relic_place(key: String) -> Vector2:
	var icon: CardIcon = _relic_icons.get(key)
	if icon != null and is_instance_valid(icon) and icon.is_inside_tree():
		return icon.global_position + icon.size / 2.0
	return _relic_row.global_position + Vector2(_relic_row.get_child_count() * 34.0 + 14.0, 14.0)


## Relic `key` lights up on the bar: it is doing its thing.
func flash_relic(key: String):
	CardFeel.note(&"relic_flash")
	var icon: CardIcon = _relic_icons.get(key)
	if icon == null or not CardFeel.shown() or not is_instance_valid(icon):
		return
	UiFeel.pop(icon)
	var tween := icon.create_tween()
	tween.tween_property(icon, "modulate", Color(1.8, 1.6, 1.0), 0.08)
	tween.tween_property(icon, "modulate", Color.WHITE, 0.35)
	fx.ring(relic_place(key), GOLD, 8.0, 34.0, 0.35, 3.0)


func _relic_used(key: String):
	flash_relic(key)
	CardFeel.sound(&"card_relic_used", -6.0)


## Relic `key`, just gained, rises out of a glow at `from` (global) and flies into the bar.
func _relic_arrives(key: String, from: Vector2):
	var relic := CardDatabase.relic(key)
	if relic == null:
		return
	if not CardFeel.shown():
		_relic_hidden.erase(key)
		_refresh_relics()
		return
	_relic_hidden[key] = true
	_refresh_relics()
	var icon: CardIcon = _relic_icons.get(key)
	if icon != null:
		icon.modulate.a = 0.0
	fx.ring(from, GOLD, 16.0, 80.0, 0.5, 5.0)
	fx.rays(from, Color("ffe08a"), 0.9)
	CardFeel.sound(&"card_relic_gained", -6.0)
	# Once the bar has laid the new icon out, it flies there.
	await get_tree().process_frame
	if not is_inside_tree():
		return
	fx.fly_icon(&"relic", relic.picture, GOLD, relic.name.substr(0, 1), from, relic_place(key), 52.0, CardFeel.time(0.6), 120.0,
		_relic_landed.bind(key), 0.55)


func _relic_landed(key: String):
	_relic_hidden.erase(key)
	var icon: CardIcon = _relic_icons.get(key)
	if icon != null and is_instance_valid(icon):
		icon.modulate.a = 1.0
		UiFeel.pop(icon)


## Gold coming in from `from` (global): coins fly into the purse, which counts up as they land.
func _coins_in(from: Vector2, amount: int):
	if amount <= 0 or not CardFeel.shown():
		_refresh_bar()
		return
	_gold_held = true
	_coins_left = clampi(roundi(amount / 4.0), 3, 12)
	var purse := _gold_label.global_position + _gold_label.size / 2.0
	fx.flow(from, purse, &"coin", _coins_left, GOLD, CardFeel.time(0.55), _coin_landed)


func _coin_landed():
	_coins_left -= 1
	CardFeel.sound(&"card_gold", -10.0, randf_range(0.95, 1.15))
	if _coins_left <= 0:
		_gold_held = false
		_refresh_bar()
		UiFeel.pop(_gold_label)


## Gold paid out to `to` (global): coins fly from the purse, which counts down.
func _coins_out(to: Vector2, amount: int):
	_refresh_bar()
	if amount <= 0 or not CardFeel.shown():
		return
	CardFeel.sound(&"card_gold_spent", -8.0)
	var purse := _gold_label.global_position + _gold_label.size / 2.0
	fx.flow(purse, to, &"coin", clampi(roundi(amount / 15.0), 3, 8), GOLD, CardFeel.time(0.4))


func _clear_body():
	# A half: only what is in it.
	if _half >= 0 and _half < _halves.size():
		_forget_views(_shop_views)
		_forget_views(_pick_views)
		hide_keywords()
		for child in _room().get_children():
			child.queue_free()
		return
	_halves = []
	_halves_done = []
	stage = null
	_shop_views.clear()
	_pick_views.clear()
	_map_canvas = null
	if _typing != null and _typing.is_valid():
		_typing.kill()
	_typing = null
	_typed = null
	_typed_then = []
	hide_keywords()
	if GameSounds.looping() == &"card_rest_fire":
		GameSounds.stop_loop()
	for child in _body.get_children():
		child.queue_free()


## A column in the middle of the room, for the simple views; it fades in (UiFeel.arrive).
func _centred_column(width: float = 760.0) -> VBoxContainer:
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	_room().add_child(centre)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(minf(width, HALF_WIDTH) if _half >= 0 else width, 0)
	column.add_theme_constant_override("separation", 14)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	centre.add_child(column)
	UiFeel.arrive(column)
	return column


func _heading(parent: Control, text: String, font_size: int = 30) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = GameFonts.HEADER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", INK)
	parent.add_child(label)
	return label


func _text(parent: Control, text: String, colour: Color = INK_DIM) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", colour)
	parent.add_child(label)
	return label


func _button(parent: Control, text: String, action: Callable, enabled: bool = true) -> Button:
	var button := Button.new()
	button.text = text
	button.disabled = not enabled
	button.custom_minimum_size = Vector2(260, 40)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# Made in a half: pressed, it is that half's player's.
	button.pressed.connect(_here0(action))
	parent.add_child(button)
	return button


## Puts the keys' and a pad's focus on the first button in `parent` that can take it, and deals its buttons in (UiFeel.deal_in).
func _focus_first(parent: Node):
	var buttons: Array = []
	for child in parent.find_children("*", "Button", true, false):
		if child.visible:
			buttons.append(child)
	UiFeel.deal_in.call_deferred(buttons)
	for child in buttons:
		if not child.disabled and child.focus_mode != Control.FOCUS_NONE:
			child.grab_focus.call_deferred()
			return


## Leaves the card game: back where it was opened from, or the title screen. A hack says how it went and goes (hack_done). Over a
## network both leave together (a move).
func leave_game():
	if networked() and not _leaving_together:
		act(&"leave", int(local_players[0]) if not local_players.is_empty() else 0, [])
		return
	var net = get_node_or_null("/root/Net")
	if net != null and net.get("card_game_here") == self:
		net.card_game_gone(self)
	if practice:
		CardUnlocks.all_open = false
	if GameSounds.looping() == &"card_rest_fire":
		GameSounds.stop_loop()
	if hacking != null:
		var won := run != null and run.won
		hack_done.emit(won, run == null or not run.over)
		return
	var to := return_scene if return_scene != "" else TITLE_SCREEN
	return_scene = ""
	var transition = get_node_or_null("/root/SceneTransition")
	if transition != null:
		transition.change_scene(to)
	else:
		get_tree().change_scene_to_file(to)


## Into a room (and back): a short wipe across the screen, `build` making the room under it. At once headless.
func _go(build: Callable):
	if not CardFeel.shown() or not is_inside_tree() or _wiping:
		build.call()
		return
	_wiping = true
	CardFeel.sound(&"card_room_entered", -10.0)
	_wipe.size = size
	_wipe.position = Vector2(-size.x, 0)
	_wipe.visible = true
	move_child(_wipe, -1)
	var tween := create_tween()
	tween.tween_property(_wipe, "position:x", 0.0, CardFeel.time(WIPE_SECONDS)).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(build)
	tween.tween_property(_wipe, "position:x", size.x, CardFeel.time(WIPE_SECONDS)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(_wiped)


func _wiped():
	_wipe.visible = false
	_wiping = false


## The card game's music for `slot` (SoundBank "The card game"), if it is filled; else whatever plays carries on.
func _music(slot: StringName):
	if slot == _music_now:
		return
	var stream := GameSounds.stream(slot)
	if stream == null or stream.resource_path == "":
		return
	_music_now = slot
	Music.play(stream.resource_path)


## --- What its words mean ---


## What `card`'s words mean, in a panel beside it (at `rect`, global, when given: where it is going to be). Nothing to explain: none.
func show_keywords(card: CardView, rect: Rect2 = Rect2()):
	# Nothing to read on a card lying face down.
	if card == null or not is_instance_valid(card) or card.face_down:
		hide_keywords()
		return
	var words := card.keywords()
	if words == "":
		hide_keywords()
		return
	_keyword_card = card
	_keyword_rect = rect
	_keyword_label.text = words
	_keyword_panel.visible = true
	_keyword_panel.reset_size()
	_place_keywords()
	move_child(_keyword_panel, -1)
	if _wipe.visible:
		move_child(_wipe, -1)


func hide_keywords():
	_keyword_card = null
	if _keyword_panel != null:
		_keyword_panel.visible = false


## The panel beside its card: where the card is going to be when that was given, else where it is now (so a card still being laid
## out, its row not yet placed, carries the panel with it).
func _place_keywords():
	if _keyword_card == null or not is_instance_valid(_keyword_card):
		return
	var rect := _keyword_rect
	if not rect.has_area():
		rect = Rect2(_keyword_card.get_global_transform() * Vector2.ZERO, _keyword_card.size * _keyword_card.scale)
	var at := Vector2(rect.end.x + 10.0, rect.position.y)
	if at.x + _keyword_panel.size.x > size.x - 8.0:
		at.x = rect.position.x - 10.0 - _keyword_panel.size.x
	at.y = clampf(at.y, 50.0, size.y - _keyword_panel.size.y - 8.0)
	_keyword_panel.position = at


func _process(_delta: float):
	# Played together: the moves come in done as the screen comes to fit them; the other machine gone, both players are here's.
	if networked():
		_take_moves()
		var net = get_node_or_null("/root/Net")
		if net != null and not net.with_another():
			_played_alone()
	if _keyword_panel == null or not _keyword_panel.visible:
		return
	if _keyword_card == null or not is_instance_valid(_keyword_card) or not _keyword_card.is_visible_in_tree() or _keyword_card.face_down:
		hide_keywords()
		return
	_place_keywords()


func _card_hovered(card: CardView, on: bool):
	if on:
		show_keywords(card)
	else:
		hide_keywords()


## --- The map ---


func _show_map():
	view = "map"
	_clear_body()
	# Gold held for coins that never set off (the rewards left at once) is counted now.
	if _gold_held and _coins_left <= 0:
		_gold_held = false
	_refresh_bar()
	_music(&"card_music_map")
	# Each layer of the system its own backdrop (CardLooks' Hacking group), falling back to the first's.
	var map_back := CardLooks.picture([&"map_background", &"map_background", &"map_background_2", &"map_background_3"][clampi(run.layer, 1, 3)])
	if map_back == null:
		map_back = CardLooks.picture(&"map_background")
	if map_back != null:
		var picture := TextureRect.new()
		picture.texture = map_back
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		picture.set_anchors_preset(Control.PRESET_FULL_RECT)
		_body.add_child(picture)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(scroll)
	var width := float(CardRun.COLUMNS - 1) * MAP_COLUMN
	var height := float(run.floors) * MAP_ROW
	var canvas := _MapLines.new()
	canvas.custom_minimum_size = Vector2(maxf(width + 200.0, 1100.0), height + 140.0)
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(canvas)
	_map_canvas = canvas
	var choices := run.choices()
	var left := (canvas.custom_minimum_size.x - width) / 2.0
	var first_choice: Button = null
	for id in run.rooms:
		var room: Dictionary = run.rooms[id]
		var at := Vector2(left + room.column * MAP_COLUMN, 70.0 + (run.floors - room.floor) * MAP_ROW)
		canvas.points[id] = at
		var button := _RoomButton.new()
		button.room = room.room
		button.tooltip_text = CardRun.room_name(room.room)
		var boss: bool = room.room == CardRun.Room.BOSS
		button.custom_minimum_size = Vector2(64, 64) if boss else Vector2(46, 46)
		button.size = button.custom_minimum_size
		button.position = at - button.size / 2.0
		var open := choices.has(id)
		var been := run.visited.has(id)
		button.disabled = not open
		button.open = open
		button.been = been
		button.focus_mode = Control.FOCUS_ALL if open else Control.FOCUS_NONE
		button.pressed.connect(choose_room.bind(id))
		canvas.add_child(button)
		if open:
			canvas.open.append(id)
			if first_choice == null:
				first_choice = button
	canvas.rooms = run.rooms
	canvas.visited = run.visited
	canvas.at = run.at
	canvas.layer = run.layer
	# Co-op: where each has voted to go, in their colour.
	for p in run.votes:
		canvas.votes[int(run.votes[p])] = canvas.votes.get(int(run.votes[p]), []) + [PLAYER_INKS[int(p) % PLAYER_INKS.size()]]
	canvas.start_point = Vector2(canvas.custom_minimum_size.x / 2.0, 70.0 + (run.floors + 1) * MAP_ROW - 20.0)
	canvas.queue_redraw()
	var hint := Label.new()
	hint.name = "MapHint"
	hint.text = "Choose where to go next." if not choices.is_empty() else ""
	if run.together() and not choices.is_empty():
		hint.text = "%s votes where to go next (agreeing goes there; else one of the two, by lot)." % run.players[_voter].name
		hint.add_theme_color_override("font_color", PLAYER_INKS[_voter % PLAYER_INKS.size()])
	else:
		hint.add_theme_color_override("font_color", INK_DIM)
	if run.layers > 1:
		hint.text = "Layer %d of %d. " % [run.layer, run.layers] + hint.text
	# Deeper in, the map comes apart into pixels.
	if run.layer > 1 and CardFeel.shown():
		var pixels := ColorRect.new()
		pixels.name = "Pixels"
		pixels.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pixels.set_anchors_preset(Control.PRESET_FULL_RECT)
		var shading := ShaderMaterial.new()
		var shader := Shader.new()
		shader.code = PIXEL_SHADER
		shading.shader = shader
		shading.set_shader_parameter("pixel", [1.0, 1.0, 2.0, 3.0][clampi(run.layer, 1, 3)])
		shading.set_shader_parameter("tear", 0.004 * run.layer)
		pixels.material = shading
		_body.add_child(pixels)
	hint.add_theme_color_override("font_color", INK_DIM)
	hint.position = Vector2(16, 8)
	_body.add_child(hint)
	# Down at the floor the player is on, gliding there from where the map was last seen.
	var focus_y := 70.0 + (run.floors - maxi(run.floor_here() + 1, 0)) * MAP_ROW
	_scroll_to.call_deferred(scroll, int(maxf(focus_y - 300.0, 0.0)))
	if first_choice != null:
		first_choice.grab_focus.call_deferred()


func _scroll_to(scroll: ScrollContainer, y: int):
	if not is_instance_valid(scroll):
		return
	var from := _map_scroll
	_map_scroll = y
	if from < 0 or from == y or not CardFeel.shown():
		scroll.scroll_vertical = y
		return
	scroll.scroll_vertical = from
	var tween := scroll.create_tween()
	tween.tween_property(scroll, "scroll_vertical", y, CardFeel.time(0.55)).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


static func _room_mark(room: CardRun.Room) -> String:
	return ["Fight", "Elite", "Rest", "Shop", "?", "Chest", "BOSS"][room]


## A room on the map: its picture (CardLooks' room_*, or a stand-in) on a round of its own, lit while it can be chosen, green once
## been to.
class _RoomButton extends Button:
	var room: CardRun.Room = CardRun.Room.FIGHT
	var open := false
	var been := false

	func _init():
		flat = true
		pivot_offset = size / 2.0
		resized.connect(func(): pivot_offset = size / 2.0)

	func _draw():
		var middle := size / 2.0
		var radius := minf(size.x, size.y) * 0.5
		var backdrop := Color("1c2531") if not been else Color("1e3326")
		draw_circle(middle, radius, backdrop)
		var edge := Color("8296a9")
		if open:
			edge = Color("9cc8f0")
		elif been:
			edge = Color("8fd6a0")
		draw_arc(middle, radius - 1.5, 0.0, TAU, 32, edge, 2.5 if open else 1.5, true)
		var slot: StringName = [&"room_fight", &"room_elite", &"room_rest", &"room_shop", &"room_event", &"room_chest", &"room_boss"][room]
		var picture := CardLooks.picture(slot)
		var area := Rect2(middle - Vector2.ONE * radius * 0.72, Vector2.ONE * radius * 1.44)
		var shade := Color.WHITE if open or been else Color(1, 1, 1, 0.5)
		if picture != null:
			draw_texture_rect(picture, CardIcon.fit(picture.get_size(), area), false, shade)
		else:
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			CardIcon.stand_in(self, slot, area)
			if not open and not been:
				draw_circle(middle, radius - 2.0, Color(0.06, 0.08, 0.1, 0.45))


## Lines between the rooms of the map, drawn under their buttons; rings pulsing about the rooms that can be chosen, the marker of
## where the player is, and the way to a room inking itself in as it is walked.
class _MapLines extends Control:
	var points := {}
	var rooms := {}
	var visited: Array = []
	var open: Array = []
	var at := -1
	var start_point := Vector2.ZERO
	## The way being walked: from, to (points) and how far along, 0 to 1; empty when none.
	var walking := {}
	## The layer of the system shown, and (co-op) the votes on each room: id -> the voters' colours.
	var layer := 1
	var votes := {}
	var _age := 0.0

	func _process(delta: float):
		_age += delta
		queue_redraw()

	func _draw():
		# The map as a network (the hacking juice): links of dashes, the walked ones lit with packets running along them.
		for id in rooms:
			if not points.has(id):
				continue
			for to in rooms[id].next:
				if not points.has(to):
					continue
				var walked: bool = visited.has(id) and visited.has(to)
				if walked:
					draw_line(points[id], points[to], Color(0.6, 0.85, 0.65, 0.9), 3.0, true)
					var packet: float = fmod(_age * 0.6 + float(id) * 0.21, 1.0)
					draw_circle(points[id].lerp(points[to], packet), 3.0, Color(0.8, 1.0, 0.85, 0.9))
				else:
					draw_dashed_line(points[id], points[to], Color(0.55, 0.62, 0.72, 0.45), 2.0, 7.0, true)
		# Co-op: a dot by each room voted for, in the voter's colour.
		for id in votes:
			if not points.has(id):
				continue
			var nth := 0
			for colour in votes[id]:
				draw_circle(points[id] + Vector2(30.0 + 12.0 * nth, -18.0), 5.0, colour)
				nth += 1
		# The rooms that can be chosen, pulsing.
		for id in open:
			if not points.has(id):
				continue
			var beat := fmod(_age * 0.9 + float(id) * 0.13, 1.0)
			var radius: float = (34.0 if rooms[id].room == CardRun.Room.BOSS else 25.0) + beat * 16.0
			draw_arc(points[id], radius, 0.0, TAU, 40, Color(0.61, 0.78, 0.94, 0.7 * (1.0 - beat)), 3.0, true)
		# The way being walked, inked in, and the marker on it.
		var marker: Vector2 = points[at] if points.has(at) else start_point
		if not walking.is_empty():
			var t: float = walking.t
			var head: Vector2 = walking.from.lerp(walking.to, t)
			draw_line(walking.from, head, Color(0.95, 0.85, 0.55, 0.95), 4.0, true)
			marker = head
		var picture := CardLooks.picture(&"map_marker")
		var area := Rect2(marker + Vector2(-14, -48), Vector2(28, 28))
		if picture != null:
			draw_texture_rect(picture, CardIcon.fit(picture.get_size(), area), false)
		else:
			CardIcon.stand_in(self, &"map_marker", area)


## Goes to room `id` of the map: the way there inked in and walked, then a wipe into what is there.
func choose_room(id: int):
	if _walking or _wiping:
		return
	# Over a network: this machine's player's vote, done on both as it comes back (_vote_move).
	if networked():
		if run.choices().has(id) and not local_players.is_empty():
			act(&"vote", int(local_players[0]), [id])
		return
	var from := run.at
	if run.together():
		# Co-op: each votes in turn; agreeing goes there, else one of the two by lot (Slay the Spire 2's way).
		var voted := run.votes.duplicate()
		var went := run.vote(_voter, id)
		if went < 0:
			if not run.choices().has(id):
				return
			CardFeel.sound(&"card_terminal_beep", -10.0)
			_voter = 1 - _voter
			_show_map()
			return
		_voter = 0
		var differed := voted.values().any(func(other): return int(other) != id)
		if differed and CardFeel.shown():
			fx.number(size / 2.0, "By lot: %s" % CardRun.room_name(run.rooms[went].room), INK, 28, 40.0, 1.3)
		id = went
	elif not run.go_to(id):
		return
	_walk_and_open(from, id)


## The way from room `from` to room `id` (gone to already) inked in and walked, then a wipe into what is there.
func _walk_and_open(from: int, id: int):
	CardFeel.sound(&"card_terminal_beep", -14.0)
	if CardFeel.shown() and _map_canvas != null and is_instance_valid(_map_canvas):
		_walking = true
		CardFeel.sound(&"card_map_step", -6.0)
		var canvas := _map_canvas
		var start: Vector2 = canvas.points[from] if canvas.points.has(from) else canvas.start_point
		canvas.walking = {"from": start, "to": canvas.points.get(id, start), "t": 0.0}
		var tween := create_tween()
		tween.tween_method(_walk_step.bind(canvas), 0.0, 1.0, CardFeel.time(WALK_SECONDS)).set_ease(Tween.EASE_IN_OUT)
		await tween.finished
		_walking = false
		if not is_inside_tree():
			return
	_go(_open_room)


func _walk_step(t: float, canvas: _MapLines):
	if is_instance_valid(canvas) and not canvas.walking.is_empty():
		canvas.walking.t = t


## The room gone into: a fight, or a room each player has a turn of (one after the other in co-op).
func _open_room():
	_event_key = ""
	match run.room_here():
		CardRun.Room.FIGHT, CardRun.Room.ELITE, CardRun.Room.BOSS:
			_start_battle()
		CardRun.Room.REST:
			_begin_turns(_show_rest)
		CardRun.Room.SHOP:
			_begin_turns(_show_shop)
		CardRun.Room.EVENT:
			_event_key = run.event_here()
			_begin_turns(_show_event)
		CardRun.Room.TREASURE:
			# Every chest opened now, in turn (the same on both machines of a network game); what each gives waits off the bar
			# until it flies in.
			_hide_new_relics = CardFeel.shown()
			for p in run.players.size():
				run.me = p
				var key := run.open_chest()
				if key != "" and CardFeel.shown():
					_relic_hidden[key] = true
			run.me = 0
			_hide_new_relics = false
			_begin_turns(_show_treasure)


## The event of the room the players are in (both see the same one).
var _event_key := ""


## --- A fight (CardStage) ---


## --- A hack (CardHack): the card game over the world ---


## The card game for `hack` over whatever is on the screen (a CanvasLayer at `layer` under the root, the world held by whoever
## opened it): the CardGame, whose hack_done says how it went. It frees itself once that has been said.
static func open_hack(hack: CardHack, layer: int = 35) -> CardGame:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var holder := CanvasLayer.new()
	holder.layer = layer
	holder.process_mode = Node.PROCESS_MODE_ALWAYS
	holder.name = "CardHack"
	var game := CardGame.new()
	game.hacking = hack
	game.process_mode = Node.PROCESS_MODE_ALWAYS
	holder.add_child(game)
	tree.root.add_child(holder)
	game.hack_done.connect(_close_hack.bind(holder), CONNECT_ONE_SHOT)
	return game


static func _close_hack(_won: bool, _left: bool, holder: CanvasLayer):
	if is_instance_valid(holder):
		holder.queue_free()


## A hack as plain data, for the other machine of a network game (Net._card_begin), and back.
static func hack_data(hack: CardHack) -> Dictionary:
	return {"length": int(hack.length), "encounter": hack.encounter, "tier": int(hack.tier), "layer": hack.layer,
		"challenge": hack.challenge, "trace": hack.trace, "seed": hack.seed, "health_share": hack.health_share}


static func hack_from(data: Dictionary) -> CardHack:
	var hack := CardHack.new()
	hack.length = clampi(int(data.get("length", 0)), 0, CardHack.Length.size() - 1) as CardHack.Length
	hack.encounter = str(data.get("encounter", ""))
	hack.tier = clampi(int(data.get("tier", 0)), 0, int(CardEncounterDefinition.Tier.BOSS)) as CardEncounterDefinition.Tier
	hack.layer = clampi(int(data.get("layer", 1)), 1, CardRun.MOST_LAYERS)
	hack.challenge = clampi(int(data.get("challenge", 0)), 0, CardRun.CHALLENGE_MOST)
	hack.trace = clampi(int(data.get("trace", 0)), 0, CardRun.TRACE_MOST)
	hack.seed = int(data.get("seed", 1))
	hack.health_share = clampf(float(data.get("health_share", 1.0)), 0.1, 3.0)
	hack.players = CardBattle.MOST_PLAYERS
	return hack


## How many choose a gate here: two over a network, a hack's own count, else as chosen on the screen.
func _players_wanted() -> int:
	if networked():
		return CardBattle.MOST_PLAYERS
	if hacking != null:
		return clampi(hacking.players, 1, CardBattle.MOST_PLAYERS)
	return players_chosen


## A hack's run: its players at the hacker's strength, its length; one fight goes straight into it.
func _start_hack(characters: Array):
	var keys: Array = characters if not characters.is_empty() else [CardDatabase.FIRST_CHARACTER]
	start_run(hacking.seed, keys, hacking.layers(), hacking.floors(), false)
	run.layer = clampi(hacking.layer, 1, CardRun.MOST_LAYERS) if hacking.layers() == 1 else 1
	run.trace = hacking.trace
	for each in run.players:
		each.max_hp = maxi(int(round(int(each.max_hp) * hacking.health_share)), 1)
		each.hp = each.max_hp
	_refresh_bar()
	if hacking.one_fight():
		_start_battle(run.battle_of(hacking.encounter_key(run.rng), hacking.tier))
	else:
		_after_start()


func _start_battle(prepared: CardBattle = null):
	battle = prepared if prepared != null else run.new_battle()
	view = "battle"
	_clear_body()
	var room := run.room_here()
	var music := &"card_music_fight"
	if room == CardRun.Room.ELITE:
		music = &"card_music_elite"
	elif room == CardRun.Room.BOSS:
		music = &"card_music_boss"
	_music(music)
	stage = CardStage.new()
	_body.add_child(stage)
	stage.finished.connect(_battle_ended)
	# A hack of one fight is as hard as its tier says, whatever room there is not.
	if hacking != null and hacking.one_fight():
		room = [CardRun.Room.FIGHT, CardRun.Room.FIGHT, CardRun.Room.ELITE, CardRun.Room.BOSS][int(hacking.tier)]
	stage.begin(self, battle, room)
	_refresh_bar()


## The card at `index` of the hand pressed: chosen, played (pressed again, needing no enemy), or put back.
func _choose_card(index: int):
	if stage != null:
		stage.choose_card(index)


## Plays the card at `index` of the hand at enemy `who` (-1 for none). False if it could not be.
func play_card(index: int, who: int = -1) -> bool:
	return stage.play_card(index, who) if stage != null else false


## An enemy pressed: the card chosen is played at it.
func enemy_pressed(i: int):
	if stage != null:
		stage.enemy_pressed(i)


func end_turn():
	if stage != null:
		stage.end_turn()


## The player's health as the fight shows it changed: the bar follows.
func refresh_health():
	_refresh_bar()


func _battle_ended(_won: bool):
	# The gold the fight gives is counted as its coins land in the purse on the rewards (_coins_in), not as it is won.
	_gold_held = CardFeel.shown()
	# The fight let go first, so the bar counts the run's health from here (a fight won's mend with it).
	battle = null
	if hacking != null and hacking.one_fight():
		# A hack of one fight: won or lost, it is over.
		run.finish_battle()
		run.over = true
		run.won = run.won or run.fights_won > 0 and not run.traced
		_go(_show_end)
		return
	run.finish_battle()
	if run.over:
		_go(_show_end)
	else:
		_go(_begin_turns.bind(_show_rewards))


## --- After a fight ---


func _show_rewards():
	view = "rewards"
	_clear_body()
	if int(run.rewards.get("gold", 0)) <= 0 or not CardFeel.shown():
		_gold_held = false
	_refresh_bar()
	var column := _centred_column(860.0)
	_heading(column, "Victory")
	_whose(column)
	# A layer's boss beaten: a piece of a locked gate's code (twist 4), once, for the first to choose.
	if run.me == 0 and run.room_here() == CardRun.Room.BOSS and run.boss_fragment != "" and not run.fragments_found.is_empty():
		_fragment_line(column, run.fragments_found[-1])
	if run.long_rest_due and run.me == run.players.size() - 1:
		_text(column, "Then the long rest, and down to layer %d." % (run.layer + 1), MUTED)
	var got: Dictionary = run.rewards
	var gold_line := _text(column, "%d gold." % int(got.get("gold", 0)), GOLD)
	var relic_line: Label = null
	if str(got.get("relic", "")) != "":
		var relic := CardDatabase.relic(got.relic)
		relic_line = _text(column, "A relic: %s. %s" % [relic.name, relic.describe()], GOLD)
		_relic_hidden[str(got.relic)] = true
		_refresh_relics()
	var cards: Array = got.get("cards", [])
	var shown_cards: Array = []
	if not cards.is_empty():
		_text(column, "Choose a card to add to your deck.")
		var row := _card_choice_row(cards, _take_and_leave)
		column.add_child(row)
		shown_cards = row.find_children("*", "CardView", true, false)
	_button(column, "Skip" if not cards.is_empty() else "Continue", _leave_rewards)
	_focus_first(column)
	if CardFeel.shown():
		_reward_moments(gold_line, int(got.get("gold", 0)), relic_line, str(got.get("relic", "")), shown_cards)
	else:
		_relic_hidden.erase(str(got.get("relic", "")))
		_refresh_relics()


## The rewards coming in: the gold flying into the purse, an elite's relic into the bar, the cards turned over one by one.
func _reward_moments(gold_line: Label, gold: int, relic_line: Label, relic_key: String, cards: Array):
	for card in cards:
		card.set_face_down(true)
	await get_tree().process_frame
	if not is_inside_tree() or view != "rewards":
		return
	if gold > 0 and is_instance_valid(gold_line):
		_coins_in(gold_line.global_position + gold_line.size / 2.0, gold)
	if relic_key != "" and is_instance_valid(relic_line):
		_relic_arrives(relic_key, relic_line.global_position + relic_line.size / 2.0)
	var tween := create_tween()
	tween.tween_interval(CardFeel.time(REWARD_FIRST))
	for card in cards:
		tween.tween_callback(_turn_reward.bind(card))
		tween.tween_interval(CardFeel.time(REWARD_EVERY))


func _turn_reward(card: CardView):
	if not is_instance_valid(card):
		return
	card.turn_over(true, CardFeel.time(0.24))
	var definition := CardDatabase.card(card.key)
	var centre := card.get_global_transform() * card.pivot_offset
	if definition != null and definition.rarity == CardDefinition.Rarity.RARE:
		CardFeel.sound(&"card_reward_rare", -6.0)
		fx.ring(centre, GOLD, 30.0, 150.0, 0.6, 7.0)
		fx.burst(centre, &"spark", 22, 340.0)
	else:
		CardFeel.sound(&"card_reward_turned", -8.0)


func _leave_rewards():
	if _sending(&"skip"):
		return
	_done_here()


## Card `key` taken: it flies to the Deck button, the others fall away, and back to the map.
func _take_and_leave(key: String):
	if _sending(&"take", [key]):
		return
	if view != "rewards" and view != "event":
		return
	var flying: CardView = null
	var others: Array = []
	for card in _room().find_children("*", "CardView", true, false):
		if card.key == key and flying == null:
			flying = card
		else:
			others.append(card)
	run.take_card(key)
	if not CardFeel.shown() or flying == null:
		_done_here()
		return
	CardFeel.sound(&"card_taken", -6.0)
	# Taken before it was turned over: turned at once, so what was taken is seen.
	if flying.face_down:
		flying.set_face_down(false)
	var from := flying.get_global_transform() * flying.pivot_offset
	fx.fly(flying, from, _deck_button.global_position + _deck_button.size / 2.0, CardFeel.time(0.45), 90.0, 0.2)
	for other in others:
		var card := other as CardView
		var tween: Tween = card.create_tween().set_parallel()
		tween.tween_property(card, "position:y", card.position.y + 90.0, CardFeel.time(0.3)).set_ease(Tween.EASE_IN)
		tween.tween_property(card, "modulate:a", 0.0, CardFeel.time(0.3))
	var wait := create_tween()
	wait.tween_interval(CardFeel.time(0.5))
	wait.tween_callback(_here0(_done_here))


func _rest_and_leave():
	if _sending(&"patch"):
		return
	var before := run.hp
	run.rest()
	if not CardFeel.shown():
		_done_here()
		return
	CardFeel.sound(&"card_mend", -6.0)
	var fire := _room().find_child("Fire", true, false) as Control
	var at := fire.global_position + fire.size / 2.0 if fire != null else size / 2.0
	fx.ring(at, MEND, 30.0, 120.0, 0.6, 6.0)
	fx.number(at + Vector2(0, -70), "+%d" % (run.hp - before), MEND, 34, 50.0, 1.0)
	for button in _room().find_children("*", "Button", true, false):
		(button as Button).disabled = true
	var wait := create_tween()
	wait.tween_interval(CardFeel.time(0.9))
	wait.tween_callback(_here0(_done_here))


## Card `index` of the deck upgraded: shown in the middle, flashing as it changes, and back to the map.
func _upgrade_and_leave(index: int):
	if _sending(&"upgrade", [index]):
		return
	var card: Dictionary = run.deck[index] if index >= 0 and index < run.deck.size() else {}
	run.upgrade(index)
	if not CardFeel.shown() or card.is_empty():
		_done_here()
		return
	var picked: CardView = _pick_views.get(_view_key(index))
	var from := picked.get_global_transform() * picked.pivot_offset if picked != null and is_instance_valid(picked) else size / 2.0
	var shown := CardView.new()
	shown.show_card(card.key, false)
	fx.add_child(shown)
	shown.position = from - fx.global_position - shown.pivot_offset
	var middle := size / 2.0 - fx.global_position - shown.pivot_offset
	for child in _room().get_children():
		if child is CanvasItem:
			(child as CanvasItem).modulate.a = 0.25
	var tween := shown.create_tween()
	tween.tween_property(shown, "position", middle, CardFeel.time(0.25)).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(shown, "scale", Vector2.ONE * 1.5, CardFeel.time(0.25))
	tween.tween_interval(CardFeel.time(0.2))
	tween.tween_callback(_upgrade_takes.bind(shown, card.key))
	tween.tween_interval(CardFeel.time(0.8))
	tween.tween_callback(shown.queue_free)
	tween.tween_callback(_here0(_done_here))


func _upgrade_takes(shown: CardView, key: String):
	if not is_instance_valid(shown):
		return
	shown.flash(0.45, 1.0)
	shown.show_card(key, true)
	CardFeel.sound(&"card_upgraded", -6.0)
	fx.burst(shown.get_global_transform() * shown.pivot_offset, &"spark", 18, 300.0)


func _remove_and_leave(index: int):
	if _sending(&"remove", [index]):
		return
	_burn_picked(index)
	run.remove_card(index)
	if not CardFeel.shown():
		_done_here()
		return
	var wait := create_tween()
	wait.tween_interval(CardFeel.time(0.6))
	wait.tween_callback(_here0(_done_here))


## The card picked at `index` burns away where it is (taken out of the deck).
func _burn_picked(index: int):
	var picked: CardView = _pick_views.get(_view_key(index))
	if picked == null or not is_instance_valid(picked) or not CardFeel.shown():
		return
	CardFeel.sound(&"card_removed", -6.0)
	var at := picked.get_global_transform() * picked.pivot_offset
	var copy := CardView.new()
	copy.show_card(picked.key, picked.upgraded)
	fx.add_child(copy)
	copy.position = at - fx.global_position - copy.pivot_offset
	picked.modulate.a = 0.0
	fx.burst(at, &"ember", 20, 200.0, Vector2.ZERO, CardView.SIZE * 0.8)
	copy.burn(CardFeel.time(0.55), copy.queue_free)


func _study():
	_pick_card(run.upgradable(), "Choose a card to upgrade.", _upgrade_and_leave, false, Callable(), true)


## A row of cards to choose one from; `on_choice` is called with the chosen key (in the half it was made in).
func _card_choice_row(keys: Array, on_choice: Callable) -> Control:
	on_choice = _here1(on_choice)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 26 if _half < 0 else 12)
	row.custom_minimum_size = Vector2(0, CardView.SIZE.y + 20)
	for key in keys:
		var holder := Control.new()
		holder.custom_minimum_size = CardView.SIZE
		var shown := CardView.new()
		shown.show_card(key, false)
		shown.chosen.connect(func(_view): on_choice.call(key))
		shown.hovered.connect(_card_hovered)
		holder.add_child(shown)
		# A button under it for the keys and a pad.
		var pick := Button.new()
		pick.text = "Take"
		pick.position = Vector2(CardView.SIZE.x / 2.0 - 40.0, CardView.SIZE.y + 6.0)
		pick.size = Vector2(80, 30)
		pick.pressed.connect(func(): on_choice.call(key))
		pick.focus_entered.connect(show_keywords.bind(shown))
		holder.add_child(pick)
		holder.custom_minimum_size.y = CardView.SIZE.y + 40.0
		row.add_child(holder)
	return row


## --- A rest ---


func _show_rest():
	view = "rest"
	_clear_body()
	_refresh_bar()
	var column := _centred_column()
	_heading(column, "A Place to Rest")
	var fire_holder := CenterContainer.new()
	var fire := _Fire.new()
	fire.name = "Fire"
	fire.custom_minimum_size = Vector2(120, 140)
	fire_holder.add_child(fire)
	column.add_child(fire_holder)
	_whose(column)
	# A short rest (twist 13): mend, study a card, or cover his tracks; in co-op, mend the partner instead.
	_text(column, "A short rest: mend, study one of your cards to make it better, or cover your tracks." + (" Or mend your partner." if run.together() else ""))
	var options := run.rest_options()
	_button(column, "Patch (mend %d)" % run.rest_amount(), _rest_and_leave)
	_button(column, "Study (upgrade a card)", _study, options.has(CardRun.Rest.STUDY))
	_button(column, "Cover Tracks (trace -%d)" % CardRun.TRACE_COVER, _cover_and_leave, options.has(CardRun.Rest.COVER_TRACKS))
	if run.together():
		var partner: Dictionary = run.players[run.partner_of(run.me)]
		_button(column, "Mend %s (%d)" % [partner.name, run.mend_amount()], _mend_and_leave, options.has(CardRun.Rest.MEND))
	_focus_first(column)
	GameSounds.loop(&"card_rest_fire", -10.0)


## Cover Tracks: the trace down by CardRun.TRACE_COVER, the meter following, and on.
func _cover_and_leave():
	if _sending(&"cover"):
		return
	var before := run.trace
	run.rest_with(CardRun.Rest.COVER_TRACKS)
	for button in _room().find_children("*", "Button", true, false):
		(button as Button).disabled = true
	if not CardFeel.shown():
		_done_here()
		return
	CardFeel.sound(&"card_terminal_beep", -6.0)
	fx.number(_trace_label.global_position + Vector2(_trace_label.size.x / 2.0, _trace_label.size.y + 14.0), "-%d" % (before - run.trace),
		TRACE_INK, 22, 24.0, 1.0)
	var wait := create_tween()
	wait.tween_interval(CardFeel.time(0.8))
	wait.tween_callback(_here0(_done_here))


## Mend the partner (co-op): they mend CardRun.MEND_SHARE of their most, and on.
func _mend_and_leave():
	if _sending(&"mend"):
		return
	var amount := run.mend_amount()
	run.rest_with(CardRun.Rest.MEND)
	for button in _room().find_children("*", "Button", true, false):
		(button as Button).disabled = true
	if not CardFeel.shown():
		_done_here()
		return
	CardFeel.sound(&"card_mend", -6.0)
	var fire := _room().find_child("Fire", true, false) as Control
	var at := fire.global_position + fire.size / 2.0 if fire != null else size / 2.0
	fx.ring(at, MEND, 30.0, 120.0, 0.6, 6.0)
	fx.number(at + Vector2(0, -70), "%s +%d" % [run.players[run.partner_of(run.me)].name, amount], MEND, 30, 50.0, 1.0)
	var wait := create_tween()
	wait.tween_interval(CardFeel.time(0.9))
	wait.tween_callback(_here0(_done_here))


## --- The long rest, between layers (twist 13) ---


## A layer's boss beaten: everybody mends fully, then each reshapes their deck (a card out, forgotten; or one upgraded), and down
## to the next layer.
func _begin_long_rest():
	run.long_rest()
	_begin_turns(_show_long_rest, _go_deeper)


func _show_long_rest():
	view = "long_rest"
	_clear_body()
	_refresh_bar()
	var column := _centred_column()
	_heading(column, "The Long Rest")
	var fire_holder := CenterContainer.new()
	var fire := _Fire.new()
	fire.name = "Fire"
	fire.custom_minimum_size = Vector2(120, 140)
	fire_holder.add_child(fire)
	column.add_child(fire_holder)
	_whose(column)
	_text(column, "Everybody is mended fully. Reshape your deck before going deeper: take a card out (forgotten, until the last layer brings it back) or make one better.")
	_button(column, "Take a card out", _pick_card.bind(run.removable(), "Choose a card to take out.", _remove_and_leave, true, _show_long_rest),
		not run.deck.is_empty())
	_button(column, "Upgrade a card", _pick_card.bind(run.upgradable(), "Choose a card to upgrade.", _upgrade_and_leave, true, _show_long_rest, true),
		not run.upgradable().is_empty())
	_button(column, "Rest only", _leave_here)
	_focus_first(column)
	GameSounds.loop(&"card_rest_fire", -10.0)


## Down to the next layer: its map, and as the last begins what Lethe took coming back (twist 8).
func _go_deeper():
	run.next_layer()
	_go(_show_layer)


## Arriving on a layer: its name, how dark it is, and on the last what came back.
func _show_layer():
	view = "layer"
	_clear_body()
	_refresh_bar()
	var column := _centred_column()
	_heading(column, "Layer %d of %d" % [run.layer, run.layers], 36)
	var share := int(round(CardRun.DARKNESS[clampi(run.layer, 0, CardRun.DARKNESS.size() - 1)] * 100.0))
	_text(column, "Deeper in, its programs are stronger, and about %d in a hundred are encrypted: Scan one to see what it will do." % share)
	for p in run.players.size():
		var back: Array = run.players[p].lethe_back
		if back.is_empty():
			continue
		var names: Array = back.map(func(card): return CardDatabase.card(card.key).name_for(true) if CardDatabase.card(card.key) != null else str(card.key))
		_text(column, "%sWhat was forgotten comes back, changed: %s." % [("%s: " % run.players[p].name) if run.together() else "", ", ".join(names)],
			Color("c9b0f0"))
	if CardFeel.shown():
		CardFeel.sound(&"card_terminal_beep", -6.0)
	_button(column, "Go on", _show_map)
	_focus_first(column)


## A code fragment found (twist 4): whose gate's, how many of its pieces now, and whether it opened.
func _fragment_line(parent: Control, found: Dictionary):
	var definition := CardDatabase.character(str(found.get("character", "")))
	if definition == null:
		return
	var have := CardUnlocks.fragments(str(found.get("character", "")))
	var line := ("A code fragment of %s's deck. It is open: %s can be played now!" % [definition.name, definition.name]) if bool(found.get("opened", false)) \
		else "A code fragment of %s's deck (%d of %d)." % [definition.name, have, definition.fragments_needed]
	_text(parent, line, definition.colour().lightened(0.3))
	if CardFeel.shown():
		CardFeel.sound(&"card_fragment", -6.0)


## A rest's fire: CardLooks' rest_fire flickering, or a flame drawn in code.
class _Fire extends Control:
	var _age := 0.0

	func _process(delta: float):
		_age += delta
		queue_redraw()

	func _draw():
		var flicker := 1.0 + sin(_age * 11.0) * 0.04 + sin(_age * 17.3) * 0.03
		var glow := Color(1.0, 0.6, 0.25, 0.16 + 0.05 * sin(_age * 7.0))
		draw_circle(size / 2.0 + Vector2(0, 16), size.x * 0.55 * flicker, glow)
		var picture := CardLooks.picture(&"rest_fire")
		var area := Rect2(Vector2(size.x * (1.0 - flicker) / 2.0, size.y * (1.0 - flicker)), size * flicker)
		if picture != null:
			draw_texture_rect(picture, CardIcon.fit(picture.get_size(), area), false, Color(1, 1, 1, 0.92 + 0.08 * sin(_age * 9.0)))
		else:
			CardIcon.stand_in(self, &"rest_fire", area)


## --- The shop ---


func _show_shop():
	view = "shop"
	_clear_body()
	_refresh_bar()
	var stock := run.shop_here()
	var column := _centred_column(1100.0)
	_heading(column, "A Merchant's Table")
	_whose(column)
	_text(column, "You have %d gold." % run.gold, GOLD)
	# Its cards in a row, or three to a row on a half of the screen.
	var row := HFlowContainer.new()
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("h_separation", 22 if _half < 0 else 10)
	row.add_theme_constant_override("v_separation", 6)
	if _half >= 0:
		row.custom_minimum_size = Vector2(HALF_WIDTH, 0)
	column.add_child(row)
	_forget_views(_shop_views)
	for i in stock.cards.size():
		var item: Dictionary = stock.cards[i]
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(CardView.SIZE.x, CardView.SIZE.y + 60.0)
		row.add_child(holder)
		if item.sold:
			var sold := Label.new()
			sold.text = "Sold"
			sold.position = Vector2(50, 90)
			sold.add_theme_color_override("font_color", MUTED)
			holder.add_child(sold)
			continue
		var shown := CardView.new()
		shown.show_card(item.key, false)
		shown.set_price(item.price, run.gold >= item.price)
		var buy_it := _here0(_buy_card.bind(i))
		shown.chosen.connect(func(_view): buy_it.call())
		shown.hovered.connect(_card_hovered)
		holder.add_child(shown)
		_shop_views[_view_key(i)] = shown
		var buy := Button.new()
		buy.text = "Buy"
		buy.disabled = run.gold < item.price
		buy.position = Vector2(CardView.SIZE.x / 2.0 - 40.0, CardView.SIZE.y + 26.0)
		buy.size = Vector2(80, 30)
		buy.pressed.connect(buy_it)
		holder.add_child(buy)
	for i in stock.relics.size():
		var item: Dictionary = stock.relics[i]
		var relic := CardDatabase.relic(item.key)
		if relic == null:
			continue
		var button := _button(column, "Sold" if item.sold else "%s - %s (%d gold)" % [relic.name, relic.describe(), item.price], _buy_relic.bind(i),
			not item.sold and run.gold >= item.price)
		button.custom_minimum_size = Vector2(720 if _half < 0 else HALF_WIDTH - 20.0, 40)
		button.clip_text = _half >= 0
		button.tooltip_text = "%s: %s" % [relic.name, relic.describe()]
		button.name = "Relic%d" % i
	var removed: bool = stock.get("removed", false)
	_button(column, "Remove a card (%d gold)" % run.remove_price, _choose_removal,
		not removed and run.gold >= run.remove_price and not run.deck.is_empty())
	_button(column, "Leave", _leave_shop)
	_focus_first(column)


func _leave_shop():
	if _sending(&"leave_room"):
		return
	_done_here()


func _choose_removal():
	_pick_card(run.removable(), "Choose a card to remove.", _remove_in_shop, true, _show_shop)


func _remove_in_shop(index: int):
	if _sending(&"buy_removal", [index]):
		return
	var price := run.remove_price
	_burn_picked(index)
	if not run.buy_removal(index):
		return
	_coins_out(size / 2.0, price)
	if not CardFeel.shown():
		_show_shop()
		return
	var wait := create_tween()
	wait.tween_interval(CardFeel.time(0.6))
	wait.tween_callback(_here0(_show_shop))


func _buy_card(i: int):
	if _sending(&"buy_card", [i]):
		return
	var shown: CardView = _shop_views.get(_view_key(i))
	var stock: Array = run.shop_here().cards
	var price: int = stock[i].price if i >= 0 and i < stock.size() else 0
	if not run.buy_card(i):
		if shown != null and is_instance_valid(shown):
			shown.refuse()
			_bubble_at(shown, "Not enough gold.")
		return
	if CardFeel.shown() and shown != null and is_instance_valid(shown):
		var from := shown.get_global_transform() * shown.pivot_offset
		_coins_out(from, price)
		var copy := CardView.new()
		copy.show_card(shown.key, false)
		fx.add_child(copy)
		copy.position = from - fx.global_position - copy.pivot_offset
		CardFeel.sound(&"card_taken", -6.0)
		fx.fly(copy, from, _deck_button.global_position + _deck_button.size / 2.0, CardFeel.time(0.5), 100.0, 0.2)
	else:
		_refresh_bar()
	_show_shop()


func _buy_relic(i: int):
	if _sending(&"buy_relic", [i]):
		return
	var stock: Array = run.shop_here().relics
	if i < 0 or i >= stock.size():
		return
	var key: String = stock[i].key
	var price: int = stock[i].price
	var button := _room().find_child("Relic%d" % i, true, false) as Control
	var from := button.global_position + button.size / 2.0 if button != null else size / 2.0
	if CardFeel.shown():
		_relic_hidden[key] = true
	if not run.buy_relic(i):
		_relic_hidden.erase(key)
		return
	_coins_out(from, price)
	_relic_arrives(key, from)
	_show_shop()


## `text` for a moment over `near`: why it cannot be done.
func _bubble_at(near: Control, text: String):
	CardFeel.note(&"bubble")
	if not CardFeel.shown():
		return
	fx.number(near.get_global_transform() * Vector2(near.size.x / 2.0, -10.0), text, Color("ffb0a0"), 18, 20.0, 1.2)


## --- An event ---


func _show_event():
	view = "event"
	_clear_body()
	_refresh_bar()
	if _event_key == "":
		_event_key = run.event_here()
	var event: CardEventDefinition = CardDatabase.events().get(_event_key)
	var column := _centred_column()
	if event == null:
		_heading(column, "Nothing Here")
		_button(column, "Continue", _leave_here)
		_focus_first(column)
		return
	_heading(column, event.title)
	_whose(column)
	var words := _text(column, event.text)
	var buttons: Array = []
	# Its own options, and listening for a word of the truth for the Message (twist 10) where it offers one.
	for option in run.event_options(_event_key):
		var button := _button(column, option.label, _event_chosen.bind(option), run.can_choose(option))
		button.custom_minimum_size = Vector2(560, 40)
		if option.action == CardEventOption.Action.MESSAGE:
			button.add_theme_color_override("font_color", CardView.MESSAGE_EDGE)
		buttons.append(button)
	_type_out(words, buttons, column)


## `label`'s words typing out, a tick every other letter; `then` (buttons) shown once it is done, dealt in, the first focused.
func _type_out(label: Label, then: Array, column: Control):
	# Two halves at once never type: both are there to be read.
	if not CardFeel.shown() or label.text.length() == 0 or _half >= 0:
		_focus_first(column)
		return
	for button in then:
		button.visible = false
	_typed = label
	_typed_then = then
	_typed_column = column
	# Laid out whole first, so the words appear where they will stay rather than re-centring as they come.
	label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	label.visible_characters = 0
	_typing = create_tween()
	_typing.tween_method(_type_step, 0.0, float(label.text.length()), CardFeel.time(label.text.length() / LETTERS_A_SECOND))
	_typing.tween_callback(_typed_out)


func _type_step(letters: float):
	if _typed == null or not is_instance_valid(_typed):
		return
	var now := int(letters)
	if now > _typed.visible_characters:
		var letter := _typed.text.substr(now - 1, 1)
		if now % 2 == 0 and letter.to_lower() != letter.to_upper():
			CardFeel.sound(&"card_text_tick", -20.0, randf_range(0.95, 1.05))
	_typed.visible_characters = now


func _typed_out():
	if _typed != null and is_instance_valid(_typed):
		_typed.visible_characters = -1
	for button in _typed_then:
		if is_instance_valid(button):
			button.visible = true
	var column := _typed_column
	_typed = null
	_typed_then = []
	_typed_column = null
	_typing = null
	if column != null and is_instance_valid(column):
		_focus_first(column)


func _event_chosen(option: CardEventOption):
	if _sending(&"event", [run.event_options(_event_key).find(option)]):
		return
	var gold_before := run.gold
	var relics_before := run.relics.size()
	_trace_before = run.trace
	_fragments_before = run.fragments_found.size()
	if option.action == CardEventOption.Action.RANDOM_RELIC and CardFeel.shown():
		# The relic it gives is hidden on the bar until it has flown there.
		var will := run.relics.duplicate()
		var action := run.choose(option)
		for key in run.relics:
			if not will.has(key):
				_relic_hidden[key] = true
		_after_event(option, action, gold_before, relics_before)
		return
	var action := run.choose(option)
	_after_event(option, action, gold_before, relics_before)


func _after_event(option: CardEventOption, action: CardEventOption.Action, gold_before: int, relics_before: int):
	_clear_body()
	_refresh_bar()
	var column := _centred_column()
	var said: Label = null
	if option.outcome != "":
		said = _text(column, option.outcome, INK)
	match action:
		CardEventOption.Action.CARD_REWARD:
			_text(column, "Choose a card to add to your deck.")
			column.add_child(_card_choice_row(run.players[run.me].event_cards, _take_and_leave))
			_button(column, "Skip", _leave_here)
		CardEventOption.Action.REMOVE_CARD:
			_pick_card(run.removable(), "Choose a card to remove.", _remove_and_leave, false)
			return
		CardEventOption.Action.UPGRADE_CARD:
			_pick_card(run.upgradable(), "Choose a card to upgrade.", _upgrade_and_leave, false, Callable(), true)
			return
		CardEventOption.Action.TRANSFORM_CARD:
			_pick_card(run.removable(), "Choose a card for the room to rewrite.", _transform_and_leave, false)
			return
		CardEventOption.Action.MESSAGE:
			_show_message(option.outcome)
			return
		_:
			# What else it did: the half-read code read, the trace, a fragment, a card put in the deck.
			if option.action == CardEventOption.Action.READ_ALL:
				_text(column, "Every half-read card in your deck can be read now.", Color("9cc8f0"))
			if run.trace != _trace_before:
				_text(column, "Trace %s%d (now %d)." % ["+" if run.trace > _trace_before else "-", absi(run.trace - _trace_before), run.trace],
					_trace_colour(run.trace))
			for found in run.fragments_found.slice(_fragments_before):
				_fragment_line(column, found)
			if option.adds_card != "" and CardDatabase.card(option.adds_card) != null:
				_text(column, "%s goes into your deck." % CardDatabase.card(option.adds_card).name, Color("e07a6a"))
			if option.action == CardEventOption.Action.RANDOM_RELIC and run.relics.size() > relics_before:
				var relic := CardDatabase.relic(run.relics[-1])
				var line := _text(column, "A relic: %s. %s" % [relic.name, relic.describe()], GOLD)
				if CardFeel.shown():
					_relic_arrives.call_deferred(run.relics[-1], size / 2.0)
				line.name = "RelicLine"
			_button(column, "Continue", _leave_here)
	if run.gold > gold_before and said != null:
		_coins_in.call_deferred(size / 2.0, run.gold - gold_before)
	if said != null:
		var buttons: Array = column.find_children("*", "Button", true, false)
		_type_out(said, buttons, column)
	else:
		_focus_first(column)


## The trace and the fragments as an event's choice was made, to say what it changed.
var _trace_before := 0
var _fragments_before := 0


## Card `index` rewritten into another of its rarity (the Shifting Room): it flashes as it changes, and on.
func _transform_and_leave(index: int):
	if _sending(&"transform", [index]):
		return
	var was: Dictionary = run.deck[index] if index >= 0 and index < run.deck.size() else {}
	var became := run.transform_card(index)
	if not CardFeel.shown() or was.is_empty() or became == "":
		_done_here()
		return
	var picked: CardView = _pick_views.get(_view_key(index))
	if picked != null and is_instance_valid(picked):
		picked.flash(0.6, 1.0)
		picked.show_card(became, bool(was.upgraded))
		fx.burst(picked.get_global_transform() * picked.pivot_offset, &"spark", 18, 300.0)
	CardFeel.sound(&"card_upgraded", -6.0)
	var wait := create_tween()
	wait.tween_interval(CardFeel.time(0.9))
	wait.tween_callback(_here0(_done_here))


## --- The Message (twist 10): how it grows is the player's to choose ---


## A word of the truth heard (`said`: what the event says of it): the Message as it stands, and the ways it can grow now, at random
## (CardRun.message_offers): a new word, a word deepened, or it spoken lighter. Or it is let be.
func _show_message(said: String = ""):
	view = "message"
	_clear_body()
	_refresh_bar()
	var column := _centred_column(900.0)
	_heading(column, "The Message")
	_whose(column)
	if said != "":
		_text(column, said, INK)
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(0, CardView.SIZE.y + 8.0)
	var card := CardView.new()
	card.name = "Message"
	var entry := _message_entry()
	card.show_card(CardDefinition.MESSAGE, false, null, -1, entry)
	card.hovered.connect(_card_hovered)
	holder.add_child(card)
	column.add_child(holder)
	var offers: Array = run.players[run.me].message_offers
	_text(column, "Choose how it grows." if not offers.is_empty() else "There is nothing more it can take now.")
	for i in offers.size():
		var button := _button(column, _offer_words(offers[i]), _grow_message.bind(i))
		button.custom_minimum_size = Vector2(720, 44)
		button.name = "Offer%d" % i
		button.add_theme_color_override("font_color", CardView.MESSAGE_EDGE)
	_button(column, "Let it be", _grow_message.bind(-1))
	_focus_first(column)


## The player now's Message as their deck has it (its entry), or {}.
func _message_entry() -> Dictionary:
	for card in run.deck:
		if str(card.key) == CardDefinition.MESSAGE:
			return card
	return {}


## An offer for the Message, in words.
func _offer_words(offer: Dictionary) -> String:
	var message := CardDatabase.card(CardDefinition.MESSAGE)
	match str(offer.get("kind", "")):
		"word":
			var word := CardDatabase.message_word(str(offer.word))
			if word == null or word.effect == null or message == null:
				return "A word."
			return "A new word: \"%s\" (%s)" % [word.line, message.effect_words(word.effect, word.effect.amount)]
		"deepen":
			var word := CardDatabase.message_word(str(offer.word))
			for entry in run.message_of(run.me).get("words", []):
				if str(entry.key) == str(offer.word) and word != null and message != null:
					return "Deepen \"%s\": %s becomes %s" % [word.line, message.effect_words(word.effect, int(entry.amount)),
						message.effect_words(word.effect, int(entry.amount) + word.step)]
			return "Deepen a word."
		"lighten":
			return "Spoken lighter: it costs %d" % maxi(int(run.message_of(run.me).get("cost", 1)) - 1, 0)
	return "?"


## Offer `index` taken (-1: let it be): the Message changes in front of them, and on.
func _grow_message(index: int):
	if _sending(&"grow", [index]):
		return
	if not run.grow_message(index):
		return
	for button in _room().find_children("*", "Button", true, false):
		(button as Button).disabled = true
	var card := _room().find_child("Message", true, false) as CardView
	if index < 0 or not CardFeel.shown() or card == null:
		_done_here()
		return
	CardFeel.sound(&"card_message_grows", -6.0)
	card.flash(0.5, 1.0)
	card.show_card(CardDefinition.MESSAGE, false, null, -1, _message_entry())
	fx.burst(card.get_global_transform() * card.pivot_offset, &"spark", 16, 260.0)
	var wait := create_tween()
	wait.tween_interval(CardFeel.time(1.0))
	wait.tween_callback(_here0(_done_here))


## --- Treasure ---


func _show_treasure():
	view = "treasure"
	_clear_body()
	# The chest is the rules' (CardRun.open_chest: the same on both machines of a network game); what it gives stays off the bar
	# until it has flown there.
	_hide_new_relics = CardFeel.shown()
	var key := run.open_chest()
	_hide_new_relics = false
	if key != "" and CardFeel.shown():
		_relic_hidden[key] = true
	_refresh_bar()
	var column := _centred_column()
	_heading(column, "A Chest")
	_whose(column)
	var chest_holder := CenterContainer.new()
	var chest := CardIcon.new()
	chest.name = "Chest"
	chest.custom_minimum_size = Vector2(180, 140)
	chest.pivot_offset = Vector2(90, 70)
	chest.show_icon(&"chest_closed")
	chest_holder.add_child(chest)
	column.add_child(chest_holder)
	var lines: Array = []
	if key == "":
		lines.append(_text(column, "Empty."))
	else:
		var relic := CardDatabase.relic(key)
		lines.append(_text(column, "A relic: %s." % relic.name, GOLD))
		lines.append(_text(column, relic.describe()))
	var go_on := _button(column, "Continue", _leave_chest)
	if not CardFeel.shown():
		chest.show_icon(&"chest_open")
		_focus_first(column)
		return
	for line in lines:
		line.modulate.a = 0.0
	go_on.visible = false
	var tween := create_tween()
	tween.tween_interval(CardFeel.time(0.35))
	tween.tween_callback(_chest_opens.bind(chest, key, lines, go_on, column))


func _chest_opens(chest: CardIcon, key: String, lines: Array, go_on: Button, column: Control):
	if not is_instance_valid(chest):
		return
	chest.show_icon(&"chest_open")
	CardFeel.sound(&"card_chest_opened", -6.0)
	var top := chest.global_position + Vector2(chest.size.x / 2.0, chest.size.y * 0.35)
	fx.rays(top, Color("ffe08a"), 1.6)
	var pop := chest.create_tween()
	pop.tween_property(chest, "scale", Vector2(1.08, 0.94), 0.06)
	pop.tween_property(chest, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if key != "":
		_relic_arrives(key, top)
	for line in lines:
		if is_instance_valid(line):
			line.create_tween().tween_property(line, "modulate:a", 1.0, 0.3)
	if is_instance_valid(go_on):
		go_on.visible = true
	_focus_first(column)


func _leave_chest():
	if _sending(&"leave_room"):
		return
	_done_here()


## --- Choosing a card of the deck ---


## Shows the deck's cards at `indices` to choose one; `on_pick` gets its index. With `cancellable`, a button goes back by
## `on_cancel` (the map, unless said). `upgrading`: pointing at a card shows it upgraded.
func _pick_card(indices: Array, title: String, on_pick: Callable, cancellable: bool = true, on_cancel: Callable = Callable(),
		upgrading: bool = false):
	view = "pick"
	# What is picked, and going back, in the half it was made in.
	on_pick = _here1(on_pick)
	var back_to: Callable = _here0(on_cancel if on_cancel.is_valid() else _leave_here)
	_clear_body()
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 10)
	_room().add_child(column)
	UiFeel.arrive(column)
	_heading(column, title, 24)
	_whose(column)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 7 if _half < 0 else 3
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	var centre := CenterContainer.new()
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centre.add_child(grid)
	scroll.add_child(centre)
	_forget_views(_pick_views)
	for index in indices:
		var card: Dictionary = run.deck[index]
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(CardView.SIZE.x, CardView.SIZE.y + 40.0)
		var shown := CardView.new()
		shown.index = index
		shown.show_card(card.key, card.upgraded, null, -1, card)
		shown.chosen.connect(func(_view): on_pick.call(index))
		shown.hovered.connect(_card_hovered)
		if upgrading:
			shown.hovered.connect(_preview_upgrade.bind(card.key))
		holder.add_child(shown)
		_pick_views[_view_key(index)] = shown
		var pick := Button.new()
		pick.text = "Choose"
		pick.position = Vector2(CardView.SIZE.x / 2.0 - 40.0, CardView.SIZE.y + 6.0)
		pick.size = Vector2(80, 30)
		pick.pressed.connect(func(): on_pick.call(index))
		if upgrading:
			pick.focus_entered.connect(_preview_upgrade.bind(shown, true, card.key))
			pick.focus_exited.connect(_preview_upgrade.bind(shown, false, card.key))
		holder.add_child(pick)
		grid.add_child(holder)
	if indices.is_empty():
		_text(column, "There is nothing to choose.")
	if cancellable or indices.is_empty():
		var back := Button.new()
		back.text = "Back" if cancellable else "Continue"
		back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		back.custom_minimum_size = Vector2(200, 40)
		back.pressed.connect(back_to)
		column.add_child(back)
	_focus_first(column)


## Pointing at a card to study shows it as it would be upgraded.
func _preview_upgrade(card: CardView, on: bool, key: String):
	if is_instance_valid(card):
		card.show_card(key, on)


## --- Cards to look at: the deck, a fight's piles ---


func _show_deck():
	if run.together():
		# Both decks (co-op), one under the other.
		var sections: Array = []
		for each in run.players:
			var theirs: Array = each.deck.duplicate()
			theirs.sort_custom(func(a, b): return str(a.key) < str(b.key))
			sections.append(["%s's Deck (%d)" % [each.name, theirs.size()], theirs])
		show_cards(sections[0][0], sections[0][1], sections.slice(1))
		return
	var sorted := run.deck.duplicate()
	sorted.sort_custom(func(a, b): return str(a.key) < str(b.key))
	show_cards("Your Deck (%d)" % run.deck.size(), sorted)


## `cards` ({key, upgraded}) to look at over everything, under `title` (and `more`: [title, cards] under it); pressing the deck again
## or Close puts them away.
func show_cards(title: String, cards: Array, more: Array = []):
	if _overlay != null:
		_close_deck()
		return
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	move_child(_overlay, fx.get_index())
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(dim)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_top = 20
	column.offset_bottom = -20
	column.add_theme_constant_override("separation", 10)
	_overlay.add_child(column)
	UiFeel.arrive(column)
	_heading(column, title, 24)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var lots := VBoxContainer.new()
	lots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lots.add_theme_constant_override("separation", 14)
	scroll.add_child(lots)
	for lot in [[title, cards]] + more:
		if lot != [title, cards]:
			_heading(lots, str(lot[0]), 22)
		var centre := CenterContainer.new()
		centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lots.add_child(centre)
		var grid := GridContainer.new()
		grid.columns = 7
		grid.add_theme_constant_override("h_separation", 14)
		grid.add_theme_constant_override("v_separation", 14)
		centre.add_child(grid)
		for card in lot[1]:
			var holder := Control.new()
			holder.custom_minimum_size = CardView.SIZE
			var shown := CardView.new()
			shown.show_card(card.key, card.get("upgraded", false), null, -1, card)
			shown.hovered.connect(_card_hovered)
			holder.add_child(shown)
			grid.add_child(holder)
		if lot[1].is_empty():
			_text(lots, "Nothing.")
	var close := Button.new()
	close.text = "Close"
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.custom_minimum_size = Vector2(200, 40)
	close.pressed.connect(_close_deck)
	column.add_child(close)
	close.grab_focus.call_deferred()


func _close_deck():
	hide_keywords()
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null


## --- The end of a run ---


func _show_end():
	view = "end"
	_clear_body()
	_gold_held = false
	_refresh_bar()
	var column := _centred_column()
	var heading := "The Run Is Won" if run.won else ("Traced" if run.traced else "Defeated")
	if hacking != null:
		heading = "Hacked" if run.won else ("Traced: the Hack Fails" if run.traced else "The Hack Fails")
	_heading(column, heading, 36)
	if run.traced:
		_text(column, "The system noticed you: the trace reached %d." % CardRun.TRACE_MOST, Color("ff8a7a"))
	var where := "Floor %d of %d." % [maxi(run.floor_here() + 1, 0), run.floors + 1]
	if run.layers > 1:
		where = "Layer %d of %d, floor %d of %d." % [run.layer, run.layers, maxi(run.floor_here() + 1, 0), run.floors + 1]
	_text(column, "%s Fights won: %d. Cards in the deck: %d. Trace: %d." % [where, run.fights_won, run.deck.size(), run.trace])
	for found in run.fragments_found:
		_fragment_line(column, found)
	if hacking != null:
		_button(column, "Back", leave_game)
	else:
		_button(column, "A New Run", _show_characters)
		_button(column, "Leave", leave_game)
	_focus_first(column)


func _unhandled_input(event: InputEvent):
	# An event's words typing out: a press shows them all at once.
	if _typing != null and _typing.is_valid() and (event.is_action_pressed(&"ui_accept")
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)):
		_typing.kill()
		_typed_out()
		get_viewport().set_input_as_handled()
