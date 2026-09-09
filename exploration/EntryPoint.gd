extends Marker2D
class_name EntryPoint
## Where the party appears when they arrive in an exploration map.
##
## A map needs at least one. Doors name the entry point they lead to, so a
## village with a north gate and a south gate puts an EntryPoint by each and
## the doors elsewhere point at them by name. Arriving with no name given (or
## a name that isn't here) uses the first one in the scene.


## The name doors refer to, e.g. "north_gate". Distinct from the node name so
## renaming the node in the editor doesn't silently break the doors elsewhere
## that point at it.
@export var entry_name: String = ""
