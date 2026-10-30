extends Node2D
class_name MoveFeel
## How a move is felt beyond its number (docs/move_feel_proposals.md; the
## designer, 2026-10-30: everything suggested, but moves coming down from above
## or up from below): the flash at its user as it leaves them, the burst where
## it lands in its element's own way, what it looks like on whoever it lands on
## (a swing's arc, a column of light, stars over a stunned head), a mark left on
## the ground, and the fight's own moments - a readied move going off, a
## reaction, a declared move coming due, a part struck, a boss staggered. Each
## move's own looks are its Hand Look, Impact Look and Ground Mark
## (SkillDefinition, "Projectile"), worked out from the move when Automatic; its
## three sounds are its slots, and an empty one plays a stand-in
## (PlaceholderSounds). Every look here is a placeholder drawn in code: the
## designer makes the real art and sound.
##
## Purely to look at, like Projectile: nothing in it rolls on Combat.rng, waits
## on anything but its own clock or changes the fight, so a fight played on two
## machines (Net) comes out the same with it. What scatters - embers, shards,
## drops - comes from a generator of its own seeded from where it is, the same
## every time. Headless nothing is made (unless plays_headless), nor while a
## fight joined under way is being caught up with.

## Set by a test that wants to see them made with nobody watching.
static var plays_headless := false

## How long each lasts, in seconds - PROPOSAL values, like the projectile's.
const SECONDS := {
	&"burst": 0.6, &"muzzle": 0.45, &"glyph": 0.5, &"swish": 0.25, &"roar": 0.55, &"puff": 0.55,
	&"swoosh": 0.32, &"heavy_swoosh": 0.42, &"half_circle": 0.4, &"thrust": 0.42, &"claw": 0.4,
	&"low_slash": 0.35, &"stake": 0.45, &"shield_stars": 1.4, &"shockwave": 0.6, &"white_out": 0.6,
	&"flash": 0.45, &"ripples": 0.8, &"bonk": 0.7, &"seal": 0.8, &"column": 0.9, &"wash": 0.7,
	&"rise": 1.0, &"shards_gather": 0.6, &"dome": 1.0, &"glyph_circle": 1.2, &"storm": 1.0,
	&"fire_ring": 0.5, &"cut_ring": 0.7, &"code_scatter": 0.6, &"lift": 0.8, &"speed_lines": 0.5,
	&"shimmer": 0.8, &"eye": 1.0, &"stream": 0.8, &"ice_spread": 1.0, &"rays": 0.8, &"wing": 0.7,
	&"disarm": 0.9, &"settle": 1.0, &"spark_beside": 0.45, &"rock_break": 0.6, &"edge": 0.4,
	&"wildfire": 0.9, &"whiff": 0.35, &"shatter": 0.55, &"motes": 0.9, &"line": 0.35,
	&"exclaim": 0.85, &"outline": 0.5, &"dust": 0.5, &"item": 0.5,
}
## How a mark on the ground lasts: gone this many rounds after it was left.
const MARK_ROUNDS := 2
## A greatsword's swing (Heavy Swoosh) stops the world this much more.
const HEAVY_SWING_STOP := 0.06
## Its strength as it is left, faded from there round by round.
const MARK_ALPHA := 0.55
## A zone laid spreads out from where it landed, a tile this long after the one
## before (Combat.zone_tiles).
const SPREAD_SECONDS_A_TILE := 0.07
## The face of somebody reacting, at the side of the screen: how long, how big.
const FACE_SECONDS := 1.1
const FACE_SIZE := 96.0
## A condition's mark flying into its strip on the HUD.
const MARK_POP_SECONDS := 0.22
const MARK_HOLD_SECONDS := 0.18
const MARK_FLY_SECONDS := 0.45
const MARK_SIZE := 34.0
## Where the screen's own flashes and faces go: over the board and the HUD,
## under any conversation or menu.
const OVERLAY_LAYER := 20

## What it is - one of SECONDS' keys - and how long it lasts.
var kind: StringName = &""
var seconds := 0.5
## Its colour, and a second one for what has two (a twin tracer, a seal's rim).
var colour := Color.WHITE
var colour_b := Color.WHITE
## The element it bursts in (Damage.Type), for a burst.
var element := -1
## Which way the blow came - from its user to here - for whatever leans that way.
var toward := Vector2.RIGHT
## A size in pixels: an area's reach, a ring's furthest.
var reach := 0.0
## Below 1 for a graze: fewer, fainter, smaller.
var strength := 1.0
## Points it draws on, from where it is: an area's tile middles, a line's end.
var points: Array = []
## Who it is on, followed if they move - and where their middle is off their sprite.
var on: Dictionary = {}
var on_offset := Vector2.ZERO
var texture: Texture2D = null
var text := ""
## The fight, for what lasts by its rounds or its marks (a mark on the ground,
## a declared move's glyphs, a zone spreading).
var combat: Combat = null

var _clock := 0.0
var _rng := RandomNumberGenerator.new()
## What it scatters, worked out as it is made: [{p, v, g, r, life, spin, a}].
var _bits: Array = []
## A mark on the ground: the round it was left in.
var _born_round := 0


static func shown() -> bool:
	if DisplayServer.get_name() == "headless" and not plays_headless:
		return false
	return not Net.catching_up()


## Makes one on `combat`'s board at `at`, with `settings` set on it - or null,
## when nothing is to be shown.
static func spawn(combat: Combat, kind: StringName, at: Vector2, settings: Dictionary = {}) -> MoveFeel:
	if not shown() or combat == null or not is_instance_valid(combat) or not combat.is_inside_tree():
		return null
	var feel := MoveFeel.new()
	feel.kind = kind
	feel.seconds = SECONDS.get(kind, 0.5)
	feel.combat = combat
	feel.position = at
	for key in settings:
		feel.set(key, settings[key])
	feel.z_as_relative = false
	feel.z_index = 905
	combat.combatant_layer().add_child(feel)
	return feel


## The middle of `comb` as drawn, on the board.
static func middle_of(combat: Combat, comb: Dictionary) -> Vector2:
	if comb.is_empty() or not comb.has("position"):
		return Vector2.ZERO
	return combat.sprite_point(comb) + combat.drawing_offset(comb)


## Over `comb`'s head.
static func head_of(combat: Combat, comb: Dictionary) -> Vector2:
	var sprite = comb.get("sprite")
	var above := Grid.TILE_SIZE * 0.45
	if sprite != null and is_instance_valid(sprite):
		above = maxf(above, sprite.head_height() + Grid.TILE_SIZE * 0.1)
	return middle_of(combat, comb) + Vector2(0.0, -above)


## A pitch for a stand-in sound, worked out from what both machines share - the
## round and who it is - never rolled.
static func pitch_for(combat: Combat, who: Dictionary) -> float:
	return 1.0 + 0.06 * sin(float(combat.round_number) * 1.7 + float(who.get("id", 0)) * 0.9)


## Plays `stream`, or the stand-in `called` when it is empty.
static func sound(combat: Combat, stream: AudioStream, called: String, who: Dictionary = {}, volume_db: float = 0.0):
	if combat == null or not is_instance_valid(combat):
		return
	if stream != null:
		combat.play_stream(stream, volume_db)
	elif called != "":
		combat.play_stream(PlaceholderSounds.make(called), volume_db - 4.0, pitch_for(combat, who))


## --- A move leaving its user ---


## How `skill`, used by `user` aimed at `aim`, leaves them: its Hand Look, or
## worked out - a glyph for a spell, a swish for something thrown, a flash for
## any other shot, nothing for a blow.
static func hand_look_of(combat: Combat, user: Dictionary, skill: SkillDefinition, aim: Vector2i) -> int:
	if skill.hand_look != SkillDefinition.HandLook.AUTOMATIC:
		return skill.hand_look
	if Combat.is_spell(skill):
		return SkillDefinition.HandLook.GLYPH
	if Combat.is_melee(skill):
		return SkillDefinition.HandLook.NONE
	var style := Projectile.style_for(combat, user, skill, aim)
	if style == SkillDefinition.ProjectileStyle.NONE:
		return SkillDefinition.HandLook.NONE
	if skill is ItemDefinition or style == SkillDefinition.ProjectileStyle.ARC:
		return SkillDefinition.HandLook.SWISH
	return SkillDefinition.HandLook.MUZZLE


## `skill` leaving `user` towards `aim`: the flash at them, and its sound - the
## move's own, played already as the animation ended, or the stand-in for one.
static func hand(combat: Combat, user: Dictionary, skill: SkillDefinition, aim: Vector2i):
	var look := hand_look_of(combat, user, skill, aim)
	if look == SkillDefinition.HandLook.NONE:
		return
	if skill.sound == null:
		var called: String = {SkillDefinition.HandLook.MUZZLE: "launch_shot", SkillDefinition.HandLook.GLYPH: "launch_spell",
			SkillDefinition.HandLook.SWISH: "launch_throw", SkillDefinition.HandLook.ROAR: "launch_roar",
			SkillDefinition.HandLook.PUFF: "launch_puff"}.get(look, "")
		sound(combat, null, called, user)
	var from := middle_of(combat, user)
	var there := combat.sprite_point({}, aim)
	var heading := (there - from).normalized() if there.distance_to(from) > 1.0 else Vector2.RIGHT
	var kind: StringName = StringName(SkillDefinition.HandLook.keys()[look].to_lower())
	var element := _element_of(combat, user, skill)
	var feel := spawn(combat, kind, from + heading * Grid.TILE_SIZE * 0.3, {"toward": heading,
		"colour": Projectile.colour_for(skill, element), "on": user, "on_offset": combat.drawing_offset(user) + heading * Grid.TILE_SIZE * 0.3,
		"text": "casing" if skill.projectile_look == SkillDefinition.ProjectileLook.TRACER else ""})
	if feel != null and look == SkillDefinition.HandLook.ROAR:
		screen_flash(combat, Color(1, 1, 1, 0.12), 0.3)


## The element `skill` lands as for `user`: raised, for a cast an upgrade was
## spent on.
static func _element_of(combat: Combat, user: Dictionary, skill: SkillDefinition) -> int:
	var element := int(skill.damage_type)
	var thrown: Array = combat.elements_of(skill)
	if not thrown.is_empty():
		element = int(thrown[0])
	return combat.effective_damage_type(user, element)


