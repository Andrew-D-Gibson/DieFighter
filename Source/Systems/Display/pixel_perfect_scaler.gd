class_name PixelPerfectScaler
extends Node
## Shows the game at a whole number of screen pixels per art pixel, with black
## bars around it, instead of stretched to fit the screen.
##
## The project renders a 1920x1080 canvas through a 6x camera and letterboxes
## it by whatever factor fits, so on a screen that isn't a multiple of 320x180
## (a 3456x2234 MacBook: 1.8x) art pixels come out 10 and 11 screen pixels
## wide. Godot's own integer stretch can't help: it counts in multiples of the
## 1920x1080 canvas, which leaves that MacBook at 1x.
##
## Instead the window switches to canvas_items stretching, set up so the
## canvas scales by exactly k/6 (k = the largest whole art scale that fits).
## Content scale factor below 1 isn't allowed, so the base size is six screens
## and the factor is k. The window then shows a little more canvas than the
## 1920x1080 frame; cameras centre on the frame anyway, a mask covers the
## extra, and screen-space layers in FRAME_UI_GROUP are moved onto the frame.

## CanvasLayers that don't follow the camera but were laid out for a
## 1920x1080 screen at the origin: shifted onto the frame when it's inset.
const FRAME_UI_GROUP: StringName = &"frame_ui"

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
var _mask: _FrameMask


func _ready() -> void:
	# Fullscreen can be toggled from the pause menu, with the tree paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_mask_layer = CanvasLayer.new()
	_mask_layer.layer = _MASK_LAYER
	_mask_layer.visible = false
	_mask = _FrameMask.new()
	_mask_layer.add_child(_mask)
	add_child(_mask_layer)

	get_tree().root.size_changed.connect(_apply)
	get_tree().node_added.connect(_on_node_added)


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
	if _active:
		var art_scale: int = art_scale_for(root.size)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
		root.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL
		root.content_scale_size = root.size * int(ScreenFrame.ART_PIXEL_SCALE)
		root.content_scale_factor = art_scale
	else:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
		root.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL
		root.content_scale_size = Vector2i(ScreenFrame.SIZE)
		root.content_scale_factor = 1.0

	_mask_layer.visible = _active
	_mask.queue_redraw()
	for layer: Node in get_tree().get_nodes_in_group(FRAME_UI_GROUP):
		_place_frame_layer(layer as CanvasLayer)


func _place_frame_layer(layer: CanvasLayer) -> void:
	if not layer:
		return
	layer.offset = ScreenFrame.rect_in_viewport(get_viewport()).position if _active else Vector2.ZERO


func _on_node_added(node: Node) -> void:
	if node is CanvasLayer and node.is_in_group(FRAME_UI_GROUP):
		_place_frame_layer.call_deferred(node)


## Paints black over everything outside the frame.
class _FrameMask:
	extends Control

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var visible: Rect2 = get_viewport().get_visible_rect()
		var frame: Rect2 = ScreenFrame.rect_in_viewport(get_viewport())
		var black: Color = Color.BLACK
		draw_rect(Rect2(visible.position, Vector2(visible.size.x, frame.position.y - visible.position.y)), black)
		draw_rect(Rect2(Vector2(visible.position.x, frame.end.y), Vector2(visible.size.x, visible.end.y - frame.end.y)), black)
		draw_rect(Rect2(Vector2(visible.position.x, frame.position.y), Vector2(frame.position.x - visible.position.x, frame.size.y)), black)
		draw_rect(Rect2(Vector2(frame.end.x, frame.position.y), Vector2(visible.end.x - frame.end.x, frame.size.y)), black)
