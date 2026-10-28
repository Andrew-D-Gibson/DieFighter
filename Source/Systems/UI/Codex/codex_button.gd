class_name CodexButton
extends Control

## A small text button drawn in the codex's own frame style: the tabs and the
## page arrows. A selected tab shows gold; a disabled arrow dims and ignores
## clicks.

signal pressed()

const _HOVER_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/hover_thump.tres")

const _BACKGROUND: Color = Color("#0f0c2e")
const _BORDER: Color = Color("#251c6b")
const _BORDER_HOVER: Color = Color("#463c91")
const _BORDER_SELECTED: Color = Color("#eed35d")

@export var text: String = "":
	set(value):
		text = value
		if _label:
			_label.text = "[center]%s[/center]" % tr(text)

var selected: bool = false:
	set(value):
		selected = value
		_refresh()

var enabled: bool = true:
	set(value):
		enabled = value
		_refresh()

var _hovered: bool = false
var _label: RichTextLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.scroll_active = false
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override(&"normal_font_size", 16)
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The font sits low in its line; this centres the caps in the frame.
	_label.offset_top = -2
	_label.offset_bottom = 0
	add_child(_label)
	text = text
	mouse_entered.connect(func() -> void:
		_hovered = true
		if enabled and not selected:
			Events.play_sound.emit(_HOVER_SFX)
		_refresh()
	)
	mouse_exited.connect(func() -> void:
		_hovered = false
		_refresh()
	)
	_refresh()


func _gui_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseButton and event.pressed \
	and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()
		accept_event()


func _refresh() -> void:
	if not _label:
		return
	var colour: Color = Globals.white
	if selected:
		colour = Globals.yellow
	elif not enabled:
		colour = Color("#463c91")
	_label.add_theme_color_override(&"default_color", colour)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), _BACKGROUND)
	var border: Color = _BORDER
	if selected:
		border = _BORDER_SELECTED
	elif _hovered and enabled:
		border = _BORDER_HOVER
	draw_rect(Rect2(Vector2(0.5, 0.5), size - Vector2.ONE), border, false, 1.0)
