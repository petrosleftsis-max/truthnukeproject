extends Node
## Autoload. The state that outlives a single battle: which encounter is being
## fought, and what condition the player's party is in.
##
## The party carries damage forward between encounters, so a battle won at
## great cost leaves you weaker for the next one. Nothing here is saved to
## disk - it lasts for the session, and "Reset Party" on the level select
## wipes it back to full strength.


## The title screen, which is where the game starts and where to_main_menu()
## sends it back to.
const MAIN_MENU := "res://main_menu.tscn"

## Set by the level select immediately before it loads scenes/game.tscn.
## GameScene reads it on entering the tree; if it is null (running game.tscn
## directly from the editor) GameScene falls back to its own exported default,
## so a battle scene is still playable on its own.
var current_encounter: EncounterDefinition = null

## combatant_key -> {"hp": int, "alive": bool}. Only player-side combatants
## are recorded. A key that isn't in here has never fought and starts fresh.
var party_state := {}

## --- The party ---
##
## Who is travelling, in marching order: the first entry leads and is the one
## you steer, the rest follow. Keys index CombatantDatabase, the same way
## encounter spawns do.
##
## Seeded from the Starting Party list on scenes/exploration.tscn the first
## time an exploration map loads, so adding a teammate is an inspector edit
## rather than a code change. Add them to CombatantDatabase first.
var party_order: Array[String] = []

## How far along the party is while walking a map, 1 to 3. Set by the map's
## MapSetup; decides the health they carry and what the character sheet
## shows them as. Encounter spawns carry their own levels, so this does not
## decide what they fight at.
var party_level: int = 1


## Puts a named party on the map, replacing whoever was travelling.
##
## Unlike seed_party this is authoritative: a map that declares its own cast is
## stating a fact about that part of the story, not offering a default. Walking
## into such a map through a door therefore changes who you are steering, which
## is the point - the church is Alithia alone whichever way you arrive at it.
func set_party(keys: Array, level: int = 1):
	party_order.clear()
	for key in keys:
		if not CombatantDatabase.combatants.has(key):
			push_warning("A map's party lists '%s', which isn't in CombatantDatabase - skipping it." % key)
			continue
		if not party_order.has(key):
			party_order.append(key)
	party_level = clampi(level, 1, 3)
	party_changed.emit()


## Fills the roster if it hasn't been set yet. Anything already in it wins, so
## this can't stomp a party the player has since reordered.
func seed_party(keys: Array):
	if not party_order.is_empty():
		return
	for key in keys:
		if CombatantDatabase.combatants.has(key) and not party_order.has(key):
			party_order.append(key)
		elif not CombatantDatabase.combatants.has(key):
			push_warning("Starting party lists '%s', which isn't in CombatantDatabase - skipping it." % key)


## The roster in marching order, leaving out anyone who has died. The leader is
## first. Everything that draws or spawns the party uses this, so the line on
## the map matches who is actually still standing.
func living_party() -> Array:
	var living: Array = []
	for key in party_order:
		if is_alive(key):
			living.append(key)
	return living


## Who is currently being steered, or "" if the whole party has fallen.
func leader() -> String:
	var living = living_party()
	return living[0] if not living.is_empty() else ""


## Moves `key` to the front of the marching order. Ignored for someone who
## isn't in the party, or who is dead - a corpse can't lead.
func set_leader(key: String) -> bool:
	if not party_order.has(key) or not is_alive(key):
		return false
	party_order.erase(key)
	party_order.insert(0, key)
	party_changed.emit()
	return true


## Passes the lead to the next living member, wrapping around. Returns the new
## leader's key, or "" if there was nobody to pass it to.
##
## Rotates the order rather than promoting the second member to the front:
## promoting would swap the front two back and forth for ever and never reach
## the third, so a party of three had only two possible leaders.
func cycle_leader() -> String:
	var living = living_party()
	if living.size() < 2:
		return leader()
	party_order.append(party_order.pop_front())
	# Step over anyone who has died, so the lead always lands on someone
	# standing. Bounded by the roster size, since at least two are alive.
	var guard = party_order.size()
	while guard > 0 and not is_alive(party_order[0]):
		party_order.append(party_order.pop_front())
		guard -= 1
	party_changed.emit()
	return leader()


