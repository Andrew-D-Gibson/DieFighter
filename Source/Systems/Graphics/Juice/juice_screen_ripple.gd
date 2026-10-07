class_name JuiceScreenRipple
extends CanvasLayer
## Full-screen overlay that runs screen_ripple.gdshader once and frees
## itself. Spawned through Juice.screen_ripple().

const _SHADER: Shader = preload("res://Source/Systems/Graphics/Juice/screen_ripple.gdshader")
const _SECONDS: float = 0.55
const _BASE_STRENGTH: float = 0.03

## Above the game and the UI, below the pause menu's own layer would be
## ideal, but the ripple is over in half a second either way.
const _LAYER: int = 90


static func spawn(context_node: Node, world_pos: Vector2, strength: float) -> void:
	var viewport: Viewport = context_node.get_viewport()
	var screen_size: Vector2 = viewport.get_visible_rect().size
	var screen_pos: Vector2 = viewport.get_canvas_transform() * world_pos

	var ripple: JuiceScreenRipple = JuiceScreenRipple.new()
	ripple.layer = _LAYER
	var rect: ColorRect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = _SHADER
	mat.set_shader_parameter("center", screen_pos / screen_size)
	mat.set_shader_parameter("aspect", screen_size.x / screen_size.y)
	mat.set_shader_parameter("strength", _BASE_STRENGTH * strength)
	# Set before tweening: a uniform the material has never been given
	# doesn't exist as a property yet, and the tween refuses it.
	mat.set_shader_parameter("progress", 0.0)
	rect.material = mat
	ripple.add_child(rect)
	context_node.get_tree().root.add_child(ripple)

	var tween: Tween = ripple.create_tween()
	tween.tween_property(mat, "shader_parameter/progress", 1.0, _SECONDS) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.finished.connect(ripple.queue_free)
