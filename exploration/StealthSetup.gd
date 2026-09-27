extends Node
class_name StealthSetup
## Makes the map it is dropped into a stealth map: the guards on it (see Guard)
## watch as they patrol, and whoever is walking it has to stay out of their
## sight. Seen for long enough, and the fight starts right there - the guards
## and the party on the tiles they were standing on.
##
## The map has to be built on the battle terrain named below - an instance of
## it, the way explore_crossroads is an instance of crossroads_terrain - so a
## tile on the map is the same tile in the fight.

## The terrain the fight is played on when somebody is caught. The map this
## sits in must be an instance of it.
@export var battle_terrain: PackedScene
## What the fight is called, in the log and on the result screen.
@export var fight_name: String = "Caught"

@export_group("What the player sees")
## Guards are only shown - them and their view - while whoever leads can see
## them (or they are right beside him, or growing sure of him). Everywhere else
## is a guess, and Cat's Ears (Q) is how to listen for them. Off: every guard is
## always on show.
@export var guards_seen_only_in_sight: bool = false

@export_group("Alert")
## How fast the map calms down again after an alarm, in alert per second - a
## full alarm (1.0) takes 50 seconds to fade at the default.
@export var alert_fades_per_second: float = 0.02

@export_group("Who fights")
## Only guards this many tiles or fewer from where he was caught start the fight
## with him. Zero: every guard on the map, all at once.
@export var joins_within_tiles: float = 0.0
## Guards further off than that arrive late - a round later for every this many
## tiles further they had to come. Zero: they never come.
@export var tiles_per_late_round: float = 6.0
## Who comes running when the one sneaking is caught, by combatant key, in the
## order they stand. Empty: they fight alone. Whether help arrives is the story
## beat's to say, so it is set per map.
@export var backup: Array[String] = []
## The waypoint they arrive at. Empty, or not found: beside whoever was caught.
@export var backup_arrives_at: String = ""

@export_group("Sound")
## A single heartbeat, played faster and louder as a guard grows sure. Empty:
## a plain synthesised thump stands in until there is a real one.
@export var heartbeat_sound: AudioStream
## The sting as a guard is sure and the "!" goes up. Empty: a synthesised one.
@export var caught_sound: AudioStream

@export_group("After")
## What marks this map's guards as dealt with once the fight is won, so they are
## not standing there again when the party walks back in. Left empty, the map's
## own path is used, which is right unless two stealth maps share a file.
@export var trigger_id: String = ""
