extends Node2D
class_name FloatingNumber
## A number that rises off a combatant and fades - the damage they just took,
## the healing they just got.
##
## The combat log already carries every number, but it is off at the side of
## the screen and scrolls: on a board this size a hit registers as a health bar
## twitching somewhere you weren't looking. Putting the number where the hit
## happened is the single cheapest way to make a skill read.
##
## Built in code rather than as a scene because it is one label and one tween,
## and a scene file would be one more thing to keep in step with the tile size.


## How far it climbs, and how long it takes. Just under a tile of travel, so a
## number never drifts far enough to be mistaken for the combatant above.
const RISE = Grid.TILE_SIZE * 0.7
const LIFETIME = 0.85

## Big, because the map is usually looked at zoomed out. At 192px tiles and a
## 0.5 zoom this is still comfortably readable.
const FONT_SIZE = 44
const OUTLINE = 10

## Above every combatant (the party tops out at 20 - see the exploration line)
## so a number is never hidden behind whoever it belongs to.
const Z = 100


## Puts `text` above `world_position` and lets it drift up and fade.
##
## `parent` should be whatever the combatant sprites themselves hang off, so
## the number shares their coordinate space and scrolls with the map.
static func spawn(parent: Node, world_position: Vector2, text: String, colour: Color) -> FloatingNumber:
	if parent == null or not is_instance_valid(parent):
		return null
	var floater = FloatingNumber.new()
	floater.position = world_position
	floater.z_as_relative = false
	floater.z_index = Z
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", colour)
	# A heavy dark outline is what keeps a light number legible over pale
	# terrain and a dark one legible over grass, without knowing either.
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", OUTLINE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Centred over the tile by hand: a Label sizes itself after it is in the
	# tree, so its width isn't known yet. A generous fixed box costs nothing
	# and keeps short and long numbers on the same centre line.
	label.size = Vector2(Grid.TILE_SIZE * 2, FONT_SIZE * 1.4)
	label.position = Vector2(-Grid.TILE_SIZE, -FONT_SIZE)
	floater.add_child(label)
	parent.add_child(floater)
	floater._float_away()
	return floater


func _float_away():
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - RISE, LIFETIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	# Held at full opacity for the first half, so the number is readable before
	# it starts going anywhere.
	tween.tween_property(self, "modulate:a", 0.0, LIFETIME * 0.5).set_delay(LIFETIME * 0.5)
	tween.chain().tween_callback(queue_free)
