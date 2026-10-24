@icon("res://art/editor_icons/dungeon.svg")
extends Resource
class_name DungeonDefinition
## Fights one after another, with a rest between each: the party walks a map
## until its fight, wins it, rests, and goes on to the next - to the end.
##
## Each step is a DungeonStage: a map to walk, or a fight to go straight into.
## A map keeps everything it has - its conversations, what can be picked up -
## except who is in the party and what they carry, which are the dungeon's
## (Party, below), and the fight at the end, which is the stage's own.
##
## What carries from one fight to the next: health spent, which a rest gives
## back; items, which are kept unless used; and gates, which are not given back
## by resting - only by the Recover Gates offer, a few times a run at most.
## See Campaign.start_dungeon, and the rest in ui/rest_panel.gd.

## Every setting below starts empty or at nothing, so a dungeon file states each
## of its own - a default that a file leaves unwritten changes with the script.

## What the dungeon is called, on the rest and at the end.
@export var display_name: String = "Dungeon"
@export_multiline var description: String = ""

@export_group("Party")
## Who goes in, leader first. The maps' own parties are not used.
@export var party: Array[String] = []
## What level they are, on the maps and in every fight - the fights' own
## player tiles' levels are not used, as in the story.
@export_range(1, 64) var level: int = 1
## Whether whoever learns their spells from books (Prometheus - see Campaign
## "Spellbooks") knows every spell of theirs in here, their path's included,
## as in Arena Mode.
@export var knows_every_spell: bool = false
## What each of them starts with, by character key: item keys, put away belt
## first (Campaign.stow_item). Their bags are emptied as the dungeon starts, so
## this is all they carry - and what they use is gone for the fights after.
@export var kit: Dictionary = {}

@export_group("Stages")
## In order. Winning the last one finishes the dungeon.
@export var stages: Array[DungeonStage] = []

@export_group("Resting")
## Whether its rests are short ones (Campaign.short_rest): everybody standing
## gets back half of what they lost, and the uses spent until a rest; nobody
## fallen gets up by themselves and no gates come back - but whoever knows
## Resuscitate may spend a casting of it on somebody fallen
## (Campaign.resuscitate_at_rest). Off, the full rest: everybody back to full
## health (Campaign.rest_party).
@export var short_rests: bool = false
## Whether somebody who fell in the last fight gets up again at a full rest.
@export var rest_revives: bool = false
## Whose gates the rest offers to bring back.
@export var gate_recovery_for: Array[String] = []
## How many rests in the whole run may bring gates back. Unused at one rest,
## the offer is made again at the next.
@export var gate_recoveries: int = 0
## What a recovery has to spend.
@export var gate_recovery_points: int = 0
## What bringing back one casting through each gate costs, by gate - nothing at
## 0, then World, Hermes, Pandora (see Stats.GATE_NAMES).
@export var gate_costs: Array[int] = []
## A store the rest offers a visit to, by key (StoreDefinition) - empty for
## none. Gold comes from the fights' Gold Reward.
@export var store: String = ""

@export_group("Test harness")
## TEMPORARY - for the late-Chapter-I laboratory sequence
## (data/dungeons/lab_chapter1_sequence.tres, docs/chapter1_audit.md), not for
## story content: no rest between the fights. Nobody is healed or gets up
## again, no gates are offered back and no store is visited, so health, the
## fallen and spent gates carry from each fight into the next. The result's
## Continue goes straight on. To be removed once the test is done.
@export var skips_rests: bool = false
## TEMPORARY - the same test: every fight of the dungeon is logged by LabMetrics
## (tools/lab_metrics.gd), under the run's label.
@export var logs_metrics: bool = false


## What one casting through gate `gate` costs to bring back - or nothing for a
## gate not costed, which is then not offered.
func gate_cost(gate: int) -> int:
	return gate_costs[gate] if gate >= 0 and gate < gate_costs.size() else 0


## The stage that stands in for `encounter` on `map`, or null.
func stage_for(map: String, encounter: EncounterDefinition) -> DungeonStage:
	for stage in stages:
		if stage == null or stage.map == "" or stage.map != map:
			continue
		if stage.replaces == null or stage.replaces == encounter or stage.replaces.resource_path == encounter.resource_path:
			return stage
	return null