## --- Where a move lands ---


## What `skill` looks like where it lands on somebody: its Impact Look, or
## worked out - a column of light for a mend, a wash for a cleanse, a rising
## light for bringing somebody back, a swing's arc for a blow.
static func impact_look_of(skill: SkillDefinition) -> int:
	if skill.impact_look != SkillDefinition.ImpactLook.AUTOMATIC:
		return skill.impact_look
	for effect in skill.all_effects():
		# What it does to its own user (Light Swing's mend) is no look on who it lands on.
		if effect == null or effect.applies_to_caster:
			continue
		match effect.type:
			EffectDefinition.EffectType.HEAL:
				return SkillDefinition.ImpactLook.COLUMN
			EffectDefinition.EffectType.DISPEL:
				return SkillDefinition.ImpactLook.WASH
			EffectDefinition.EffectType.REVIVE:
				return SkillDefinition.ImpactLook.RISE
	if Combat.is_melee(skill) and skill.deals_damage:
		return SkillDefinition.ImpactLook.SWOOSH
	return SkillDefinition.ImpactLook.NONE


## `skill`, used by `attacker`, landing on `target`: how it looks there - and,
## for a move that flew nothing (a blow), the burst its element makes and the
## sound of it landing, which a projectile makes for itself.
static func impact(combat: Combat, attacker: Dictionary, target: Dictionary, skill: SkillDefinition, flown: bool, grazed: bool):
	var at := middle_of(combat, target)
	var element := _element_of(combat, attacker, skill)
	var from := middle_of(combat, attacker)
	var heading := (at - from).normalized() if at.distance_to(from) > 1.0 else Vector2.RIGHT
	if not flown:
		if skill.deals_damage:
			burst(combat, at, element, 0.6 if grazed else 1.0)
		sound(combat, skill.impact_sound, _impact_sound_of(skill, element, grazed), target)
	var look := impact_look_of(skill)
	if look == SkillDefinition.ImpactLook.NONE:
		return
	var kind: StringName = StringName(SkillDefinition.ImpactLook.keys()[look].to_lower())
	var tint := Projectile.colour_for(skill, element)
	var settings := {"toward": heading, "colour": tint, "on": target, "on_offset": combat.drawing_offset(target),
		"strength": 0.6 if grazed else 1.0, "reach": Grid.TILE_SIZE * (0.5 + combat.aoe_radius_of(attacker, skill))}
	match look:
		SkillDefinition.ImpactLook.SHIELD_STARS, SkillDefinition.ImpactLook.BONK, SkillDefinition.ImpactLook.EYE:
			settings["points"] = [head_of(combat, target) - at]
		SkillDefinition.ImpactLook.DISARM:
			settings["colour"] = Color("cfd6dd")
		SkillDefinition.ImpactLook.SEAL:
			settings["colour"] = Color("ffd166")
			settings["colour_b"] = Color("fff1c2")
		SkillDefinition.ImpactLook.WHITE_OUT:
			screen_flash(combat, Color(1, 1, 1, 0.9), 0.5)
			kind = &"shockwave"
			settings["reach"] = Grid.TILE_SIZE * (1.0 + combat.aoe_radius_of(attacker, skill))
		SkillDefinition.ImpactLook.SHOCKWAVE:
			combat.shake_camera(18.0)
	spawn(combat, kind, at, settings)
	match look:
		SkillDefinition.ImpactLook.RIPPLES:
			_wobble(target)
		SkillDefinition.ImpactLook.LOW_SLASH:
			_dip(target)
		SkillDefinition.ImpactLook.LIFT:
			_lift(target)
		SkillDefinition.ImpactLook.HEAVY_SWOOSH:
			# A greatsword's weight: a beat more than its share of health alone gives.
			if shown():
				combat.hit_stop(HEAVY_SWING_STOP)
		SkillDefinition.ImpactLook.SPARK_BESIDE:
			# Down beside them, not on them: they flinch away from it.
			var sprite = target.get("sprite")
			if shown() and sprite != null and is_instance_valid(sprite):
				sprite.recoil(Vector2(-1.0, -0.4))


## The same move over an area: its look once, over the whole of it, from
## `centre` - a dome settling, a storm turning, a stream running, ice spreading,
## a wing sweeping, a great glyph drawn round its user.
static func over_area(combat: Combat, attacker: Dictionary, skill: SkillDefinition, centre: Vector2i, tiles: Array):
	var look := impact_look_of(skill)
	var area_looks := [SkillDefinition.ImpactLook.DOME, SkillDefinition.ImpactLook.STORM, SkillDefinition.ImpactLook.STREAM,
		SkillDefinition.ImpactLook.ICE_SPREAD, SkillDefinition.ImpactLook.WING, SkillDefinition.ImpactLook.GLYPH_CIRCLE,
		SkillDefinition.ImpactLook.WILDFIRE, SkillDefinition.ImpactLook.FIRE_RING, SkillDefinition.ImpactLook.CUT_RING]
	if not look in area_looks:
		return
	var at := combat.sprite_point({}, centre) if look != SkillDefinition.ImpactLook.GLYPH_CIRCLE else middle_of(combat, attacker)
	var element := _element_of(combat, attacker, skill)
	var from := middle_of(combat, attacker)
	var heading := (at - from).normalized() if at.distance_to(from) > 1.0 else Vector2.RIGHT
	var relative := []
	for tile in tiles:
		if typeof(tile) == TYPE_VECTOR2I:
			relative.append(combat.sprite_point({}, tile) - at)
	# Out from where it starts: a stream from its user's side, the rest from the middle.
	var start := (from - at) if look == SkillDefinition.ImpactLook.STREAM else Vector2.ZERO
	relative.sort_custom(func(a, b): return a.distance_to(start) < b.distance_to(start))
	var kind: StringName = StringName(SkillDefinition.ImpactLook.keys()[look].to_lower())
	spawn(combat, kind, at, {"toward": heading, "colour": Projectile.colour_for(skill, element), "points": relative,
		"reach": Grid.TILE_SIZE * (0.6 + maxf(combat.aoe_radius_of(attacker, skill), 1.0)), "element": element})


## Whether `skill`'s look is drawn once over its area (over_area) rather than
## on each it lands on.
static func looks_over_area(skill: SkillDefinition) -> bool:
	return impact_look_of(skill) in [SkillDefinition.ImpactLook.DOME, SkillDefinition.ImpactLook.STORM,
		SkillDefinition.ImpactLook.STREAM, SkillDefinition.ImpactLook.ICE_SPREAD, SkillDefinition.ImpactLook.WING,
		SkillDefinition.ImpactLook.GLYPH_CIRCLE, SkillDefinition.ImpactLook.WILDFIRE, SkillDefinition.ImpactLook.FIRE_RING,
		SkillDefinition.ImpactLook.CUT_RING]


## The stand-in sound of `skill` landing: by its element, or a mend's, or a graze.
static func _impact_sound_of(skill: SkillDefinition, element: int, grazed: bool) -> String:
	if grazed:
		return "impact_graze"
	for effect in skill.all_effects():
		if effect != null and effect.type == EffectDefinition.EffectType.HEAL and not effect.applies_to_caster:
			return "impact_mend"
	if not skill.deals_damage:
		return "impact_psychic" if Combat.is_spell(skill) else ""
	return "impact_" + Damage.type_name(element).to_lower()


## The burst `element` makes where something lands - embers rising for fire,
## droplets for water, swirling lines for wind, grit for earth, bubbles for
## poison, ripples for the mind, a white-hot core for plasma, shards for ice,
## forks for lightning, sparks for metal, hissing drips for acid, gold motes for
## the Idol, a white star for a plain blow. `mend` for a heal's green motes.
static func burst(combat: Combat, at: Vector2, element: int, strength: float = 1.0, mend: bool = false):
	spawn(combat, &"burst", at, {"element": -2 if mend else element, "strength": strength,
		"colour": Projectile.MEND if mend else Damage.type_colour(element), "reach": Grid.TILE_SIZE * 0.5})


## A blow that missed `target`: a whiff of air where it passed them by.
static func missed(combat: Combat, attacker: Dictionary, target: Dictionary, skill: SkillDefinition):
	var at := middle_of(combat, target)
	var from := middle_of(combat, attacker)
	var heading := (at - from).normalized() if at.distance_to(from) > 1.0 else Vector2.RIGHT
	sound(combat, null, "impact_miss", target)
	spawn(combat, &"whiff", at, {"toward": heading, "colour": Color(0.92, 0.94, 1.0)})


## An image going to pieces at `at` - a copy taking a blow, an image broken.
static func shatter(combat: Combat, at: Vector2):
	sound(combat, null, "impact_shatter")
	spawn(combat, &"shatter", at, {"colour": Color(0.8, 0.92, 1.0)})


## Mended: motes rising off `target`.
static func mended(combat: Combat, target: Dictionary):
	spawn(combat, &"motes", middle_of(combat, target), {"colour": Projectile.MEND, "on": target,
		"on_offset": combat.drawing_offset(target)})


## --- Marks on the ground ---


## The mark `skill` leaves on `tiles` - scorched, frosted, a puddle, a smoking
## pit: its Ground Mark, or by the element it hurt with. Fades over MARK_ROUNDS
## rounds; purely to look at.
static func mark_ground(combat: Combat, attacker: Dictionary, skill: SkillDefinition, tiles: Array):
	var mark := skill.ground_mark
	if mark == SkillDefinition.GroundMark.AUTOMATIC:
		if not skill.deals_damage:
			return
		match _element_of(combat, attacker, skill):
			Damage.Type.FIRE, Damage.Type.PLASMA:
				mark = SkillDefinition.GroundMark.SCORCH
			Damage.Type.ICE:
				mark = SkillDefinition.GroundMark.FROST
			Damage.Type.WATER:
				mark = SkillDefinition.GroundMark.PUDDLE
			Damage.Type.ACID:
				mark = SkillDefinition.GroundMark.PIT
			_:
				return
	if mark == SkillDefinition.GroundMark.NONE or tiles.is_empty() or not shown():
		return
	var first: Vector2 = combat.sprite_point({}, tiles[0])
	var relative := []
	for tile in tiles:
		if typeof(tile) == TYPE_VECTOR2I:
			relative.append(combat.sprite_point({}, tile) - first)
	var feel := spawn(combat, &"mark", first, {"points": relative, "element": mark, "seconds": INF})
	if feel != null:
		feel._born_round = combat.round_number
		feel.on_the_ground()


