extends TextureRect
## One face in the turn queue.
##
## Three things have to be readable at a glance from this strip: whose turn it
## is right now, who has already gone, and which side each of them is on.
## Before, only the last of those was shown - the border colour - so the queue
## said who was in the fight but not where in it you were.

## Palette, matching ui/blue_theme.tres and the battle selector.
const SIDE_PLAYER := Color("4a86c8")
const SIDE_ENEMY := Color("c05a5a")
## The one whose turn it is: brighter, and ringed in the accent.
const CURRENT_RING := Color("7fb4ea")
## Everyone who has already acted this round fades back, so the queue reads as
## "what is left to happen" rather than a flat list.
const SPENT_ALPHA := 0.4

var max_hp: int
var hp: int

var _is_current := false


func set_max_hp(max_hp: int):
	$Deadness.max_value = max_hp
	self.max_hp = max_hp
	update_deadness()


func set_hp(hp: int):
	self.hp = hp
	update_deadness()


func update_deadness():
	var deadness_value = max_hp - hp
	$Deadness.value = deadness_value


func set_side(side: int):
	$Border.modulate = CURRENT_RING if _is_current else (SIDE_PLAYER if side == 0 else SIDE_ENEMY)


func set_turn_taken(taken: bool):
	# Read off the node each time rather than cached at ready. The queue
	# is now refreshed on every turn change, which can reach an icon before its
	# _ready has run - and a cached null there is a hard error, not a no-op.
	var shader_material := material as ShaderMaterial
	if shader_material != null:
		shader_material.set_shader_parameter("color_factor", int(taken))
	# The greyscale shader already says "spent"; dropping the opacity as well
	# makes the difference survive being glanced at rather than looked at.
	modulate.a = SPENT_ALPHA if taken and not _is_current else 1.0


## Marks this as the combatant currently acting. Scaled up as well as ringed,
## because on a row of same-sized faces a colour change alone is easy to miss.
func set_current(current: bool, side: int):
	_is_current = current
	scale = Vector2(1.15, 1.15) if current else Vector2.ONE
	set_side(side)
	if current:
		modulate.a = 1.0
