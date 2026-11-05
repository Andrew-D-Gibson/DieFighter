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
## Other designs that may stand in for scene on a visit, each as likely as
## scene itself, e.g. a choice of suns. Authored for the same slot, so they
## should fit where scene does. Only used inside a SetPieceComposition.
@export var scene_variants: Array[PackedScene] = []

func get_parallax_level() -> int:
	return parallax_level


## Every design this piece may show: scene first, then its variants.
func get_scene_choices() -> Array[PackedScene]:
	var choices: Array[PackedScene] = []
	if scene:
		choices.append(scene)
	for variant: PackedScene in scene_variants:
		if variant:
			choices.append(variant)
	return choices
