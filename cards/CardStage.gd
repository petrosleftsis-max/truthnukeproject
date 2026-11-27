extends Control
class_name CardStage
## One fight of the card game on the screen (docs/card_game.md "How it feels"; the designer, 2026-11-26: all of
## docs/proposals_2026-11-26_card_juice.md but section 11): the player and the enemies (CardFighter), the hand (CardHand), the piles
## (CardPile), the energy (CardOrb), End Turn, and everything a fight plays out over them.
##
## The rules (CardBattle) happen at once; the stage hears each `beat` of them and plays it back in order, one at a time with short
## gaps, so every card drawn, every blow, every enemy's move is seen. On the player's own turn they never wait on it: the next card
## can be chosen while the last plays out, and the beats play faster the more are waiting. During the enemies' turn the hand waits
## for "Your Turn" (a key pressed in its last EARLY_SECONDS still counts). Once every beat has played, whatever they left out is put
## right from the rules (`_settle`), so the screen always ends up showing the fight as it is.
##
## Headless (a suite) nothing moves and every beat plays at once, as the rules do. Every timing here is PROPOSAL, and every one is
## halved at the Fast pace (CardFeel.time).

## The fight's last beat has played out (the victory or the defeat with it): the game moves on.
signal finished(won: bool)

## Gaps after each kind of beat, in seconds (before the pace): a card drawn, a hit, a hit of a flurry (falling to the least by the
## third), one of a sweep across every enemy, a status put on, one wearing off, Block gained, an enemy's move done.
const DRAW_GAP := 0.075
const HIT_GAP := 0.2
const FLURRY_GAP := 0.16
const FLURRY_GAP_LEAST := 0.08
const SWEEP_GAP := 0.07
const STATUS_GAP := 0.16
const WEAR_GAP := 0.06
const BLOCK_GAP := 0.14
const MOVE_DONE_GAP := 0.32
## How long a card going off holds in the middle before its effects.
const PLAYED_HOLD := 0.2
## The fewest beats waiting before they hurry, and the least share of a gap they hurry down to.
const HURRY_FROM := 3
const HURRY_LEAST := 0.35
## A key pressed this long before the hand comes back still counts (the tactics fights' CombatUI.EARLY_SECONDS).
const EARLY_SECONDS := 0.2
## How hard a blow knocks whoever it lands on: pixels, and more for a bigger share of their health.
const KNOCK := 9.0
const KNOCK_MORE := 18.0
## A last blow's slow motion: its length and how slow (the tactics fights' Combat.SLOW_MOTION_SECONDS and _SHARE).
const SLOW_SECONDS := 0.3
const SLOW_SHARE := 0.4

const INK := Color("dce8f5")
const INK_DIM := Color("c2ceda")
const MUTED := Color("8296a9")
const ACCENT := Color("4a86c8")
const GOLD := Color("e8c872")
const DAMAGE_INK := Color("ffffff")
const PLAYER_HURT_INK := Color("ff8a7a")
const BLOCK_INK := Color("7fb4ea")
const MEND_INK := Color("8fd6a0")
const POISON_INK := Color("8fd66a")
const HURT := Color("c0453a")
const POISONED := Color("4aa040")
const YOUR_TURN := Color("9cc8f0")
const ENEMY_TURN := Color("f0a070")

## Where things stand on the stage (its own coordinates; 1280 by about 680 under the run's bar).
const PLAYER_AT := Vector2(40, 12)
const ENEMIES_AT := Rect2(300, 12, 940, 352)
const HAND_AT := Rect2(150, 380, 980, 300)
const ORB_AT := Vector2(46, 438)
const DRAW_AT := Vector2(30, 560)
const DISCARD_AT := Vector2(1180, 560)
const EXHAUST_AT := Vector2(1096, 560)
const END_AT := Rect2(1136, 444, 132, 48)
## Where a card goes off, and where one being dragged at an enemy is held.
const PLAY_SPOT := Vector2(640, 250)
const HOLD_SPOT := Vector2(640, 470)

var game: CardGame = null
var battle: CardBattle = null
var room: CardRun.Room = CardRun.Room.FIGHT
var fx: CardFx = null

var player_view: CardFighter
## Both players' figures (co-op: side by side, at PAIR_SCALE); player_view is the first's.
var player_views: Array = []
## Whose hand, piles and energy are shown and played: the rules' active player (swap_hands).
var shown := 0
## Co-op: the other player's hand (Tab).
var swap_button: Button
## The beats about one player's hand and piles ("player" in them): only the shown one's are played on the hand.
const OWN_BEATS := [&"shuffled", &"drawn", &"discarded", &"faded", &"played", &"card_gone", &"energy", &"given", &"stolen"]
const PAIR_SCALE := 0.62
var enemy_views: Array = []
## The row the enemies stand in (one called in mid-fight joins it).
var _enemy_row: HBoxContainer
## The Tethers held (twist 7): their small cards and threads.
var tether_layer: CardTethers
var aim: CardAim
var banner: TurnBanner
var vignette: HurtVignette

## --- Seats: each hand on the screen with its own energy, piles and End Turn (or Ready) ---
##
## One hand at a time (alone, or two players with Swap): one seat, showing `shown`'s. Both hands at once (two players on one screen,
## `both_hands`; the designer's "try them all", 2026-11-27): a seat each, side by side, each player's device playing their own (CardGame
## .player_of_event). The names below (hand, orb, the piles, end_button, selected_id, target...) are the seat in use now's (`_at`),
## so everything that drew one hand draws whichever is in use; what plays on a seat sets it first (_use).

## Every seat on the screen; the one in use now.
var seats: Array = []
var _at := 0
## Both players' hands at once, side by side (else one at a time, with Swap).
var both_hands := false
## The seat that last chose a card: whose aim the arrow and the enemies' outlines show.
var _last_seat := 0

var hand: CardHand:
	get:
		return seats[_at].hand if _at < seats.size() else null
	set(value):
		seats[_at].hand = value
var draw_pile: CardPile:
	get:
		return seats[_at].draw_pile if _at < seats.size() else null
	set(value):
		seats[_at].draw_pile = value
var discard_pile: CardPile:
	get:
		return seats[_at].discard_pile if _at < seats.size() else null
	set(value):
		seats[_at].discard_pile = value
var exhaust_pile: CardPile:
	get:
		return seats[_at].exhaust_pile if _at < seats.size() else null
	set(value):
		seats[_at].exhaust_pile = value
var orb: CardOrb:
	get:
		return seats[_at].orb if _at < seats.size() else null
	set(value):
		seats[_at].orb = value
var end_button: Button:
	get:
		return seats[_at].end_button if _at < seats.size() else null
	set(value):
		seats[_at].end_button = value
## The card chosen (its id), and the enemy aimed at.
var selected_id: int:
	get:
		return seats[_at].selected_id if _at < seats.size() else -1
	set(value):
		if _at < seats.size():
			seats[_at].selected_id = value
var target: int:
	get:
		return seats[_at].target if _at < seats.size() else -1
	set(value):
		if _at < seats.size():
			seats[_at].target = value
## Whether the keys or a pad are what is being used (the keys' card rises).
var keys_in_use: bool:
	get:
		return seats[_at].keys_in_use if _at < seats.size() else false
	set(value):
		if _at < seats.size():
			seats[_at].keys_in_use = value
var focus_id: int:
	get:
		return seats[_at].focus_id if _at < seats.size() else -1
	set(value):
		if _at < seats.size():
			seats[_at].focus_id = value

var _world: Control
var _end_glow: Panel:
	get:
		return seats[_at].end_glow if _at < seats.size() else null
	set(value):
		seats[_at].end_glow = value
var _end_glow_tween: Tween:
	get:
		return seats[_at].end_glow_tween if _at < seats.size() else null
	set(value):
		seats[_at].end_glow_tween = value
var _bubble: PanelContainer
var _bubble_label: Label
var _bubble_tween: Tween = null
var _log_button: Button
var _log_panel: PanelContainer
var _log_label: Label
var _log: Array[String] = []
var _hint: Label
var _grey: ColorRect = null
var _queue: Array = []
var _playing := false
var _intro_done := false
var _locked := false
var _over := false
var _early := {}
var _drawn_run := 0
var _acting := -1
var _relic_from := ""
var _played_view: CardView:
	get:
		return seats[_at].played_view if _at < seats.size() else null
	set(value):
		if _at < seats.size():
			seats[_at].played_view = value
var _played_id: int:
	get:
		return seats[_at].played_id if _at < seats.size() else -1
	set(value):
		if _at < seats.size():
			seats[_at].played_id = value
var _dragging: int:
	get:
		return seats[_at].dragging if _at < seats.size() else -1
	set(value):
		if _at < seats.size():
			seats[_at].dragging = value
var _shake := 0.0
var _shake_rng := RandomNumberGenerator.new()
var _heart := 0.0

static var _stops := 0
static var _slowed := 0


func _init():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_shake_rng.seed = 2717


## Puts fight `the_battle` on the stage for `owner_game` (whose effects layer it draws on), a fight of room kind `kind`, and starts it.
func begin(owner_game: CardGame, the_battle: CardBattle, kind: CardRun.Room):
	game = owner_game
	battle = the_battle
	room = kind
	fx = game.fx
	_build()
	battle.beat.connect(_on_beat)
	battle.said.connect(_say)
	_intro()
	battle.start()


func _exit_tree():
	# A blow's stop or a last blow's slowing never outlives the fight.
	_stops = 0
	_slowed = 0
	Engine.time_scale = 1.0
	Rumble.stop()


static func moves() -> bool:
	return CardFeel.shown()


## --- Building it ---