## --- The fight's own moments ---


## A readied move going off: a quick line from whoever readied it to whoever
## set it off, just before it fires.
static func readied_line(combat: Combat, reactor: Dictionary, setter: Dictionary):
	if setter.is_empty() or reactor.is_empty():
		return
	var from := middle_of(combat, reactor)
	spawn(combat, &"line", from, {"points": [middle_of(combat, setter) - from], "colour": Color("b48cff")})


## `reactor` reacting: a "!" over them, and their face at the side of the screen
## for a moment.
static func exclaim(combat: Combat, reactor: Dictionary):
	if reactor.is_empty() or not shown():
		return
	spawn(combat, &"exclaim", head_of(combat, reactor), {"colour": Color("ffd166"), "on": reactor,
		"on_offset": head_of(combat, reactor) - combat.sprite_point(reactor)})
	var face: Texture2D = reactor.get("icon")
	var layer := _overlay(combat)
	if layer == null or face == null:
		return
	var card := _FaceCard.new()
	card.face = face
	card.words = str(reactor.get("name", ""))
	card.hostile = reactor.get("side", 0) != 0
	layer.add_child(card)


## `comb` has declared a move: a glyph on each tile it will land on, turning
## faster as its landing comes - drawn until it lands or is dropped.
static func declared(combat: Combat, comb: Dictionary):
	if not comb.has("declared") or not shown():
		return
	var tiles: Array = comb.declared.get("tiles", [])
	if tiles.is_empty():
		return
	var first: Vector2 = combat.sprite_point({}, tiles[0])
	var relative := []
	for tile in tiles:
		if typeof(tile) == TYPE_VECTOR2I:
			relative.append(combat.sprite_point({}, tile) - first)
	var feel := spawn(combat, &"declared", first, {"points": relative, "on": comb, "seconds": INF,
		"colour": Color("ff9a3c") if comb.get("side", 0) != 0 else Color("ffd166")})
	if feel != null:
		feel.on_the_ground()


## A part of `target` struck: its outline flashing, over `tiles`.
static func part_struck(combat: Combat, tiles: Array, tint: Color):
	if tiles.is_empty():
		return
	var first: Vector2 = combat.sprite_point({}, tiles[0])
	var relative := []
	for tile in tiles:
		relative.append(combat.sprite_point({}, tile) - first)
	spawn(combat, &"outline", first, {"points": relative, "colour": tint})


## A zone just laid (Combat.lay_zone): it spreads out from `from` rather than
## appearing all at once - Combat.zone_tiles hands the board what has spread so
## far, and this keeps the board drawing until it has all.
static func zone_spreads(combat: Combat, zone_id: int, from: Vector2i, tiles: Array):
	if not shown() or tiles.is_empty():
		return
	var furthest := 0
	for tile in tiles:
		furthest = maxi(furthest, absi(tile.x - from.x) + absi(tile.y - from.y))
	combat.spreading_zones[zone_id] = {"from": from, "since": Time.get_ticks_msec()}
	var feel := spawn(combat, &"spread", combat.sprite_point({}, from), {"seconds": SPREAD_SECONDS_A_TILE * (furthest + 1) + 0.05,
		"element": zone_id})


## Somebody shoved across `at`: dust kicked up.
static func dust(combat: Combat, at: Vector2, strength: float = 1.0):
	spawn(combat, &"dust", at, {"colour": Color(0.78, 0.7, 0.58), "strength": strength})


## Somebody thrown or shoved into something solid at `at`: a thud, a ring of
## dust, and the view shaken.
static func thud(combat: Combat, at: Vector2):
	sound(combat, null, "impact_thud")
	combat.shake_camera(10.0)
	spawn(combat, &"dust", at, {"colour": Color(0.78, 0.7, 0.58), "strength": 1.6})
	spawn(combat, &"shockwave", at, {"colour": Color(0.85, 0.78, 0.65), "reach": Grid.TILE_SIZE * 0.8, "strength": 0.6})


## A puff of smoke at `at` - somebody vanishing, or arriving.
static func puff(combat: Combat, at: Vector2, tint: Color = Color(0.86, 0.86, 0.92)):
	spawn(combat, &"puff", at, {"colour": tint})


## `item_key` taken off `from` and carried to `to` - a steal, a loot: its icon
## flying across.
static func item_flies(combat: Combat, from: Dictionary, to: Dictionary, item_key: String):
	if not shown() or from.is_empty() or to.is_empty():
		return
	var icon: Texture2D = null
	if ItemDatabase.is_item(item_key):
		var item: ItemDefinition = ItemDatabase.item(item_key)
		icon = item.icon if item != null else null
	var start := middle_of(combat, from)
	spawn(combat, &"item", start, {"points": [middle_of(combat, to) - start], "texture": icon, "colour": Color("ffd166")})


## A summon bounding out of whoever called it, onto its tile.
static func bound_out(combat: Combat, caster: Dictionary, summoned: Dictionary):
	var sprite = summoned.get("sprite")
	if not shown() or sprite == null or not is_instance_valid(sprite) or caster.is_empty():
		return
	sprite.fly_in(middle_of(combat, caster) - middle_of(combat, summoned), 0.4, Grid.TILE_SIZE * 0.6)
	puff(combat, middle_of(combat, summoned), Color(1.0, 0.75, 0.5))


## Somebody thrown (Hurl): their drawing goes over on an arc from `from`, its
## shadow under it, and lands with a thud and a ring of dust.
static func thrown(combat: Combat, body: Dictionary, from: Vector2):
	var sprite = body.get("sprite")
	if not shown() or sprite == null or not is_instance_valid(sprite):
		return
	var at := middle_of(combat, body)
	var flight := 0.45
	sprite.fly_in(from - at, flight, Grid.TILE_SIZE * 0.9)
	spawn(combat, &"lift", at, {"seconds": flight, "reach": Grid.TILE_SIZE * 0.35, "text": "shadow"})
	await combat.get_tree().create_timer(flight).timeout
	if is_instance_valid(combat):
		thud(combat, at)


## A shudder through `target`'s drawing - a mind struck.
static func _wobble(target: Dictionary):
	var sprite = target.get("sprite")
	if sprite != null and is_instance_valid(sprite):
		sprite.wobble(0.6)


## `target`'s drawing dipping - their legs cut.
static func _dip(target: Dictionary):
	var sprite = target.get("sprite")
	if sprite != null and is_instance_valid(sprite):
		sprite.dip(0.4)


## `target`'s drawing lifting off the ground a moment, its shadow under it.
static func _lift(target: Dictionary):
	var sprite = target.get("sprite")
	if sprite != null and is_instance_valid(sprite):
		sprite.fly_in(Vector2(0.0, -Grid.TILE_SIZE * 0.3), 0.6, Grid.TILE_SIZE * 0.25)


## --- Over the whole screen ---


## The layer the screen's own flashes and faces go on - made on the fight the
## first time it is wanted.
static func _overlay(combat: Combat) -> CanvasLayer:
	if not shown() or combat == null or not is_instance_valid(combat) or not combat.is_inside_tree():
		return null
	var layer: CanvasLayer = combat.get_node_or_null("MoveFeelOverlay")
	if layer == null:
		layer = CanvasLayer.new()
		layer.name = "MoveFeelOverlay"
		layer.layer = OVERLAY_LAYER
		combat.add_child(layer)
	return layer


## The whole screen flashing `tint` and fading over `seconds` - a white-out, a
## roar's pulse.
static func screen_flash(combat: Combat, tint: Color, seconds: float):
	var layer := _overlay(combat)
	if layer == null:
		return
	var flash := ColorRect.new()
	flash.color = tint
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(flash)
	var fade := flash.create_tween()
	fade.tween_property(flash, "modulate:a", 0.0, seconds).set_ease(Tween.EASE_IN)
	fade.tween_callback(flash.queue_free)


