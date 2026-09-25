extends PanelContainer
## One party member's portrait: in the column down the left of the HUD, and the
## large one beside the skills. The face on top, and who it is and how they are
## doing written underneath it rather than across the art.

## Health bar colours, matching the turn queue and the battle selector's party
## panel - amber below a third, so a bar means the same thing everywhere it
## appears.
const HEALTH_FULL := Color("6fb26a")
const HEALTH_HURT := Color("c8913f")
const HURT_BELOW := 0.34

var _hp := -1


func set_icon(texture: Texture2D):
	$Layout/Icon.texture = texture


## Who this is, under the face. Empty hides the line.
func set_name_text(text: String):
	$Layout/Name.text = text
	$Layout/Name.visible = text != ""


## The numbers and a bar underneath them. The numbers alone were exact but
## needed reading; the bar is the one that survives being glanced at while
## something else has your attention.
func set_health(hp: int, hp_max: int):
	var bar: ProgressBar = $Layout/Health
	$Layout/HealthText.text = "{0}/{1}".format([hp, hp_max])
	if _hp > hp:
		HealthBarMarks.drain(bar, _hp, hp, maxi(hp_max, 1))
	_hp = hp
	bar.max_value = maxi(hp_max, 1)
	bar.value = clampi(hp, 0, maxi(hp_max, 1))
	var fill := bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill == null:
		return
	var fraction = 0.0 if hp_max <= 0 else float(hp) / float(hp_max)
	fill.bg_color = HEALTH_FULL if fraction > HURT_BELOW else HEALTH_HURT


## What an aimed skill would do to them - see HealthBarMarks.
func show_change(change: int):
	var bar: ProgressBar = $Layout/Health
	HealthBarMarks.show_preview(bar, int(bar.value), change, int(bar.max_value))


func clear_change():
	HealthBarMarks.clear_preview($Layout/Health)