func _build():
	var background := CardLooks.picture(&"fight_background")
	if background != null:
		var back := TextureRect.new()
		back.texture = background
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		back.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(back)
	_world = Control.new()
	_world.mouse_filter = Control.MOUSE_FILTER_PASS
	_world.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_world)
	player_view = CardFighter.new().setup_player(battle.players[0], 0)
	player_view.position = PLAYER_AT
	player_view.health_shown.connect(_player_health)
	_world.add_child(player_view)
	player_views = [player_view]
	shown = battle.active
	if battle.together():
		player_view.scale = Vector2.ONE * PAIR_SCALE
		var second := CardFighter.new().setup_player(battle.players[1], 1)
		second.scale = Vector2.ONE * PAIR_SCALE
		second.position = PLAYER_AT + Vector2(CardFighter.SIZE.x * PAIR_SCALE + 6.0, 0.0)
		second.health_shown.connect(_player_health)
		_world.add_child(second)
		player_views.append(second)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.position = ENEMIES_AT.position
	row.size = ENEMIES_AT.size
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	_world.add_child(row)
	_enemy_row = row
	enemy_views.clear()
	for i in battle.enemies.size():
		var view := CardFighter.new().setup_enemy(i, battle.enemies[i])
		view.pressed.connect(_fighter_pressed)
		row.add_child(view)
		enemy_views.append(view)
	# The Tethers on the table (twist 7), over the figures and under the hand.
	tether_layer = CardTethers.new().setup(self)
	tether_layer.let_go_pressed.connect(_let_go_pressed)
	_world.add_child(tether_layer)
	_hint = Label.new()
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.position = Vector2(ENEMIES_AT.position.x, ENEMIES_AT.end.y + 2)
	_hint.size = Vector2(ENEMIES_AT.size.x, 20)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 13)
	_hint.add_theme_color_override("font_color", ACCENT.lightened(0.3))
	_world.add_child(_hint)
	# A seat each, side by side (both hands at once), or one showing whoever's hand is shown.
	both_hands = battle.together() and game != null and game.hands_together()
	seats.clear()
	for s in (2 if both_hands else 1):
		_build_seat(s)
	_use(0)
	# Over a network, this machine's player's seat is the one in use.
	if both_hands and game.networked() and not game.local_players.is_empty():
		_last_seat = _seat_of(int(game.local_players[0]))
	swap_button = Button.new()
	swap_button.position = END_AT.position + Vector2(0, -38)
	swap_button.custom_minimum_size = Vector2(END_AT.size.x, 32)
	swap_button.size = Vector2(END_AT.size.x, 32)
	swap_button.focus_mode = Control.FOCUS_NONE
	swap_button.clip_text = true
	swap_button.pressed.connect(swap_hands)
	swap_button.visible = battle.together() and not both_hands
	_world.add_child(swap_button)
	var figures_tall := CardFighter.SIZE.y * player_view.scale.y
	_log_button = Button.new()
	_log_button.text = "Log"
	_log_button.position = Vector2(PLAYER_AT.x, PLAYER_AT.y + figures_tall + 6)
	_log_button.custom_minimum_size = Vector2(56, 24)
	_log_button.focus_mode = Control.FOCUS_NONE
	_log_button.toggle_mode = true
	_log_button.tooltip_text = "What happened, line by line."
	_log_button.toggled.connect(func(on: bool): _log_panel.visible = on)
	_world.add_child(_log_button)
	# The hands over everything of the seats'.
	for s in seats.size():
		_world.add_child(seats[s].hand)
	_log_panel = PanelContainer.new()
	_log_panel.position = Vector2(PLAYER_AT.x, PLAYER_AT.y + figures_tall + 34)
	_log_panel.custom_minimum_size = Vector2(300, 150)
	_log_panel.visible = false
	_log_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log_label = Label.new()
	_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_label.custom_minimum_size = Vector2(290, 140)
	_log_label.add_theme_font_size_override("font_size", 12)
	_log_label.add_theme_color_override("font_color", INK_DIM)
	_log_panel.add_child(_log_label)
	_world.add_child(_log_panel)
	_bubble = PanelContainer.new()
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.visible = false
	_bubble_label = Label.new()
	_bubble_label.add_theme_color_override("font_color", INK)
	_bubble_label.add_theme_font_size_override("font_size", 16)
	_bubble.add_child(_bubble_label)
	_bubble.set_meta(UiFeel.NO_FEEL, true)
	add_child(_bubble)
	aim = CardAim.new()
	add_child(aim)
	banner = TurnBanner.new()
	add_child(banner)
	vignette = HurtVignette.new()
	add_child(vignette)
	for s in seats.size():
		_use(s)
		orb.set_energy(battle.energy, battle.max_energy, false)
		draw_pile.set_count(battle.draw_pile.size(), false)
		discard_pile.set_count(battle.discard_pile.size(), false)
		exhaust_pile.set_count(battle.exhaust_pile.size(), false)
	_use(0)
	_refresh_pair()


## Where each seat's parts stand with both hands at once: its hand, energy, End Turn (Ready), and piles; one seat alone uses the
## stage's own constants (HAND_AT, ORB_AT...).
const SEAT_PLACES := [
	{"hand": Rect2(118, 388, 452, 292), "orb": Vector2(14, 404), "end": Rect2(14, 494, 100, 40), "draw": Vector2(14, 548),
		"discard": Vector2(566, 548), "exhaust": Vector2(566, 420)},
	{"hand": Rect2(710, 388, 452, 292), "orb": Vector2(1182, 404), "end": Rect2(1166, 494, 100, 40), "draw": Vector2(1194, 548),
		"discard": Vector2(640, 548), "exhaust": Vector2(640, 420)},
]


## One seat's state: whose it is, its parts, what is chosen and aimed on it, and what of it is on its way somewhere.
class _Seat:
	var player := 0
	var hand: CardHand
	var orb: CardOrb
	var draw_pile: CardPile
	var discard_pile: CardPile
	var exhaust_pile: CardPile
	var end_button: Button
	var end_glow: Panel
	var end_glow_tween: Tween = null
	var selected_id := -1
	var target := -1
	var focus_id := -1
	var keys_in_use := false
	var played_view: CardView = null
	var played_id := -1
	var dragging := -1
	var flying := 0


## Seat `s` built: its energy orb, piles, End Turn (Ready) with its glow, and its hand (added over the rest by _build).
func _build_seat(s: int):
	var seat := _Seat.new()
	seat.player = s if both_hands else battle.active
	seats.append(seat)
	_at = s
	var place: Dictionary = SEAT_PLACES[s] if both_hands else {"hand": HAND_AT, "orb": ORB_AT, "end": END_AT, "draw": DRAW_AT,
		"discard": DISCARD_AT, "exhaust": EXHAUST_AT}
	orb = CardOrb.new()
	orb.position = place.orb
	orb.use_fx(fx)
	_world.add_child(orb)
	draw_pile = CardPile.new().setup("Draw", "The draw pile: shuffled in from the discard pile when it runs out. Press to see what is in it.")
	draw_pile.position = place.draw
	draw_pile.pressed.connect(_show_pile.bind(&"draw", s))
	_world.add_child(draw_pile)
	discard_pile = CardPile.new().setup("Discard", "The discard pile: what was played and what was left in the hand. Press to see it.")
	discard_pile.position = place.discard
	discard_pile.pressed.connect(_show_pile.bind(&"discard", s))
	_world.add_child(discard_pile)
	exhaust_pile = CardPile.new().setup("Exhausted", "Gone for the rest of the fight. Press to see them.")
	exhaust_pile.position = place.exhaust
	exhaust_pile.pressed.connect(_show_pile.bind(&"exhaust", s))
	exhaust_pile.visible = false
	_world.add_child(exhaust_pile)
	var end_at: Rect2 = place.end
	_end_glow = Panel.new()
	_end_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end_glow.position = end_at.position
	_end_glow.size = end_at.size
	var glow := StyleBoxFlat.new()
	glow.bg_color = Color(0, 0, 0, 0)
	glow.set_corner_radius_all(8)
	glow.shadow_color = Color(1.0, 0.8, 0.4, 0.9)
	glow.shadow_size = 14
	glow.border_color = Color(1.0, 0.85, 0.5, 1.0)
	glow.set_border_width_all(2)
	glow.set_expand_margin_all(2)
	_end_glow.add_theme_stylebox_override("panel", glow)
	_end_glow.modulate.a = 0.0
	_world.add_child(_end_glow)
	end_button = Button.new()
	end_button.name = "EndTurn%d" % s
	end_button.text = "End Turn"
	end_button.position = end_at.position
	end_button.custom_minimum_size = end_at.size
	end_button.size = end_at.size
	end_button.focus_mode = Control.FOCUS_NONE
	end_button.tooltip_text = "End your turn: the hand goes to the discard pile and the enemies act (Space, Triangle)."
	end_button.pressed.connect(_end_pressed.bind(s))
	_world.add_child(end_button)
	var hand_at: Rect2 = place.hand
	hand = CardHand.new()
	hand.name = "Hand%d" % s
	hand.position = hand_at.position
	hand.size = hand_at.size
	hand.clicked.connect(_card_clicked.bind(s))
	hand.pointed.connect(_card_pointed.bind(s))
	hand.drag_started.connect(_drag_started.bind(s))
	hand.dragged.connect(_dragged.bind(s))
	hand.drag_ended.connect(_drag_ended.bind(s))


## Seat `s` in use: its parts are what the names read, and its player the rules' player now.
func _use(s: int):
	if seats.is_empty():
		return
	_at = clampi(s, 0, seats.size() - 1)
	if battle != null:
		battle.active = seats[_at].player


## The seat showing player `p` (with one hand at a time, the only one).
func _seat_of(p: int) -> int:
	return clampi(p, 0, seats.size() - 1) if both_hands else 0


## Whether seat `s` is played on this machine (over a network, only this player's; CardGame.plays_here).
func _seat_plays_here(s: int) -> bool:
	return s < seats.size() and (game == null or game.plays_here(seats[s].player))


## `call` done on each seat in turn, with the rules' player now its player; the seat and player in use as they were after.
func _each_seat(call: Callable):
	if seats.is_empty() or battle == null:
		return
	var was_at := _at
	var was_active := battle.active
	for s in seats.size():
		_at = s
		battle.active = seats[s].player
		call.call()
	_at = was_at
	battle.active = was_active


## A seat's End Turn (or Ready) pressed.
func _end_pressed(s: int):
	if not _seat_plays_here(s):
		return
	_use(s)
	end_turn()


## The fight beginning: the player comes in from the left, the enemies one after another from the right, and an elite or the boss
## with its name across the screen. The beats wait for it.
func _intro():
	_intro_done = false
	if moves():
		for p in player_views.size():
			player_views[p].arrive(Vector2(-260, 0), CardFeel.time(0.1 * p))
		for i in enemy_views.size():
			enemy_views[i].arrive(Vector2(380, 0), CardFeel.time(0.12 + 0.15 * i))
		if room == CardRun.Room.FIGHT:
			CardFeel.sound(&"card_fight_begins")
		await _sleep(CardFeel.time(0.5 + 0.15 * enemy_views.size()))
		if room == CardRun.Room.ELITE or room == CardRun.Room.BOSS:
			var boss := room == CardRun.Room.BOSS
			fx.title(global_position + Vector2(640, 200), _main_enemy_name(), Color("f0a070") if boss else Color("e8c872"), 58 if boss else 48,
				CardFeel.time(1.0))
			CardFeel.sound(&"card_boss_arrives" if boss else &"card_elite_arrives")
			SoundFollows.give_way(1.6)
			if boss:
				shake_by(9.0)
			await _sleep(CardFeel.time(1.35))
		# The run's last boss: the Message is spoken whole (twist 10).
		if battle.truth_spoken:
			fx.title(global_position + Vector2(640, 250), "The truth, spoken whole", CardView.MESSAGE_EDGE, 40, CardFeel.time(1.2))
			CardFeel.sound(&"card_truth_spoken", -4.0)
			await _sleep(CardFeel.time(1.2))
	else:
		CardFeel.note(&"card_fight_begins")
		if battle.truth_spoken:
			CardFeel.note(&"card_truth_spoken")
	_intro_done = true
	if not _queue.is_empty() and not _playing:
		_playing = true
		_play.call_deferred()


## The name an elite or a boss fight is known by: its strongest enemy's.
func _main_enemy_name() -> String:
	var best: Dictionary = {}
	for enemy in battle.enemies:
		if best.is_empty() or int(enemy.max_hp) > int(best.max_hp):
			best = enemy
	return str(best.get("name", ""))


## --- Playing the beats back ---


func _on_beat(what: StringName, info: Dictionary):
	_queue.append({"what": what, "info": info.duplicate(true)})
	if _intro_done and not _playing:
		_playing = true
		_play.call_deferred()


func _play():
	while not _queue.is_empty():
		var next: Dictionary = _queue.pop_front()
		var wait := _show(next.what, next.info)
		if moves() and wait > 0.0:
			await _sleep(_paced(wait))
	_playing = false
	_settle()


## A gap at the pace chosen, hurried on the player's own turn when beats are waiting.
func _paced(seconds: float) -> float:
	var paced := CardFeel.time(seconds)
	if not _locked and _queue.size() > HURRY_FROM:
		paced *= maxf(HURRY_LEAST, 1.0 - 0.1 * float(_queue.size() - HURRY_FROM))
	return paced


## Waits `seconds` on a timer of the stage's own (gone with it, so a fight left mid-beat simply stops). A blow's stop holds it.
func _sleep(seconds: float):
	var timer := Timer.new()
	timer.one_shot = true
	add_child(timer)
	timer.start(maxf(seconds, 0.001))
	await timer.timeout
	timer.queue_free()


## Shows one beat; how long to wait after it.
func _show(what: StringName, info: Dictionary) -> float:
	CardFeel.note(what)
	if what != &"drawn":
		_drawn_run = 0
	if what in OWN_BEATS:
		var p := int(info.get("player", shown))
		# One hand at a time: the partner's hand and piles are not on the screen, only a word for a card they play.
		if not both_hands and p != shown:
			return _elsewhere(what, info)
		# Played on that player's seat, the rules' player now theirs while it is.
		var was := battle.active
		_at = _seat_of(p)
		battle.active = p
		var wait := _show_beat(what, info)
		battle.active = was
		return wait
	return _show_beat(what, info)