## `condition` just put on `target`: its mark pops up over them and flies into
## their condition strip on the HUD (combat_ui.condition_point) - or, with no
## strip up for them, only pops and fades.
static func condition_put(combat: Combat, target: Dictionary, condition: ConditionDefinition, helpful: bool):
	var layer := _overlay(combat)
	if layer == null or condition == null or target.is_empty():
		return
	var board := combat.combatant_layer()
	var from: Vector2 = board.get_global_transform_with_canvas() * head_of(combat, target)
	var to = null
	if combat.game_ui != null and combat.game_ui.has_method("condition_point"):
		to = combat.game_ui.condition_point(target)
	var mark := _ConditionMark.new()
	mark.tint = ConditionStrip.HELPFUL if helpful else ConditionStrip.HARMFUL
	mark.letters = ConditionStrip.tag_of(condition)
	mark.position = from
	mark.scale = Vector2.ZERO
	layer.add_child(mark)
	var flight := mark.create_tween()
	flight.tween_property(mark, "scale", Vector2.ONE * 1.3, MARK_POP_SECONDS * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	flight.tween_property(mark, "scale", Vector2.ONE, MARK_POP_SECONDS * 0.4)
	flight.tween_interval(MARK_HOLD_SECONDS)
	if to is Vector2:
		flight.tween_property(mark, "position", to, MARK_FLY_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		flight.parallel().tween_property(mark, "scale", Vector2.ONE * 0.55, MARK_FLY_SECONDS)
		flight.tween_property(mark, "modulate:a", 0.0, 0.12)
	else:
		flight.tween_property(mark, "position:y", from.y - 40.0, MARK_FLY_SECONDS)
		flight.parallel().tween_property(mark, "modulate:a", 0.0, MARK_FLY_SECONDS)
	flight.tween_callback(mark.queue_free)


## A boss staggered: a crack across its stagger bar on the HUD.
static func staggered(combat: Combat, comb: Dictionary):
	if not shown() or combat.game_ui == null or not combat.game_ui.has_method("crack_stagger_bar"):
		return
	combat.game_ui.crack_stagger_bar(comb)


## --- Drawn ---


## Moved down onto the ground: over the map's tiles, under everybody standing
## on them and the board's own marks - first among the map's children.
func on_the_ground():
	var map := get_parent().get_parent() if get_parent() != null else null
	if map == null:
		return
	reparent(map)
	map.move_child(self, 0)
	z_as_relative = true
	z_index = 0


func _ready():
	_rng.seed = hash([kind, position.round(), element, text])
	match kind:
		&"burst":
			_build_burst()
		&"puff", &"dust":
			_scatter(int(8 * strength) + 4, Grid.TILE_SIZE * 0.12, 30.0, 110.0, -30.0, Vector2(0.18, 0.32))
		&"shatter":
			_scatter(14, Grid.TILE_SIZE * 0.1, 260.0, 520.0, 500.0, Vector2(0.05, 0.12), true)
		&"rock_break":
			_scatter(10, Grid.TILE_SIZE * 0.08, 180.0, 420.0, 900.0, Vector2(0.05, 0.1), true)
		&"spark_beside":
			_scatter(12, Grid.TILE_SIZE * 0.05, 250.0, 520.0, 1100.0, Vector2(0.02, 0.04))
			for bit in _bits:
				bit.v.y = -absf(bit.v.y)
		&"code_scatter":
			_scatter(12, Grid.TILE_SIZE * 0.1, 120.0, 300.0, 0.0, Vector2(0.06, 0.09))
		&"motes", &"column", &"rise":
			_rise(12, Grid.TILE_SIZE * 0.3)
		&"fire_ring", &"wildfire":
			_scatter(18, Grid.TILE_SIZE * 0.2, 40.0, 120.0, -260.0, Vector2(0.03, 0.06))
		&"storm":
			_forks(5, reach * 0.9)
		&"shards_gather":
			for i in 10:
				var angle := TAU * float(i) / 10.0 + _rng.randf_range(-0.2, 0.2)
				_bits.append({"p": Vector2.from_angle(angle) * Grid.TILE_SIZE * _rng.randf_range(0.8, 1.3), "a": _rng.randf_range(0.0, TAU),
					"r": Grid.TILE_SIZE * _rng.randf_range(0.06, 0.11)})
		&"cut_ring":
			for i in 6:
				var angle := TAU * float(i) / 6.0
				_bits.append({"p": Vector2.from_angle(angle) * reach * _rng.randf_range(0.35, 0.8), "a": angle})
		&"item":
			pass


## Its bits flung out from the middle: `count` of them, from within `spread`, at
## `slow` to `fast` pixels a second, pulled down at `pull`, sized within `sizes`
## (shares of a tile) - turning, for shards.
func _scatter(count: int, spread: float, slow: float, fast: float, pull: float, sizes: Vector2, turning: bool = false):
	for i in count:
		var angle := _rng.randf_range(0.0, TAU)
		_bits.append({"p": Vector2.from_angle(angle) * _rng.randf_range(0.0, spread),
			"v": Vector2.from_angle(angle) * _rng.randf_range(slow, fast), "g": pull,
			"r": Grid.TILE_SIZE * _rng.randf_range(sizes.x, sizes.y), "life": _rng.randf_range(0.6, 1.0),
			"spin": _rng.randf_range(-9.0, 9.0) if turning else 0.0, "a": _rng.randf_range(0.0, TAU)})


## Motes rising off somebody, from across `width`.
func _rise(count: int, width: float):
	for i in count:
		_bits.append({"p": Vector2(_rng.randf_range(-width, width) * 0.5, _rng.randf_range(-Grid.TILE_SIZE * 0.1, Grid.TILE_SIZE * 0.3)),
			"v": Vector2(_rng.randf_range(-12.0, 12.0), -_rng.randf_range(90.0, 190.0)), "g": 0.0,
			"r": Grid.TILE_SIZE * _rng.randf_range(0.015, 0.035), "life": _rng.randf_range(0.6, 1.0), "spin": 0.0,
			"a": _rng.randf_range(0.0, TAU)})


## Jagged forks out from the middle, for lightning and a storm.
func _forks(count: int, length: float):
	for i in count:
		var angle := TAU * float(i) / float(count) + _rng.randf_range(-0.4, 0.4)
		var line := PackedVector2Array([Vector2.ZERO])
		var steps := 5
		for step in range(1, steps + 1):
			var along := Vector2.from_angle(angle) * length * float(step) / float(steps)
			line.append(along + Vector2.from_angle(angle + PI / 2.0) * _rng.randf_range(-length * 0.12, length * 0.12))
		_bits.append({"line": line, "flicker": _rng.randf_range(0.0, 1.0)})


func _build_burst():
	var tile := float(Grid.TILE_SIZE)
	var many := maxi(int(16.0 * strength), 6)
	match element:
		Damage.Type.FIRE:
			_scatter(many, tile * 0.14, 30.0, 90.0, -320.0, Vector2(0.025, 0.05))
		Damage.Type.WATER:
			_scatter(many, tile * 0.08, 200.0, 380.0, 1200.0, Vector2(0.02, 0.035))
			for bit in _bits:
				bit.v.y -= 260.0
		Damage.Type.EARTH:
			_scatter(many, tile * 0.08, 160.0, 360.0, 1100.0, Vector2(0.025, 0.05), true)
			for bit in _bits:
				bit.v.y -= 220.0
		Damage.Type.POISON:
			_scatter(many / 2 + 3, tile * 0.18, 10.0, 40.0, -140.0, Vector2(0.03, 0.06))
		Damage.Type.ICE:
			_scatter(many, tile * 0.05, 260.0, 480.0, 0.0, Vector2(0.05, 0.1), true)
			for bit in _bits:
				bit.a = bit.v.angle()
		Damage.Type.LIGHTNING:
			_forks(5, tile * 0.55)
		Damage.Type.METAL:
			_scatter(many, tile * 0.05, 380.0, 680.0, 1400.0, Vector2(0.01, 0.02))
			for bit in _bits:
				bit.v.y -= 200.0
		Damage.Type.ACID:
			_scatter(many / 2 + 4, tile * 0.16, 20.0, 90.0, 700.0, Vector2(0.02, 0.035))
			_rise(6, tile * 0.4)
		Damage.Type.IDOL, -2:
			_rise(many, tile * 0.5)
		Damage.Type.PLASMA:
			_scatter(many, tile * 0.05, 300.0, 520.0, 0.0, Vector2(0.012, 0.025))
		_:
			pass


func _process(delta: float):
	_clock += delta
	if not on.is_empty():
		var sprite = on.get("sprite")
		if sprite != null and is_instance_valid(sprite):
			position = sprite.position + on_offset
	match kind:
		&"mark":
			# Gone over its rounds, faded round by round.
			if combat == null or not is_instance_valid(combat) or combat.round_number - _born_round >= MARK_ROUNDS:
				queue_free()
				return
		&"declared":
			# Until it lands, or is dropped.
			if combat == null or not is_instance_valid(combat) or not on.get("alive", false) or not on.has("declared"):
				queue_free()
				return
		&"spread":
			if combat != null and is_instance_valid(combat) and combat.controller != null:
				combat.controller.queue_redraw()
			if _clock >= seconds:
				if combat != null and is_instance_valid(combat):
					combat.spreading_zones.erase(element)
					if combat.controller != null:
						combat.controller.queue_redraw()
				queue_free()
			return
	if _clock >= seconds:
		queue_free()
		return
	queue_redraw()


## Where `bit` is, `s` seconds in.
static func _at(bit: Dictionary, s: float) -> Vector2:
	return bit.p + bit.v * s + Vector2(0.0, 0.5 * bit.g * s * s)


func _draw():
	var t := clampf(_clock / seconds, 0.0, 1.0) if seconds < INF else 0.0
	var tile := float(Grid.TILE_SIZE)
	match kind:
		&"burst":
			_draw_burst(t)
		&"muzzle":
			_draw_muzzle(t)
		&"glyph":
			_draw_glyph(Vector2.ZERO, tile * (0.32 + 0.22 * t), t * 4.0, Color(colour, 1.0 - t), 2.0 + 3.0 * (1.0 - t))
		&"swish":
			var angle := toward.angle()
			var reached := minf(t / 0.5, 1.0)
			_draw_band(Vector2.ZERO - toward * tile * 0.3, tile * 0.42, angle - 1.0, angle - 1.0 + 2.0 * reached, 10.0 * (1.0 - t), 1.0,
				Color(1, 1, 1, 0.7 * (1.0 - t)))
		&"roar":
			for i in 3:
				var own := clampf((t - 0.12 * i) / 0.75, 0.0, 1.0)
				if own <= 0.0 or own >= 1.0:
					continue
				var angle := toward.angle()
				draw_arc(Vector2.ZERO, tile * (0.3 + 1.6 * own), angle - 0.7, angle + 0.7, 24, Color(colour.lerp(Color.WHITE, 0.5), 0.8 * (1.0 - own)),
					10.0 * (1.0 - own) + 2.0)
		&"puff", &"dust":
			for bit in _bits:
				var s := _clock
				var own: float = clampf(t / bit.life, 0.0, 1.0)
				draw_circle(_at(bit, s), bit.r * (0.6 + 0.9 * own) * strength, Color(colour, 0.55 * (1.0 - own)))
		&"swoosh", &"heavy_swoosh", &"edge":
			var heavy := kind == &"heavy_swoosh"
			var angle := toward.angle() + PI / 2.0
			var sweep := minf(t / 0.35, 1.0)
			var radius := tile * (0.62 if heavy else 0.5)
			var start := angle - 1.3
			var tint := colour.lerp(Color.WHITE, 0.25 if kind == &"edge" else 0.6)
			if kind == &"edge":
				draw_circle(Vector2.ZERO, tile * 0.3 * (1.0 - t), Color(colour, 0.35 * (1.0 - t)))
			_draw_band(-toward * tile * 0.15, radius, start, start + 2.6 * sweep, (26.0 if heavy else 15.0) * strength * (1.0 - t * 0.6), 2.0,
				Color(tint, 0.9 * (1.0 - t)))
		&"half_circle":
			var angle := toward.angle()
			var sweep := minf(t / 0.4, 1.0)
			_draw_band(Vector2.ZERO, tile * 0.85, angle - PI / 2.0, angle - PI / 2.0 + PI * sweep, 16.0 * (1.0 - t * 0.6), 2.0,
				Color(colour.lerp(Color.WHITE, 0.6), 0.85 * (1.0 - t)))
		&"thrust":
			var reach_now := minf(t / 0.2, 1.0)
			var back := -toward * tile * 0.8
			draw_line(back, back.lerp(toward * tile * 0.25, reach_now), Color(1, 1, 1, 0.95 * (1.0 - t * t)), 9.0 * (1.0 - t) + 2.0)
			if t > 0.15:
				var flare := clampf((t - 0.15) / 0.5, 0.0, 1.0)
				draw_colored_polygon(_star(Vector2.ZERO, 4, tile * 0.2 * (1.0 - flare), tile * 0.04, 0.3), Color(1, 1, 1, 1.0 - flare))
		&"claw":
			var across := Vector2.from_angle(-PI / 3.0)
			var sideways := across.orthogonal()
			for i in 3:
				var own := clampf((t - 0.06 * i) / 0.3, 0.0, 1.0)
				var middle := sideways * tile * 0.13 * float(i - 1)
				var half := across * tile * 0.38
				_draw_slash(middle - half, middle - half + half * 2.0 * minf(own * 2.5, 1.0), 9.0, Color(1.0, 0.18, 0.15, 1.0 - t))
		&"low_slash":
			var reached := minf(t / 0.25, 1.0)
			var low := Vector2(0.0, tile * 0.32)
			_draw_slash(low + Vector2(-tile * 0.45, 0), low + Vector2(-tile * 0.45 + tile * 0.9 * reached, -tile * 0.06), 8.0,
				Color(colour.lerp(Color.WHITE, 0.5), 1.0 - t))
		&"stake":
			var punch := clampf(t / 0.2, 0.0, 1.0)
			var foot := Vector2(tile * 0.18, tile * 0.38)
			var length := tile * 0.42 * (0.4 + 0.6 * punch)
			draw_colored_polygon(PackedVector2Array([foot, foot + Vector2(-tile * 0.06, -length), foot + Vector2(tile * 0.06, -length)]),
				Color(0.75, 0.62, 0.45, 1.0 - t * 0.7))
			if punch >= 1.0:
				var ring := clampf((t - 0.2) / 0.5, 0.0, 1.0)
				_draw_ellipse_ring(foot, tile * 0.35 * ring, tile * 0.12 * ring, Color(0.85, 0.78, 0.65, 0.8 * (1.0 - ring)), 3.0)
		&"shield_stars":
			if t < 0.3:
				var own := t / 0.3
				draw_colored_polygon(_shield(Vector2.ZERO, tile * (0.28 + 0.12 * own)), Color(0.75, 0.9, 1.0, 0.8 * (1.0 - own)))
			var head: Vector2 = points[0] if not points.is_empty() else Vector2(0, -tile * 0.5)
			for i in 3:
				var angle := _clock * 5.0 + TAU * float(i) / 3.0
				var spot := head + Vector2(cos(angle) * tile * 0.22, sin(angle) * tile * 0.07)
				draw_colored_polygon(_star(spot, 5, tile * 0.07, tile * 0.03, angle), Color(1.0, 0.92, 0.4, minf(1.0, (1.0 - t) * 3.0)))
		&"shockwave":
			for i in 2:
				var own := clampf((t - 0.15 * i) / 0.75, 0.0, 1.0)
				if own <= 0.0 or own >= 1.0:
					continue
				var radius := (reach if reach > 0.0 else tile) * (0.2 + 0.8 * own)
				_draw_ellipse_ring(Vector2(0, tile * 0.25), radius, radius * 0.4, Color(colour.lerp(Color.WHITE, 0.5), 0.9 * (1.0 - own) * strength),
					12.0 * (1.0 - own) + 2.0)
		&"flash":
			draw_circle(Vector2.ZERO, tile * (0.4 + 0.5 * t), Color(1, 1, 1, 0.85 * (1.0 - t)))
			for i in 8:
				var angle := TAU * float(i) / 8.0
				draw_line(Vector2.from_angle(angle) * tile * 0.3, Vector2.from_angle(angle) * tile * (0.5 + 0.6 * t), Color(1, 1, 1, 0.8 * (1.0 - t)), 3.0)
		&"ripples":
			for i in 3:
				var own := clampf((t - 0.15 * i) / 0.7, 0.0, 1.0)
				if own <= 0.0 or own >= 1.0:
					continue
				_draw_wobbly_ring(Vector2.ZERO, tile * (0.15 + 0.55 * own), 4.0 * (1.0 - own), Color(colour, 0.85 * (1.0 - own)), 3.0)
		&"bonk":
			var head: Vector2 = points[0] if not points.is_empty() else Vector2(0, -tile * 0.5)
			var pop := minf(t / 0.15, 1.0)
			var size := tile * 0.2 * (pop * 1.2 if pop < 1.0 else 1.2 - 0.2 * minf((t - 0.15) / 0.1, 1.0))
			draw_colored_polygon(_star(head, 6, size, size * 0.45, 0.2), Color(1.0, 0.85, 0.2, 1.0 - maxf(t - 0.6, 0.0) / 0.4))
			for i in 4:
				var angle := -PI / 2.0 + (float(i) - 1.5) * 0.5
				var from := head + Vector2.from_angle(angle) * size * 1.3
				draw_line(from, from + Vector2.from_angle(angle) * tile * 0.12, Color(1, 1, 1, 1.0 - t), 3.0)
		&"seal":
			var stamp := minf(t / 0.18, 1.0)
			var radius := tile * 0.3 * (2.2 - 1.2 * stamp)
			var fade := 1.0 - maxf(t - 0.6, 0.0) / 0.4
			draw_circle(Vector2.ZERO, radius, Color(colour, 0.25 * fade))
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(colour, 0.95 * fade), 5.0)
			draw_arc(Vector2.ZERO, radius * 0.72, 0.0, TAU, 32, Color(colour_b, 0.8 * fade), 3.0)
			draw_line(Vector2(-radius * 0.4, 0), Vector2(radius * 0.4, 0), Color(colour_b, 0.9 * fade), 4.0)
			draw_line(Vector2(0, -radius * 0.4), Vector2(0, radius * 0.4), Color(colour_b, 0.9 * fade), 4.0)
		&"column", &"rise":
			var grow := minf(t / 0.25, 1.0)
			var fade := 1.0 - maxf(t - 0.5, 0.0) / 0.5
			var width := tile * 0.36
			for i in 4:
				var share := 1.0 - float(i) / 4.0
				draw_rect(Rect2(Vector2(-width * share * 0.5, -tile * 1.1 * grow), Vector2(width * share, tile * 1.1 * grow + tile * 0.4)),
					Color(colour, 0.12 * fade))
			_draw_motes(t, colour)
		&"motes":
			_draw_motes(t, colour)
		&"wash":
			var band := lerpf(-tile * 0.6, tile * 0.5, t)
			draw_rect(Rect2(Vector2(-tile * 0.4, band - tile * 0.08), Vector2(tile * 0.8, tile * 0.16)), Color(1, 1, 1, 0.4 * (1.0 - t)))
			for i in 3:
				var at := Vector2((float(i) - 1.0) * tile * 0.22, -tile * 0.3)
				var gone := clampf((t - 0.2 * i) / 0.5, 0.0, 1.0)
				var size := tile * 0.09 * (1.0 - gone)
				draw_rect(Rect2(at - Vector2.ONE * size, Vector2.ONE * size * 2.0), Color(1.0, 0.45, 0.4, 0.9 * (1.0 - gone)))
				for j in 4:
					var drift := Vector2.from_angle(TAU * j / 4.0 + i) * tile * 0.15 * gone
					draw_circle(at + drift + Vector2(0, -tile * 0.1 * gone), 3.0, Color(1, 1, 1, 0.8 * (1.0 - gone)))
		&"shards_gather":
			var come := minf(t / 0.6, 1.0)
			for bit in _bits:
				var at: Vector2 = bit.p * (1.0 - come)
				draw_colored_polygon(_shard(at, bit.r, bit.a + come * 3.0), Color(0.82, 0.92, 1.0, 0.85 * (1.0 - maxf(come - 0.85, 0.0) / 0.15)))
			if come >= 1.0:
				draw_circle(Vector2.ZERO, tile * 0.35 * (t - 0.6) / 0.4 + 4.0, Color(1, 1, 1, 0.6 * (1.0 - (t - 0.6) / 0.4)))
		&"dome":
			var settle := minf(t / 0.4, 1.0)
			var fade := 1.0 - maxf(t - 0.6, 0.0) / 0.4
			var radius := reach * (1.35 - 0.35 * settle)
			var arc := _ellipse_points(Vector2.ZERO, radius, radius * 0.75, 40, PI, TAU)
			arc.append(Vector2(radius, 0))
			draw_colored_polygon(arc, Color(colour.lerp(Color.WHITE, 0.5), 0.12 * fade))
			draw_polyline(arc, Color(colour.lerp(Color.WHITE, 0.6), 0.85 * fade), 4.0)
			_draw_ellipse_ring(Vector2.ZERO, radius, radius * 0.3, Color(colour, 0.6 * fade), 3.0)
		&"glyph_circle":
			var drawn := minf(t / 0.6, 1.0)
			var fade := 1.0 - maxf(t - 0.7, 0.0) / 0.3
			draw_arc(Vector2.ZERO, reach, -PI / 2.0, -PI / 2.0 + TAU * drawn, 64, Color(colour, 0.9 * fade), 5.0)
			draw_arc(Vector2.ZERO, reach * 0.85, PI / 2.0, PI / 2.0 + TAU * drawn, 56, Color(colour, 0.6 * fade), 3.0)
			for i in int(16 * drawn):
				var angle := -PI / 2.0 + TAU * float(i) / 16.0
				draw_line(Vector2.from_angle(angle) * reach * 0.86, Vector2.from_angle(angle) * reach * 0.98, Color(colour, fade), 3.0)
			if drawn >= 1.0:
				_draw_glyph(Vector2.ZERO, reach * 0.6, _clock, Color(colour, 0.8 * fade), 3.0)
		&"storm":
			var fade := minf(t / 0.15, 1.0) * (1.0 - maxf(t - 0.7, 0.0) / 0.3)
			for i in 4:
				var angle := _clock * (3.0 + i) + float(i) * 1.3
				draw_arc(Vector2.ZERO, reach * (0.3 + 0.17 * i), angle, angle + 2.2, 24, Color(colour, 0.6 * fade), 4.0)
			for bit in _bits:
				if fmod(_clock * 10.0 + bit.flicker * 3.0, 2.0) < 0.7:
					draw_polyline(bit.line, Color(colour.lerp(Color.WHITE, 0.6), 0.9 * fade), 3.0)
		&"fire_ring":
			var ring := minf(t / 0.6, 1.0)
			var radius := (reach if reach > 0.0 else tile * 0.8) * (0.2 + 0.8 * ring)
			_draw_ellipse_ring(Vector2(0, tile * 0.15), radius, radius * 0.45, Color(colour.lerp(Color(1, 0.9, 0.5), 0.3), 0.9 * (1.0 - t)), 10.0 * (1.0 - t) + 2.0)
			_draw_embers(t)
		&"wildfire":
			for i in points.size():
				var own := clampf((t - float(i) * 0.06) / 0.45, 0.0, 1.0)
				if own <= 0.0 or own >= 1.0:
					continue
				var square := Rect2(points[i] - Vector2.ONE * tile * 0.5, Vector2.ONE * tile)
				draw_rect(square, Color(colour, 0.35 * (1.0 - own)))
				for j in 3:
					var flame: Vector2 = points[i] + Vector2((float(j) - 1.0) * tile * 0.2, tile * 0.2 - own * tile * 0.5)
					draw_circle(flame, tile * 0.07 * (1.0 - own), Color(1.0, 0.8 - 0.5 * own, 0.3, 0.9 * (1.0 - own)))
		&"cut_ring":
			var ring := minf(t / 0.7, 1.0)
			var radius := reach * ring
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(1, 1, 1, 0.9 * (1.0 - t)), 5.0)
			for bit in _bits:
				var far: float = bit.p.length()
				var cut := clampf((radius - far) / (tile * 0.3), 0.0, 1.0)
				var split := Vector2.from_angle(bit.a + PI / 2.0) * tile * 0.12 * cut
				var alpha := 0.9 * (1.0 - cut)
				draw_arc(bit.p + split, tile * 0.09, bit.a, bit.a + PI, 10, Color(colour, alpha), 3.0)
				draw_arc(bit.p - split, tile * 0.09, bit.a + PI, bit.a + TAU, 10, Color(colour, alpha), 3.0)
		&"code_scatter":
			for bit in _bits:
				var at := _at(bit, _clock)
				var own: float = clampf(t / bit.life, 0.0, 1.0)
				var glyph_colour := Color(0.35, 1.0, 0.5, 1.0 - own)
				if int(bit.a * 10.0) % 2 == 0:
					draw_rect(Rect2(at - Vector2(bit.r * 0.25, bit.r * 0.5), Vector2(bit.r * 0.5, bit.r)), glyph_colour, false, 3.0)
				else:
					draw_line(at - Vector2(0, bit.r * 0.5), at + Vector2(0, bit.r * 0.5), glyph_colour, 3.0)
		&"lift":
			var squeeze := 1.0 - 0.4 * sin(PI * t)
			_draw_ellipse_fill(Vector2(0, tile * 0.38), (reach if reach > 0.0 else tile * 0.3) * squeeze, tile * 0.08 * squeeze, Color(0, 0, 0, 0.3))
		&"speed_lines":
			for i in 6:
				var y := (float(i) - 2.5) * tile * 0.12
				var x := lerpf(tile * 0.7, -tile * 0.9, fmod(t * 1.6 + float(i) * 0.17, 1.0))
				draw_line(Vector2(x, y), Vector2(x + tile * 0.35, y), Color(colour.lerp(Color.WHITE, 0.5), 0.8 * (1.0 - t)), 3.0)
		&"shimmer":
			for i in 5:
				var x := (float(i) - 2.0) * tile * 0.12
				var line := PackedVector2Array()
				for step in 9:
					var y := -tile * 0.5 + tile * 0.12 * step
					line.append(Vector2(x + sin(_clock * 14.0 + step + i) * 5.0, y))
				draw_polyline(line, Color(colour.lerp(Color.WHITE, 0.6), 0.6 * sin(PI * t)), 2.0)
		&"eye":
			var head: Vector2 = points[0] if not points.is_empty() else Vector2(0, -tile * 0.55)
			var open := minf(t / 0.3, 1.0)
			var fade := 1.0 - maxf(t - 0.7, 0.0) / 0.3
			var width := tile * 0.28
			var lid := _ellipse_points(head, width, tile * 0.13 * open, 24, 0.0, TAU)
			draw_colored_polygon(lid, Color(1, 1, 1, 0.75 * fade))
			draw_polyline(lid, Color(colour, fade), 3.0)
			draw_circle(head, tile * 0.07 * open, Color(colour.darkened(0.3), fade))
		&"stream":
			for i in points.size():
				var own := clampf((t - float(i) * 0.05) / 0.45, 0.0, 1.0)
				if own <= 0.0 or own >= 1.0:
					continue
				var middle: Vector2 = points[i]
				for j in 3:
					var line := PackedVector2Array()
					for step in 7:
						var x := -tile * 0.4 + tile * 0.8 * step / 6.0
						line.append(middle + Vector2(x, (float(j) - 1.0) * tile * 0.15 + sin(x * 0.05 + _clock * 10.0) * 6.0).rotated(toward.angle()))
					draw_polyline(line, Color(colour.lerp(Color.WHITE, 0.3), 0.75 * sin(PI * own)), 3.0)
		&"ice_spread":
			for i in points.size():
				var own := clampf((t - float(i) * 0.06) / 0.5, 0.0, 1.0)
				if own <= 0.0:
					continue
				var middle: Vector2 = points[i]
				var fade := 1.0 - maxf(t - 0.7, 0.0) / 0.3
				draw_rect(Rect2(middle - Vector2.ONE * tile * 0.5, Vector2.ONE * tile), Color(0.75, 0.92, 1.0, 0.18 * fade))
				for j in 6:
					var angle := TAU * float(j) / 6.0 + float(i)
					draw_line(middle, middle + Vector2.from_angle(angle) * tile * 0.35 * own, Color(0.9, 0.97, 1.0, 0.8 * fade), 3.0)
		&"rays":
			var top := Vector2(0, -tile * 0.9)
			var fade := sin(PI * t)
			for i in 7:
				var angle := PI / 2.0 + (float(i) - 3.0) * 0.16
				draw_line(top, top + Vector2.from_angle(angle) * tile * 1.3, Color(colour.lerp(Color.WHITE, 0.5), 0.5 * fade), 6.0)
		&"wing":
			var sweep := lerpf(-1.0, 1.0, t)
			var fade := sin(PI * t)
			var span := reach
			var centre := toward.orthogonal() * span * 0.2 + toward * span * sweep * 0.6
			var wing := PackedVector2Array([centre])
			for i in 9:
				var share := float(i) / 8.0
				var along := toward.orthogonal() * span * (share - 0.5) * 1.6
				wing.append(centre + along - toward * span * (0.35 + 0.15 * sin(share * PI * 4.0)) * sin(share * PI))
			draw_colored_polygon(wing, Color(colour.lerp(Color.WHITE, 0.5), 0.25 * fade))
			draw_polyline(wing, Color(colour.lerp(Color.WHITE, 0.6), 0.55 * fade), 3.0)
		&"disarm":
			var up := Vector2(tile * 0.35 * t, -tile * 0.6 * sin(PI * minf(t * 1.1, 1.0)) + tile * 0.3 * t)
			var angle := t * TAU * 1.5
			var blade := Vector2.from_angle(angle) * tile * 0.22
			draw_line(up - blade, up + blade, Color(colour, 1.0 - maxf(t - 0.7, 0.0) / 0.3), 6.0)
			var guard := Vector2.from_angle(angle + PI / 2.0) * tile * 0.07
			draw_line(up - blade * 0.6 - guard, up - blade * 0.6 + guard, Color(0.7, 0.55, 0.3, 1.0 - maxf(t - 0.7, 0.0) / 0.3), 5.0)
		&"settle":
			var click := minf(t / 0.2, 1.0)
			_draw_ellipse_ring(Vector2(0, tile * 0.2), tile * 0.3 * click, tile * 0.1 * click, Color(1, 1, 1, 0.7 * (1.0 - click)), 3.0)
			var glint := sin(PI * clampf((t - 0.25) / 0.75, 0.0, 1.0))
			draw_colored_polygon(_star(Vector2(tile * 0.08, tile * 0.12), 4, tile * 0.12 * glint, tile * 0.025, 0.0), Color(1, 1, 0.9, 0.9 * glint))
		&"spark_beside", &"rock_break", &"shatter":
			for bit in _bits:
				var own: float = clampf(t / bit.life, 0.0, 1.0)
				var at := _at(bit, _clock)
				match kind:
					&"spark_beside":
						draw_line(at, at - bit.v.normalized() * 14.0, Color(1.0, 0.85, 0.5, 1.0 - own), 3.0)
					&"rock_break":
						draw_colored_polygon(_shard(at, bit.r, bit.a + bit.spin * _clock), Color(0.55, 0.42, 0.3, 1.0 - own))
					&"shatter":
						draw_colored_polygon(_shard(at, bit.r, bit.a + bit.spin * _clock), Color(colour, 0.9 * (1.0 - own)))
		&"whiff":
			var past := toward * tile * (0.2 + 0.6 * t)
			for i in 3:
				var offset := toward.orthogonal() * (float(i) - 1.0) * tile * 0.12
				draw_line(offset + past - toward * tile * 0.4, offset + past, Color(colour, 0.6 * (1.0 - t)), 3.0)
		&"line":
			var end: Vector2 = points[0] if not points.is_empty() else Vector2.ZERO
			var drawn := minf(t / 0.35, 1.0)
			var fade := 1.0 - maxf(t - 0.6, 0.0) / 0.4
			draw_line(Vector2.ZERO, end * drawn, Color(colour, 0.9 * fade), 6.0)
			draw_line(Vector2.ZERO, end * drawn, Color(1, 1, 1, 0.7 * fade), 2.0)
			draw_arc(Vector2.ZERO, tile * 0.2, 0.0, TAU, 24, Color(colour, fade), 3.0)
			if drawn >= 1.0:
				draw_arc(end, tile * 0.25, 0.0, TAU, 24, Color(colour, fade), 4.0)
		&"exclaim":
			var pop := minf(t / 0.15, 1.0)
			var size := int(tile * 0.45 * (0.6 + 0.4 * pop))
			var font := ThemeDB.fallback_font
			var fade := 1.0 - maxf(t - 0.7, 0.0) / 0.3
			var at := Vector2(-size * 0.15, 0.0)
			draw_string_outline(font, at, "!", HORIZONTAL_ALIGNMENT_LEFT, -1, size, int(size * 0.25), Color(0, 0, 0, 0.85 * fade))
			draw_string(font, at, "!", HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(colour, fade))
		&"outline":
			var half := Vector2.ONE * tile * 0.5
			for point in points:
				draw_rect(Rect2(point - half, half * 2.0), Color(colour.lerp(Color.WHITE, 0.4), 0.9 * (1.0 - t)), false, 8.0 * (1.0 - t) + 2.0)
		&"item":
			var end: Vector2 = points[0] if not points.is_empty() else Vector2.ZERO
			var at := Vector2.ZERO.lerp(end, t) + Vector2(0.0, -tile * 0.5 * sin(PI * t))
			if texture != null:
				var size := Vector2.ONE * tile * 0.32
				draw_texture_rect(texture, Rect2(at - size / 2.0, size), false)
			else:
				draw_circle(at, tile * 0.12, Color(colour, 0.9))
				draw_arc(at, tile * 0.12, 0.0, TAU, 20, Color(1, 1, 1, 0.9), 3.0)
		&"mark":
			_draw_mark()
		&"declared":
			_draw_declared()


