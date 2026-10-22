class_name PieceVariant
extends Sprite2D
## Shows one random frame of a scrolling piece's sheet and holds it: the same
## piece baked at several angles, so a field of it never lines up. The game
## draws at 6x zoom, so turning the sprite in-engine would tilt its pixels;
## the angles live in the art instead.


func _ready() -> void:
	frame = RNGManager.randi_range(RNGManager.Bucket.BACKGROUND, 0, hframes * vframes - 1)
