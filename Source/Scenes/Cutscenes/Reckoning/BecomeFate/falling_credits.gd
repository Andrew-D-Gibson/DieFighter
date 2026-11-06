extends Control
## The credits as Become Fate rolls them (RECKONING_ENDINGS.md §7): falling.
## They come in over the top of the screen and drop down it, into the hole,
## rather than rising like credits anywhere else. Stacked top to bottom
## they'd arrive backwards, so the blocks are stacked bottom up (each still
## reads heading over names): the title falls in first and "Thanks for
## playing" last. That last line slows to a stop in the middle of the
## screen and holds there; everything else falls on out.
##
## Drawn on the 1080p layer, at six screen pixels per font pixel, so the text
## sits on the art grid's scale but glides down smoothly between its pixels,
## like the starfield.

## The last line has come to rest in the middle and been held.
signal rolled

## Screen pixels a second the column falls.
@export var fall_speed: float = 150.0
## Seconds the last line takes to come to rest, and is held once it has.
@export var settle_seconds: float = 2.4
@export var hold_seconds: float = 2.6

const _ART_SCALE: float = 6.0
## Screen pixels between lines, and the extra a GAP line leaves.
const _LINE_GAP: float = 18.0
const _BLOCK_GAP: float = 54.0
## Approved palette: headings in Fate's purple, names in the game's white,
## the title in bone, the die's colour.
const _HEADING_COLOR: Color = Color("#c552f1")
const _NAME_COLOR: Color = Color("#cef0f1")
const _TITLE_COLOR: Color = Color("#c4c1bc")
const _SHADOW: Color = Color("#040217")

var _labels: Array[Label] = []
## Each label's top relative to the column's, which is the last line's.
var _offsets: PackedFloat32Array = PackedFloat32Array()
## Where the column's top is: the rest fall with it at a steady speed, and
## the last line rides it until it starts to settle on its own.
var _column_top: float = 0.0
var _last_top: float = 0.0
var _falling: bool = false
var _settled: bool = false
var _last: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var y: float = 0.0
	# Block by block, bottom up: the first block ends up lowest, so it falls
	# in first. Each block still reads top to bottom, heading over names.
	var blocks: Array[Array] = _blocks(ReckoningCredits.lines())
	for b: int in range(blocks.size() - 1, -1, -1):
		for line: Dictionary in blocks[b]:
			var label: Label = _make_label(line)
			if _labels.is_empty():
				# The closing line, the one that comes to rest: a size up
				# from the headings it's written as.
				label.theme_type_variation = FontRoles.slot(FontRoles.BODY, _ART_SCALE)
			_labels.append(label)
			_offsets.append(y)
			y += label.get_combined_minimum_size().y + _LINE_GAP
		y += _BLOCK_GAP
	_last = _labels[0]
	_column_top = -y
	_last_top = _column_top
	_place()


## The credits' lines split at their gaps.
func _blocks(lines: Array[Dictionary]) -> Array[Array]:
	var blocks: Array[Array] = [[]]
	for line: Dictionary in lines:
		if line["style"] == ReckoningCredits.Style.GAP:
			if not blocks.back().is_empty():
				blocks.append([])
			continue
		blocks.back().append(line)
	if blocks.back().is_empty():
		blocks.pop_back()
	return blocks


func _make_label(line: Dictionary) -> Label:
	var label: Label = Label.new()
	var style: ReckoningCredits.Style = line["style"]
	var text: String = str(line["text"])
	label.text = tr(text) if style == ReckoningCredits.Style.HEADING else text
	match style:
		ReckoningCredits.Style.TITLE:
			label.theme_type_variation = FontRoles.slot(FontRoles.BODY, _ART_SCALE * 2.0)
			label.add_theme_color_override("font_color", _TITLE_COLOR)
		ReckoningCredits.Style.HEADING:
			label.theme_type_variation = FontRoles.slot(FontRoles.SMALL, _ART_SCALE)
			label.add_theme_color_override("font_color", _HEADING_COLOR)
		_:
			label.theme_type_variation = FontRoles.slot(FontRoles.BODY, _ART_SCALE)
			label.add_theme_color_override("font_color", _NAME_COLOR)
	label.add_theme_color_override("font_shadow_color", _SHADOW)
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", int(_ART_SCALE))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


## Starts the fall.
func roll() -> void:
	_falling = true


func _process(delta: float) -> void:
	if not _falling:
		return
	_column_top += fall_speed * delta
	if not _settled:
		_settle_last(delta)
	_place()


## The last line falls with the column until it's near the middle, then
## eases in to rest there: its speed falls off with the distance left, so it
## arrives in about settle_seconds without a jolt.
func _settle_last(delta: float) -> void:
	var screen: Vector2 = get_viewport_rect().size
	var rest: float = (screen.y - _last.get_combined_minimum_size().y) / 2.0
	var settle_distance: float = fall_speed * settle_seconds / 2.0
	var to_rest: float = rest - _last_top
	if to_rest > settle_distance:
		_last_top = _column_top
		return
	_last_top += maxf(fall_speed * to_rest / settle_distance, 6.0) * delta
	if rest - _last_top <= 0.5:
		_last_top = rest
		_settled = true
		var hold: Tween = create_tween()
		hold.tween_interval(hold_seconds)
		hold.tween_callback(rolled.emit)


func _place() -> void:
	var screen: Vector2 = get_viewport_rect().size
	for i: int in _labels.size():
		var label: Label = _labels[i]
		var top: float = _last_top if label == _last else _column_top
		label.size = Vector2(screen.x, 0.0)
		label.position = Vector2(0.0, roundf(top + _offsets[i]))
