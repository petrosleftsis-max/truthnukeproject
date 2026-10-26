@icon("res://art/editor_icons/familiar_form.svg")
extends Resource
class_name FamiliarForm
## The animal a familiar takes on a map (Find Familiar - see StealthWatch
## "Familiar"): a rat in the sewers, a cat in the streets, a raven out of doors.
## A StealthSetup names one for its map; a map that names none gets the rat.
##
## What it looks like is a guard's business only close up - an animal about
## the place is nothing to look twice at - so a guard makes it out only within
## Noticed Within; a hound smells it as ever; and a magic sensor knows it for
## what it is.

## What it is called in the log and on the bar.
@export var name: String = "Rat"
@export_multiline var description: String = ""

@export_group("Body")
## Tiny or Small: either fits through a gap nothing bigger does (a grate, a
## drain, a hole under a fence - ExplorationScene "Small gaps").
@export var size: Sizes.Size = Sizes.Size.TINY
## How it gets about: on the ground, or flying - over whatever stops only
## walkers (Blocks without 1 in it), the way a flier crosses it in a fight.
@export_enum("Ground", "Flying") var movement_class: int = 0
## How fast it goes, as a share of the party's walking pace.
@export_range(0.25, 3.0, 0.05) var speed: float = 1.3

@export_group("Being seen")
## How close a guard has to be to make it out at all, in tiles - however far
## he can see anybody else.
@export_range(0.5, 10.0, 0.25) var noticed_within: float = 2.0

@export_group("Look")
## Its walking animation, when it has one ("walk" and "idle")...
@export var sprite_frames: SpriteFrames
## ...or a still - and with neither, a small shape in Colour.
@export var texture: Texture2D
@export var colour: Color = Color("8a7f74")
