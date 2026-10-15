class_name Sizes
## How big something is, and what that means on the board.
##
## A Human is one tile. Each step smaller is half as wide - Small a half, Tiny a
## quarter - and each step bigger twice as wide: Large 2 x 2 tiles, Enormous
## 4 x 4, Monstrous 8 x 8. Gigantic is the exception: 16 x 16 or bigger, as big
## as its CombatantDefinition.gigantic_span says.
##
## What is smaller than a tile shares one with its own side, a tile holding
## SPACE_IN_A_TILE: 16 Tiny, or 4 Small, or a mix (Combat.room_for). What is a
## tile or more has the tiles it covers to itself, and goes only where all of
## them fit. A body is cover to anybody not two sizes bigger than it
## (CController.blocks_sight).

## Stored by number, so a new size would go on the end.
enum Size { TINY, SMALL, HUMAN, LARGE, ENORMOUS, MONSTROUS, GIGANTIC }

const NAMES := ["Tiny", "Small", "Human", "Large", "Enormous", "Monstrous", "Gigantic"]

## How much of a tile one of each size takes, out of SPACE_IN_A_TILE.
const SHARE := [1, 4, 16, 16, 16, 16, 16]
const SPACE_IN_A_TILE := 16

## Tiles a side for everything from Human up, by size.
const SPAN := [1, 1, 1, 2, 4, 8, 16]


static func name_of(size: int) -> String:
	return NAMES[clampi(size, 0, NAMES.size() - 1)]


## How many tiles a side something of `size` covers - 1 for anything a tile or
## smaller. `gigantic_span` is how big a Gigantic one is, never under 16.
static func span(size: int, gigantic_span: int = 16) -> int:
	if size == Size.GIGANTIC:
		return maxi(16, gigantic_span)
	return SPAN[clampi(size, 0, SPAN.size() - 1)]


## Whether something of `size` is smaller than a tile, and shares one.
static func shares(size: int) -> bool:
	return size < Size.HUMAN


## How much of a tile one of `size` takes.
static func share(size: int) -> int:
	return SHARE[clampi(size, 0, SHARE.size() - 1)]


## How big it is drawn, a Human being 1: a quarter for Tiny, a half for Small,
## and its span for the rest.
static func draw_scale(size: int, gigantic_span: int = 16) -> float:
	match size:
		Size.TINY:
			return 0.25
		Size.SMALL:
			return 0.5
	return float(span(size, gigantic_span))
