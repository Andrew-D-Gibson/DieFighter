class_name BackgroundModifierLabel
extends Control
## Announces the permanent rule of the background the player just arrived in.
##
## Backgrounds are drawn from a random pool, so the player does not pick their
## rule — which means the rule has to announce itself, once, before the first
## die is placed. Without this banner "shields do nothing here" reads as a bug
## rather than as the terrain. Hidden entirely in plain space, so the banner
## appearing at all is itself information.

## Bounds on how far the banner will stretch to fit its rule.
const _MIN_TEXT_WIDTH: int = 360
const _MAX_TEXT_WIDTH: int = 1200

## How long the banner sits at full opacity before fading.
@export var hold_time: float = 3.5

## Fade timings, kept separate because the fade in should be a snap and the
## fade out should feel like the ship settling into the new region.
@export var fade_in_time: float = 0.25
@export var fade_out_time: float = 1.0

@onready var _panel: PanelContainer = %Panel
@onready var _name_label: RichTextLabel = %NameLabel
@onready var _description_label: RichTextLabel = %DescriptionLabel

var _tween: Tween


func _ready() -> void:
	modulate.a = 0.0
	visible = false
	Events.background_modifier_applied.connect(_on_modifier_applied)


func _on_modifier_applied(modifier: BackgroundModifierResource) -> void:
	if _tween:
		_tween.kill()

	if modifier == null:
		visible = false
		modulate.a = 0.0
		return

	_populate(modifier)
	_play()


func _populate(modifier: BackgroundModifierResource) -> void:
	var tint: String = modifier.color.to_html(false)

	_name_label.text = "[center][color=%s]%s[/color][/center]" % [
		tint, modifier.modifier_name.to_upper()
	]
	_description_label.text = "[center]%s[/center]" % Utils.format_text(
		modifier.description, 1
	)

	# Border picks up the background's own palette, so the banner reads as part
	# of the region rather than as generic UI chrome.
	var style: StyleBox = _panel.get_theme_stylebox("panel")
	if style is StyleBoxFlat:
		var flat: StyleBoxFlat = (style as StyleBoxFlat).duplicate()
		flat.border_color = modifier.color
		_panel.add_theme_stylebox_override("panel", flat)

	_fit_to_text()


## RichTextLabel's fit_content only sizes height, so without this the panel
## either clips a long rule or leaves a lane of empty box around a short one.
## Measuring the parsed (tag-free) text lets the banner hug whatever it says.
func _fit_to_text() -> void:
	var width: int = maxi(_text_width(_name_label), _text_width(_description_label))
	width = clampi(width, _MIN_TEXT_WIDTH, _MAX_TEXT_WIDTH)
	_name_label.custom_minimum_size.x = width
	_description_label.custom_minimum_size.x = width


func _text_width(label: RichTextLabel) -> int:
	var font: Font = label.get_theme_font("normal_font")
	if font == null:
		return _MIN_TEXT_WIDTH
	var font_size: int = label.get_theme_font_size("normal_font_size")
	var measured: float = font.get_string_size(
		label.get_parsed_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
	).x
	# Small cushion so a glyph never lands flush against the border.
	return int(ceil(measured)) + 24


func _play() -> void:
	visible = true
	modulate.a = 0.0

	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, fade_in_time)
	_tween.tween_interval(hold_time)
	_tween.tween_property(self, "modulate:a", 0.0, fade_out_time)
	_tween.tween_callback(func() -> void: visible = false)