## Its bits as its element's burst.
func _draw_burst(t: float):
	var tile := float(Grid.TILE_SIZE)
	var fade := 1.0 - t
	# The landing itself: a white-hot flash, brief.
	if t < 0.25:
		var flash := 1.0 - t / 0.25
		draw_circle(Vector2.ZERO, tile * 0.22 * flash * strength + 2.0, Color(1, 1, 1, 0.85 * flash))
	match element:
		Damage.Type.FIRE:
			for bit in _bits:
				var own: float = clampf(t / bit.life, 0.0, 1.0)
				var hot := Color(1.0, 0.92, 0.55).lerp(colour, minf(own * 2.0, 1.0)).lerp(Color(0.5, 0.08, 0.02), maxf(own - 0.5, 0.0) * 2.0)
				draw_circle(_at(bit, _clock) + Vector2(sin(_clock * 9.0 + bit.a) * 6.0, 0.0), bit.r * (1.0 - own * 0.7), Color(hot, 1.0 - own))
		Damage.Type.WATER:
			_draw_ellipse_ring(Vector2(0, tile * 0.1), tile * (0.15 + 0.35 * t), tile * (0.05 + 0.12 * t), Color(colour, 0.7 * fade), 4.0)
			for bit in _bits:
				var own: float = clampf(t / bit.life, 0.0, 1.0)
				var at := _at(bit, _clock)
				var going: Vector2 = bit.v + Vector2(0.0, bit.g * _clock)
				draw_set_transform(at, going.angle(), Vector2(1.6, 1.0))
				draw_circle(Vector2.ZERO, bit.r, Color(colour.lerp(Color.WHITE, 0.3), 1.0 - own))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		Damage.Type.WIND:
			for i in 4:
				var start := t * 7.0 + TAU * float(i) / 4.0
				draw_arc(Vector2.ZERO, tile * (0.12 + 0.38 * t + 0.03 * i), start, start + 1.3, 16, Color(colour.lerp(Color.WHITE, 0.4), 0.85 * fade),
					4.0 * fade + 1.0)
		Damage.Type.EARTH:
			_draw_ellipse_fill(Vector2(0, tile * 0.15), tile * (0.2 + 0.3 * t), tile * (0.07 + 0.1 * t), Color(colour.darkened(0.2), 0.35 * fade))
			for bit in _bits:
				var own: float = clampf(t / bit.life, 0.0, 1.0)
				draw_colored_polygon(_shard(_at(bit, _clock), bit.r, bit.a + bit.spin * _clock), Color(colour.darkened(0.15 * float(int(bit.a) % 3)), 1.0 - own))
		Damage.Type.POISON:
			for bit in _bits:
				var own: float = clampf(t / bit.life, 0.0, 1.0)
				var at := _at(bit, _clock) + Vector2(sin(_clock * 6.0 + bit.a) * 5.0, 0.0)
				var pop := own > 0.85
				draw_arc(at, bit.r * (0.6 + 0.6 * own) * (1.4 if pop else 1.0), 0.0, TAU, 14, Color(colour, (1.0 - own) * (0.4 if pop else 1.0)), 3.0)
				draw_circle(at + Vector2(-bit.r * 0.25, -bit.r * 0.25), bit.r * 0.18, Color(1, 1, 1, 0.6 * (1.0 - own)))
		Damage.Type.PSYCHIC:
			for i in 3:
				var own := clampf((t - 0.15 * i) / 0.7, 0.0, 1.0)
				if own > 0.0 and own < 1.0:
					_draw_wobbly_ring(Vector2.ZERO, tile * (0.1 + 0.45 * own), 4.0 * (1.0 - own), Color(colour, 0.9 * (1.0 - own)), 3.0)
		Damage.Type.PLASMA:
			draw_circle(Vector2.ZERO, tile * 0.3 * (1.0 - t) * strength, Color(colour, 0.5 * fade))
			draw_circle(Vector2.ZERO, tile * 0.18 * (1.0 - t) * strength, Color(1, 1, 1, 0.95 * fade))
			for bit in _bits:
				var at := _at(bit, _clock)
				draw_line(at, at - bit.v.normalized() * 10.0, Color(colour.lerp(Color.WHITE, 0.5), fade), 3.0)
		Damage.Type.ICE:
			for bit in _bits:
				var own: float = clampf(t / bit.life, 0.0, 1.0)
				draw_colored_polygon(_shard(_at(bit, _clock), bit.r, bit.a + bit.spin * _clock * 0.3), Color(colour.lerp(Color.WHITE, 0.4), 1.0 - own))
		Damage.Type.LIGHTNING:
			for bit in _bits:
				if fmod(_clock * 14.0 + bit.flicker * 4.0, 2.0) < 1.1:
					draw_polyline(bit.line, Color(colour.lerp(Color.WHITE, 0.55), fade), 4.0 * fade + 1.0)
		Damage.Type.METAL:
			for bit in _bits:
				var own: float = clampf(t / bit.life, 0.0, 1.0)
				var at := _at(bit, _clock)
				var going: Vector2 = (bit.v + Vector2(0.0, bit.g * _clock)).normalized()
				draw_line(at, at - going * 16.0, Color(Color(1.0, 0.95, 0.7).lerp(colour, own), 1.0 - own), 3.0)
		Damage.Type.ACID:
			for bit in _bits:
				var own: float = clampf(t / bit.life, 0.0, 1.0)
				var at := _at(bit, _clock)
				if bit.g > 0.0:
					draw_circle(at, bit.r * (1.0 - own * 0.5), Color(colour, 1.0 - own))
				else:
					draw_circle(at, bit.r * (1.0 + 1.5 * own), Color(0.8, 0.85, 0.75, 0.35 * (1.0 - own)))
		Damage.Type.IDOL, -2:
			draw_arc(Vector2.ZERO, tile * (0.15 + 0.3 * t), 0.0, TAU, 32, Color(colour, 0.6 * fade), 3.0)
			_draw_motes(t, colour)
		_:
			for i in 8:
				var angle := TAU * float(i) / 8.0 + 0.2
				draw_line(Vector2.from_angle(angle) * tile * (0.1 + 0.15 * t), Vector2.from_angle(angle) * tile * (0.22 + 0.25 * t),
					Color(1, 1, 1, 0.9 * fade), 4.0 * fade + 1.0)
			draw_arc(Vector2.ZERO, tile * (0.15 + 0.25 * t), 0.0, TAU, 28, Color(colour, 0.6 * fade), 3.0)


