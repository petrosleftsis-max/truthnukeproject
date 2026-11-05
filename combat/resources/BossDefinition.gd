@icon("res://art/editor_icons/boss.svg")
extends Resource
class_name BossDefinition
## What makes somebody a boss (CombatantDefinition.boss) - whatever their size.
##
## A boss has its name brought up across the screen when it appears, a health
## bar of its own across the top (with its stagger bar under it, if it has one),
## its phases, and its music. Everything else a boss might want - immunities,
## more turns a round, an aura, being big - is on CombatantDefinition and its
## passives, where anybody can have it.

## Shown under its name: "Warden of the Ash Gate".
@export var title: String = ""
## Track to change to as it appears. Empty keeps the music.
@export var music: String = ""
## Its stagger bar. Empty, it has none.
@export var stagger: StaggerDefinition
@export_group("Title cards")
## In place of the fight's own words, while they are on the field (FightCards).
@export var opening_card: String = ""
@export var victory_card: String = ""
@export var defeat_card: String = ""
## The large picture that slides in as they are revealed. Empty: their icon, drawn large.
@export var reveal_portrait: Texture2D
## The sting as they light up. Empty: a stand-in.
@export var reveal_sound: AudioStream
@export_group("")
## In any order: each begins once its At Health is reached.
@export var phases: Array[BossPhase] = []
## What the enemy codex's second page says about them, above their phases and
## stagger bar - written once they are studied in a later phase (Combat
## "The enemy codex").
@export_multiline var codex_second_page: String = ""


## The phases, highest health first - the order they come in.
func phases_in_order() -> Array:
	var sorted := phases.filter(func(phase): return phase != null)
	sorted.sort_custom(func(a, b): return a.at_health > b.at_health)
	return sorted
