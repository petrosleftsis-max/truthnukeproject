@tool
extends Resource
class_name FloorDefinition
## One floor of a map with more than one (EncounterDefinition.floors): an area of
## the terrain, painted where it is like any other, that lies over - or under -
## the others (Combat "Heights"). Its cells are its floor; anywhere in its Region
## left unpainted is open air, which a line of sight can pass down through and
## anybody can drop down off the edge into.
##
## Every floor is laid over the same ground: Over says where its Region's top
## left corner sits over the bottom floor, in the bottom floor's own tiles. The
## bottom floor is Over its own Region's corner.

## As the floor buttons say it: "Ground", "Gallery".
@export var name: String = ""
## The tiles of the map that are this floor.
@export var region: Rect2i = Rect2i()
## How high it is: 0 the bottom, 1 a storey above, and so on. A line of sight
## from one floor to another passes every floor between; range across is the
## distance plus a step for every storey.
@export_range(0, 4, 1) var level: int = 0
## Where the top left of Region lies over the bottom floor, in its tiles.
@export var over: Vector2i = Vector2i.ZERO
