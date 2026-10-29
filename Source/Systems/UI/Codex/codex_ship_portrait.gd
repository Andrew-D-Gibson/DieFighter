class_name CodexShipPortrait
extends SubViewportContainer
## An enemy's full ship art for the codex pane: its graphics scene drawn live,
## engines and moving parts and all, rather than the targeting computer's
## silhouette. Scaled by the largest whole number that fits, so the pixels
## stay square; the few ships wider than the box are shrunk to fit instead.

## The art's size when a scene has no sprites to measure.
const _FALLBACK_SIZE: Vector2 = Vector2(32.0, 32.0)

var _viewport: SubViewport
var _ship: Node2D


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch = true
	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	add_child(_viewport)


## Shows [param enemy]'s ship, replacing whichever was shown before.
func show_ship(enemy: EnemyResource) -> void:
	if is_instance_valid(_ship):
		_ship.queue_free()
	_ship = null
	if enemy == null or enemy.ship_graphics_scene == null:
		return
	_ship = enemy.ship_graphics_scene.instantiate() as Node2D
	if _ship == null:
		return
	_viewport.add_child(_ship)
	# The enemy shader draws nothing until told how opaque to be, which in a
	# fight is the graphics manager's job (_set_transparency).
	var shader: ShaderMaterial = _ship.material as ShaderMaterial
	if shader:
		shader.set_shader_parameter("alpha", 1.0)

	var bounds: Rect2 = _art_bounds(_ship)
	var fit: float = minf(size.x / bounds.size.x, size.y / bounds.size.y)
	var zoom: float = floorf(fit) if fit >= 1.0 else fit
	if zoom < 1.0:
		# Nearest-neighbour shrinking drops whole rows of pixels; blending
		# them keeps the ship's shape.
		_ship.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_ship.scale = Vector2.ONE * zoom
	# Engine exhaust is drawn in world space, which ignores the ship's scale;
	# the ship sits still here, so drawing it in the ship's own space looks
	# the same and shrinks with it.
	for particles: Node in _ship.find_children("*", "CPUParticles2D", true, false):
		(particles as CPUParticles2D).local_coords = true
	# Centred with the art's top-left corner on a whole pixel, so a sprite of
	# odd size doesn't land between pixels.
	var top_left: Vector2 = ((size - bounds.size * zoom) / 2.0).round()
	_ship.position = top_left - bounds.position * zoom


## The rect every sprite in [param ship] covers, in its own space.
static func _art_bounds(ship: Node2D) -> Rect2:
	var bounds: Rect2 = Rect2()
	var found: bool = false
	var pending: Array[Node] = [ship]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		pending.append_array(node.get_children())
		var sprite: Sprite2D = node as Sprite2D
		if sprite == null or sprite.texture == null:
			continue
		var to_ship: Transform2D = Transform2D.IDENTITY
		var step: Node = sprite
		while step != ship:
			to_ship = (step as Node2D).transform * to_ship
			step = step.get_parent()
		var rect: Rect2 = to_ship * sprite.get_rect()
		bounds = rect if not found else bounds.merge(rect)
		found = true
	if not found:
		return Rect2(-_FALLBACK_SIZE / 2.0, _FALLBACK_SIZE)
	return bounds