## One beat shown, on the seat in use for one about a hand; how long to wait after it.
func _show_beat(what: StringName, info: Dictionary) -> float:
	match what:
		&"shuffled":
			return _shuffled(info)
		&"drawn":
			return _drawn(info)
		&"turn":
			return _turn(info)
		&"enemy_turn":
			return _enemy_turn()
		&"discarded":
			return _discarded(info)
		&"played":
			return _played(info)
		&"card_gone":
			return _card_gone(info)
		&"energy":
			return _energy(info)
		&"hit":
			return _hit(info)
		&"spines":
			return _spines(info)
		&"block":
			return _block(info)
		&"status":
			return _status(info)
		&"poison":
			return _poisoned(info)
		&"heal":
			return _healed(info)
		&"lose":
			return _lost(info)
		&"fell":
			return _fell(info)
		&"move":
			return _move(info)
		&"move_done":
			return _move_done(info)
		&"intent":
			return _intent(info)
		&"relic":
			return _relic(info)
		&"ended":
			return _ended(info)
		# How enemies choose and what their traits do (docs/proposals_2026-11-27_card_ai.md).
		&"faded":
			return _faded(info)
		&"overtime":
			return _overtime(info)
		&"slept", &"woke", &"winding", &"curled", &"uncurled", &"choked":
			return _trait_beat(what, info)
		# Two players, and Prometheus's hacking.
		&"ready":
			return _ready_beat(info)
		&"down":
			return _down_beat(info)
		&"read":
			return _read_beat(info)
		&"trace":
			return _trace_beat(info)
		&"phase":
			return _phase(info)
		&"given":
			return _given(info)
		&"stolen":
			return _stolen(info)
		&"returned":
			return _returned(info)
		&"joined":
			return _joined(info)
		&"split":
			return _split(info)
		&"rising":
			return _rising(info)
		&"rose":
			return _rose(info)
		# Tethers (twist 7).
		&"tied":
			return _tied(info)
		&"tether_did":
			tether_layer.did(info.tether)
			return 0.12
		&"frayed":
			tether_layer.fray(info.tether, int(info.strength))
			CardFeel.sound(&"card_tether_frayed", -12.0)
			return 0.1
		&"snapped":
			return _snapped(info)
	return 0.0


func fighter(who: int) -> CardFighter:
	if who < 0:
		var p := CardBattle.player_index(who)
		return player_views[p] if p >= 0 and p < player_views.size() else null
	if who >= 0 and who < enemy_views.size():
		return enemy_views[who]
	return null


## --- Two players (co-op, one screen) ---


## A beat about the hand not shown (the partner's): a card they play named over their figure; the rest is left to _settle.
func _elsewhere(what: StringName, info: Dictionary) -> float:
	var p := int(info.get("player", 0))
	var view: CardFighter = player_views[p] if p >= 0 and p < player_views.size() else null
	if what != &"played" or view == null:
		return 0.0
	var card: Dictionary = info.get("card", {})
	var definition := CardDatabase.card(str(card.get("key", "")))
	if definition != null and moves():
		fx.number(view.head() + Vector2(0, -20), definition.name_for(bool(card.get("upgraded", false))), INK, 18, 40.0, 0.9)
	CardFeel.sound(&"card_played_skill", -10.0)
	return PLAYED_HOLD


## The other player's hand, piles and energy shown, and theirs to play (the Swap button, Tab). Not one who is down.
func swap_hands():
	if battle == null or not battle.together() or battle.over or _over or both_hands:
		return
	var other := 1 - shown
	if bool(battle.players[other].down):
		return
	_show_hand_of(other)


func _show_hand_of(p: int):
	if battle == null or p < 0 or p >= battle.players.size() or both_hands:
		return
	_at = 0
	selected_id = -1
	target = -1
	_dragging = -1
	_stop_aiming()
	if game != null:
		game.hide_keywords()
	battle.active = p
	var changed_hands := shown != p
	shown = p
	seats[0].player = p
	if changed_hands:
		for id in hand.order.duplicate():
			var view := hand.take(id)
			if view != null:
				view.queue_free()
		CardFeel.sound(&"card_drawn", -8.0)
	_sync_hand()
	orb.set_energy(battle.energy, battle.max_energy, false)
	draw_pile.set_count(battle.draw_pile.size(), false)
	discard_pile.set_count(battle.discard_pile.size(), false)
	exhaust_pile.set_count(battle.exhaust_pile.size(), false)
	exhaust_pile.visible = battle.exhaust_pile.size() > 0
	_refresh_pair()
	_refresh_cards()
	_refresh_selection()
	_refresh_end_glow()


## Whose hand it is marked on their figure, and the Ready and Swap buttons' words.
func _refresh_pair():
	if battle == null or end_button == null:
		return
	if both_hands:
		# Each seat its own Ready; each figure lit while its player still plays.
		for s in seats.size():
			var p: int = seats[s].player
			player_views[p].set_aim(0 if bool(battle.players[p].ready) or bool(battle.players[p].down) else 2)
			var button: Button = seats[s].end_button
			var ready: bool = battle.players[p].ready
			button.text = "%s: %s" % [battle.players[p].name, "Not Ready" if ready else "Ready"] if not bool(battle.players[p].down) else "%s is down" % battle.players[p].name
			button.disabled = bool(battle.players[p].down) or battle.over or not _seat_plays_here(s)
			button.tooltip_text = ("Take back %s's Ready, to play on." if ready else "%s is done this turn; once both are Ready the enemies act. Playing a card takes it back.") \
				% battle.players[p].name + " (%s)" % game.ready_key_words(p)
		return
	for p in player_views.size():
		player_views[p].set_aim(2 if battle.together() and p == shown else 0)
	if not battle.together():
		return
	var other := 1 - shown
	var other_down: bool = battle.players[other].down
	swap_button.text = "%s's hand" % battle.players[other].name if not other_down else "%s is down" % battle.players[other].name
	swap_button.disabled = other_down or battle.over
	swap_button.tooltip_text = "Show %s's hand, to play it (Tab)." % battle.players[other].name
	var ready: bool = battle.players[shown].ready
	end_button.text = "Not Ready" if ready else "Ready"
	end_button.tooltip_text = ("Take back %s's Ready, to play on (Space, Triangle)." if ready else
		"%s is done this turn; once both are Ready the enemies act (Space, Triangle). Playing a card takes it back.") % battle.players[shown].name


## Co-op: the player shown says Ready, or takes it back. Once both have, the enemies' turn; else the other's hand comes up.
func _ready_pressed():
	var me: int = seats[_at].player
	var ready: bool = not bool(battle.players[me].ready)
	selected_id = -1
	hand.chosen = -1
	_stop_aiming()
	game.hide_keywords()
	CardFeel.sound(&"card_end_turn", -6.0)
	game.act(&"ready", me, [ready])
	_refresh_pair()
	_refresh_cards()
	_refresh_end_glow()


## A move of the fight's done (CardGame.act: here at once, or as it comes back in order over a network): a card played (`args`: its
## id, the enemy), a Ready said or taken back ([on]), a Tether let go ([its id]). The hand waits once it has ended the turn. Whether
## it was done.
func apply_move(kind: StringName, p: int, args: Array) -> bool:
	if battle == null or battle.over or p < 0 or p >= battle.players.size():
		return false
	var turn_was := battle.turn
	var done := false
	var was_at := _at
	_at = _seat_of(p)
	match kind:
		&"play":
			if args.size() >= 2:
				done = battle.play_card_id(p, int(args[0]), int(args[1]))
		&"ready":
			if args.size() >= 1:
				battle.set_ready(p, bool(args[0]))
				done = true
				# One hand at a time: Ready brings up the other's, while they still play.
				if bool(args[0]) and not both_hands and battle.turn == turn_was and not battle.over and battle.together():
					var other := 1 - p
					if not bool(battle.players[other].down) and not bool(battle.players[other].ready):
						_show_hand_of(other)
		&"let_go":
			if args.size() >= 1:
				done = battle.let_go(p, int(args[0]))
	if battle.turn != turn_was or battle.over:
		_locked = true
		if game != null:
			game.hide_keywords()
		if kind == &"ready" and not battle.over:
			_say("--- The enemies' turn ---")
	_at = was_at
	if not both_hands and not battle.over and battle.turn == turn_was:
		battle.active = seats[0].player
	_refresh_pair()
	_refresh_cards()
	_refresh_end_glow()
	return done


func _ready_beat(info: Dictionary) -> float:
	var who := fighter(int(info.who))
	if who != null and moves():
		fx.number(who.head() + Vector2(0, -24), "Ready" if bool(info.on) else "Not ready", YOUR_TURN if bool(info.on) else INK_DIM, 20, 30.0, 0.8)
	_refresh_pair()
	return 0.1


## A player down for the fight (co-op): their figure falls; with their hand shown, the other's comes up.
func _down_beat(info: Dictionary) -> float:
	var who := fighter(int(info.who))
	if who == null:
		return 0.0
	who.fall(true)
	CardFeel.sound(&"card_hit_heavy", -2.0)
	if moves():
		fx.number(who.head(), "Down!", Color("ff8a7a"), 30, 50.0, 1.0)
		vignette.flare(HURT, 0.8, true)
	shake_by(8.0)
	var p := CardBattle.player_index(int(info.who))
	if p == shown and battle.together() and not bool(battle.players[1 - p].down):
		_show_hand_of(1 - p)
	return 0.6


## --- Tethers (twist 7) ---


## A Tether tied: its small card springs up at the feet of whoever it holds.
func _tied(info: Dictionary) -> float:
	tether_layer.tie(info.tether)
	CardFeel.sound(&"card_tether_tied", -6.0)
	var held := fighter(int(info.tether.on))
	if held != null and moves():
		fx.ring(held.centre(), CardTethers.ink_of(int(info.tether.holder)), 12.0, 70.0, 0.35, 4.0)
	return 0.25


## A Tether gone: frayed through, let go, cut, broken or loose.
func _snapped(info: Dictionary) -> float:
	var at := tether_layer.snap(info.tether, StringName(info.why))
	var why := StringName(info.why)
	if why == &"renewed":
		return 0.0
	CardFeel.sound(&"card_tether_cut" if why == &"cut" or why == &"broken" else &"card_tether_snapped", -6.0)
	if at != Vector2.INF and moves():
		fx.burst(at, &"spark", 10, 220.0)
	var definition := CardDatabase.card(str(info.tether.key))
	var words := {&"frayed": "%s snaps", &"let_go": "%s let go", &"cut": "%s is cut", &"broken": "%s breaks", &"loose": "%s goes loose"}
	if definition != null and words.has(why):
		_say(String(words[why]) % definition.name + ".")
		if moves() and at != Vector2.INF:
			fx.number(at + Vector2(0, -24), String(words[why]) % definition.name, INK_DIM, 15, 20.0, 0.8)
	return 0.25


## Whether pressing a Tether held by `holder` (a who) lets it go here: a player's whose hand is played here, on their turn.
func lets_go(holder: int) -> bool:
	var p := CardBattle.player_index(holder)
	if p < 0 or battle == null or battle.over or _locked or _over or bool(battle.players[p].down):
		return false
	if both_hands:
		return _seat_plays_here(_seat_of(p))
	return p == shown and _seat_plays_here(0)


## A held Tether pressed: let go early, if it is ours to let go.
func _let_go_pressed(id: int):
	for tether in battle.tethers:
		if int(tether.id) != id:
			continue
		var p := CardBattle.player_index(int(tether.holder))
		if not lets_go(int(tether.holder)):
			bubble("Not yours to let go." if p < 0 or (not both_hands and p != shown) else "Not now.")
			return
		game.hide_keywords()
		if battle.together() or game.networked():
			game.act(&"let_go", p, [id])
			return
		var turn_was := battle.turn
		if battle.let_go(p, id) and (battle.turn != turn_was or battle.over):
			_locked = true
		_refresh_pair()
		_refresh_cards()
		return


