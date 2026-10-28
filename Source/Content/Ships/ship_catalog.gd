class_name ShipCatalog

## Finds the player ships in Source/Content/Ships/. Loaded at use rather than
## preloaded: a ship's starting tiles drag in the whole effect catalog, and
## Globals (an early autoload) asks for ships.

const _DIR: String = "res://Source/Content/Ships/"
## The ship a run flies when nothing chose one: an old save, a direct boot of
## the game scene, a test.
const DEFAULT_ID: StringName = &"die_fighter"


## Every ship, in ship-select order.
static func all() -> Array[ShipResource]:
	var ships: Array[ShipResource] = []
	for path: String in Utils.list_resource_paths(_DIR):
		var res: Resource = ResourceLoader.load(path)
		if res is ShipResource:
			ships.append(res)
	ships.sort_custom(func(a: ShipResource, b: ShipResource) -> bool:
		return a.sort_order < b.sort_order
	)
	return ships


## The ship with this id, or the default one for an unknown or empty id.
static func find(id: StringName) -> ShipResource:
	var fallback: ShipResource = null
	for ship: ShipResource in all():
		if ship.id == id:
			return ship
		if ship.id == DEFAULT_ID:
			fallback = ship
	return fallback
