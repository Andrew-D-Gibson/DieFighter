class_name JumpArrowReveal
extends RefCounted
## Brings a hidden jump arrow back out of its dark slot in the same blocky
## "coming online" wipe the systems panel and the map open with (see
## RevealOverlay): the arrow builds up a few pixels at a time, sweeping in
## from its top-left corner.
##
## The tile can't simply fade: tile.gdshader writes its own alpha and ignores
## modulate. So for the length of the wipe a plain copy of the arrow's current
## frame stands in for it, drawn through the reveal shader, and the real
## sprite comes back under it once the copy is whole. The copy lacks the
## tile shader's highlight glow, so it fades off the real sprite rather than
## blinking out.

const _REVEAL_SHADER: Shader = preload("res://Assets/Shaders/map_reveal_shader.gdshader")
## Side of one block of the wipe, in pixels: the same grain as the map's.
const _CELL_PIXELS: int = 3
const _HANDOFF_SECONDS: float = 0.25


## Plays the wipe on [param arrow], which should already be visible.
static func play(arrow: Tile, duration: float) -> void:
	var sprite: AnimatedSprite2D = arrow.sprite_frames
	if not sprite or not sprite.sprite_frames:
		return
	var frame: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if not frame:
		return

	# An atlas region's UVs aren't 0-1, which the shader's grid needs.
	var stand_in: Sprite2D = Sprite2D.new()
	stand_in.texture = ImageTexture.create_from_image(frame.get_image())
	stand_in.centered = sprite.centered
	stand_in.offset = sprite.offset
	stand_in.position = sprite.position
	stand_in.z_index = sprite.z_index + 1
	var cells: Vector2 = (stand_in.texture.get_size() / _CELL_PIXELS).ceil()
	stand_in.material = _reveal_material(cells)
	arrow.add_child(stand_in)
	sprite.hide()

	# Progress has to pass every cell's offset (column + row, from the
	# shader's progress_bias) plus one more for the last cell to fill.
	var tween: Tween = stand_in.create_tween()
	tween.tween_property(
		stand_in, "material:shader_parameter/progress", cells.x + cells.y - 1.0, duration
	).from(0.0)
	tween.tween_callback(func() -> void:
		if is_instance_valid(sprite):
			sprite.show())
	tween.tween_property(stand_in, "modulate:a", 0.0, _HANDOFF_SECONDS)
	tween.tween_callback(stand_in.queue_free)


## The panels' reveal, inverted: cells fill in rather than clear.
static func _reveal_material(cells: Vector2) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = _REVEAL_SHADER
	material.set_shader_parameter("invert", true)
	material.set_shader_parameter("position", Vector2(0.5, 0.5))
	material.set_shader_parameter("grid_size", cells)
	material.set_shader_parameter("progress_bias", Vector2(10, 10))
	material.set_shader_parameter("progress", 0.0)
	return material