## A half-read card's words read at last (twist 4): said over the hand.
func _read_beat(info: Dictionary) -> float:
	var card: Dictionary = info.get("card", {})
	var definition := CardDatabase.card(str(card.get("key", "")))
	if definition != null:
		bubble("Code read: %s" % definition.name)
		_say("You read the rest of %s." % definition.name)
	CardFeel.sound(&"card_fragment", -8.0)
	return 0.3


## A loud card raised the trace (twist 3): the run's meter answers.
func _trace_beat(info: Dictionary) -> float:
	CardFeel.sound(&"card_trace_rose", -8.0)
	if game != null:
		game.trace_rose(int(info.get("gained", 0)))
	return 0.1


func _shuffled(info: Dictionary) -> float:
	CardFeel.sound(&"card_shuffled", -6.0)
	if info.get("start", false):
		draw_pile.set_count(int(info.count))
		return 0.25
	if moves():
		fx.flow(discard_pile.top(), draw_pile.top(), &"card", mini(int(info.count), 10), Color.WHITE, 0.32)
		fx.number(draw_pile.top() + Vector2(0, -62), "Shuffled", INK_DIM, 17, 18, 0.9)
	discard_pile.set_count(0)
	draw_pile.set_count(int(info.count))
	return 0.4


func _drawn(info: Dictionary) -> float:
	var card: Dictionary = info.card
	draw_pile.set_count(int(info.draw_left))
	discard_pile.set_count(int(info.discard_left), false)
	if hand.views.has(int(card.id)):
		return 0.0
	var view := _card_view(card)
	if moves():
		view.set_face_down(true)
		hand.add(view, int(card.id), draw_pile.top())
		view.turn_over(true, CardFeel.time(0.2))
	else:
		hand.add(view, int(card.id))
	CardFeel.sound(&"card_drawn", -9.0, 1.0 + 0.05 * _drawn_run)
	_drawn_run += 1
	return DRAW_GAP


func _turn(_info: Dictionary) -> float:
	_acting = -1
	_relic_from = ""
	if moves():
		banner.top = global_position.y + 356.0
		banner.announce("Your Turn", YOUR_TURN)
	CardFeel.sound(&"card_your_turn")
	return 0.35


func _enemy_turn() -> float:
	if moves():
		banner.top = global_position.y + 356.0
		banner.announce("Enemy Turn", ENEMY_TURN)
	CardFeel.sound(&"card_enemy_turn")
	return 0.5


func _discarded(info: Dictionary) -> float:
	var cards: Array = info.cards
	var nth := 0
	for card in cards:
		var view := hand.take(int(card.id))
		if view == null:
			discard_pile.set_count(discard_pile.count + 1, false)
			continue
		_to_pile(view, discard_pile, CardFeel.time(0.04) * nth)
		nth += 1
	_refresh_end_glow()
	return 0.04 * nth + 0.15


## Sends `view` to `pile` (shrinking as it goes), `delay` seconds from now; the pile counts it as it lands.
func _to_pile(view: CardView, pile: CardPile, delay: float = 0.0):
	if not moves():
		view.queue_free()
		pile.set_count(pile.count + 1, false)
		return
	var from := view.get_global_transform() * view.pivot_offset
	_flying += 1
	fx.fly(view, from, pile.top(), CardFeel.time(0.26), 46.0, 0.32, _landed_on.bind(pile, _at), delay)


## Cards on their way to a pile just now (the seat in use's): the piles' counts are put right from the rules once there are none.
var _flying: int:
	get:
		return seats[_at].flying if _at < seats.size() else 0
	set(value):
		if _at < seats.size():
			seats[_at].flying = value


## A card landed on `pile` of seat `s`'s.
func _landed_on(pile: CardPile, s: int = 0):
	if s < seats.size():
		seats[s].flying = maxi(seats[s].flying - 1, 0)
	if is_instance_valid(pile):
		pile.visible = true
		pile.set_count(pile.count + 1)
		CardFeel.sound(&"card_discarded", -14.0)
	if s < seats.size() and seats[s].flying == 0 and not _playing:
		_sync_piles()


func _played(info: Dictionary) -> float:
	var card: Dictionary = info.card
	var id := int(card.id)
	if selected_id == id:
		selected_id = -1
	if _dragging == id:
		_dragging = -1
	_stop_aiming()
	game.hide_keywords()
	var view := hand.take(id)
	_played_id = id
	_relic_from = ""
	CardFeel.sound([&"card_played_attack", &"card_played_skill", &"card_played_power", &"card_played_skill"][clampi(int(info.type), 0, 3)], -5.0)
	Rumble.tap(0.25, 0.06)
	if not moves():
		if view != null:
			view.queue_free()
		_played_view = null
		return 0.0
	if view == null:
		view = _card_view(card)
		add_child(view)
		view.position = hand.middle() - global_position - view.pivot_offset
	var from := view.get_global_transform() * view.pivot_offset
	view.reparent(fx, false)
	view.position = from - fx.global_position - view.pivot_offset
	view.set_playable(true, false)
	view.set_selected(false)
	_played_view = view
	var spot := global_position + PLAY_SPOT
	var lean := 0.0
	var who := int(info.target)
	if who >= 0 and fighter(who) != null:
		var toward := fighter(who).centre()
		spot = spot.lerp(toward, 0.22)
		lean = clampf((toward.x - spot.x) / 900.0, -0.2, 0.2)
	var tween := view.create_tween().set_parallel()
	tween.tween_property(view, "position", spot - fx.global_position - view.pivot_offset, CardFeel.time(0.16)).set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(view, "scale", Vector2.ONE * 1.05, CardFeel.time(0.16))
	tween.tween_property(view, "rotation", lean, CardFeel.time(0.16))
	_type_code(spot + Vector2(0, -CardView.SIZE.y * 0.62), _code_of(card, who))
	_refresh_end_glow()
	return PLAYED_HOLD


## A card as the code it runs, for the line typing across as it is played: "> exec thrust -t rat".
func _code_of(card: Dictionary, who: int) -> String:
	var line := "> exec %s%s" % [str(card.get("key", "")), "_v2" if bool(card.get("upgraded", false)) else ""]
	if who >= 0 and who < battle.enemies.size():
		line += " -t %s" % str(battle.enemies[who].key)
	return line


## The hacking juice (docs/proposals_2026-11-26_card_juice.md section 11): a card played types across as a fragment of code over
## where it goes off, ticking as it goes, then fades. Only to look at.
func _type_code(at: Vector2, text: String):
	if not moves() or text == "":
		return
	var line := Label.new()
	line.text = text
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_font_size_override("font_size", 15)
	line.add_theme_color_override("font_color", Color("6fe08a"))
	line.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	line.add_theme_constant_override("outline_size", 4)
	fx.add_child(line)
	line.reset_size()
	line.position = at - fx.global_position - Vector2(line.size.x / 2.0, 0.0)
	line.visible_characters = 0
	var tween := line.create_tween()
	tween.tween_method(_code_typed.bind(line), 0.0, float(text.length()), CardFeel.time(0.025 * text.length()))
	tween.tween_interval(CardFeel.time(0.4))
	tween.tween_property(line, "modulate:a", 0.0, CardFeel.time(0.3))
	tween.tween_callback(line.queue_free)


func _code_typed(letters: float, line: Label):
	if not is_instance_valid(line):
		return
	var now := int(letters)
	if now > line.visible_characters and now % 3 == 0:
		CardFeel.sound(&"card_code_tick", -20.0)
	line.visible_characters = now


func _card_gone(info: Dictionary) -> float:
	var view: CardView = _played_view if _played_id == int(info.card.id) else null
	_played_view = null
	_played_id = -1
	var to: StringName = info.to
	if view == null or not is_instance_valid(view) or not moves():
		if view != null and is_instance_valid(view):
			view.queue_free()
		match to:
			&"discard":
				discard_pile.set_count(discard_pile.count + 1, false)
			&"exhaust":
				exhaust_pile.visible = true
				exhaust_pile.set_count(exhaust_pile.count + 1, false)
		return 0.0
	var at := view.get_global_transform() * view.pivot_offset
	match to:
		&"discard":
			_flying += 1
			fx.fly(view, at, discard_pile.top(), CardFeel.time(0.24), 60.0, 0.3, _landed_on.bind(discard_pile, _at))
			return 0.1
		&"tether":
			# A Tether: it flies onto whoever it holds, and becomes its small card there.
			var held := fighter(int(info.get("on", -1 - shown)))
			var to_point := held.centre() if held != null else at
			fx.fly(view, at, to_point, CardFeel.time(0.26), 0.0, 0.25)
			return 0.2
		&"exhaust":
			fx.burst(at, &"ember", 18, 200.0, Vector2.ZERO, CardView.SIZE * 0.8)
			CardFeel.sound(&"card_exhausted", -6.0)
			_flying += 1
			view.burn(CardFeel.time(0.45), _burnt.bind(view, _at))
			return 0.3
		_:
			# A Power: it breaks into light flowing into the player's side.
			fx.ring(at, GOLD, 30.0, 120.0, 0.4, 6.0)
			fx.flow(at, player_views[clampi(seats[_at].player, 0, player_views.size() - 1)].centre(), &"spark", 12, GOLD, CardFeel.time(0.42))
			var tween := view.create_tween().set_parallel()
			tween.tween_property(view, "scale", Vector2.ONE * 1.35, CardFeel.time(0.25))
			tween.tween_property(view, "modulate:a", 0.0, CardFeel.time(0.25))
			tween.chain().tween_callback(view.queue_free)
			return 0.3


## A card burnt away into seat `s`'s exhausted pile.
func _burnt(view: CardView, s: int = 0):
	if is_instance_valid(view):
		view.queue_free()
	if s >= seats.size():
		return
	seats[s].flying = maxi(seats[s].flying - 1, 0)
	seats[s].exhaust_pile.visible = true
	seats[s].exhaust_pile.set_count(seats[s].exhaust_pile.count + 1)
	if seats[s].flying == 0 and not _playing:
		_sync_piles()


func _energy(info: Dictionary) -> float:
	var change := int(info.change)
	orb.set_energy(int(info.energy), battle.max_energy, true, change > 0)
	if change > 0:
		CardFeel.sound(&"card_energy_filled", -8.0)
	_refresh_cards()
	return 0.0


func _hit(info: Dictionary) -> float:
	var struck := fighter(int(info.to))
	if struck == null:
		return 0.0
	var striker := fighter(int(info.from))
	var away := Vector2.RIGHT if int(info.to) >= 0 else Vector2.LEFT
	if striker != null and striker != struck:
		away = (struck.centre() - striker.centre()).normalized()
	var lost := int(info.lost)
	var blocked := int(info.blocked)
	var most := maxi(int(info.max_hp), 1)
	var share := float(lost) / float(most)
	var lethal: bool = info.lethal
	var on_player := int(info.to) < 0
	if blocked > 0:
		struck.show_block(int(info.block), true, true)
		if int(info.block) == 0:
			fx.burst(struck.shield_place(), &"shard", 12, 300.0, away * 140.0)
			CardFeel.sound(&"card_block_broken", -5.0)
		else:
			CardFeel.sound(&"card_block_struck", -5.0)
		fx.number(struck.shield_place() + Vector2(0, -22), ("-%d" % blocked) if lost > 0 else "Blocked", BLOCK_INK, 22 if lost > 0 else 24, 30.0, 0.7)
	if lost > 0 or blocked == 0:
		struck.knock(away, KNOCK + KNOCK_MORE * minf(share * 2.0, 1.0))
		struck.flash()
		# The hacking juice: a hit tears the figure into strips for an instant.
		if lost > 0:
			struck.glitch(minf(0.45 + share * 2.5, 1.0))
			CardFeel.sound(&"card_glitch", -14.0)
		fx.slash(struck.centre(), away.angle() + 0.35 * (1.0 if int(info.nth) % 2 == 0 else -1.0), Color.WHITE, 170.0)
		fx.burst(struck.centre(), &"spark", 6 + int(12.0 * minf(share * 2.0, 1.0)), 280.0, away * 140.0)
		fx.number(struck.head(), str(lost), PLAYER_HURT_INK if on_player else DAMAGE_INK, 28 + int(22.0 * minf(share * 2.0, 1.0)), 52.0, 0.85)
		struck.show_hp(int(info.hp), most, true)
		CardFeel.sound(&"card_hit_heavy" if CardFeel.heavy(lost, most, lethal) else &"card_hit", -4.0, 1.0 + 0.07 * int(info.nth))
		_stop(CardFeel.stop_for(lost, most, lethal))
		shake_by(CardFeel.shake_for(lost, most, lethal))
		if on_player:
			if moves():
				vignette.flare(HURT, 0.25 + share * 2.0, lethal)
			Rumble.blow(share, lethal)
	else:
		struck.knock(away, 4.0)
		if on_player:
			Rumble.tap(0.2, 0.05)
	if int(info.of) > 1 and int(info.nth) < int(info.of) - 1:
		if bool(info.sweep) and _next_is_hit(int(info.nth)):
			return SWEEP_GAP
		return maxf(FLURRY_GAP - 0.04 * int(info.nth), FLURRY_GAP_LEAST)
	if bool(info.sweep) and _next_is_hit(int(info.nth)):
		return SWEEP_GAP
	return HIT_GAP


