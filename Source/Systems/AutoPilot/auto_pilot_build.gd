class_name AutoPilotBuild
extends RefCounted
## Plans the grid for a policy: which cell a new tile should go in (or which
## twin it should upgrade), which sealed cell a Grid Slot should open, which
## tile is worth moving where out of a fight (or merging into its twin), and
## what each tile on the grid adds.
##
## The board is worth the sum of what each tile does with a die, as the
## policy values it, read with the tiles where they stand. Where a tile stands
## matters to relays (a Feed only pays if something sits where it feeds),
## to tiles that count their neighbours or the empty cells around them, and
## to tiles that answer a neighbour activating. A layout that isn't the
## grid's own is tried by swapping it into the grid for the length of one
## synchronous valuation and swapping it straight back: the forecast reads
## positions through the real targeting handlers, so that's the only way it
## can see a tile in a cell it isn't in. Nothing runs in between, so the game
## never sees the stand-in.
##
## Only tiles whose chain reads the grid are revalued per layout; the rest
## are worth the same wherever they go, and are valued once per decision.

## Gains below this aren't worth a move: two layouts that close are a tie,
## and a tie mustn't flip back and forth.
const MIN_GAIN: float = 0.5
## Per neighbour that takes dice, for a tile that answers a neighbour
## activating (TileEvent ON_ADJACENT / ON_SURROUNDING_TILE_ACTIVATED).
const _LISTENER_PER_NEIGHBOUR: float = 0.75
## Opening a sealed cell next to the machine beats one off in a corner: most
## positional tiles reward packing. Per neighbouring tile, as a tie-break.
const _SEALED_NEIGHBOUR: float = 0.1

## Steps whose result depends on where tiles stand.
const _POSITIONAL_TARGETING: Array[EffectEnums.TargetingSubtype] = [
	EffectEnums.TargetingSubtype.TARGET_SURROUNDING_TILES,
	EffectEnums.TargetingSubtype.TARGET_TILE_WITH_OFFSET,
	EffectEnums.TargetingSubtype.TARGET_RANDOM_ADJACENT_TILE,
	EffectEnums.TargetingSubtype.TARGET_MIRRORED_TILE,
]
const _POSITIONAL_AMOUNTS: Array[EffectEnums.AmountModifierSubtype] = [
	EffectEnums.AmountModifierSubtype.ADD_ADJACENT_TILES,
	EffectEnums.AmountModifierSubtype.ADD_EMPTY_ADJACENT_CELLS,
]
## A Feed with no targeting step of its own may be aimed by the ship's rules
## (the Carousel's Reactor), which also go by position.
const _POSITIONAL_TILE_CONTROL: Array[EffectEnums.TileControlSubtype] = [
	EffectEnums.TileControlSubtype.PASS_DIE_TO_TILE,
	EffectEnums.TileControlSubtype.FEED_HOLOGRAM,
]
const _NEIGHBOUR_EVENTS: Array[TileEvent.EventType] = [
	TileEvent.EventType.ON_ADJACENT_TILE_ACTIVATED,
	TileEvent.EventType.ON_SURROUNDING_TILE_ACTIVATED,
]

## (tile: Tile) -> float: what the tile is worth, read off the grid as it
## stands when called.
var _worth: Callable
## () -> float: what one more free cell is worth to the policy right now. A
## merge frees one (or, for a copy taken from an offer, uses none).
var _room_worth: Callable
## Off-grid tiles of each upgraded resource, standing in for a tile that
## hasn't been upgraded yet while its upgrade is valued.
var _upgraded_stand_ins: Dictionary[TileResource, Tile] = {}
## Worth of tiles that read nothing off the grid, by instance id, for one
## decision (see reset()).
var _fixed_worth: Dictionary[int, float] = {}
## Whether each tile resource reads the grid. Resources don't change, so this
## lasts the run.
static var _positional: Dictionary[TileResource, bool] = {}


