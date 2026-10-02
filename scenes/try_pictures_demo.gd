extends Control
## The point-and-click demo, on the title screen as Clues Demo: Captain Vell's
## office, to try everything a picture can do - clues and the journal (J),
## working things out, showing somebody what you found, a lock to crack, a
## torn letter to piece together, things to put together and a lens to look
## through. Open this and press F6 to go straight to it.
##
## Built in pictures/clues_*.tscn, with its clues in res://clues/ and its
## conversation in Dialogue/clues_demo.dialogue. Closing the last picture goes
## back to the title screen.

const OFFICE := "res://pictures/clues_office.tscn"


func _ready():
	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.07, 0.09)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	Campaign.reset()
	Campaign.set_party(["cyrus"])
	Campaign.empty_inventory("cyrus")
	await get_tree().process_frame
	await Pictures.open(OFFICE)
	if is_inside_tree():
		Campaign.to_main_menu()
