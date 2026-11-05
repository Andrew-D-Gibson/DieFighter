class_name TrailerShotResource
extends Resource
## One reproducible trailer shot: a run set up just so (ship, scenario, seed,
## sky, grid, dice, hull) and, optionally, the beats to play once it's up.
## The same shot comes out the same on every take, so a take can be redone
## until the timing is right, or recorded hands-free with Movie Maker
## (tools/trailer_capture.sh).
##
## Shots live in Source/Debug/Trailer/Shots/; the file's base name is the
## shot's id (`shot thesis`, `--trailer-shot=thesis`). TrailerDirector runs
## them, TrailerScript plays the beats.

## What the shot is for, and anything a re-shoot needs to know. Shown by
## `shot list`.
@export_multiline var notes: String = ""

@export_group("Run")
## The ship flown (ShipCatalog id: die_fighter, outrigger, carousel). The
## two "coming soon" ships can be filmed here before they're playable.
@export var ship_id: StringName = &"die_fighter"
## The scenario the run opens in (ContentRegistry id: the .tres base name,
## e.g. COMBAT_wolfpack, GATE_bastion).
@export var scenario_id: String = ""
## The run seed. Same seed, same rolls, same intents, same sky.
@export var run_seed: int = 1
## The sector (0 is the Tail), which sets enemy scaling and the gate.
@export_range(0, 2) var sector: int = 0
## The sky to fight under, with its hazard or rule. Null keeps the
## scenario's own pick.
@export var background: BackgroundResource

@export_group("Loadout")
## Tiles by grid cell (x 0-4, y 0-2 on the Die Fighter). Empty keeps the
## ship's starting tiles.
@export var tiles: Dictionary[Vector2i, TileResource] = {}
## Opens every sealed cell, as if every Grid Slot had been found.
@export var open_all_cells: bool = false
## Dice owned; 0 keeps the ship's starting count.
@export_range(0, 8) var dice: int = 0
## Hull at the start; 0 is full.
@export var hull: int = 0
## Max hull; 0 keeps the ship's.
@export var max_hull: int = 0
@export var money: int = 0
## Engine charge at the start.
@export var charge: int = 0
## Faces for the run's first rolls, in order: the opening hand, then each
## reroll after it. Rolls past the end of the list are the seed's.
@export var forced_rolls: Array[int] = []

@export_group("Take")
## The player can't die (unless a beat asks for `fx death`).
@export var god_mode: bool = true
## Hides the debug and bookkeeping overlays.
@export var clean_hud: bool = true
## Shows the drawn cursor. A scripted drag needs it to read as a hand.
@export var show_cursor: bool = true
## Mutes the music bus, so a take's audio is sound effects only and the edit
## can lay the trailer track over it.
@export var mute_music: bool = true
## The game speed for the whole take (1 is normal).
@export_range(0.05, 2.0, 0.05) var time_scale: float = 1.0
## The beats, one command per line, played once the scenario is up. Blank
## and `#` lines are skipped. See TrailerScript for the commands. Empty for
## a shot you play by hand.
@export var beats: PackedStringArray = []


## Why this shot can't run, or "" if it can. Checked before anything changes.
func problem() -> String:
	if ContentRegistry.get_scenario_path(scenario_id) == "":
		return "no scenario '%s'" % scenario_id
	var ship: ShipResource = ShipCatalog.find(ship_id)
	if ship == null or ship.id != ship_id:
		return "no ship '%s'" % ship_id
	var cells: Array[Vector2i] = ship.get_cells()
	for cell: Vector2i in tiles:
		if cell not in cells:
			return "a tile sits at %s, which %s doesn't have" % [cell, ship_id]
		if tiles[cell] == null:
			return "the tile at %s is empty" % cell
	for face: int in forced_rolls:
		if face < 1 or face > 6:
			return "forced roll %d isn't a die face" % face
	return ""


## The save the run starts from: this loadout and sector, and no scenarios,
## so GameStateManager generates the sector around it from the run seed.
func build_save(ship: ShipResource) -> GameSaveResource:
	var start: GameSaveResource = ShipCatalog.starting_save(ship)
	var game_save: GameSaveResource = GameSaveResource.new()
	game_save.ship_id = start.ship_id
	game_save.player_max_health = max_hull if max_hull > 0 else start.player_max_health
	game_save.player_health = mini(hull, game_save.player_max_health) if hull > 0 \
		else game_save.player_max_health
	game_save.player_engine_charge = charge
	game_save.num_of_dice = dice if dice > 0 else start.num_of_dice
	game_save.money = money
	game_save.sector_index = sector
	game_save.tile_locations = tiles.duplicate() if not tiles.is_empty() else start.tile_locations.duplicate()
	game_save.unlocked_cells = ship.get_cells() if open_all_cells else start.unlocked_cells.duplicate()
	for cell: Vector2i in game_save.tile_locations:
		if cell not in game_save.unlocked_cells:
			game_save.unlocked_cells.append(cell)
	return game_save
