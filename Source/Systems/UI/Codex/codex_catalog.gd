class_name CodexCatalog
extends RefCounted

## What the codex lists and in what order, and the text it shows for each
## entry. The order is the entry's number in the codex, so it should only move
## when content is added.

## Tiles are grouped by colour, the colour being the folder their art is in.
const _TILE_COLOUR_ORDER: Array[String] = [
	"RedTiles", "BlueTiles", "GreenTiles", "YellowTiles", "PurpleTiles",
]


## Every tile a player could own: those offered as rewards, those a ship
## starts with, and any held-out tile the player has owned anyway.
static func tile_ids() -> Array[String]:
	var kit: Dictionary[String, bool] = {}
	for ship: ShipResource in ShipCatalog.all():
		if not ship.starting_save:
			continue
		for tile: TileResource in ship.starting_save.tile_locations.values():
			kit[ContentRegistry.get_tile_id(tile.resource_path)] = true

	var ids: Array[String] = []
	for id: String in ContentRegistry.get_tile_ids():
		var tile: TileResource = tile_resource(id)
		if tile and (tile.offered_as_reward or kit.has(id) or CollectionManager.has_tile(id)):
			ids.append(id)
	ids.sort_custom(func(a: String, b: String) -> bool:
		var colour_a: int = _tile_colour_rank(tile_resource(a))
		var colour_b: int = _tile_colour_rank(tile_resource(b))
		if colour_a != colour_b:
			return colour_a < colour_b
		return plain_name(tile_resource(a).tile_name) < plain_name(tile_resource(b).tile_name)
	)
	return ids


## Every enemy marked for the codex, by name.
static func enemy_ids() -> Array[String]:
	var ids: Array[String] = []
	for id: String in ContentRegistry.get_enemy_ids():
		var enemy: EnemyResource = enemy_resource(id)
		if enemy and enemy.in_codex:
			ids.append(id)
	ids.sort_custom(func(a: String, b: String) -> bool:
		return enemy_resource(a).enemy_name < enemy_resource(b).enemy_name
	)
	return ids


static func tile_resource(id: String) -> TileResource:
	var path: String = ContentRegistry.get_tile_path(id)
	return load(path) as TileResource if path != "" else null


static func enemy_resource(id: String) -> EnemyResource:
	var path: String = ContentRegistry.get_enemy_path(id)
	return load(path) as EnemyResource if path != "" else null


static func tile_icon(tile: TileResource) -> Texture2D:
	if not tile.textures:
		return null
	return tile.textures.get_frame_texture(&"default", 0)


## Every action the enemy can take, once each, as "Name: what it does". An
## amount reads as the range its options roll before run depth scales it.
static func enemy_action_lines(enemy: EnemyResource) -> Array[String]:
	var order: Array[String] = []
	var actions: Dictionary[String, EnemyActionResource] = {}
	var lows: Dictionary[String, int] = {}
	var highs: Dictionary[String, int] = {}
	for pool: EnemyTurnActionList in enemy.action_options:
		for option: EnemyActionOptionResource in pool.actions_possible:
			var action: EnemyActionResource = option.base_action
			if not action or action.name.is_empty():
				continue
			if not actions.has(action.name):
				order.append(action.name)
				actions[action.name] = action
				lows[action.name] = option.min_amount
				highs[action.name] = option.max_amount
			else:
				lows[action.name] = mini(lows[action.name], option.min_amount)
				highs[action.name] = maxi(highs[action.name], option.max_amount)

	var lines: Array[String] = []
	for action_name: String in order:
		var amount: String = amount_range_text(lows[action_name], highs[action_name])
		lines.append("[color=yellow]%s[/color]: %s" % [action_name, actions[action_name].describe(amount)])
	return lines


static func amount_range_text(low: int, high: int) -> String:
	if high <= 0:
		return ""
	if low == high or low <= 0:
		return str(high)
	return "%d-%d" % [low, high]


## [param text] with its BBCode tags taken out, for sorting by name.
static func plain_name(text: String) -> String:
	var regex: RegEx = RegEx.create_from_string(r"\[[^\]]*\]")
	return regex.sub(text, "", true).to_lower()


static func _tile_colour_rank(tile: TileResource) -> int:
	var icon: Texture2D = tile_icon(tile)
	var path: String = icon.resource_path if icon else ""
	if icon is AtlasTexture and (icon as AtlasTexture).atlas:
		path = (icon as AtlasTexture).atlas.resource_path
	for i: int in _TILE_COLOUR_ORDER.size():
		if path.contains("/%s/" % _TILE_COLOUR_ORDER[i]):
			return i
	return _TILE_COLOUR_ORDER.size()
