class_name StaticBackgroundObjectResource
extends Resource

@export var scene: PackedScene
@export var position: Vector2
@export var scale: Vector2 = Vector2.ONE
@export var rotation: float = 0.0
@export var modulate: Color = Color.WHITE
@export var parallax_level: int = 0  # 0 = no movement, higher = faster movement

@export_category('Variation')
## How far this piece may wander, each way, on top of its composition's shared
## offset. Only used inside a SetPieceComposition.
@export var position_jitter: Vector2 = Vector2.ZERO
## How much a CelestialBody's diameter may grow or shrink, as a fraction
## (0.15 = up to 15% either way). It stays on whole pixels. Only used inside a
## SetPieceComposition.
@export_range(0.0, 0.5, 0.01) var size_jitter: float = 0.0

func get_parallax_level() -> int:
	return parallax_level