## A muzzle's flash, towards where it was aimed, and the smoke after it - and,
## for a shot, its casing flicking out.
func _draw_muzzle(t: float):
	var tile := float(Grid.TILE_SIZE)
	var angle := toward.angle()
	if t < 0.3:
		var flash := 1.0 - t / 0.3
		var spikes := PackedVector2Array()
		for i in 12:
			var spike_angle := TAU * float(i) / 12.0
			var long := 1.0 + 1.6 * maxf(cos(spike_angle), 0.0)
			var radius := tile * (0.16 * long if i % 2 == 0 else 0.06) * flash
			spikes.append(Vector2.from_angle(angle + spike_angle) * radius)
		draw_colored_polygon(spikes, Color(1.0, 0.9, 0.55, 0.95 * flash))
		draw_circle(Vector2.ZERO, tile * 0.06 * flash, Color(1, 1, 1, flash))
	for i in 3:
		var drift := toward * tile * (0.1 + 0.25 * t) * float(i + 1) * 0.6 + Vector2(0, -tile * 0.15 * t)
		draw_circle(drift, tile * (0.05 + 0.08 * t), Color(0.8, 0.8, 0.82, 0.4 * (1.0 - t)))
	if text == "casing":
		var out := toward.orthogonal() * (1.0 if toward.x >= 0.0 else -1.0)
		var at := -toward * tile * 0.15 + out * tile * 0.5 * t + Vector2(0.0, -tile * 0.6 * t + tile * 1.4 * t * t)
		draw_set_transform(at, t * 18.0, Vector2.ONE)
		draw_rect(Rect2(Vector2(-5, -2.5), Vector2(10, 5)), Color(0.85, 0.66, 0.25, 1.0 - t))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Motes rising, in `tint`, each twinkling.
