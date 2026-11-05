class_name KeywordDiagram
extends Control
## The picture over a spatial keyword's rule in its hover pop-up (the info
## panel's and the codex's): a 3x3 patch of grid, the tile in the middle, and
## arrows to the slots the term reaches.
##
## The art is Art/Textures/UI/keyword_diagram.aseprite, one frame per term, on
## the grid's own 24px slots. It's drawn at a whole multiple of its pixels, so
## it stays as crisp as the rest of the pixel art beside it.

const _SHEET: Texture2D = preload("res://Assets/Textures/UI/keyword_diagram-Sheet.png")
## One frame of the sheet: three 24px slots square.
const _FRAME_SIZE: int = 72
## Sheet frame per keyword id, in the order the .aseprite holds them.
const _FRAMES: Dictionary[String, int] = {"adjacent": 0, "surrounding": 1}

var term: String = ""
## Screen pixels per art pixel.
var pixel_scale: int = 1


static func supports(keyword_id: String) -> bool:
	return _FRAMES.has(keyword_id)


## Puts a diagram over [param label] in [param popup] for [param keyword_id],
## or hides it for a term without one. The first call moves the label into a
## column under the diagram; later ones reuse it. [param ui_scale] is the
## popup's screen pixels per art pixel.
static func configure(popup: PanelContainer, label: RichTextLabel, keyword_id: String, ui_scale: float) -> void:
	var diagram: KeywordDiagram = popup.find_child("KeywordDiagram", true, false) as KeywordDiagram
	if diagram == null:
		if not supports(keyword_id):
			return	# nothing to show yet; build it the first time it's needed
		var column: VBoxContainer = VBoxContainer.new()
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		popup.add_child(column)
		diagram = KeywordDiagram.new()
		diagram.name = "KeywordDiagram"
		diagram.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(diagram)
		label.reparent(column)
	diagram.term = keyword_id
	diagram.pixel_scale = maxi(1, roundi(ui_scale))
	diagram.custom_minimum_size = Vector2.ONE * _FRAME_SIZE * diagram.pixel_scale
	diagram.visible = supports(keyword_id)
	diagram.queue_redraw()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _draw() -> void:
	if not supports(term):
		return
	var side: float = _FRAME_SIZE * pixel_scale
	# Centred, on a whole screen pixel, so no art pixel straddles two.
	var at: Vector2 = Vector2(floorf((size.x - side) / 2.0), 0.0)
	var region: Rect2 = Rect2(_FRAMES[term] * _FRAME_SIZE, 0, _FRAME_SIZE, _FRAME_SIZE)
	draw_texture_rect_region(_SHEET, Rect2(at, Vector2(side, side)), region)
