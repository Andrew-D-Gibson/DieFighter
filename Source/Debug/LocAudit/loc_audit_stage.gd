class_name LocAuditStage
extends Node
## Where the localization audit poses each screen: an offscreen 1920x1080
## viewport laid out like the game's (a world drawn through a 6x camera on the
## 320x180 grid, and a UI layer at full resolution), which it photographs.
##
## Being a viewport of its own, it shows only what the audit put in it, and
## photographs the same way at any window size or stretch setting.

const SIZE: Vector2i = Vector2i(1920, 1080)
const _WORLD_SIZE: Vector2 = Vector2(320, 180)
const _WORLD_ZOOM: float = 6.0
## The game's backdrop colour, so light text reads as it would in play.
const _BACKDROP: Color = Color(0.0156863, 0.00784314, 0.0901961)
## Room left round the text when a photo is cropped to it.
const _CROP_MARGIN: int = 24

var viewport: SubViewport
## World-space screens (popups, the menus, callouts) go here.
var world: Node2D
## Full-resolution screens (the info panel) go here.
var ui: CanvasLayer


func _ready() -> void:
	viewport = SubViewport.new()
	viewport.name = "SubViewport"
	viewport.size = SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.gui_disable_input = true
	add_child(viewport)

	var backdrop_layer: CanvasLayer = CanvasLayer.new()
	backdrop_layer.layer = -100
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = _BACKDROP
	backdrop.size = Vector2(SIZE)
	backdrop_layer.add_child(backdrop)
	viewport.add_child(backdrop_layer)

	world = Node2D.new()
	world.name = "World"
	viewport.add_child(world)
	var camera: Camera2D = Camera2D.new()
	camera.position = _WORLD_SIZE / 2.0
	camera.zoom = Vector2.ONE * _WORLD_ZOOM
	viewport.add_child(camera)
	camera.make_current()

	ui = CanvasLayer.new()
	ui.name = "UI"
	viewport.add_child(ui)


## Frees everything the last screen left on the stage.
func clear() -> void:
	for holder: Node in [world, ui]:
		for child: Node in holder.get_children():
			holder.remove_child(child)
			child.queue_free()


## Waits [param frames] frames, letting containers lay out and tweens play.
func settle(frames: int = 3) -> void:
	for i: int in range(frames):
		await get_tree().process_frame


## A photo of the stage as last drawn, cropped to the text and art under
## [param subject] (the whole stage if it shows none). Null in a headless run,
## which draws nothing.
func photograph(subject: Node) -> Image:
	if DisplayServer.get_name() == "headless":
		return null
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	if image == null or image.is_empty():
		return null
	var crop: Rect2i = content_rect(subject)
	if crop.size.x <= 0 or crop.size.y <= 0:
		return image
	return image.get_region(crop)


## The on-screen box round every visible label and picture under
## [param subject], with a margin, clamped to the stage.
func content_rect(subject: Node) -> Rect2i:
	var bounds: Rect2 = Rect2()
	var found: bool = false
	var nodes: Array[Node] = [subject]
	nodes.append_array(subject.find_children("*", "", true, false))
	for node: Node in nodes:
		var rect: Rect2 = _screen_rect(node)
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		bounds = rect if not found else bounds.merge(rect)
		found = true
	if not found:
		return Rect2i(Vector2i.ZERO, SIZE)
	var margin: Vector2 = Vector2.ONE * _CROP_MARGIN
	var grown: Rect2 = Rect2(bounds.position - margin, bounds.size + margin * 2.0)
	return Rect2i(grown).intersection(Rect2i(Vector2i.ZERO, SIZE))


## Where [param node] draws on the stage, if it's text or a picture that's
## showing; an empty rect otherwise.
static func _screen_rect(node: Node) -> Rect2:
	var item: CanvasItem = node as CanvasItem
	if item == null or not item.is_visible_in_tree() or item.modulate.a <= 0.0:
		return Rect2()
	var local: Rect2
	if node is Label or node is RichTextLabel:
		if (node as Control).size.x <= 0.0:
			return Rect2()
		local = Rect2(Vector2.ZERO, (node as Control).size)
	elif node is TextureRect and (node as TextureRect).texture:
		local = Rect2(Vector2.ZERO, (node as Control).size)
	elif node is Sprite2D and (node as Sprite2D).texture:
		local = (node as Sprite2D).get_rect()
	elif node is NinePatchRect or node is PanelContainer:
		local = Rect2(Vector2.ZERO, (node as Control).size)
	else:
		return Rect2()
	return item.get_global_transform_with_canvas() * local