func _draw_motes(t: float, tint: Color):
	for bit in _bits:
		var own: float = clampf(t / bit.life, 0.0, 1.0)
		var twinkle: float = 0.6 + 0.4 * sin(_clock * 16.0 + bit.a * 5.0)
		draw_circle(_at(bit, _clock), bit.r * twinkle, Color(tint.lerp(Color.WHITE, 0.35), (1.0 - own) * 0.95))


## Embers rising, for a ring of fire.
func _draw_embers(t: float):
	for bit in _bits:
		var own: float = clampf(t / bit.life, 0.0, 1.0)
		var at: Vector2 = _at(bit, _clock) * Vector2(1.0 + 2.0 * t, 1.0)
		draw_circle(at, bit.r * (1.0 - own * 0.6), Color(Color(1.0, 0.85, 0.4).lerp(colour, own), 1.0 - own))


## A mark on the ground, its kind in `element` (SkillDefinition.GroundMark),
## fading round by round.
func _draw_mark():
	var tile := float(Grid.TILE_SIZE)
	var rounds := float(combat.round_number - _born_round) if combat != null and is_instance_valid(combat) else 0.0
	var alpha := MARK_ALPHA * (1.0 - rounds / float(MARK_ROUNDS)) * minf(_clock / 0.3, 1.0)
	for i in points.size():
		var at: Vector2 = points[i]
		var wobble := sin(float(i) * 2.7) * tile * 0.05
		match element:
			SkillDefinition.GroundMark.SCORCH:
				_draw_ellipse_fill(at, tile * 0.38 + wobble, tile * 0.3, Color(0.08, 0.05, 0.03, alpha))
				_draw_ellipse_fill(at + Vector2(tile * 0.06, -tile * 0.02), tile * 0.2, tile * 0.14, Color(0.35, 0.12, 0.02, alpha * 0.6))
			SkillDefinition.GroundMark.FROST:
				_draw_ellipse_fill(at, tile * 0.4 + wobble, tile * 0.32, Color(0.82, 0.94, 1.0, alpha * 0.7))
				for j in 6:
					var angle := TAU * float(j) / 6.0 + float(i)
					draw_line(at, at + Vector2.from_angle(angle) * tile * 0.3, Color(1, 1, 1, alpha), 2.0)
			SkillDefinition.GroundMark.PUDDLE:
				_draw_ellipse_fill(at, tile * 0.36 + wobble, tile * 0.22, Color(0.25, 0.5, 0.85, alpha * 0.8))
				_draw_ellipse_ring(at + Vector2(-tile * 0.08, -tile * 0.04), tile * 0.12, tile * 0.05, Color(1, 1, 1, alpha * 0.6), 2.0)
			SkillDefinition.GroundMark.PIT:
				_draw_ellipse_fill(at, tile * 0.32 + wobble, tile * 0.24, Color(0.2, 0.25, 0.05, alpha))
				_draw_ellipse_fill(at, tile * 0.2, tile * 0.14, Color(0.55, 0.75, 0.1, alpha * 0.8))
				var smoke := fmod(_clock * 0.6 + float(i) * 0.3, 1.0)
				draw_circle(at + Vector2(sin(_clock + i) * 8.0, -tile * 0.4 * smoke), tile * 0.06 * (1.0 + smoke), Color(0.85, 0.9, 0.75, alpha * 0.5 * (1.0 - smoke)))
	queue_redraw()


