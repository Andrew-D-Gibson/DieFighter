class_name PixelPerfectScaler
extends Node
## Shows the game at a whole number of screen pixels per art pixel, with black
## bars around it, instead of stretched to fit the screen.
##
## The project renders a 1920x1080 canvas through a 6x camera and letterboxes
## it by whatever factor fits, so on a screen that isn't a multiple of 320x180
## (a 3456x2234 MacBook: 1.8x) art pixels come out 10 and 11 screen pixels
## wide. Godot's own stretch settings can't fix that: integer stretch counts
## in multiples of the 1920x1080 canvas (1x on that MacBook) and rounds the
## content scale factor down to a whole number, and fractional stretch always
## fills the screen.
##
## Instead the window switches to canvas_items stretching (so it draws at the
## screen's own resolution) on the usual 1920x1080 base, which keeps the
## viewport exactly as the rest of the game expects it, and the root's global
## canvas transform then shrinks that fitted picture to k/6 (k = the largest
## whole art scale that fits) and centres it. The global canvas transform
## also moves every CanvasLayer and maps the mouse, so nothing else needs to
## know. A mask blacks out the band it leaves, where anything drawn past the
## frame's edge would otherwise show.

## Under the cursor (layer 128), over everything else.
const _MASK_LAYER: int = 127

## The player's choice. It only takes effect in fullscreen: windowed, the
## window scales on offer are whole multiples already.
var _wanted: bool = false
## Whether the sizing is in effect right now.
var _active: bool = false

## Applies it to a window too, for tests and offline previews that can't go
## fullscreen.
var apply_in_window: bool = false:
	set(value):
		apply_in_window = value
		_apply()
var _mask_layer: CanvasLayer
## The window mode _apply() last saw. On macOS the window reaches its
## fullscreen size a few frames before it reports being fullscreen, so a size
## change alone can come too early.
var _last_mode: Window.Mode = Window.MODE_WINDOWED


func _ready() -> void:
	# Fullscreen can be toggled from the pause menu, with the tree paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_mask_layer = CanvasLayer.new()
	_mask_layer.layer = _MASK_LAYER
	_mask_layer.visible = false
	_mask_layer.add_child(_FrameMask.new())
	add_child(_mask_layer)

	get_tree().root.size_changed.connect(_apply)


func set_wanted(wanted: bool) -> void:
	_wanted = wanted
	_apply()


func is_wanted() -> bool:
	return _wanted


func is_active() -> bool:
	return _active


## The whole art scale that fits [param window_size]: 10 on a 3456x2234
## screen, 6 on 1920x1080. Never below 1.
static func art_scale_for(window_size: Vector2i) -> int:
	var fit: Vector2 = Vector2(window_size) / Globals.SCREEN_SIZE
	return maxi(1, floori(minf(fit.x, fit.y)))


## Where the frame goes in a [param window_size] window: [param art_scale]
## screen pixels per art pixel, centred on whole pixels.
static func frame_rect_for(window_size: Vector2i, art_scale: int) -> Rect2i:
	var frame_size: Vector2i = Vector2i(Globals.SCREEN_SIZE) * art_scale
	return Rect2i((window_size - frame_size) / 2, frame_size)


func _process(_delta: float) -> void:
	if get_tree().root.mode != _last_mode:
		_apply()


## Rechecked whenever the window changes size or mode, including fullscreen
## entered from outside the menu (the macOS green button).
func _apply() -> void:
	var root: Window = get_tree().root
	_last_mode = root.mode
	var fullscreen: bool = root.mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]
	_active = _wanted and (fullscreen or apply_in_window)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS if _active else Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	root.content_scale_size = Vector2i(ScreenFrame.SIZE)
	root.content_scale_factor = 1.0
	root.global_canvas_transform = Transform2D.IDENTITY
	if _active:
		# The window's own fit, viewport to window pixels, is the final
		# transform while the global one is the identity.
		var fitted: Transform2D = root.get_final_transform()
		var frame: Rect2i = frame_rect_for(root.size, art_scale_for(root.size))
		var wanted: Transform2D = Transform2D(0.0, Vector2(frame.size) / ScreenFrame.SIZE, 0.0, Vector2(frame.position))
		root.global_canvas_transform = fitted.affine_inverse() * wanted
	_mask_layer.visible = _active


## Paints black over everything outside the frame. It sits under the global
## canvas transform like every other layer, so it masks in viewport units.
class _FrameMask:
	extends Control

	## Far enough out to cover any window around the frame.
	const _REACH: float = 100000.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var frame: Rect2 = Rect2(Vector2.ZERO, ScreenFrame.SIZE)
		var black: Color = Color.BLACK
		draw_rect(Rect2(-_REACH, -_REACH, 2.0 * _REACH, _REACH), black)
		draw_rect(Rect2(-_REACH, frame.end.y, 2.0 * _REACH, _REACH), black)
		draw_rect(Rect2(-_REACH, 0.0, _REACH, frame.size.y), black)
		draw_rect(Rect2(frame.end.x, 0.0, _REACH, frame.size.y), black)
