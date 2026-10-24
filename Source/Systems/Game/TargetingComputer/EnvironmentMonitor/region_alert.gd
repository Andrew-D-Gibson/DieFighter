class_name RegionAlert
extends Node2D
## A card that spells out the region's rule or hazard on arrival, over the
## main viewer while the ships fly in, then shrinks away into the
## EnvironmentMonitor's screen, so the player learns both what the rule says
## and where to look it up again. Clicking it sends it off at once.
##
## Players who know the backgrounds by heart can turn it off in the options
## (Globals.show_region_alerts); the monitor still swings up either way.

## Reached the monitor. The monitor answers with a kick and counts the rule as
## read.
signal landed()

const _PANEL_TEXTURE: Texture2D = preload("res://Assets/Textures/TutorialManager/background.png")

## Where the card shows: the middle of the main viewer, which nothing uses
## while the ships are still flying in.
const _SHOW_AT: Vector2 = Vector2(160, 112)
## Above the main viewer, its tiles and the dice, under damage numbers.
const _Z_INDEX: int = 60
const _TEXT_WIDTH: float = 128.0

const _POP_SECONDS: float = 0.25
## Long enough to read a one-line rule while the ships arrive.
const _HOLD_SECONDS: float = 2.2
const _FLIGHT_SECONDS: float = 0.45
## How small the card is as it disappears into the monitor's screen.
const _LANDED_SCALE: float = 0.06

var title: String = ""
var color: Color = Color.WHITE
var description: String = ""
## Where to fly to, asked as the flight starts: the monitor may still be
## swinging up when the card appears.
var landing_point: Callable

var _panel: PanelContainer
var _flying: bool = false
var _hold_timer: SceneTreeTimer


func _ready() -> void:
	top_level = true
	z_as_relative = false
	z_index = _Z_INDEX
	global_position = _SHOW_AT
	_build()
	Events.jump.connect(_vanish)
	_pop_in()


func _build() -> void:
	_panel = PanelContainer.new()
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = _PANEL_TEXTURE
	style.texture_margin_left = 2.0
	style.texture_margin_top = 2.0
	style.texture_margin_right = 2.0
	style.texture_margin_bottom = 2.0
	style.content_margin_left = 5.0
	style.content_margin_right = 5.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 4.0
	_panel.add_theme_stylebox_override("panel", style)
	_panel.gui_input.connect(_on_panel_input)
	add_child(_panel)

	var lines: VBoxContainer = VBoxContainer.new()
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_theme_constant_override("separation", 0)
	_panel.add_child(lines)
	lines.add_child(_label("[color=%s]%s[/color]" % [color.to_html(false), title]))
	# Formatted like the info panel: keyword tokens, palette colours, icons.
	lines.add_child(_label(Utils.format_text(description)))

	# Centred on this node, so scaling it shrinks the card toward its middle.
	_panel.reset_size()
	_panel.position = -(_panel.size / 2.0).round()


func _label(text: String) -> RichTextLabel:
	var label: RichTextLabel = RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(_TEXT_WIDTH, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("default_color", Globals.white)
	label.text = text
	return label


func _pop_in() -> void:
	scale = Vector2.ONE * 0.6
	modulate.a = 0.0
	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(self, "scale", Vector2.ONE, _POP_SECONDS) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, _POP_SECONDS * 0.6)
	_hold_timer = get_tree().create_timer(_POP_SECONDS + _HOLD_SECONDS)
	_hold_timer.timeout.connect(_fly_to_monitor)


func _on_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
	and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_panel.accept_event()
		_fly_to_monitor()


## Shrinks off into the monitor's screen, fading out as it gets there.
func _fly_to_monitor() -> void:
	if _flying or not is_inside_tree():
		return
	_flying = true
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var target: Vector2 = landing_point.call() if landing_point.is_valid() else global_position

	var tween: Tween = create_tween().set_parallel()
	# Slow to start, fast to finish: it gets sucked in rather than drifting.
	tween.tween_property(self, "global_position", target, _FLIGHT_SECONDS) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2.ONE * _LANDED_SCALE, _FLIGHT_SECONDS) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, _FLIGHT_SECONDS * 0.4) \
		.set_delay(_FLIGHT_SECONDS * 0.6)
	tween.chain().tween_callback(func() -> void:
		landed.emit()
		queue_free()
	)


## Jumping away makes the rule moot: the card just fades where it is.
func _vanish() -> void:
	if _flying:
		return
	_flying = true
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)
