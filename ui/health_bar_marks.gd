class_name HealthBarMarks
## Two marks laid over a health bar, for the turn queue's faces and the party's
## portraits alike.
##
## The preview: while a skill is being aimed, the stretch of the bar the hit
## would take away, so the damage is seen where the health is rather than only
## read off a prompt. And the drain: when health is lost, the bar drops at once
## - its value always says exactly what is left - and a strip where the lost
## health was fades back to the new end over a moment, so a hit reads as a hit
## rather than a number changing.

const PREVIEW_LOSS := Color(1.0, 0.36, 0.32, 0.9)
const PREVIEW_GAIN := Color(0.55, 0.95, 0.6, 0.75)
const DRAIN := Color(0.95, 0.8, 0.45, 0.85)
const DRAIN_HOLD := 0.25
const DRAIN_TIME := 0.45


## Marks the stretch of `bar` that `change` would take off (negative) or put
## back (positive) from `hp`, out of `most`.
static func show_preview(bar: ProgressBar, hp: int, change: int, most: int):
	clear_preview(bar)
	if bar == null or change == 0 or most <= 0:
		return
	var after = clampi(hp + change, 0, most)
	var from = float(mini(hp, after)) / float(most)
	var to = float(maxi(hp, after)) / float(most)
	var mark := _strip(bar, "Preview", from, to, PREVIEW_LOSS if change < 0 else PREVIEW_GAIN)
	# A slow pulse, so the prompt's number and the bar are seen to be one thing.
	var pulse := mark.create_tween().set_loops()
	pulse.tween_property(mark, "modulate:a", 0.45, 0.45)
	pulse.tween_property(mark, "modulate:a", 1.0, 0.45)


static func clear_preview(bar: ProgressBar):
	if bar == null:
		return
	var mark = bar.get_node_or_null("Preview")
	if mark != null:
		bar.remove_child(mark)
		mark.queue_free()


## Health fell from `before` to `after`, out of `most`: the strip where it was,
## fading down to the new end of the bar.
static func drain(bar: ProgressBar, before: int, after: int, most: int):
	if bar == null or after >= before or most <= 0 or not bar.is_inside_tree():
		return
	var old = bar.get_node_or_null("Drain")
	if old != null:
		bar.remove_child(old)
		old.queue_free()
	var from = float(clampi(after, 0, most)) / float(most)
	var to = float(clampi(before, 0, most)) / float(most)
	var strip := _strip(bar, "Drain", from, to, DRAIN)
	var tween := strip.create_tween()
	tween.tween_interval(DRAIN_HOLD)
	tween.tween_property(strip, "size:x", 0.0, DRAIN_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(strip.queue_free)


static func _strip(bar: ProgressBar, called: String, from: float, to: float, colour: Color) -> ColorRect:
	var strip := ColorRect.new()
	strip.name = called
	strip.color = colour
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.position = Vector2(bar.size.x * from, 0)
	strip.size = Vector2(maxf(bar.size.x * (to - from), 1.0), bar.size.y)
	bar.add_child(strip)
	return strip
