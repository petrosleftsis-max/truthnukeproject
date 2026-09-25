class_name GameFonts
## The game's two typefaces: Alegreya Sans for everything, and Cinzel - Roman
## inscription capitals - for names, headings, speakers and the turn banner.
## Both are SIL Open Font License; the licences sit beside them in res://fonts.
##
## Put on the project theme when the game starts rather than written into
## ui/blue_theme.tres. Godot loads the project theme before it imports anything,
## so on a fresh clone - nothing imported yet - a theme naming these files
## failed to load, and importing the fonts then crashed the editor outright. By
## the time any scene runs they are imported, so this is always safe.

const BODY := "res://fonts/AlegreyaSans-Regular.ttf"
const DISPLAY := "res://fonts/cinzel_semibold.tres"

## The theme type a Label takes to be set in the display face:
## `label.theme_type_variation = GameFonts.HEADER`.
const HEADER := &"HeaderLabel"


## Dresses the project theme in both faces. Called once, by an autoload.
static func apply() -> void:
	var theme := ThemeDB.get_project_theme()
	if theme == null:
		return
	var body = load(BODY)
	if body is Font:
		theme.default_font = body
	var display = display_font()
	if display != null:
		theme.set_type_variation(HEADER, &"Label")
		theme.set_font(&"font", HEADER, display)


## The display face, for the odd control that is not a Label and so cannot
## take HEADER - the speaker's name in dialogue is a RichTextLabel.
static func display_font() -> Font:
	var display = load(DISPLAY)
	return display if display is Font else null
