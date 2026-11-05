class_name TextFitBox
extends Container
## A Container holding one Label or RichTextLabel, which it fits (see
## TextFit) to the width its own container gives it, then asks for the height
## the text needs: wrapped onto a second line, the row grows; shrunk, it
## doesn't. For text in a layout (an options row, a list), where a TextFitter
## would be undone by the container.
##
## Expanding horizontally (SIZE_EXPAND), it takes the width it's given and
## fits to it; otherwise it hugs its text at full size, like a plain label.
##
## From code: `row.add_child(TextFitBox.wrap(label, TextFitPolicy.wrapping()))`.

## After every fit, with where the text went.
signal fitted(result: TextFit.Result)

@export var policy: TextFitPolicy
## Share a scale with other fitted text (see TextFitGroup).
var group: TextFitGroup:
	set = set_group
## The last fit, or null before the first.
var result: TextFit.Result

var _label: Control
var _minimum: Vector2 = Vector2.ZERO
var _signature: String = ""
## The scale the group allows (1 with no group).
var _max_scale: float = 1.0
var _fitted_width: float = -1.0
## Refits text fitted while something above was mid-animation, once at rest.
var _settle: TextFitSettle = TextFitSettle.new()


## [param label] in a new TextFitBox that takes over its place in a layout:
## its size flags and mouse handling move to the box.
static func wrap(label: Control, fit_policy: TextFitPolicy) -> TextFitBox:
	var fit_box: TextFitBox = TextFitBox.new()
	fit_box.name = "%sFit" % label.name
	fit_box.policy = fit_policy
	fit_box.size_flags_horizontal = label.size_flags_horizontal
	fit_box.size_flags_vertical = label.size_flags_vertical
	fit_box.size_flags_stretch_ratio = label.size_flags_stretch_ratio
	fit_box.mouse_filter = label.mouse_filter
	label.size_flags_horizontal = Control.SIZE_FILL
	label.size_flags_vertical = Control.SIZE_FILL
	fit_box.add_child(label)
	return fit_box


func set_group(value: TextFitGroup) -> void:
	if group == value:
		return
	if group != null:
		group.remove(_fit_at)
	group = value
	_max_scale = 1.0
	if group != null:
		group.add(_best_scale, _fit_at)


## The label being fitted.
func text_label() -> Control:
	return _label


func _ready() -> void:
	if policy == null:
		policy = TextFitPolicy.single_line()
	for child: Node in get_children():
		if child is Label or child is RichTextLabel:
			_label = child as Control
			break
	if _label == null:
		push_error("TextFitBox: %s holds no Label or RichTextLabel" % get_path())
		return
	_label.set_meta(TextFit.META, self)
	_label.draw.connect(_on_label_draw)
	set_process(false)
	set_notify_transform(true)
	queue_sort()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_SORT_CHILDREN:
			_fit()
		NOTIFICATION_RESIZED:
			# A new width can change the group's scale; a new height can't.
			if group != null and not is_equal_approx(size.x, _fitted_width):
				group.request()
		NOTIFICATION_TRANSLATION_CHANGED, NOTIFICATION_THEME_CHANGED:
			_changed()
		NOTIFICATION_TRANSFORM_CHANGED:
			if _settle.moved(self):
				set_process(true)


func _process(_delta: float) -> void:
	if not _settle.settled():
		return
	set_process(false)
	if _settle.off_scale():
		_changed()


func _get_minimum_size() -> Vector2:
	return _minimum


func _hugs() -> bool:
	return not (size_flags_horizontal & Control.SIZE_EXPAND)


## The room the text is fitted to: the width it's given, or none to hug.
func _fit_box() -> Rect2:
	return Rect2(0.0, 0.0, INF if _hugs() else size.x, INF)


func _fit() -> void:
	if _label == null or not _label.is_inside_tree():
		return
	if not _hugs() and size.x <= 0.0:
		return
	_fitted_width = size.x
	_signature = _signature_now()
	var fit: TextFit.Result = TextFit.solve(_label, _fit_box(), policy, _max_scale)
	TextFit.place(fit, Rect2(Vector2.ZERO, Vector2(fit.block_size.x * fit.scale if _hugs() else size.x,
		size.y)), policy)
	TextFit.apply(_label, fit)
	_settle.fitted(self)
	result = fit
	var footprint: Vector2 = fit.block_size * fit.scale
	var wanted: Vector2 = Vector2(ceilf(footprint.x) if _hugs() else 0.0, ceilf(footprint.y))
	if not wanted.is_equal_approx(_minimum):
		_minimum = wanted
		update_minimum_size()
	fitted.emit(fit)


func _best_scale() -> float:
	if _label == null or not _label.is_inside_tree():
		return 1.0
	return TextFit.best_scale(_label, _fit_box(), policy)


func _fit_at(max_scale: float) -> void:
	_max_scale = max_scale
	queue_sort()


func _changed() -> void:
	if group != null:
		group.request()
	queue_sort()


func _signature_now() -> String:
	var font: Font = _label.get_theme_font(&"normal_font" if _label is RichTextLabel else &"font")
	var shown: String = (_label as RichTextLabel).get_parsed_text() if _label is RichTextLabel \
		else _label.atr((_label as Label).text)
	return "%s|%s|%s" % [shown, font.get_rids() if font else [], _label.get_theme_font_size(
		&"normal_font_size" if _label is RichTextLabel else &"font_size")]


func _on_label_draw() -> void:
	if _signature_now() != _signature:
		_changed()
