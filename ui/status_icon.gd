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

## The gold the map rings somebody in while their portrait is pointed at: the
## portrait lights up in the same colour, so the two read as one.
const HOVER_EDGE := Color(1.0, 0.84, 0.35, 0.95)

## Whether it lights up under the cursor. Only the party column's portraits
## do - those are the ones a click does something with; the big one beside the
## skills is the one acting, not a button.
var lights_on_hover := false:
	set(value):
		lights_on_hover = value
		if not value:
			_light(false)


## Asked for the tooltip each time one is about to show, so it can say what a
## click on the portrait would do right now. Unset, it is tooltip_text.
var tip_source: Callable


func _ready():
	mouse_entered.connect(func(): _light(lights_on_hover))
	mouse_exited.connect(_light.bind(false))


func _get_tooltip(_at_position: Vector2) -> String:
	return tip_source.call() if tip_source.is_valid() else tooltip_text


## Whether it is lit up under the cursor right now.
func is_lit() -> bool:
	return has_theme_stylebox_override("panel")


func _light(on: bool):
	remove_theme_stylebox_override("panel")
	if not on:
		return
	var base := get_theme_stylebox("panel")
	var lit: StyleBox = base.duplicate() if base != null else StyleBoxFlat.new()
	if lit is StyleBoxFlat:
		lit.border_color = HOVER_EDGE
		lit.set_border_width_all(2)
		lit.bg_color = lit.bg_color.lightened(0.08)
	add_theme_stylebox_override("panel", lit)


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