func _init(worth: Callable, room_worth: Callable) -> void:
	_worth = worth
	_room_worth = room_worth


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for stand_in: Tile in _upgraded_stand_ins.values():
			if is_instance_valid(stand_in):
				stand_in.free()


## Forgets what tiles were worth: the board (shields, charge, uses left) may
## have changed since.
func reset() -> void:
	_fixed_worth.clear()


static func _grid() -> TileGrid:
	return Globals.tile_grid


# ── Valuing layouts ────────────────────────────────────────────────────────────

## The grid's layout as it stands: a copy that can be changed freely.
static func current_layout() -> Dictionary[Vector2i, Tile]:
	return _grid().tile_locations.duplicate()


## What the board would be worth with [param layout] on the grid and the
## sealed cells in [param opened] open.
func worth_of(layout: Dictionary[Vector2i, Tile], opened: Array[Vector2i] = []) -> float:
	var grid: TileGrid = _grid()
	var real: Dictionary[Vector2i, Tile] = grid.tile_locations
	var newly_open: Array[Vector2i] = []
	for cell: Vector2i in opened:
		# The grid keeps its open cells in _cell_set (is_grid_pos_valid() reads
		# it); a sealed cell is opened there and only there, and closed again
		# below before anything else can look.
		if grid.is_cell_locked(cell) and not grid._cell_set.has(cell):
			grid._cell_set[cell] = true
			newly_open.append(cell)
	grid.tile_locations = layout
	var total: float = 0.0
	for cell: Vector2i in layout:
		total += _tile_worth(layout[cell], cell)
	grid.tile_locations = real
	for cell: Vector2i in newly_open:
		grid._cell_set.erase(cell)
	return total


func _tile_worth(tile: Tile, cell: Vector2i) -> float:
	if not is_instance_valid(tile) or tile.tile_resource == null:
		return 0.0
	if not is_positional(tile.tile_resource):
		var id: int = tile.get_instance_id()
		if not _fixed_worth.has(id):
			_fixed_worth[id] = _worth.call(tile)
		return _fixed_worth[id]
	return _worth.call(tile) + _listener_bonus(tile, cell)


## A tile that answers a neighbour activating pays per neighbour that will.
func _listener_bonus(tile: Tile, cell: Vector2i) -> float:
	var bonus: float = 0.0
	for response: TileEvent in tile.tile_resource.event_responses:
		if response == null or not response.event in _NEIGHBOUR_EVENTS:
			continue
		var diagonals: bool = response.event == TileEvent.EventType.ON_SURROUNDING_TILE_ACTIVATED
		for neighbour: Tile in _neighbours(cell, diagonals):
			if not _refuses_dice(neighbour.tile_resource):
				bonus += _LISTENER_PER_NEIGHBOUR
	return bonus


static func _neighbours(cell: Vector2i, diagonals: bool) -> Array[Tile]:
	var grid: TileGrid = _grid()
	var found: Array[Tile] = []
	for x: int in range(-1, 2):
		for y: int in range(-1, 2):
			if (x == 0 and y == 0) or (not diagonals and x != 0 and y != 0):
				continue
			var tile: Tile = grid.tile_locations.get(cell + Vector2i(x, y))
			if is_instance_valid(tile):
				found.append(tile)
	return found


## Whether where a tile of [param resource] stands changes what it does.
static func is_positional(resource: TileResource) -> bool:
	if _positional.has(resource):
		return _positional[resource]
	var reads_grid: bool = false
	for response: TileEvent in resource.event_responses:
		if response and response.event in _NEIGHBOUR_EVENTS:
			reads_grid = true
	var chain: EffectChain = resource.effect_chain
	if chain and not reads_grid:
		var steps: Array[EffectData] = []
		steps.append_array(chain.effects)
		for rule: ConditionalEffectData in chain.repetition_conditions:
			steps.append(rule)
		reads_grid = _reads_grid(steps)
	_positional[resource] = reads_grid
	return reads_grid