## A declared move's glyphs on its tiles, turning faster the fewer of the other
## side are still to have a turn before it lands.
func _draw_declared():
	var tile := float(Grid.TILE_SIZE)
	var waiting: int = on.get("declared", {}).get("waiting", []).size() if on.has("declared") else 0
	var pace := 1.0 + 3.0 / float(waiting + 1)
	var pulse := 0.55 + 0.45 * sin(_clock * TAU * pace * 0.5)
	for point in points:
		_draw_glyph(point, tile * 0.3, _clock * pace, Color(colour, 0.35 + 0.4 * pulse), 2.0 + 2.0 * pulse)
	queue_redraw()


## --- Shapes ---


## A spell's glyph: a ring of marks round two triangles turning against it.
func _draw_glyph(at: Vector2, radius: float, turn: float, tint: Color, width: float):
	draw_arc(at, radius, 0.0, TAU, 40, tint, width)
	for i in 12:
		var angle := turn + TAU * float(i) / 12.0
		draw_line(at + Vector2.from_angle(angle) * radius * 0.82, at + Vector2.from_angle(angle) * radius * (0.92 if i % 3 else 1.0), tint, width)
	for k in 2:
		var tri := PackedVector2Array()
		for i in 4:
			tri.append(at + Vector2.from_angle(-turn * 1.3 + PI * k + TAU * float(i) / 3.0) * radius * 0.62)
		draw_polyline(tri, tint, width)


## A curved band along a circle round `centre`, `from` to `to` (radians),
## `thick` at its leading end narrowing to `thin` at its tail.
func _draw_band(centre: Vector2, radius: float, from: float, to: float, thick: float, thin: float, tint: Color):
	if absf(to - from) < 0.02:
		return
	var steps := 18
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in steps + 1:
		var share := float(i) / float(steps)
		var angle := lerpf(from, to, share)
		var width := lerpf(thin, thick, share)
		outer.append(centre + Vector2.from_angle(angle) * (radius + width * 0.5))
		inner.append(centre + Vector2.from_angle(angle) * (radius - width * 0.5))
	inner.reverse()
	outer.append_array(inner)
	draw_colored_polygon(outer, tint)


## A slash: a line thick in the middle, pointed at both ends.
func _draw_slash(from: Vector2, to: Vector2, thick: float, tint: Color):
	if from.distance_to(to) < 1.0:
		return
	var side := (to - from).orthogonal().normalized() * thick * 0.5
	var middle := from.lerp(to, 0.5)
	draw_colored_polygon(PackedVector2Array([from, middle + side, to, middle - side]), tint)


## A ring drawn as an ellipse, `rx` across and `ry` down.
func _draw_ellipse_ring(at: Vector2, rx: float, ry: float, tint: Color, width: float):
	if rx < 1.0:
		return
	var ring := _ellipse_points(at, rx, ry, 32, 0.0, TAU)
	ring.append(ring[0])
	draw_polyline(ring, tint, width)


func _draw_ellipse_fill(at: Vector2, rx: float, ry: float, tint: Color):
	if rx < 1.0 or ry < 0.5:
		return
	draw_colored_polygon(_ellipse_points(at, rx, ry, 28, 0.0, TAU), tint)


func _ellipse_points(at: Vector2, rx: float, ry: float, steps: int, from: float, to: float) -> PackedVector2Array:
	var found := PackedVector2Array()
	for i in steps:
		var angle := lerpf(from, to, float(i) / float(steps - 1 if to - from < TAU else steps))
		found.append(at + Vector2(cos(angle) * rx, sin(angle) * ry))
	return found


## A ring that wobbles as it goes, for the mind.
func _draw_wobbly_ring(at: Vector2, radius: float, wobble: float, tint: Color, width: float):
	var ring := PackedVector2Array()
	for i in 33:
		var angle := TAU * float(i) / 32.0
		ring.append(at + Vector2.from_angle(angle) * (radius + sin(angle * 5.0 + _clock * 12.0) * wobble))
	draw_polyline(ring, tint, width)


## A star of `points` points round `at`.
static func _star(at: Vector2, count: int, outer: float, inner: float, turn: float) -> PackedVector2Array:
	var found := PackedVector2Array()
	for i in count * 2:
		found.append(at + Vector2.from_angle(turn + PI * float(i) / float(count)) * (outer if i % 2 == 0 else inner))
	return found


## A sliver of something broken, turned `turn`.
static func _shard(at: Vector2, size: float, turn: float) -> PackedVector2Array:
	return PackedVector2Array([at + Vector2.from_angle(turn) * size, at + Vector2.from_angle(turn + 2.4) * size * 0.45,
		at + Vector2.from_angle(turn + 3.6) * size * 0.6])


## A shield's shape, flat-topped and pointed below.
static func _shield(at: Vector2, size: float) -> PackedVector2Array:
	return PackedVector2Array([at + Vector2(-size * 0.7, -size * 0.8), at + Vector2(size * 0.7, -size * 0.8),
		at + Vector2(size * 0.7, size * 0.1), at + Vector2(0.0, size * 0.9), at + Vector2(-size * 0.7, size * 0.1)])


## A condition's mark on its way to the HUD: the strip's own picture, tinted,
## its letters on it.
class _ConditionMark extends Node2D:
	var tint := Color.WHITE
	var letters := ""

	func _draw():
		var size := MoveFeel.MARK_SIZE
		draw_texture_rect(ConditionStrip.MARK, Rect2(-Vector2.ONE * size / 2.0, Vector2.ONE * size), false, tint)
		if letters != "":
			var font := ThemeDB.fallback_font
			var font_size := int(size * 0.5)
			var width := font.get_string_size(letters, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			var at := Vector2(-width / 2.0, font_size * 0.35)
			draw_string_outline(font, at, letters, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0, 0, 0, 0.9))
			draw_string(font, at, letters, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


## The face of somebody reacting, slid in at the side of the screen - the
## party's on the left, the other side's on the right - and out again.
class _FaceCard extends Control:
	var face: Texture2D = null
	var words := ""
	var hostile := false
	var _clock := 0.0

	func _ready():
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _process(delta: float):
		_clock += delta
		if _clock >= MoveFeel.FACE_SECONDS:
			queue_free()
			return
		queue_redraw()

	func _draw():
		var t := _clock / MoveFeel.FACE_SECONDS
		var slide := minf(t / 0.15, 1.0) * minf((1.0 - t) / 0.15, 1.0)
		var box := Vector2(MoveFeel.FACE_SIZE + 140.0, MoveFeel.FACE_SIZE + 16.0)
		var screen := get_viewport_rect().size
		var y := screen.y * 0.36
		var x := lerpf(-box.x, 16.0, slide) if not hostile else lerpf(screen.x, screen.x - box.x - 16.0, slide)
		var edge := Color("ff6b5e") if hostile else Color("6fb7ff")
		draw_rect(Rect2(Vector2(x, y), box), Color(0.05, 0.06, 0.09, 0.85))
		draw_rect(Rect2(Vector2(x, y), box), edge, false, 3.0)
		if face != null:
			draw_texture_rect(face, Rect2(Vector2(x + 8.0, y + 8.0), Vector2.ONE * MoveFeel.FACE_SIZE), false)
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(x + MoveFeel.FACE_SIZE + 18.0, y + box.y * 0.45), words, HORIZONTAL_ALIGNMENT_LEFT, 120.0, 18, Color.WHITE)
		draw_string(font, Vector2(x + MoveFeel.FACE_SIZE + 18.0, y + box.y * 0.45 + 30.0), "Reacts!", HORIZONTAL_ALIGNMENT_LEFT, 120.0, 22,
			Color("ffd166"))