## Whether the next beat waiting is another hit of the same sweep (the card hitting every enemy).
func _next_is_hit(nth: int) -> bool:
	if _queue.is_empty():
		return false
	var next: Dictionary = _queue.front()
	return next.what == &"hit" and int(next.info.get("nth", -1)) == nth and bool(next.info.get("sweep", false))


func _spines(info: Dictionary) -> float:
	var spiked := fighter(int(info.from))
	var struck := fighter(int(info.to))
	if struck == null or spiked == null:
		return 0.0
	CardFeel.sound(&"card_spines", -6.0)
	if moves():
		fx.flow(spiked.centre(), struck.centre(), &"spike", 7, Color.WHITE, CardFeel.time(0.18))
	struck.knock((struck.centre() - spiked.centre()).normalized(), 7.0)
	struck.flash(0.6)
	fx.number(struck.head(), str(int(info.lost)), Color("c9d2b0"), 24, 40.0, 0.75)
	struck.show_hp(int(info.hp), int(info.max_hp), true)
	if int(info.to) < 0:
		if moves():
			vignette.flare(HURT, 0.2, bool(info.lethal))
		Rumble.blow(float(info.lost) / maxf(float(info.max_hp), 1.0), bool(info.lethal))
	return 0.25


func _block(info: Dictionary) -> float:
	var who := fighter(int(info.who))
	if who == null:
		return 0.0
	var change := int(info.change)
	who.show_block(int(info.block), true, false)
	if change > 0:
		CardFeel.sound(&"card_block_gained", -6.0)
		if moves():
			fx.ring(who.shield_place(), BLOCK_INK, 10.0, 46.0, 0.3, 4.0)
			fx.number(who.shield_place() + Vector2(0, -24), "+%d" % change, BLOCK_INK, 20, 26.0, 0.6)
		return BLOCK_GAP
	return 0.0


func _status(info: Dictionary) -> float:
	var who := fighter(int(info.who))
	if who == null:
		return 0.0
	var key: StringName = info.key
	var before := int(info.before)
	var after := int(info.after)
	if key == &"scanned" and after > before:
		CardFeel.sound(&"card_scanned", -6.0)
	if after > before:
		var good := not CardStatus.harmful(key)
		CardFeel.sound(&"card_status_good" if good else &"card_status_bad", -6.0)
		if moves():
			var from := _status_from(who)
			var to := who.badge_place(key)
			who.show_status(key, after, true, false)
			fx.fly_icon(StringName("status_" + String(key)), null, CardBadge.colour_of(key), CardStatus.name_of(key).substr(0, 1), from, to,
				30.0, CardFeel.time(0.34), 90.0 if good else 24.0, _status_landed.bind(who, key, before == 0), 1.0)
		else:
			who.show_status(key, after, false)
		if int(info.who) < 0:
			_refresh_cards()
		return STATUS_GAP
	who.show_status(key, after, true)
	if int(info.who) < 0:
		_refresh_cards()
	return WEAR_GAP


func _status_landed(who: CardFighter, key: StringName, new: bool):
	if not is_instance_valid(who):
		return
	if new:
		who.land(key)


## Where a status being put on comes from: the card going off, the enemy acting, a relic on the bar, or just over whoever gets it.
func _status_from(who: CardFighter) -> Vector2:
	if _played_view != null and is_instance_valid(_played_view):
		return _played_view.get_global_transform() * _played_view.pivot_offset
	if _acting >= 0 and fighter(_acting) != null:
		return fighter(_acting).centre()
	if _relic_from != "" and game != null:
		return game.relic_place(_relic_from)
	return who.head() + Vector2(0, -90)


func _poisoned(info: Dictionary) -> float:
	var who := fighter(int(info.who))
	if who == null:
		return 0.0
	CardFeel.sound(&"card_poison", -6.0)
	if moves():
		fx.burst(who.centre() + Vector2(0, -30), &"drop", 12, 120.0, Vector2.ZERO, Vector2(110, 60))
		fx.number(who.head(), str(int(info.lost)), POISON_INK, 28, 46.0, 0.85)
	who.flash(0.4)
	who.show_hp(int(info.hp), int(info.max_hp), true)
	if int(info.who) < 0:
		if moves():
			vignette.flare(POISONED, 0.3, bool(info.lethal))
		Rumble.blow(float(info.lost) / maxf(float(info.max_hp), 1.0), bool(info.lethal))
	return 0.32


func _healed(info: Dictionary) -> float:
	var who := fighter(int(info.who))
	if who == null:
		return 0.0
	CardFeel.sound(&"card_mend", -6.0)
	if moves():
		fx.ring(who.centre(), MEND_INK, 20.0, 80.0, 0.45, 5.0)
		fx.number(who.head(), "+%d" % int(info.amount), MEND_INK, 28, 46.0, 0.85)
	who.show_hp(int(info.hp), int(info.max_hp), true)
	return 0.22


func _lost(info: Dictionary) -> float:
	var who := fighter(int(info.who))
	if who == null:
		return 0.0
	who.flash(0.6)
	fx.number(who.head(), str(int(info.lost)), Color("d8a0f0"), 26, 44.0, 0.8)
	who.show_hp(int(info.hp), int(info.max_hp), true)
	CardFeel.sound(&"card_hit", -8.0, 0.85)
	if int(info.who) < 0:
		if moves():
			vignette.flare(HURT, 0.25, bool(info.lethal))
		Rumble.blow(float(info.lost) / maxf(float(info.max_hp), 1.0), bool(info.lethal))
	return 0.2


func _fell(info: Dictionary) -> float:
	var who := fighter(int(info.who))
	if who == null:
		return 0.0
	who.fall(true)
	if int(info.get("rises", 0)) > 0:
		who.show_rising(int(info.rises))
	CardFeel.sound(&"card_enemy_falls", -4.0)
	Rumble.thump()
	if target == int(info.who):
		var living := battle.living()
		target = living[0] if not living.is_empty() else -1
	if bool(info.last):
		_slow_motion(SLOW_SECONDS, SLOW_SHARE)
		SoundFollows.give_way(1.2)
		return 0.6
	return 0.35


func _move(info: Dictionary) -> float:
	var who := fighter(int(info.who))
	if who == null:
		return 0.0
	_acting = int(info.who)
	who.intent_flare()
	if moves():
		fx.number(who.intent_place() + Vector2(0, -4), str(info.name), INK_DIM, 16, 18.0, 1.0)
	_relic_from = ""
	var animation: StringName = who.figure.animation_for(bool(info.attacks)) if who.figure != null else &""
	if animation != &"" and moves():
		# Played at the pace (twice as fast at Fast); its length is then the real wait, which _paced would shorten again.
		var seconds := who.figure.act(animation, 1.0 / CardFeel.time(1.0))
		return clampf(seconds * CardFigure.LANDS_AT, 0.15, 1.2) / CardFeel.time(1.0)
	# No animation of its own: it steps towards the player instead.
	who.step(player_view.centre())
	return 0.18


func _move_done(info: Dictionary) -> float:
	var who := fighter(int(info.who))
	if who != null:
		who.step_back()
	_acting = -1
	return MOVE_DONE_GAP


func _intent(info: Dictionary) -> float:
	var who := fighter(int(info.who))
	if who == null:
		return 0.0
	who.show_intent(info.intent, true, intent_words(info.intent))
	# It changed its mind, and says so (Reactive, waking, curling up).
	if bool(info.get("changed", false)) and moves():
		fx.number(who.intent_place() + Vector2(0, 26), "!", Color("ffe08a"), 26, 20.0, 0.7)
		return 0.25
	return 0.05


## --- How enemies choose, and their traits ---


## Ethereal cards still in the hand as the turn ends: they burn away into the exhausted pile.
func _faded(info: Dictionary) -> float:
	var nth := 0
	for card in info.cards:
		var view := hand.take(int(card.id))
		if view == null:
			exhaust_pile.visible = true
			exhaust_pile.set_count(exhaust_pile.count + 1, false)
			continue
		if not moves():
			view.queue_free()
			exhaust_pile.visible = true
			exhaust_pile.set_count(exhaust_pile.count + 1, false)
			continue
		var at := view.get_global_transform() * view.pivot_offset
		view.reparent(fx, false)
		view.position = at - fx.global_position - view.pivot_offset
		fx.burst(at, &"ember", 10, 160.0, Vector2.ZERO, CardView.SIZE * 0.6)
		_flying += 1
		view.burn(CardFeel.time(0.4), _burnt.bind(view, _at))
		nth += 1
	if nth > 0:
		CardFeel.sound(&"card_exhausted", -8.0)
	return 0.25 if nth > 0 else 0.0


## An enemy's Overtime ended the turn: the hand waits, and it is said across the screen. In co-op it only made that player Ready.
func _overtime(info: Dictionary) -> float:
	if not battle.together():
		_locked = true
	_at = _seat_of(int(info.get("player", shown)))
	selected_id = -1
	_stop_aiming()
	CardFeel.sound(&"card_overtime", -4.0)
	if moves():
		banner.top = global_position.y + 356.0
		banner.announce("Overtime", ENEMY_TURN)
		var who := fighter(int(info.who))
		if who != null:
			who.flash(0.7)
	return 0.6


## Sleeping, waking, a countdown ticking, curling up and uncurling: a word over the enemy, and its sound.
func _trait_beat(what: StringName, info: Dictionary) -> float:
	var who := fighter(int(info.who))
	if who == null:
		return 0.0
	var words := ""
	var colour := INK_DIM
	var sound := &""
	match what:
		&"slept":
			words = "Zz"
			colour = Color("9ab0f0")
		&"woke":
			words = "Awake!"
			colour = Color("ffe08a")
			sound = &"card_woke"
			who.flash(0.6)
			shake_by(3.0)
		&"winding":
			words = "%s in %d" % [str(info.get("name", "")), int(info.get("left", 1))]
			colour = Color("ffe08a")
			sound = &"card_countdown"
		&"curled":
			words = "Curls up!"
			colour = BLOCK_INK
			sound = &"card_curled"
		&"uncurled":
			words = "Uncurls"
		&"choked":
			# The Devourer ate a Status card: it chokes, and spits out all it ate.
			words = "Chokes!"
			colour = Color("8fd66a")
			sound = &"card_choked"
			who.flash(0.8)
			shake_by(5.0)
	if sound != &"":
		CardFeel.sound(sound, -5.0)
	if moves() and words != "":
		fx.number(who.head() + Vector2(0, -20), words, colour, 20, 30.0, 0.9)
	return 0.35 if what != &"uncurled" else 0.15