## The members an encounter will actually deploy: living, and able to fight
## (see CombatantDefinition.can_fight). A guide or a prisoner travelling with
## the party walks the map and shows in the portraits, but is left out here.
func battle_party() -> Array:
	var fighters: Array = []
	for key in living_party():
		var definition: CombatantDefinition = CombatantDatabase.combatants.get(key)
		if definition != null and definition.can_fight:
			fighters.append(key)
	return fighters


## --- Recruiting and losing people ---
##
## These are the story hooks. They can be called from anywhere, including
## straight out of a dialogue file, because Campaign is registered as a state
## autoload shortcut for Dialogue Manager:
##
##     ~ enfina_joins
##     Enfina: I'll come with you.
##     do Campaign.add_member("enfina")
##     => END
##
## Anyone added is at full health unless they've fought before, and lands at
## the back of the marching order so the lead doesn't change under the player.
func add_member(key: String, at_front: bool = false) -> bool:
	if not CombatantDatabase.combatants.has(key):
		push_warning("Campaign.add_member('%s'): no such combatant in CombatantDatabase." % key)
		return false
	if party_order.has(key):
		return false
	if at_front:
		party_order.insert(0, key)
	else:
		party_order.append(key)
	party_changed.emit()
	announce("[color=lightgreen]%s[/color] joins the party.
" % display_name_of(key))
	return true


## Removes someone from the party - they left, or the story took them. Their
## carried health is forgotten too, so rejoining later starts them fresh;
## pass keep_state to remember the state they left in.
func remove_member(key: String, keep_state: bool = false) -> bool:
	if not party_order.has(key):
		return false
	party_order.erase(key)
	if not keep_state:
		party_state.erase(key)
	party_changed.emit()
	announce("[color=red]%s[/color] leaves the party.
" % display_name_of(key))
	return true


func has_member(key: String) -> bool:
	return party_order.has(key)


## Emitted whenever the roster changes, so anything showing the party (the
## exploration line, the portrait column) can redraw itself without polling.
signal party_changed()

## Something worth saying in the log, wherever the log happens to be.
##
## Campaign outlives every scene, so whatever wants to say something - an item
## changing hands, somebody joining or leaving - says it here without having to
## know whether a battle or a map is on screen. The HUD is the same scene in
## both, and it listens.
signal announced(text: String)


## Says `text` in the log. Takes the same BBCode the combat log does.
func announce(text: String):
	announced.emit(text)


## What to call somebody in the log: their proper name, falling back to the key
## so a line is never blank about who it is talking about.
func display_name_of(key: String) -> String:
	var definition: CombatantDefinition = CombatantDatabase.combatants.get(key)
	return definition.name if definition != null and definition.name != "" else key

## Somebody's bag changed - used, given, or handed to somebody else. Carries
## whose it was, so a screen showing several at once can redraw just the one.
signal inventory_changed(combatant_key)


## What the HUD needs to draw the party: one entry per living member, leader
## first. hp comes from what they carried out of the last battle, so the
## portraits show real wear rather than everyone at full health.
func party_members() -> Array:
	var members: Array = []
	for key in living_party():
		var definition: CombatantDefinition = CombatantDatabase.combatants.get(key)
		if definition == null:
			continue
		# What they have at the level this map has them at - a level 3 Alithia
		# walking around with her level 1 health would read as badly wounded.
		var hp = definition.hp_at(party_level)
		var max_hp = hp
		if party_state.has(key):
			hp = party_state[key].hp
			# What they were last fielded with, so the bar reads against the
			# health they actually had rather than their level 1 figure.
			max_hp = party_state[key].get("max_hp", definition.hp_at(party_level))
		members.append({
			"key": key,
			"name": definition.name,
			"icon": definition.portrait(),
			"map_sprite": definition.map_still(),
			# The animation set travels with the still: the party walks the map
			# with the same SpriteFrames it fights with.
			"sprite_frames": definition.sprite_frames,
			"hp": hp,
			"max_hp": max_hp,
			"is_leader": key == leader(),
		})
	return members

## --- Exploration ---
##
## Exploration is the hub: battles are started from inside a map and hand
## control back to it afterwards, so the map and the spot you were standing on
## have to survive a scene change.

## Scene path of the exploration map to load, and where in it to put the party.
## return_position is only used when return_to_position is true - otherwise the
## map's own entry point decides, which is what happens when you walk through a
## door into a new map.
var current_map: String = ""
var return_position := Vector2.ZERO
var return_to_position := false
## Which EntryPoint to arrive at, for a door that names one. Ignored when
## return_to_position is set.
var target_entry := ""
## Ids of encounter triggers already beaten, so a fight doesn't restart every
## time you walk back past where it happened.
var cleared_triggers := {}


## Remembers where the party is standing and starts `encounter`. Call this
## instead of setting current_encounter directly when a battle is launched from
## exploration, so the trigger can be retired and the map restored afterwards.
func begin_battle_from_exploration(encounter: EncounterDefinition, map_path: String, party_position: Vector2, trigger_id: String):
	current_encounter = encounter
	current_map = map_path
	return_position = party_position
	return_to_position = true
	_pending_trigger = trigger_id


## Whether a battle is currently one the exploration map is waiting to get
## control back from.
func has_map_to_return_to() -> bool:
	return return_to_position and current_map != ""


## Called when a battle launched from exploration ends. A win retires its
## trigger; a loss leaves it in place so the fight can be tried again.
func finish_battle_from_exploration(won: bool):
	if won and _pending_trigger != "":
		cleared_triggers[_pending_trigger] = true
	_pending_trigger = ""


func is_trigger_cleared(trigger_id: String) -> bool:
	return trigger_id != "" and cleared_triggers.has(trigger_id)


## Sends the party through a door: a different map, arriving at the named
## entry point rather than at remembered coordinates.
func travel_to_map(map_path: String, entry_name: String):
	current_map = map_path
	target_entry = entry_name
	return_to_position = false


var _pending_trigger := ""


## Applies whatever condition `key` was left in by earlier battles to a
## freshly-created combatant dictionary. No stored state means untouched.
func apply_carried_state(comb: Dictionary, key: String):
	if not party_state.has(key):
		return
	var stored = party_state[key]
	# Clamped, because the health carried out of one fight can exceed what this
	# one allows: walking a level 3 survivor into a battle that fields them at
	# level 1 should not start them above full.
	comb.hp = mini(stored.hp, comb.max_hp)
	comb.alive = stored.alive


## Whether `key` is still standing - false only once they have actually died
## in an earlier encounter. The level select uses this to warn about a wiped
## party, and the spawner uses it to leave the dead out of later battles.
func is_alive(key: String) -> bool:
	if not party_state.has(key):
		return true
	return party_state[key].alive


## Records how the party came out of a battle. Called by Combat when the fight
## ends, for every player-side combatant, win or lose.
func record_party(combatants: Array):
	for comb in combatants:
		if comb.side != 0:
			continue
		var key = comb.get("combatant_key", "")
		if key == "":
			continue
		party_state[key] = {
			"hp": maxi(comb.hp, 0),
			# The health they fought at, which is their level's rather than their
			# level 1 figure - without it the level select would show a level 3
			# survivor as 25/10 once per-level health entered the picture.
			"max_hp": comb.max_hp,
			"alive": comb.alive,
		}


## Back to full strength: everyone alive, everyone at full health, every
## encounter trigger in the world armed again, and the marching order back to
## however the starting party is configured.
## What a conversation standing in front of a fight decided.
##
## A dialogue answers with a `do` line on the branch that means it:
##
##     - We're ready
##         do Campaign.accept_encounter()
##     - Let's look around a bit more first
##         do Campaign.decline_encounter()
##
## Saying nothing counts as declining. Closing the balloon must not be a way of
## slipping past a fight you were asked about - the trigger is standing in the
## party's path, and the answer decides whether they walk into it or back out
## of it, never whether they get to walk through it.
enum EncounterAnswer { UNANSWERED, ACCEPTED, DECLINED }

var _encounter_answer := EncounterAnswer.UNANSWERED


## Walk into the fight this conversation is about, once it has finished.
func accept_encounter():
	_encounter_answer = EncounterAnswer.ACCEPTED


## Back away from it instead. The party is walked out of the trigger's reach
## when the conversation ends, so they can come back when they are ready.
func decline_encounter():
	_encounter_answer = EncounterAnswer.DECLINED


## Clears any answer left over, so a conversation begins with nothing assumed.
func forget_encounter_answer():
	_encounter_answer = EncounterAnswer.UNANSWERED


## Reads the answer and clears it in one go, so it can never be acted on twice.
func take_encounter_answer() -> EncounterAnswer:
	var answer = _encounter_answer
	_encounter_answer = EncounterAnswer.UNANSWERED
	return answer


func reset():
	_arena_return = {}
	_encounter_answer = EncounterAnswer.UNANSWERED
	party_state.clear()
	cleared_triggers.clear()
	party_order.clear()
	party_level = 1
	inventories.clear()
	# Starting over starts over: what the last playthrough had read, pulled and
	# opened is not true of this one.
	flags.clear()


## One-line summary of the party's condition for the level select, e.g.
## "Enfina 16/16, Cyrus 4/10, Prometheus (dead)". Empty string before the
## first battle, when nobody has taken a scratch yet.
func describe_party() -> String:
	if party_state.is_empty():
		return ""
	var parts = []
	for key in party_state:
		var stored = party_state[key]
		var definition: CombatantDefinition = CombatantDatabase.combatants.get(key)
		var display = definition.name if definition != null else key
		if not stored.alive:
			parts.append("%s (dead)" % display)
		else:
			# The health they were last fielded with, for the same reason the party
			# panel uses it: "12/10" reads as a bug rather than as a veteran.
			var max_hp = stored.get("max_hp", definition.max_hp if definition != null else stored.hp)
			parts.append("%s %d/%d" % [display, stored.hp, max_hp])
	return ", ".join(parts)


## Whether every party member recorded so far is dead - the point at which no
## encounter can be started without resetting first.
func is_party_wiped() -> bool:
	if party_state.is_empty():
		return false
	for key in party_state:
		if party_state[key].alive:
			return false
	return true


## --- Flags ---
##
## Named facts about this playthrough: what has been read, pulled, opened,
## agreed to. Kept here because this is the one thing that survives walking to
## another map and fighting a battle, which is exactly the span a flag has to
## last for to be worth anything.
##
## Dialogue reads and writes them directly, since Campaign is a Dialogue
## Manager state autoload:
##
##     if Campaign.flag("read_the_notice")
##         Guard: So you have seen it.
##     else
##         Guard: There is a notice by the gate.
##     do Campaign.set_flag("spoke_to_guard")
##
## Interactables set and require them without any code at all - see the Flags
## group on Interactable, which is how a button opens a door.

## name -> value. Usually true, but anything can be stored: a count of how many
## times something was asked, which of three endings was taken.
var flags := {}


## Sets `flag_name`. The value is true unless you say otherwise, because
## "this happened" is what almost every flag means.
func set_flag(flag_name: String, value = true):
	if flag_name == "":
		return
	flags[flag_name] = value


## Whether `flag_name` is set and not switched off. false for one never set, so
## a condition can be written before the thing that sets it exists.
func flag(flag_name: String) -> bool:
	if not flags.has(flag_name):
		return false
	var value = flags[flag_name]
	# An explicit false, 0 or "" reads as not set, so a flag can be turned off
	# either by clearing it or by setting it false, and a condition written
	# against it means the same thing either way.
	#
	# Tested by type rather than by comparing the value against false, 0 and ""
	# in turn: comparing a bool against a String is an error at runtime, not a
	# false, and it takes the whole expression - and the flag - down with it.
	match typeof(value):
		TYPE_NIL:
			return false
		TYPE_BOOL:
			return value
		TYPE_INT, TYPE_FLOAT:
			return value != 0
		TYPE_STRING, TYPE_STRING_NAME:
			return value != ""
	return true


## What was stored under `flag_name`, for the flags carrying more than yes or
## no - a count, a name, a choice.
func flag_value(flag_name: String, fallback = null):
	return flags.get(flag_name, fallback)


## Forgets `flag_name` entirely, so flag() reads false and flag_value() gives
## its fallback again.
func clear_flag(flag_name: String):
	flags.erase(flag_name)


## --- Story screens ---
##
## A conversation played over a black screen, with somewhere to go afterwards.
## Set here rather than passed in because changing scene cannot carry arguments,
## and this is already the thing that survives the change.

var story_dialogue := ""
var story_title := "start"
var story_next_scene := ""


## Queues `dialogue` to play over black, then `next_scene` - or the menu, when
## the story has nowhere to be yet.
func begin_story(dialogue: String, title: String = "start", next_scene: String = ""):
	story_dialogue = dialogue
	story_title = title
	story_next_scene = next_scene


func clear_story():
	story_dialogue = ""
	story_title = "start"
	story_next_scene = ""


## --- Leaving ---


## Back to the title screen, from wherever the game currently is.
##
## Written to be called from a dialogue: Campaign is one of the autoloads the
## Dialogue Manager exposes to `do` lines (see state_autoload_shortcuts in
## project.godot), so the last line of a story scene can be
##
##     do Campaign.to_main_menu()
##
## and the conversation ends by handing the player back to the menu.
##
## Clears the run on the way out. Whatever the player picks next starts from
## the menu's own idea of a beginning, and a half-finished party left lying
## around would be inherited by it.
## Where Arena Mode was opened from, so leaving it hands you back rather than
## only ever offering the title screen.
##
## Arena Mode is reachable mid-run - from a fight, or from the middle of the
## sewers - and it used to be a one-way door: the only way out was the main
## menu, which threw the run away. It holds copies rather than relying on the
## live fields, because opening a fight from the arena overwrites those.
##
## Empty when the arena was opened from the title screen, where going back to
## the title screen is the right thing and there is nothing else to go back to.
var _arena_return := {}


func enter_arena_from(scene_path: String, standing_at = null):
	_arena_return = {
		"scene": scene_path,
		"map": current_map,
		"encounter": current_encounter,
		"position": standing_at if standing_at != null else return_position,
		# Only a map remembers where you were standing. A battle is re-entered
		# from its encounter, and the title screen from nothing at all.
		"to_position": standing_at != null,
	}


func can_leave_arena() -> bool:
	return not _arena_return.is_empty()


## Hands the player back wherever they opened the arena from.
func leave_arena():
	if _arena_return.is_empty():
		to_main_menu()
		return
	var back = _arena_return
	_arena_return = {}
	current_map = back.map
	current_encounter = back.encounter
	return_position = back.position
	return_to_position = back.to_position
	SceneTransition.change_scene(back.scene)


func to_main_menu():
	_arena_return = {}
	# The title screen plays nothing of its own, and a battle's music carrying
	# on underneath it belongs to a fight that is over. Only here: Arena Mode and
	# the maps set their own, so those keep playing until something says otherwise.
	Music.stop()
	reset()
	clear_story()
	current_map = ""
	current_encounter = null
	return_to_position = false
	SceneTransition.change_scene(MAIN_MENU)


## --- Inventories ---
##
## A bag per character rather than one shared pool, so who is carrying the last
## potion is a real question. Everyone in the party can reach everyone else's
## outside a fight (see the inventory screen on I); in a battle a character has
## only what is in their own first four slots.


## How much anybody can carry. Slots rather than a growing list so a bag has a
## shape on screen and "full" means something.
const INVENTORY_SIZE := 12

## The slots that come with you into a fight. They are the front of the same
## bag rather than a separate pocket, so packing for a battle is a decision
## made with the inventory screen before walking into one.
const COMBAT_SLOTS := 4

## combatant_key -> Array[String] of exactly INVENTORY_SIZE entries, "" where
## the slot is empty. Empty slots are kept rather than compacted away so an
## item stays where it was put.
var inventories: Dictionary = {}


## Somebody's bag, made if they have never had one.
func inventory_of(key: String) -> Array:
	if not inventories.has(key):
		var slots: Array = []
		slots.resize(INVENTORY_SIZE)
		slots.fill("")
		# Empty. A bag is filled by something that happens - an encounter's
		# spawn list handing one out in Arena Mode, or a dialogue giving
		# somebody something - never by simply existing. Walking onto a map
		# used to grant a character their database kit, which meant every
		# exploration started with a satchel nobody had been given.
		inventories[key] = slots
	return inventories[key]


## Replaces somebody's bag outright, in the order given.
##
## Used when a battle is opened straight from the menu: what each character is
## carrying is the encounter's to decide there, rather than whatever their
## database entry lists or they happened to be holding on some map.
func set_inventory(key: String, items: Array):
	var slots: Array = []
	slots.resize(INVENTORY_SIZE)
	slots.fill("")
	for i in mini(items.size(), INVENTORY_SIZE):
		if items[i] == "":
			continue
		if ItemDatabase.items.has(items[i]):
			slots[i] = items[i]
		else:
			push_warning("A spawn hands '%s' to %s, which is not in ItemDatabase." % [items[i], key])
	inventories[key] = slots
	inventory_changed.emit(key)


## Puts `item_id` in `key`'s first free slot. False if there is no such item or
## nowhere to put it - a full bag refuses rather than silently dropping it.
##
## Written to be called from a dialogue:
##
##     do Campaign.give_item("cyrus", "cure_potion")
##
## Campaign is one of the autoloads the Dialogue Manager exposes to `do` lines
## (see state_autoload_shortcuts in project.godot).
func give_item(key: String, item_id: String) -> bool:
	if not ItemDatabase.items.has(item_id):
		push_warning("Campaign.give_item('%s', '%s'): no such item." % [key, item_id])
		return false
	if not CombatantDatabase.combatants.has(key):
		push_warning("Campaign.give_item('%s', '%s'): no such character." % [key, item_id])
		return false
	var slots = inventory_of(key)
	for i in slots.size():
		if slots[i] == "":
			slots[i] = item_id
			inventory_changed.emit(key)
			var item: ItemDefinition = ItemDatabase.item(item_id)
			announce("[color=lightgreen]%s[/color] receives [color=yellow]%s[/color].
" % [
				display_name_of(key), item.name if item != null else item_id])
			return true
	push_warning("Campaign.give_item('%s', '%s'): their bag is full." % [key, item_id])
	return false


## Takes one `item_id` off `key`, preferring the combat slots so that using one
## in a fight spends the one that was to hand. False if they had none.
func take_item(key: String, item_id: String) -> bool:
	var slots = inventory_of(key)
	for i in slots.size():
		if slots[i] == item_id:
			slots[i] = ""
			inventory_changed.emit(key)
			return true
	return false


## Moves whatever is in one slot to another, swapping if the destination is
## taken. The two slots can belong to different people, which is how the party
## hands things round: both bags are open on the same screen.
func move_item(from_key: String, from_slot: int, to_key: String, to_slot: int) -> bool:
	var from_slots = inventory_of(from_key)
	var to_slots = inventory_of(to_key)
	if from_slot < 0 or from_slot >= from_slots.size():
		return false
	if to_slot < 0 or to_slot >= to_slots.size():
		return false
	if from_key == to_key and from_slot == to_slot:
		return false
	var moving = from_slots[from_slot]
	from_slots[from_slot] = to_slots[to_slot]
	to_slots[to_slot] = moving
	inventory_changed.emit(from_key)
	if to_key != from_key:
		inventory_changed.emit(to_key)
	return true


## What `key` can actually reach in a fight: the item ids in their first
## COMBAT_SLOTS slots, in order, with the empties left out.
func combat_items_of(key: String) -> Array:
	var found: Array = []
	var slots = inventory_of(key)
	for i in mini(COMBAT_SLOTS, slots.size()):
		if slots[i] != "":
			found.append(slots[i])
	return found


## How many of `item_id` somebody is carrying, anywhere in their bag.
func count_of(key: String, item_id: String) -> int:
	var total = 0
	for slot in inventory_of(key):
		if slot == item_id:
			total += 1
	return total


## Gives somebody an empty bag, and stops their starting kit filling it later.
##
## For a map that opens before anybody has been given anything: the crossroads
## is Cyrus at the very beginning, and the potions he is written as owning
## belong to a later part of the story. Making the bag here rather than leaving
## it unmade is the point - inventory_of() seeds an unmade one from the
## database, so "empty" has to be a bag that exists and is empty.
func empty_inventory(key: String):
	var slots: Array = []
	slots.resize(INVENTORY_SIZE)
	slots.fill("")
	inventories[key] = slots
	inventory_changed.emit(key)
