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


## The number says what happened (MoveFeel - PROPOSAL values): as big again,
## at most, for a blow that took a whole health bar...
const MOST_GROWTH := 0.6
## ...a word under it for a graze...
const TAG_SIZE := 22
## ...a crack across it for a blow resisted, and a jagged star behind it,
## brighter, for one they are weak to.
const VULNERABLE_LIGHTEN := 0.3


## Puts `text` above `world_position` and lets it drift up and fade.
##
## `parent` should be whatever the combatant sprites themselves hang off, so
## the number shares their coordinate space and scrolls with the map.
##
## `how` says what happened (MoveFeel): "share" (of their health, 0 to 1) makes
## it bigger, "graze" puts the word under it, "resisted" cracks it and
## "vulnerable" makes it brighter, on a jagged star.
static func spawn(parent: Node, world_position: Vector2, text: String, colour: Color, how: Dictionary = {}) -> FloatingNumber:
	if parent == null or not is_instance_valid(parent):
		return null
	var floater = FloatingNumber.new()
	floater.position = world_position
	floater.z_as_relative = false
	floater.z_index = Z
	var grown := 1.0 + MOST_GROWTH * clampf(float(how.get("share", 0.0)), 0.0, 1.0)
	floater.scale = Vector2.ONE * grown
	if how.get("vulnerable", false):
		colour = colour.lightened(VULNERABLE_LIGHTEN)
		floater.add_child(_Mark.new(true, colour))
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", colour.darkened(0.25) if how.get("resisted", false) else colour)
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
	if how.get("resisted", false):
		floater.add_child(_Mark.new(false, colour))
	if how.get("graze", false):
		var tag := Label.new()
		tag.text = "Graze"
		tag.add_theme_font_size_override("font_size", TAG_SIZE)
		tag.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		tag.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		tag.add_theme_constant_override("outline_size", 6)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.size = Vector2(Grid.TILE_SIZE * 2, TAG_SIZE * 1.4)
		tag.position = Vector2(-Grid.TILE_SIZE, FONT_SIZE * 0.45)
		floater.add_child(tag)
	parent.add_child(floater)
	floater._float_away()
	return floater


## What is drawn with the number: a crack across it (resisted), or a jagged
## star behind it (vulnerable).
class _Mark extends Node2D:
	var star := false
	var tint := Color.WHITE

	func _init(behind: bool, colour: Color):
		star = behind
		tint = colour
		show_behind_parent = behind
		z_index = -1 if behind else 1

	func _draw():
		var size := float(FloatingNumber.FONT_SIZE)
		var middle := Vector2(0.0, -size * 0.3)
		if star:
			var points := PackedVector2Array()
			for i in 16:
				points.append(middle + Vector2.from_angle(TAU * float(i) / 16.0) * size * (1.15 if i % 2 == 0 else 0.7) * Vector2(1.3, 0.9))
			draw_colored_polygon(points, Color(tint.darkened(0.55), 0.75))
			draw_polyline(points + PackedVector2Array([points[0]]), Color(tint, 0.9), 3.0)
		else:
			var crack := PackedVector2Array([middle + Vector2(-size * 0.5, -size * 0.3), middle + Vector2(-size * 0.2, -size * 0.05),
				middle + Vector2(size * 0.05, -size * 0.25), middle + Vector2(size * 0.3, size * 0.15), middle + Vector2(size * 0.7, size * 0.3)])
			draw_polyline(crack, Color(0, 0, 0, 0.75), 3.0)
			draw_polyline(crack, Color(1, 1, 1, 0.6), 1.0)


func _float_away():
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - RISE, LIFETIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	# Held at full opacity for the first half, so the number is readable before
	# it starts going anywhere.
	tween.tween_property(self, "modulate:a", 0.0, LIFETIME * 0.5).set_delay(LIFETIME * 0.5)
	tween.chain().tween_callback(queue_free)
