extends Sprite2D

var speed: float = 0
var uv_offset: float = 0

func _process(delta: float) -> void:
	uv_offset += speed * delta
	material.set_shader_parameter("uv_offset", uv_offset)
