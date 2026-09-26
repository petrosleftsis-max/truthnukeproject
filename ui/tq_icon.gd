extends TextureRect
## One face in the turn queue.
##
## Four things have to be readable at a glance from this strip: whose turn it
## is right now, who has already gone, which side each of them is on, and how
## much fight is left in them.

## Palette, matching ui/blue_theme.tres and the battle selector.
const SIDE_PLAYER := Color("4a86c8")
const SIDE_ENEMY := Color("c05a5a")
## The one whose turn it is: brighter, and ringed in the accent.
const CURRENT_RING := Color("7fb4ea")
## Everyone who has already acted this round fades back, so the queue reads as
## "what is left to happen" rather than a flat list.
const SPENT_ALPHA := 0.4

## Health bar colours, by how much is left. Amber below a third, which is
## roughly "one more hit could do it" - the same thresholds the battle
## selector's party panel uses, so a bar means the same thing everywhere.
const HEALTH_FULL := Color("6fb26a")
const HEALTH_HURT := Color("c8913f")
const HURT_BELOW := 0.34

## The gold the map rings somebody in while their face is pointed at: the face
## lights up in the same colour, so the two read as one.
const HOVER_EDGE := Color(1.0, 0.84, 0.35, 1.0)

var max_hp: int
var hp: int

var _is_current := false
var _side := 0
var _taken := false
var _hovered := false

## Asked for the tooltip each time one is about to show, so it can say what a
## click on the face would do right now. Unset, it is tooltip_text.
var tip_source: Callable


func _ready():
	mouse_entered.connect(set_hovered.bind(true))
	mouse_exited.connect(set_hovered.bind(false))


func _get_tooltip(_at_position: Vector2) -> String:
	return tip_source.call() if tip_source.is_valid() else tooltip_text


## Lit under the cursor: ringed in gold, and at full strength even if they
## have already acted, so the face being pointed at is never the faded one.
func set_hovered(on: bool):
	_hovered = on
	set_side(_side)
	_apply_alpha()


func is_hovered() -> bool:
	return _hovered


func set_max_hp(max_hp: int):
	$Health.max_value = maxi(max_hp, 1)
	self.max_hp = max_hp
	_refresh_health()


func set_hp(hp: int):
	if self.hp > hp:
		HealthBarMarks.drain($Health, self.hp, hp, maxi(max_hp, 1))
	self.hp = hp
	_refresh_health()


## What an aimed skill would do to them - see HealthBarMarks.
func show_change(change: int):
	HealthBarMarks.show_preview($Health, hp, change, maxi(max_hp, 1))


func clear_change():
	HealthBarMarks.clear_preview($Health)


## A bar along the bottom of the face rather than the red wash this used to
## paint over the portrait: the wash said "hurt" but never how badly, and it
## obscured the one thing the icon exists to show.
func _refresh_health():
	$Health.value = clampi(hp, 0, maxi(max_hp, 1))
	var fill := $Health.get_theme_stylebox("fill") as StyleBoxFlat
	if fill == null:
		return
	var fraction = 0.0 if max_hp <= 0 else float(hp) / float(max_hp)
	fill.bg_color = HEALTH_FULL if fraction > HURT_BELOW else HEALTH_HURT


func set_side(side: int):
	_side = side
	if _hovered:
		$Border.modulate = HOVER_EDGE
	else:
		$Border.modulate = CURRENT_RING if _is_current else (SIDE_PLAYER if side == 0 else SIDE_ENEMY)


func set_turn_taken(taken: bool):
	# Read off the node each time rather than cached at ready. The queue is
	# refreshed on every turn change, which can reach an icon before its _ready
	# has run - and a cached null there is a hard error, not a no-op.
	var shader_material := material as ShaderMaterial
	if shader_material != null:
		shader_material.set_shader_parameter("color_factor", int(taken))
	# The greyscale shader already says "spent"; dropping the opacity as well
	# makes the difference survive being glanced at rather than looked at.
	_taken = taken
	_apply_alpha()


func _apply_alpha():
	modulate.a = SPENT_ALPHA if _taken and not _is_current and not _hovered else 1.0


## Marks this as the combatant currently acting. Scaled up as well as ringed,
## because on a row of same-sized faces a colour change alone is easy to miss.
func set_current(current: bool, side: int):
	_is_current = current
	scale = Vector2(1.15, 1.15) if current else Vector2.ONE
	# The condition marks under the face keep their size either way - scaled up
	# with it, they reached under the next face along.
	var marks = get_node_or_null("Conditions")
	if marks != null:
		marks.scale = Vector2.ONE / scale
	set_side(side)
	_apply_alpha()
