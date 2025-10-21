class_name StaticBackgroundObjectResource 
extends Resource
	
@export var scene: PackedScene
@export var position: Vector2
@export var scale: Vector2 = Vector2.ONE
@export var rotation: float = 0.0
@export var modulate: Color = Color.WHITE
@export var parallax_level: int = 0  # 0 = no movement, higher = faster movement

func get_parallax_level() -> int:
	return parallax_level
