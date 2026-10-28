class_name ShipResource
extends Resource

## A ship the player can fly a run in: the shape of its tile grid, what it
## starts with, and any rules of its own. One .tres per ship in
## Source/Content/Ships/; ShipCatalog finds them there.

## Stable, written to the save. Never rename one that has shipped.
@export var id: StringName
@export var display_name: String
## One or two lines for the ship-select card. BBCode, coloured like tile text.
@export_multiline var description: String
## Left to right on the ship-select popup.
@export var sort_order: int = 0

@export_category("Run Start")
## Hull, dice, credits and starting tiles for a new run. Every tile position
## must be one of the grid's cells.
@export var starting_save: GameSaveResource

@export_category("Tile Grid")
## The cells a tile can sit in, in grid coordinates. Empty means every cell of
## the grid_size rectangle. Cells left out of the rectangle are holes: nothing
## sits there and nothing counts as adjacent across them.
@export var grid_cells: Array[Vector2i] = []
## The rectangle the grid spans, used when grid_cells is empty.
@export var grid_size: Vector2i = Vector2i(5, 3)
@export var grid_spacing: int = 24
## Shifts the grid's top-left away from where the main viewer puts it.
@export var grid_offset: Vector2 = Vector2.ZERO

@export_category("Rules")
## Optional. Instanced as a child of the TileGrid when the game scene starts,
## so it sits in grid space and can listen to Events for rules of the ship's
## own (a grid that turns, dice that charge the engine) or dress the cockpit.
@export var behavior_scene: PackedScene
## The first-run tutorial is written around the default ship's grid.
@export var supports_tutorial: bool = false

@export_category("Art")
## The ship in the opening cutscene. Needs a "boost" animation, nose up.
## Null keeps the cutscene's own.
@export var cutscene_frames: SpriteFrames
## Where the cutscene's exhaust plumes leave the hull, in the sprite's local
## pixels (nose up, so engines sit at positive y).
@export var cutscene_exhaust_points: PackedVector2Array = PackedVector2Array([
	Vector2(-8.5, 9.0), Vector2(8.5, 9.0)
])
## Shown on the ship-select card. Null falls back to cutscene_frames' first
## "boost" frame.
@export var preview_texture: Texture2D


## Every cell a tile can sit in, top row first, left to right.
func get_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if grid_cells.is_empty():
		for y: int in grid_size.y:
			for x: int in grid_size.x:
				cells.append(Vector2i(x, y))
		return cells
	cells.assign(grid_cells)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x)
	)
	return cells


func get_preview_texture() -> Texture2D:
	if preview_texture:
		return preview_texture
	if cutscene_frames and cutscene_frames.has_animation(&"boost") \
	and cutscene_frames.get_frame_count(&"boost") > 0:
		return cutscene_frames.get_frame_texture(&"boost", 0)
	return null
