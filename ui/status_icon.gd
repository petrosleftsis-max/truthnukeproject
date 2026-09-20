extends PanelContainer
## One party member's portrait in the column down the left of the HUD.

## Health bar colours, matching the turn queue and the battle selector's party
## panel - amber below a third, so a bar means the same thing everywhere it
## appears.
const HEALTH_FULL := Color("6fb26a")
const HEALTH_HURT := Color("c8913f")
const HURT_BELOW := 0.34


func set_icon(texture: Texture2D):
	$Icon.texture = texture


## The numbers and a bar underneath them. The numbers alone were exact but
## needed reading; the bar is the one that survives being glanced at while
## something else has your attention.
func set_health(hp: int, hp_max: int):
	$Icon/HealthText.text = "{0}/{1}".format([hp, hp_max])
	$Icon/Health.max_value = maxi(hp_max, 1)
	$Icon/Health.value = clampi(hp, 0, maxi(hp_max, 1))
	var fill := $Icon/Health.get_theme_stylebox("fill") as StyleBoxFlat
	if fill == null:
		return
	var fraction = 0.0 if hp_max <= 0 else float(hp) / float(hp_max)
	fill.bg_color = HEALTH_FULL if fraction > HURT_BELOW else HEALTH_HURT
