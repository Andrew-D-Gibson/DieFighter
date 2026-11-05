class_name TextFitter
extends Node
## Keeps its parent, a Label or RichTextLabel placed by hand rather than by a
## container, fitted inside the box its text may appear in (see TextFit), as
## the text, language, font or frame change.
##
## The box is, by box_source:
## - PARENT: the label's parent Control (a button, a panel) less the padding,
##   which names the frame's text-safe area: inside its border, above its 3D
##   lip.
## - AUTHORED: the rect the label had when the fitter started, for a label
##   laid out by hand in a scene.
## and `box`, when set, overrides either (in the label's parent's
## coordinates), for code that works out its own room.
##
## From code: `TextFitter.attach(label, TextFitPolicy.single_line())`. In a
## scene: a TextFitter child under the label, with a policy resource.
## A label inside a Container wants a TextFitBox instead: the container would
## undo every placement.

## After every fit, with where the text went: frames that hug their text
## resize to result.ink_rect.
signal fitted(result: TextFit.Result)

enum BoxSource {PARENT, AUTHORED}

@export var policy: TextFitPolicy
@export var box_source: BoxSource = BoxSource.PARENT
## The frame's text-safe area, in from each edge of the parent.
@export var padding_left: float = 0.0
@export var padding_top: float = 0.0
@export var padding_right: float = 0.0
@export var padding_bottom: float = 0.0
## Moves the fitted text by this much without refitting: a pressed button's
## face sinks, and its text with it.
@export var offset: Vector2 = Vector2.ZERO:
	set = set_offset

## A box of the caller's own, in the label's parent's coordinates. An empty
## one (the default) uses box_source.
var box: Rect2 = Rect2():
	set = set_box
## Share a scale with other fitted text (see TextFitGroup).
var group: TextFitGroup:
	set = set_group
## The last fit, or null before the first.
var result: TextFit.Result

var _label: Control
var _authored: Rect2 = Rect2()
## What the last fit was of: refits only when it changes.
var _signature: String = ""
var _queued: bool = false


## The fitter on [param label], made and added if it has none.
static func attach(label: Control, fit_policy: TextFitPolicy = null) -> TextFitter:
	var existing: TextFitter = TextFit.fitter_of(label) as TextFitter
	if existing != null:
		if fit_policy != null:
			existing.policy = fit_policy
			existing.refit()
		return existing
	var fitter: TextFitter = TextFitter.new()
	fitter.name = "TextFitter"
	fitter.policy = fit_policy
	# Internal, so code walking the label's children never meets it.
	label.add_child(fitter, false, Node.INTERNAL_MODE_BACK)
	return fitter


func set_padding(left: float, top: float, right: float, bottom: float) -> void:
	padding_left = left
	padding_top = top
	padding_right = right
	padding_bottom = bottom
	refit()


func set_offset(value: Vector2) -> void:
	offset = value
	if result != null and is_instance_valid(_label):
		_label.position = result.position + offset


func set_box(value: Rect2) -> void:
	box = value
	refit()


func set_group(value: TextFitGroup) -> void:
	if group == value:
		return
	if group != null:
		group.remove(_fit_at)
	group = value
	if group != null:
		group.add(_best_scale, _fit_at)


## The box the text is fitted into now, in the label's parent's coordinates.
func frame_box() -> Rect2:
	if box.has_area():
		return box
	var parent: Control = _label.get_parent() as Control if _label else null
	if box_source == BoxSource.PARENT and parent != null:
		return Rect2(padding_left, padding_top, parent.size.x - padding_left - padding_right,
			parent.size.y - padding_top - padding_bottom)
	return Rect2(_authored.position + Vector2(padding_left, padding_top),
		_authored.size - Vector2(padding_left + padding_right, padding_top + padding_bottom))


## Fits again at the end of the frame (once, however often it's asked).
func refit() -> void:
	if _queued or not is_inside_tree():
		return
	_queued = true
	_refit_now.call_deferred()


func _ready() -> void:
	_label = get_parent() as Control
	if not (_label is Label or _label is RichTextLabel):
		push_error("TextFitter: %s's parent must be a Label or RichTextLabel" % get_path())
		set_process(false)
		return
	if policy == null:
		policy = TextFitPolicy.single_line()
	_authored = Rect2(_label.position, _label.size)
	var parent: Control = _label.get_parent() as Control
	if not parent is Container:
		# The fit places the label; anchors would stretch it again on every
		# resize of its frame.
		_label.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	_label.set_meta(TextFit.META, self)
	_label.draw.connect(_on_label_draw)
	_label.theme_changed.connect(refit)
	if parent is Container:
		push_warning("TextFitter: %s is laid out by a Container, which undoes its fit; wrap it in a TextFitBox" % _label.get_path())
	if parent != null:
		parent.resized.connect(refit)
	refit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		refit()


func _refit_now() -> void:
	_queued = false
	if not is_instance_valid(_label) or not _label.is_inside_tree():
		return
	_signature = _signature_now()
	if group != null:
		group.request()
	else:
		_fit_at(1.0)


func _best_scale() -> float:
	if not is_instance_valid(_label) or not _label.is_inside_tree():
		return 1.0
	return TextFit.best_scale(_label, frame_box(), policy)


func _fit_at(max_scale: float) -> void:
	if not is_instance_valid(_label) or not _label.is_inside_tree():
		return
	result = TextFit.solve(_label, frame_box(), policy, max_scale)
	TextFit.apply(_label, result)
	_label.position += offset
	fitted.emit(result)


## Text, font (through its current files) and box: what a fit depends on.
## Read on every draw, so text set from code, a language or a font change
## refits on the frame it shows.
func _signature_now() -> String:
	var source_text: String = ""
	var font: Font
	if _label is RichTextLabel:
		source_text = (_label as RichTextLabel).get_parsed_text()
		font = _label.get_theme_font(&"normal_font")
	else:
		source_text = _label.atr((_label as Label).text)
		font = _label.get_theme_font(&"font")
	return "%s|%s|%s|%s" % [source_text, font.get_rids() if font else [], _label.get_theme_font_size(
		&"normal_font_size" if _label is RichTextLabel else &"font_size"), frame_box()]


func _on_label_draw() -> void:
	if _signature_now() != _signature:
		refit()
