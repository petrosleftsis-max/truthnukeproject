extends Node
class_name GuardChat
## Two guards on a stealth map who meet every so often to talk: they leave
## their rounds, stand at their spots facing each other - their minds on the
## talk and their view the narrower for it - say their lines, and go back.
##
## Close enough (Earshot Tiles), or listening (Q) from further off, the party
## overhears them, a line at a time over their heads; every line of it heard
## sets Overheard Flag.
##
## A check-in, too: when the time comes and one of them is not there to meet -
## knocked out, being sick, too ill to stand - the other puts the map on edge
## and goes looking for him.

## The two, by their node names on the map.
@export var first_guard: String = ""
@export var second_guard: String = ""
## Where each stands to talk, by waypoint. Empty: the first stays where he is,
## and the second comes to stand beside him.
@export var first_stands_at: String = ""
@export var second_stands_at: String = ""
## How long after the map starts they first meet, and how often after that.
@export var first_after_seconds: float = 15.0
@export var every_seconds: float = 45.0
## What they say, a line each in turn, the first guard first. Empty: they
## talk, but nothing that can be made out.
@export var lines: Array[String] = []
@export var seconds_per_line: float = 3.5
## How near the party has to be to overhear them, in tiles - twice as far
## while listening.
@export var earshot_tiles: float = 5.0
## Set once every line has been overheard.
@export var overheard_flag: String = ""
## Whether a partner missing when it is time to meet is noticed.
@export var check_in: bool = true
