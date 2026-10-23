class_name JuicePixelated
extends Node2D
## Renders an effect at the game's base resolution, so procedurally drawn
## shapes come out in the same chunky pixels as the art around them instead
## of smooth full-resolution edges.
##
## The effect draws into its own 320x180 viewport that tracks the main camera,
## and that image is drawn back here, screen-aligned and unfiltered. Here
## rather than as a CanvasLayer so the effect keeps its place in the world's
## draw order.
##
## Frees itself once the effect leaves the tree.

## The game's pixel grid. Screen-aligned rather than world-aligned, so the
## pixels stay the game's size even while the camera is zoomed in.
const BASE_RESOLUTION: Vector2i = Vector2i(320, 180)

var _viewport: SubViewport = SubViewport.new()
var _effect: Node2D


## Wraps [param effect] and places the result under [param parent], where the
## effect itself would otherwise have gone.
static func spawn(parent: Node, effect: Node2D, draw_z_index: int) -> JuicePixelated:
	var pixelated: JuicePixelated = JuicePixelated.new()
	pixelated._effect = effect
	pixelated.z_index = draw_z_index
	parent.add_child(pixelated)
	return pixelated


func _ready() -> void:
	# Effects like the kill focus play inside a hitstop, so this has to keep
	# up with them.
	process_mode = Node.PROCESS_MODE_ALWAYS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# A transparent viewport stores its colors premultiplied by alpha. Drawn
	# back with a plain mix, anything half-faded (a ring on its way out) would
	# be dimmed twice and go muddy.
	var blend: CanvasItemMaterial = CanvasItemMaterial.new()
	blend.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	material = blend

	_viewport.size = BASE_RESOLUTION
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)

	_effect.tree_exited.connect(queue_free)
	_viewport.add_child(_effect)
	_sync()
	# Again once the caller has placed this node: spawn() adds it before they
	# can, and a first frame drawn at the parent's origin flickers.
	_sync.call_deferred()


func _process(_delta: float) -> void:
	_sync()


## Points the effect's viewport through the main camera, shrunk down to the
## base grid, and puts the effect where this node is in the world.
func _sync() -> void:
	if not is_instance_valid(_effect):
		return
	var downscale: Transform2D = Transform2D.IDENTITY.scaled(Vector2.ONE / _pixel_size())
	_viewport.canvas_transform = downscale * get_canvas_transform()
	_effect.transform = global_transform
	queue_redraw()


func _draw() -> void:
	# Undo this node's own placement, so the texture lands one texel per game
	# pixel, square to the screen.
	var to_screen: Transform2D = get_global_transform_with_canvas()
	draw_set_transform_matrix(to_screen.affine_inverse() * Transform2D.IDENTITY.scaled(Vector2.ONE * _pixel_size()))
	draw_texture(_viewport.get_texture(), Vector2.ZERO)


## How many screen pixels make up one game pixel.
func _pixel_size() -> float:
	return get_viewport_rect().size.x / BASE_RESOLUTION.x