## A phase begins: its line across the screen over it, and the screen shakes.
func _phase(info: Dictionary) -> float:
	var who := fighter(int(info.who))
	CardFeel.sound(&"card_phase", -3.0)
	if not moves():
		return 0.0
	if who != null:
		who.flash(0.9, 0.3)
	var line := str(info.get("line", ""))
	if line != "":
		fx.title(global_position + Vector2(640, 220), line, Color("f0a070"), 34, CardFeel.time(1.2))
	shake_by(7.0)
	return 0.9 if line != "" else 0.3


## Cards an enemy gives the player fly from it to where they go: the discard pile, the draw pile, or the hand.
func _given(info: Dictionary) -> float:
	var from_fighter := fighter(int(info.from))
	var from: Vector2 = from_fighter.centre() if from_fighter != null else global_position + PLAY_SPOT
	var to: StringName = info.to
	CardFeel.sound(&"card_junk", -5.0)
	var nth := 0
	for card in info.cards:
		if to == &"hand":
			if hand.views.has(int(card.id)):
				continue
			var view := _card_view(card)
			hand.add(view, int(card.id), from if moves() else Vector2.INF)
			nth += 1
			continue
		var pile: CardPile = draw_pile if to == &"draw" else discard_pile
		if not moves():
			pile.set_count(pile.count + 1, false)
			continue
		var flying := _card_view(card)
		flying.in_hand = false
		fx.add_child(flying)
		flying.position = from - fx.global_position - flying.pivot_offset
		flying.scale = Vector2.ONE * 0.7
		_flying += 1
		fx.fly(flying, from, pile.top(), CardFeel.time(0.4), 40.0, 0.35, _landed_on.bind(pile, _at), CardFeel.time(0.08) * nth)
		nth += 1
	_refresh_cards()
	return 0.15 + 0.08 * nth


## Cards taken from the draw pile fly to the enemy who took them, and are gone into it.
func _stolen(info: Dictionary) -> float:
	var thief := fighter(int(info.who))
	CardFeel.sound(&"card_stolen", -5.0)
	var nth := 0
	for card in info.cards:
		draw_pile.set_count(maxi(draw_pile.count - 1, 0), false)
		if not moves() or thief == null:
			continue
		var flying := _card_view(card)
		flying.in_hand = false
		flying.set_face_down(true)
		fx.fly(flying, draw_pile.top(), thief.centre(), CardFeel.time(0.4), 60.0, 0.25, Callable(), CardFeel.time(0.08) * nth)
		nth += 1
	return 0.4


## What a fallen enemy held comes back: into the hand, flying from where it fell (or onto the discard pile).
func _returned(info: Dictionary) -> float:
	var giver := fighter(int(info.who))
	var from: Vector2 = giver.centre() if giver != null else global_position + PLAY_SPOT
	CardFeel.sound(&"card_drawn", -6.0)
	# Each card back to whoever owns it: into their hand where the rules put it there, else onto their discard pile (the shown one's
	# with one hand at a time; _settle puts the rest right).
	var was_at := _at
	var was_active := battle.active
	for card in info.cards:
		var owner := -1
		for p in battle.players.size():
			if battle.players[p].hand.any(func(held): return int(held.id) == int(card.id)) \
					or battle.players[p].discard_pile.any(func(held): return int(held.id) == int(card.id)):
				owner = p
		if owner < 0 or (not both_hands and owner != shown):
			continue
		_at = _seat_of(owner)
		battle.active = owner
		if battle.hand.any(func(held): return int(held.id) == int(card.id)):
			if not hand.views.has(int(card.id)):
				hand.add(_card_view(card), int(card.id), from if moves() else Vector2.INF)
		else:
			discard_pile.set_count(discard_pile.count + 1, false)
	_at = was_at
	battle.active = was_active
	_refresh_cards()
	return 0.3


## An enemy comes into the fight (called in, or split from another): a new view at its place, in the row, coming in.
func _joined(info: Dictionary) -> float:
	var at := int(info.who)
	if at < 0 or at >= battle.enemies.size():
		return 0.0
	var view := _new_enemy_view(at)
	CardFeel.sound(&"card_summoned", -4.0)
	if moves():
		var from := fighter(int(info.get("from", CardBattle.NOBODY)))
		view.arrive(Vector2(0, -60) if from == null else Vector2(40, 0), 0.0)
	return 0.45


## An enemy split: it bursts and is gone (what it split into joins in its place).
func _split(info: Dictionary) -> float:
	var who := fighter(int(info.who))
	if who == null:
		return 0.0
	CardFeel.sound(&"card_summoned", -2.0, 0.8)
	if moves():
		fx.burst(who.centre(), &"drop", 22, 260.0, Vector2.ZERO, Vector2(120, 120))
		shake_by(5.0)
	who.fall(true)
	return 0.35


func _rising(info: Dictionary) -> float:
	var who := fighter(int(info.who))
	if who != null:
		who.show_rising(int(info.left))
	return 0.1


## A fallen Linked one stands again: a fresh view in its place, rising.
func _rose(info: Dictionary) -> float:
	var at := int(info.who)
	if at < 0 or at >= battle.enemies.size():
		return 0.0
	var view := _new_enemy_view(at)
	CardFeel.sound(&"card_rose", -4.0)
	if moves():
		view.arrive(Vector2(0, 40), 0.0)
		view.flash(0.8, 0.3)
	return 0.45


## A new view for enemy `at` as the rules have it now: in place of the one there, or after the others.
func _new_enemy_view(at: int) -> CardFighter:
	var view := CardFighter.new().setup_enemy(at, battle.enemies[at])
	view.pressed.connect(_fighter_pressed)
	if at < enemy_views.size():
		var old: CardFighter = enemy_views[at]
		var index := old.get_index()
		_enemy_row.add_child(view)
		_enemy_row.move_child(view, index)
		old.queue_free()
		enemy_views[at] = view
	else:
		_enemy_row.add_child(view)
		enemy_views.append(view)
	return view


func _relic(info: Dictionary) -> float:
	_relic_from = str(info.key)
	if game != null:
		game.flash_relic(_relic_from)
	CardFeel.sound(&"card_relic_used", -6.0)
	return 0.25


func _ended(info: Dictionary) -> float:
	_over = true
	_fight_over(bool(info.won))
	return 0.0


## The end of the fight: won, "Victory" comes in hard and what is left of the hand and the piles is swept away; lost, the colour
## drains out of the screen as it slows and "Defeated" fades in. Then `finished`, at once: "Victory" stays up until the wipe into the
## rewards takes it. Headless, after FIGHT_OVER_SECONDS (a suite waits on it).
func _fight_over(won: bool):
	_locked = true
	selected_id = -1
	_stop_aiming()
	_refresh_end_glow()
	if moves():
		if won:
			await _sleep(CardFeel.time(0.35))
			fx.title(global_position + Vector2(640, 230), "Victory", GOLD, 76, CardFeel.time(1.3))
			CardFeel.sound(&"card_fight_won")
			shake_by(6.0)
			var nth := 0
			# Every seat's hand swept away, and its parts faded.
			for seat in seats:
				for id in seat.hand.order.duplicate():
					var view: CardView = seat.hand.take(id)
					if view == null:
						continue
					var from := view.get_global_transform() * view.pivot_offset
					fx.fly(view, from, from + Vector2(0, 360), CardFeel.time(0.4), -30.0, 0.8, Callable(), CardFeel.time(0.03) * nth)
					nth += 1
				for part in [seat.orb, seat.draw_pile, seat.discard_pile, seat.exhaust_pile, seat.end_button, seat.end_glow]:
					part.create_tween().tween_property(part, "modulate:a", 0.0, CardFeel.time(0.4))
			swap_button.create_tween().tween_property(swap_button, "modulate:a", 0.0, CardFeel.time(0.4))
			await _sleep(CardFeel.time(1.5))
		else:
			_greying()
			_slow_motion(0.8, 0.5)
			SoundFollows.give_way(2.5)
			CardFeel.sound(&"card_fight_lost")
			var words := fx.title(global_position + Vector2(640, 230), "Defeated", Color("e07a6a"), 76, -1.0, 1.0, 1.0)
			await _sleep(2.2)
			if is_instance_valid(words):
				words.queue_free()
	else:
		CardFeel.note(&"card_fight_won" if won else &"card_fight_lost")
		await _sleep(CardGame.FIGHT_OVER_SECONDS)
	finished.emit(won)


## The colour draining out of the whole screen (a lost fight).
func _greying():
	_grey = ColorRect.new()
	_grey.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grey.set_anchors_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float amount = 0.0;