static func _reads_grid(steps: Array[EffectData]) -> bool:
	for data: EffectData in steps:
		if data == null:
			continue
		match data.category:
			EffectEnums.Category.TARGETING:
				if data.subtype in _POSITIONAL_TARGETING:
					return true
			EffectEnums.Category.AMOUNT_MODIFIER:
				if data.subtype in _POSITIONAL_AMOUNTS:
					return true
			EffectEnums.Category.TILE_CONTROL:
				if data.subtype in _POSITIONAL_TILE_CONTROL:
					return true
			EffectEnums.Category.CONDITIONAL:
				var branching: ConditionalEffectData = data as ConditionalEffectData
				if branching and (_reads_grid(branching.if_true_effects) or _reads_grid(branching.if_false_effects)):
					return true
	return false


static func _refuses_dice(resource: TileResource) -> bool:
	for check: ActivationResource in resource.activation_checks:
		if check.type == ActivationResource.ActivationType.CANT_BE_ACTIVATED_WITH_DIE:
			return true
	return false


# ── Upgrades ───────────────────────────────────────────────────────────────────

## The grid tile a copy of [param resource] would upgrade, or null.
static func twin_for(resource: TileResource, besides: Tile = null) -> Tile:
	var grid: TileGrid = _grid()
	for cell: Vector2i in grid.get_cells():
		var tile: Tile = grid.tile_locations.get(cell)
		if is_instance_valid(tile) and tile != besides and tile.can_merge(resource):
			return tile
	return null


## [param layout] with the tile in [param cell] swapped for its upgrade.
func _upgraded(layout: Dictionary[Vector2i, Tile], cell: Vector2i) -> Dictionary[Vector2i, Tile]:
	var trial: Dictionary[Vector2i, Tile] = layout.duplicate()
	trial[cell] = _stand_in(layout[cell].tile_resource.upgraded_version)
	return trial


func _stand_in(resource: TileResource) -> Tile:
	if not is_instance_valid(_upgraded_stand_ins.get(resource)):
		_upgraded_stand_ins[resource] = _grid().create_tile(resource)
	return _upgraded_stand_ins[resource]


# ── Decisions ──────────────────────────────────────────────────────────────────

## Where [param tile], not on the grid yet, would add the most, and how much:
## {cell, gain}. A twin's cell means dropping it there upgrades the twin,
## which needs no free cell. With [param sealed], the sealed cells count as
## free (a Grid Slot about to open one). Empty when there's no cell for it.
func best_cell_for(tile: Tile, sealed: bool = false) -> Dictionary:
	var grid: TileGrid = _grid()
	var layout: Dictionary[Vector2i, Tile] = current_layout()
	var base: float = worth_of(layout)
	var opened: Array[Vector2i] = []
	if sealed:
		opened = grid.get_locked_cells()
	var cells: Array[Vector2i] = grid.get_cells()
	cells.append_array(opened)
	var best: Dictionary = {}
	for cell: Vector2i in cells:
		if layout.has(cell):
			continue
		var trial: Dictionary[Vector2i, Tile] = layout.duplicate()
		trial[cell] = tile
		var gain: float = worth_of(trial, opened) - base
		if best.is_empty() or gain > best["gain"] + 0.001:
			best = {"cell": cell, "gain": gain}
	var twin: Tile = twin_for(tile.tile_resource)
	if twin:
		var twin_cell: Vector2i = grid.find_tile_pos(twin)
		var gain: float = worth_of(_upgraded(layout, twin_cell)) - base + _room_worth.call()
		if best.is_empty() or gain > best["gain"] + 0.001:
			best = {"cell": twin_cell, "gain": gain}
	return best