void fragment() {
	vec3 c = textureLod(screen, SCREEN_UV, 0.0).rgb;
	float g = dot(c, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(c, vec3(g) * 0.72, amount), 1.0);
}"""
	var greying := ShaderMaterial.new()
	greying.shader = shader
	_grey.material = greying
	add_child(_grey)
	move_child(_grey, aim.get_index())
	var tween := _grey.create_tween()
	tween.tween_method(func(value: float): greying.set_shader_parameter("amount", value), 0.0, 1.0, 1.2)


## --- Once the beats have played ---


## Puts right whatever the beats left out, from the rules: health, Block, statuses, intents, the hand, the piles, the energy; then
## the hand comes back if it is the player's turn.
func _settle():
	if battle == null:
		return
	for p in player_views.size():
		_sync_fighter(player_views[p], battle.players[p], {})
	# One hand at a time: the hand shown follows the rules' (a new turn opens on the first standing), and never stays on one who is
	# down. Both at once: each seat stays its player's.
	if not both_hands:
		if battle.together() and bool(battle.players[battle.active].down) and not bool(battle.players[1 - battle.active].down):
			battle.active = 1 - battle.active
		if shown != battle.active:
			_show_hand_of(battle.active)
		_use(0)
	for i in battle.enemies.size():
		if i >= enemy_views.size():
			_new_enemy_view(i)
		_sync_fighter(enemy_views[i], battle.enemies[i], battle.intent_of(battle.enemies[i]))
	_sync_hand()
	if tether_layer != null:
		tether_layer.sync(battle.tethers)
	_each_seat(_sync_counts)
	_sync_piles()
	if not battle.over and _locked and not _over:
		_locked = false
		_take_early_press()
	_refresh_cards()
	_refresh_selection()
	_refresh_end_glow()


## The seat in use's energy and draw pile as the rules have them.
func _sync_counts():
	if orb.energy != battle.energy:
		orb.set_energy(battle.energy, battle.max_energy, false)
	if draw_pile.count != battle.draw_pile.size():
		draw_pile.set_count(battle.draw_pile.size(), false)


## Every seat's discard and exhaust piles' counts as the rules have them, once no card is on its way to one.
func _sync_piles():
	_each_seat(_sync_piles_here)


func _sync_piles_here():
	if battle == null or _flying > 0 or _playing:
		return
	if discard_pile.count != battle.discard_pile.size():
		discard_pile.set_count(battle.discard_pile.size(), false)
	if exhaust_pile.count != battle.exhaust_pile.size():
		exhaust_pile.set_count(battle.exhaust_pile.size(), false)
	exhaust_pile.visible = battle.exhaust_pile.size() > 0


func _sync_fighter(view: CardFighter, who: Dictionary, intent: Dictionary):
	# A fallen enemy stays fallen: what the rules still keep on it (its statuses, its last health) is not shown again. A player
	# down for the fight (co-op) too.
	if (who.has("alive") and not who.alive) or bool(who.get("down", false)):
		if view.alive:
			view.fall(false)
		return
	if view.hp != int(who.hp) or view.max_hp != maxi(int(who.max_hp), 1):
		view.show_hp(int(who.hp), int(who.max_hp), false)
	if view.block != int(who.block):
		view.show_block(int(who.block), false)
	var statuses: Dictionary = who.statuses
	for key in view.badges.keys():
		if not statuses.has(key):
			view.show_status(key, 0, false)
	for key in statuses:
		var badge: CardBadge = view.badges.get(key)
		if badge == null or badge.amount != int(statuses[key]):
			view.show_status(key, int(statuses[key]), false)
		elif not badge.visible:
			badge.visible = true
	if not intent.is_empty() and view.alive and not view.shows_intent(intent):
		view.show_intent(intent, false, intent_words(intent))


## Every hand drawn as the rules have it: a view for each card in it, none for a card that is not.
func _sync_hand():
	_each_seat(_sync_hand_here)


func _sync_hand_here():
	var ids: Array = battle.hand.map(func(card): return int(card.id))
	for id in hand.order.duplicate():
		if not ids.has(id):
			var view := hand.take(id)
			if view != null:
				view.queue_free()
	for card in battle.hand:
		if not hand.views.has(int(card.id)):
			hand.add(_card_view(card), int(card.id))
	hand.order = ids
	hand.layout()


func _card_view(card: Dictionary) -> CardView:
	var view := CardView.new()
	view.show_card(card.key, card.upgraded, battle, -1, card)
	view.show_cost(battle.cost_of(card))
	view.in_hand = true
	return view


## Every card's numbers worked out again and its glow set, on every seat: the energy, the statuses, the enemy aimed at.
func _refresh_cards():
	if battle == null or seats.is_empty():
		return
	_each_seat(_refresh_cards_here)


func _refresh_cards_here():
	if battle == null or hand == null:
		return
	var plays_here := _seat_plays_here(_at)
	var living := battle.living()
	for i in battle.hand.size():
		var card: Dictionary = battle.hand[i]
		var view: CardView = hand.views.get(int(card.id))
		if view == null:
			continue
		var aimed := target if int(card.id) == selected_id and battle.needs_target(i) else -1
		view.show_card(card.key, card.upgraded, battle, aimed, card)
		view.show_cost(battle.cost_of(card))
		var at: int = (living[0] if not living.is_empty() else -1) if battle.needs_target(i) else -1
		view.set_playable(battle.refusal(i, at) == "" and not _locked and plays_here)


## The chosen card risen and glowing on every seat; the enemies the last seat's could go to outlined, the one aimed at marked, its
## preview on their bars.
func _refresh_selection():
	if battle == null or seats.is_empty():
		return
	_each_seat(_refresh_hand_choice)
	var was_at := _at
	var was_active := battle.active
	_at = clampi(_last_seat, 0, seats.size() - 1)
	battle.active = seats[_at].player
	_refresh_enemies_aimed()
	_at = was_at
	battle.active = was_active
	_refresh_cards()
	_aim_now()


## The seat in use's hand: its chosen card risen, the keys' card marked.
func _refresh_hand_choice():
	var index := selected_index()
	if index < 0:
		selected_id = -1
	hand.chosen = selected_id
	hand.focus = focus_id if keys_in_use and selected_id < 0 else -1
	for id in hand.views:
		hand.views[id].set_selected(id == selected_id)
	hand.layout()


## The enemies as the seat in use's chosen card would meet them: outlined, aimed at, its damage previewed on their bars.
func _refresh_enemies_aimed():
	var index := selected_index()
	var aiming := index >= 0 and battle.needs_target(index)
	var all := index >= 0 and _hits_all(index)
	for view in enemy_views:
		var state := 0
		if view.alive and aiming:
			state = 2 if view.who == target else 1
		elif view.alive and all:
			state = 2
		view.set_aim(state)
		var lost := 0
		if view.alive and ((aiming and view.who == target) or all):
			lost = battle.preview_damage(index, view.who)
		view.preview(lost)
	if aiming:
		_hint.text = "Choose an enemy for it (or press it again to put it back)."
	elif index >= 0:
		_hint.text = "Press it again to play it."
	else:
		_hint.text = ""


func _hits_all(index: int) -> bool:
	var definition := CardDatabase.card(battle.hand[index].key)
	return definition != null and definition.target == CardDefinition.Target.ALL_ENEMIES


## The arrow from the last seat's chosen card to the enemy it is aimed at (or the pointer, while it is over no one).
func _aim_now():
	if seats.is_empty() or battle == null:
		return
	var was_at := _at
	var was_active := battle.active
	_at = clampi(_last_seat, 0, seats.size() - 1)
	battle.active = seats[_at].player
	_aim_here()
	_at = was_at
	battle.active = was_active


func _aim_here():
	var index := selected_index()
	if index < 0 or not battle.needs_target(index) or _over:
		aim.stop()
		return
	var view: CardView = hand.views.get(selected_id)
	if view == null:
		aim.stop()
		return
	var start := hand.centre_of(selected_id) + Vector2(0, -CardView.SIZE.y * 0.45 * view.scale.y)
	var aimed: CardFighter = fighter(target) if target >= 0 else null
	if aimed != null and aimed.alive:
		aim.aim(start, aimed.centre(), aimed.rest_rect())
		return
	aim.aim(start, get_global_mouse_position(), Rect2())


func _stop_aiming():
	if aim != null:
		aim.stop()
	for view in enemy_views:
		view.set_aim(0)
		view.preview(0)
	if _hint != null:
		_hint.text = ""


## The living enemy under `at` (global), or -1.
func _enemy_at(at: Vector2) -> int:
	for view in enemy_views:
		if view.alive and view.rest_rect().has_point(at):
			return view.who
	return -1


func _refresh_end_glow():
	_each_seat(_refresh_end_glow_here)


## The seat in use's End Turn glowing while there is nothing left it could play.
func _refresh_end_glow_here():
	if end_button == null:
		return
	var nothing_to_play := battle != null and not battle.over and not _locked and not _over and not battle.hand.is_empty() \
		and _seat_plays_here(_at)
	if nothing_to_play:
		var living := battle.living()
		for i in battle.hand.size():
			if battle.refusal(i, (living[0] if not living.is_empty() else -1) if battle.needs_target(i) else -1) == "":
				nothing_to_play = false
				break
	if battle != null and battle.hand.is_empty() and not battle.over and not _locked and _seat_plays_here(_at):
		nothing_to_play = true
	end_button.disabled = battle == null or battle.over or _over or not _seat_plays_here(_at) \
		or (both_hands and bool(battle.players[seats[_at].player].down))
	if _end_glow_tween != null and _end_glow_tween.is_valid():
		_end_glow_tween.kill()
	if not nothing_to_play or not moves():
		_end_glow.modulate.a = 0.0
		return
	_end_glow_tween = _end_glow.create_tween().set_loops()
	_end_glow_tween.tween_property(_end_glow, "modulate:a", 1.0, 0.55).set_trans(Tween.TRANS_SINE)
	_end_glow_tween.tween_property(_end_glow, "modulate:a", 0.3, 0.55).set_trans(Tween.TRANS_SINE)


## --- Choosing and playing ---


## The chosen card's place in the rules' hand, or -1.
func selected_index() -> int:
	if battle == null or selected_id < 0:
		return -1
	for i in battle.hand.size():
		if int(battle.hand[i].id) == selected_id:
			return i
	return -1


func _index_of(id: int) -> int:
	for i in battle.hand.size():
		if int(battle.hand[i].id) == id:
			return i
	return -1


## Both hands at once: the seat in use is the rules' player now's (what the input chose with _use, or a suite's).
func _follow_active():
	if both_hands and battle != null:
		_at = _seat_of(battle.active)


## The card at `index` of the hand pressed: chosen; pressed again, played (one needing no enemy) or put back.
func choose_card(index: int):
	_follow_active()
	if battle == null or battle.over or index < 0 or index >= battle.hand.size() or not _seat_plays_here(_at):
		return
	_last_seat = _at
	var id := int(battle.hand[index].id)
	if selected_id == id:
		if battle.needs_target(index):
			selected_id = -1
		else:
			play_card(index, -1)
			return
		_refresh_selection()
		return
	var living := battle.living()
	var check := battle.refusal(index, (living[0] if not living.is_empty() else -1) if battle.needs_target(index) else -1)
	if check != "":
		_refuse(id, check)
		selected_id = -1
		_refresh_selection()
		return
	selected_id = id
	focus_id = id
	if battle.needs_target(index) and not living.has(target):
		target = living[0] if not living.is_empty() else -1
	_refresh_selection()


## Plays the card at `index` of the hand at enemy `who` (-1 for none). False if it could not be.
func play_card(index: int, who: int = -1) -> bool:
	_follow_active()
	if battle == null or not _seat_plays_here(_at):
		return false
	var check := battle.refusal(index, who)
	if check != "":
		if index >= 0 and index < battle.hand.size():
			_refuse(int(battle.hand[index].id), check)
		else:
			_say(check)
		return false
	selected_id = -1
	hand.chosen = -1
	_stop_aiming()
	# Done through the game (here at once, or in order over a network); a card that ends the turn (an enemy's Overtime) has the hand
	# wait for the enemies' turn to play out, as End Turn does (apply_move).
	if battle.together() or (game != null and game.networked()):
		return game.act(&"play", battle.active, [int(battle.hand[index].id), who])
	var turn_was := battle.turn
	var played := battle.play(index, who)
	if battle.turn != turn_was:
		_locked = true
		game.hide_keywords()
	_refresh_pair()
	return played


func enemy_pressed(i: int):
	_follow_active()
	if battle == null or battle.over or _locked:
		return
	var index := selected_index()
	if index < 0 or not battle.needs_target(index):
		return
	play_card(index, i)


func end_turn():
	_follow_active()
	if battle == null or battle.over or _locked or _over or not _seat_plays_here(_at):
		return
	# Two players: each says Ready instead, and the enemies act once both have.
	if battle.together():
		_ready_pressed()
		return
	_locked = true
	selected_id = -1
	hand.chosen = -1
	_stop_aiming()
	game.hide_keywords()
	CardFeel.sound(&"card_end_turn", -6.0)
	_say("--- The enemies' turn ---")
	battle.end_turn()
	_refresh_cards()
	_refresh_end_glow()


## A card that cannot be played: it shakes its head, the energy flashes red if that is why, and why shows over the hand.
func _refuse(id: int, why: String):
	var view: CardView = hand.views.get(id)
	if view != null:
		view.refuse()
	if why == "Not enough energy.":
		orb.refuse()
	bubble(why)
	_say(why)


## `text` over the hand for a moment.
func bubble(text: String):
	_bubble_label.text = text
	CardFeel.note(&"bubble")
	if not moves():
		return
	_bubble.visible = true
	_bubble.reset_size()
	var over_x := 640.0 if hand == null else hand.position.x + hand.size.x / 2.0
	_bubble.position = Vector2(over_x - _bubble.size.x / 2.0, HAND_AT.position.y - 8.0)
	if _bubble_tween != null and _bubble_tween.is_valid():
		_bubble_tween.kill()
	_bubble.modulate.a = 0.0
	_bubble_tween = _bubble.create_tween()
	_bubble_tween.set_ignore_time_scale(true)
	_bubble_tween.tween_property(_bubble, "modulate:a", 1.0, 0.1)
	_bubble_tween.tween_interval(1.1)
	_bubble_tween.tween_property(_bubble, "modulate:a", 0.0, 0.3)
	_bubble_tween.tween_callback(func(): _bubble.visible = false)


## An enemy pressed: for the card the last seat chose.
func _fighter_pressed(view: CardFighter):
	if both_hands:
		_use(_last_seat)
	enemy_pressed(view.who)


func _card_clicked(id: int, s: int = 0):
	if _locked or _over or not _seat_plays_here(s):
		return
	if both_hands:
		_use(s)
	keys_in_use = false
	var index := _index_of(id)
	if index >= 0:
		choose_card(index)


func _card_pointed(id: int, s: int = 0):
	if both_hands:
		_use(s)
	var view: CardView = hand.views.get(id) if id >= 0 else null
	if view == null:
		game.hide_keywords()
		return
	# Beside where it is rising to, not where it is on its way.
	var rest := hand.rest_of(id)
	var area := CardView.SIZE * float(rest.scale)
	game.show_keywords(view, Rect2(hand.global_position + rest.at - area / 2.0, area))


func _drag_started(id: int, s: int = 0):
	if _locked or _over or not _seat_plays_here(s):
		return
	if both_hands:
		_use(s)
	_last_seat = _at
	var index := _index_of(id)
	if index < 0:
		return
	keys_in_use = false
	var living := battle.living()
	var check := battle.refusal(index, (living[0] if not living.is_empty() else -1) if battle.needs_target(index) else -1)
	if check != "":
		_refuse(id, check)
		return
	_dragging = id
	selected_id = id
	if battle.needs_target(index):
		hand.hold(id, global_position + HOLD_SPOT, 1.05)
		target = -1
	_refresh_selection()
	game.hide_keywords()


func _dragged(id: int, at: Vector2, s: int = 0):
	if both_hands:
		_use(s)
	if _dragging != id:
		return
	var index := _index_of(id)
	if index < 0:
		return
	if battle.needs_target(index):
		var over := _enemy_at(at)
		if over != target:
			target = over
			_refresh_selection()
		var start := hand.centre_of(id) + Vector2(0, -CardView.SIZE.y * 0.5)
		if over >= 0:
			aim.aim(start, fighter(over).centre(), fighter(over).rest_rect())
		else:
			aim.aim(start, at, Rect2())
	else:
		hand.hold(id, at, 1.05)


func _drag_ended(id: int, at: Vector2, s: int = 0):
	if both_hands:
		_use(s)
	if _dragging != id:
		return
	_dragging = -1
	var index := _index_of(id)
	hand.release(id)
	if index < 0:
		return
	if battle.needs_target(index):
		var over := _enemy_at(at)
		if over >= 0:
			target = over
			play_card(index, over)
			return
	elif at.y < hand.global_position.y + 30.0:
		play_card(index, -1)
		return
	# Let go nowhere it could be played: back into the hand.
	selected_id = -1
	_refresh_selection()


## --- Keys and a pad ---


func _unhandled_input(event: InputEvent):
	if battle == null or _over or game == null or game._overlay != null or game.view != "battle":
		return
	if event.is_echo():
		return
	var press: bool = event is InputEventKey and event.pressed and event.keycode >= KEY_1 and event.keycode <= KEY_9
	for action in [&"end_turn", &"ui_accept", &"ui_cancel", &"ui_left", &"ui_right", &"swap_leader"]:
		if event.is_action_pressed(action):
			press = true
	if not press:
		return
	if _locked:
		_early = {"event": event, "at": Time.get_ticks_msec()}
		return
	if _key(event):
		get_viewport().set_input_as_handled()


## A key pressed while the hand waited, acted on now if it was pressed in the wait's last moment.
func _take_early_press():
	if _early.is_empty():
		return
	var event: InputEvent = _early.event
	var late := Time.get_ticks_msec() - int(_early.at) <= int(EARLY_SECONDS * 1000.0)
	_early = {}
	if late:
		_key(event)


## What a key does in a fight; whether it did anything. Both hands at once: on the hand of the player whose device pressed it
## (CardGame.player_of_event; a device nobody's, the last hand used).
func _key(event: InputEvent) -> bool:
	if both_hands:
		var p := game.player_of_event(event) if game != null else -1
		if p == CardGame.NOBODY_HERE:
			return false
		if p < 0:
			# Over a network every device here is this machine's player's; on one screen with nothing shared out, the last hand used.
			p = int(game.local_players[0]) if game != null and game.networked() and not game.local_players.is_empty() \
				else seats[clampi(_last_seat, 0, seats.size() - 1)].player
		if not _seat_plays_here(_seat_of(p)):
			return false
		_use(_seat_of(p))
		_last_seat = _at
	if event.is_action_pressed(&"end_turn"):
		end_turn()
		return true
	if event.is_action_pressed(&"swap_leader") and battle.together():
		swap_hands()
		return true
	if event is InputEventKey and event.keycode >= KEY_1 and event.keycode <= KEY_9:
		keys_in_use = true
		var nth: int = event.keycode - KEY_1
		if nth < hand.order.size():
			choose_card(_index_of(int(hand.order[nth])))
		return true
	var index := selected_index()
	var aiming := index >= 0 and battle.needs_target(index)
	if event.is_action_pressed(&"ui_left") or event.is_action_pressed(&"ui_right"):
		var way := -1 if event.is_action_pressed(&"ui_left") else 1
		keys_in_use = true
		if aiming:
			var living := battle.living()
			if not living.is_empty():
				var at := living.find(target)
				target = living[posmod(at + way, living.size())]
		elif not hand.order.is_empty():
			selected_id = -1
			var at := hand.order.find(focus_id)
			focus_id = int(hand.order[posmod(at + way if at >= 0 else 0, hand.order.size())])
			var view: CardView = hand.views.get(focus_id)
			if view != null:
				game.show_keywords(view)
		_refresh_selection()
		return true
	if event.is_action_pressed(&"ui_accept"):
		keys_in_use = true
		if aiming:
			play_card(index, target)
		elif index >= 0:
			play_card(index, -1)
		elif focus_id >= 0:
			choose_card(_index_of(focus_id))
		elif not hand.order.is_empty():
			focus_id = int(hand.order[0])
			_refresh_selection()
		return true
	if event.is_action_pressed(&"ui_cancel") and selected_id >= 0:
		selected_id = -1
		_refresh_selection()
		return true
	return false


## --- The piles, the log ---


func _show_pile(which: StringName, s: int = 0):
	if battle == null or game == null:
		return
	if both_hands:
		_use(s)
	var cards: Array = []
	var title := ""
	match which:
		&"draw":
			# In no particular order: what is next is not to be known.
			cards = battle.draw_pile.duplicate()
			cards.sort_custom(func(a, b): return str(a.key) < str(b.key))
			title = "The Draw Pile (%d)" % cards.size()
		&"discard":
			cards = battle.discard_pile.duplicate()
			title = "The Discard Pile (%d)" % cards.size()
		_:
			cards = battle.exhaust_pile.duplicate()
			title = "Exhausted (%d)" % cards.size()
	game.show_cards(title, cards)


func _player_health(_now: int, _most: int):
	if game != null:
		game.refresh_health()


func _say(text: String):
	_log.append(text)
	if _log_label != null:
		_log_label.text = "\n".join(_log.slice(maxi(_log.size() - 9, 0)))


## --- A blow's weight ---


## Shakes the fight `pixels` (as the Screen shake dial allows), settling quickly.
func shake_by(pixels: float):
	_shake = maxf(_shake, pixels * Comfort.share(Comfort.SHAKE))


## The screen stops for `seconds` (real time): a blow's weight. Never headless.
func _stop(seconds: float):
	if seconds <= 0.0 or not moves():
		return
	CardFeel.note(&"stopped")
	_stops += 1
	Engine.time_scale = 0.0
	get_tree().create_timer(seconds, true, false, true).timeout.connect(CardStage._stop_over)


static func _stop_over():
	_stops = maxi(_stops - 1, 0)
	if _stops == 0:
		Engine.time_scale = SLOW_SHARE if _slowed > 0 else 1.0


## The world slows to `share` for `seconds` (real time): a last blow. Not for anybody who has turned it off (Comfort).
func _slow_motion(seconds: float, share: float):
	if not moves() or not Comfort.slow_motion():
		return
	CardFeel.note(&"slowed")
	_slowed += 1
	if _stops == 0:
		Engine.time_scale = share
	get_tree().create_timer(seconds, true, false, true).timeout.connect(CardStage._slow_over)


static func _slow_over():
	_slowed = maxi(_slowed - 1, 0)
	if _slowed == 0 and _stops == 0:
		Engine.time_scale = 1.0


func _process(delta: float):
	if _world != null:
		if _shake > 0.2:
			_world.position = Vector2(_shake_rng.randf_range(-1.0, 1.0), _shake_rng.randf_range(-1.0, 1.0)) * _shake
			_shake *= exp(-delta * 16.0)
		elif _world.position != Vector2.ZERO:
			_shake = 0.0
			_world.position = Vector2.ZERO
	if battle == null or seats.is_empty():
		return
	# With the mouse, the last seat's chosen card's arrow follows the pointer, and pointing at an enemy aims it there.
	var was_at := _at
	var was_active := battle.active
	if both_hands:
		_at = clampi(_last_seat, 0, seats.size() - 1)
		battle.active = seats[_at].player
	var index := selected_index()
	if index >= 0 and battle.needs_target(index) and _dragging < 0 and not keys_in_use and not _locked:
		var over := _enemy_at(get_global_mouse_position())
		if over != target:
			target = over
			_refresh_selection()
		else:
			_aim_now()
	_at = was_at
	battle.active = was_active
	# A heartbeat in the hands, and a faint pulse at the edges, while near death (the shown player's; with both hands, the worse off).
	var mine: CardFighter = player_views[shown] if shown >= 0 and shown < player_views.size() else player_view
	if both_hands:
		for view in player_views:
			if view.alive and view.max_hp > 0 and (mine == null or float(view.hp) / float(view.max_hp) < float(mine.hp) / maxf(float(mine.max_hp), 1.0)):
				mine = view
	if battle != null and not battle.over and battle.player.max_hp > 0 and mine != null and mine.max_hp > 0 \
			and float(mine.hp) / float(mine.max_hp) <= CardFeel.NEAR_DEATH and mine.hp > 0:
		var real := delta / maxf(Engine.time_scale, 0.05)
		Rumble.heartbeat(real)
		_heart -= real
		if _heart <= 0.0:
			_heart = Rumble.HEART_EVERY
			if moves():
				vignette.flare(HURT, 0.3)


## What an enemy's intent means, in words, for its tooltip.
static func intent_words(intent: Dictionary) -> String:
	if intent.get("hidden", false):
		return "You cannot tell what it will do."
	if intent.get("asleep", false):
		return "Asleep: it does nothing this turn."
	var parts: Array[String] = []
	var damage := int(intent.get("damage", 0))
	var hits := int(intent.get("hits", 1))
	var helps := int(intent.get("helps", 0))
	var for_whom: String = ["", " for its worst hurt ally", " for its whole side"][clampi(helps, 0, 2)]
	if damage > 0:
		parts.append("attack for %d%s" % [damage, (" %d times" % hits) if hits > 1 else ""])
	if int(intent.get("block", 0)) > 0:
		parts.append(("curl up behind Block" if intent.get("curled", false) else "gain Block") + for_whom)
	if int(intent.get("heal", 0)) > 0:
		parts.append("mend %d%s" % [int(intent.heal), for_whom])
	var apply: StringName = intent.get("apply", &"")
	if apply != &"":
		parts.append("give you %s" % CardStatus.name_of(apply))
	var gain: StringName = intent.get("gain", &"")
	if gain != &"":
		parts.append(("grow stronger (%s)" % CardStatus.name_of(gain)) if helps == 0 else ("give %s%s" % [CardStatus.name_of(gain), for_whom]))
	var adds := str(intent.get("adds", ""))
	if adds != "":
		var card := CardDatabase.card(adds)
		parts.append("put %s in your deck" % (card.name if card != null else adds))
	if int(intent.get("steals", 0)) > 0:
		parts.append("take %d of your cards" % int(intent.steals))
	if intent.get("summons", false):
		parts.append("call for help")
	var ties := str(intent.get("ties", ""))
	if ties != "":
		var tether := CardDatabase.card(ties)
		parts.append("tie its %s to you (hit it to break it)" % (tether.name if tether != null else "Tether"))
	if int(intent.get("cuts", 0)) > 0:
		parts.append("cut %d of your Tethers" % int(intent.cuts))
	var name_said := str(intent.get("name", ""))
	var said := ""
	if parts.is_empty():
		said = name_said if name_said != "" else "Nothing known."
	else:
		said = ", ".join(parts)
		said = said.substr(0, 1).to_upper() + said.substr(1)
		said = "%s: %s." % [name_said, said] if name_said != "" else said + "."
	var countdown := int(intent.get("countdown", 0))
	if countdown > 0:
		said += " It lands in %d turn%s." % [countdown, "" if countdown == 1 else "s"]
	var then = intent.get("then")
	if then is Dictionary and not then.is_empty():
		said += "\nThen, unless the fight changes its mind: %s" % intent_words(then)
	return said