## The sealed cell a Grid Slot should open: where one of [param candidates]
## (tiles on offer) or a tile already on the grid would add the most, with
## cells beside the machine winning ties. (-1, -1) if nothing is sealed.
func best_sealed_cell(candidates: Array[Tile] = []) -> Vector2i:
	var grid: TileGrid = _grid()
	var layout: Dictionary[Vector2i, Tile] = current_layout()
	var base: float = worth_of(layout)
	var best_cell := Vector2i(-1, -1)
	var best_score: float = -INF
	for cell: Vector2i in grid.get_locked_cells():
		var opened: Array[Vector2i] = [cell]
		var gain: float = 0.0
		for tile: Tile in candidates:
			if is_instance_valid(tile):
				var trial: Dictionary[Vector2i, Tile] = layout.duplicate()
				trial[cell] = tile
				gain = maxf(gain, worth_of(trial, opened) - base)
		for from: Vector2i in layout:
			if not _movable(layout[from]):
				continue
			var trial: Dictionary[Vector2i, Tile] = layout.duplicate()
			trial.erase(from)
			trial[cell] = layout[from]
			gain = maxf(gain, worth_of(trial, opened) - base)
		var score: float = gain + _SEALED_NEIGHBOUR * _neighbours(cell, true).size()
		if score > best_score + 0.001:
			best_score = score
			best_cell = cell
	return best_cell


## The single drag that improves the grid most, out of a fight: a tile to an
## empty cell, two tiles swapped, or a tile dropped on its twin to upgrade
## it. {tile, cell, gain}, or empty if no drag gains at least MIN_GAIN.
func best_rearrangement() -> Dictionary:
	var grid: TileGrid = _grid()
	var layout: Dictionary[Vector2i, Tile] = current_layout()
	var base: float = worth_of(layout)
	var best: Dictionary = _best_merge(layout, base)
	# Nothing on the grid reads positions: every layout is worth the same.
	if not layout.values().any(func(tile: Tile) -> bool:
			return is_instance_valid(tile) and is_positional(tile.tile_resource)):
		return best
	var cells: Array[Vector2i] = grid.get_cells()
	for from: Vector2i in layout:
		var moving: Tile = layout[from]
		if not _movable(moving):
			continue
		for to: Vector2i in cells:
			if to == from:
				continue
			var other: Tile = layout.get(to)
			# A swap is tried once, from the cell that comes first. Dropped on
			# its twin it would merge instead: _best_merge() weighs that.
			if other and (not _movable(other) or _before(to, from) or other.can_merge(moving.tile_resource)):
				continue
			var trial: Dictionary[Vector2i, Tile] = layout.duplicate()
			trial.erase(from)
			if other:
				trial[from] = other
			trial[to] = moving
			var gain: float = worth_of(trial) - base
			if gain >= MIN_GAIN and (best.is_empty() or gain > best["gain"] + 0.001):
				best = {"tile": moving, "cell": to, "gain": gain}
	return best


## The best merge of two copies on the grid: {tile, cell, gain} with the
## tile to drop on the twin in cell, or empty if none gains MIN_GAIN. The
## twin that stays is the one standing where the upgrade is worth more.
func _best_merge(layout: Dictionary[Vector2i, Tile], base: float) -> Dictionary:
	var best: Dictionary = {}
	for from: Vector2i in layout:
		var moving: Tile = layout[from]
		if not _movable(moving):
			continue
		for to: Vector2i in layout:
			if to == from or not layout[to].can_merge(moving.tile_resource):
				continue
			var trial: Dictionary[Vector2i, Tile] = _upgraded(layout, to)
			trial.erase(from)
			var gain: float = worth_of(trial) - base + _room_worth.call()
			if gain >= MIN_GAIN and (best.is_empty() or gain > best["gain"] + 0.001):
				best = {"tile": moving, "cell": to, "gain": gain}
	return best


## What [param tile] adds to the board: the board's worth less what it would
## be worth without it.
func contribution(tile: Tile) -> float:
	var layout: Dictionary[Vector2i, Tile] = current_layout()
	var without: Dictionary[Vector2i, Tile] = layout.duplicate()
	without.erase(_grid().find_tile_pos(tile))
	return worth_of(layout) - worth_of(without)


static func _movable(tile: Tile) -> bool:
	return is_instance_valid(tile) and tile.tile_resource != null and tile.tile_resource.dragging_allowed


static func _before(a: Vector2i, b: Vector2i) -> bool:
	return a.y < b.y or (a.y == b.y and a.x < b.x)
