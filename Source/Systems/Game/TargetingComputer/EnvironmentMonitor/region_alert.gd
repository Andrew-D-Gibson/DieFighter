class_name RegionAlert
extends Node2D
## A card that spells out the region's rule or hazard on arrival. It unfolds
## out of the EnvironmentMonitor's screen into the empty sky (the ships wait
## for it; see ArrivalIntro), holds while the player reads, then folds back
## into the screen, so the player learns both what the rule says and where to
## look it up again. The rest of the cockpit dims a little while it's up, and
## a click anywhere (or its Close button) sends it back at once.
##
## The first time a player meets a rule or hazard the card doesn't time out:
## a new player reads slowly, and the hold that suits a returning one is gone
## before they're done. It waits for Close or a click (wait_for_close; the
## monitor decides from CollectionManager).
##
## Players who know the backgrounds by heart can turn it off in the options
## (Globals.show_region_alerts); the monitor still swings up either way.

## Reached the monitor. The monitor answers with a kick and counts the rule as
## read.
signal landed()

const _PANEL_TEXTURE: Texture2D = preload("res://Assets/Textures/TutorialManager/background.png")
const _BUTTON_SCENE: PackedScene = preload("res://Source/Systems/UI/Buttons/small_button.tscn")
## The tutorial card's blue button: this card wears the same panel.
const _BUTTON_TEXTURE: Texture2D = preload("res://Assets/Textures/UI/Buttons/button_small_blue.png")
const _BUTTON_HOVER_COLOR: Color = Color(0.262745, 0.65098, 0.988235, 1)

## Where the card shows: the sky above the main viewer, which is empty while
## the ships hold off, rather than over the busy tile grid.
const _SHOW_AT: Vector2 = Vector2(160, 44)
## Above the main viewer, its tiles and the dice, under damage numbers.
const _Z_INDEX: int = 60
const _TEXT_WIDTH: float = 128.0

## The same near-black the boss band dims with, much fainter: enough to lift
## the card off the cockpit without blacking it out.
const _DIM_COLOR: Color = Color(0.0156863, 0.00784314, 0.0901961, 0.3)
## Covers the screen with room to spare for camera shake.
const _DIM_RECT: Rect2 = Rect2(-16, -16, 352, 212)

const _UNFOLD_SECONDS: float = 0.4
## Long enough to read a one-line rule.
const _HOLD_SECONDS: float = 2.2
## Extra time to read a footnote (a hazard's timing).
const _FOOTNOTE_HOLD_SECONDS: float = 1.3
const _FOLD_SECONDS: float = 0.45
## How small the card is at the monitor's screen, coming and going.
const _AT_MONITOR_SCALE: float = 0.06

var title: String = ""
var color: Color = Color.WHITE
var description: String = ""
## Small print under the description, e.g. when a hazard hits. Empty for none.
var footnote: String = ""
## The monitor's screen, asked as each flight starts.
var landing_point: Callable
## Stay up until the player closes it, instead of folding away on a timer.
var wait_for_close: bool = false

var _dim: ColorRect
## Everything that flies: the panel and its text.
var _card: Node2D
var _panel: PanelContainer
var _close_button: Button
## Folds the card once the player has had time to read it. Null while it
## waits for Close.
var _hold_timer: SceneTreeTimer
var _folding: bool = false


func _ready() -> void:
	top_level = true
	z_as_relative = false
	z_index = _Z_INDEX
	global_position = Vector2.ZERO
	_build()
	Events.jump.connect(_vanish)
	_unfold()


func _build() -> void:
	# Also catches the click that skips the card, and keeps it from landing
	# on whatever is underneath.
	_dim = ColorRect.new()
	_dim.position = _DIM_RECT.position
	_dim.size = _DIM_RECT.size
	_dim.color = _DIM_COLOR
	_dim.modulate.a = 0.0
	_dim.gui_input.connect(_on_click)
	add_child(_dim)

	_card = Node2D.new()
	add_child(_card)

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
	_panel.gui_input.connect(_on_click)
	_card.add_child(_panel)

	var lines: VBoxContainer = VBoxContainer.new()
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_theme_constant_override("separation", 0)
	_panel.add_child(lines)
	lines.add_child(_label("[color=%s]%s[/color]" % [color.to_html(false), title]))
	# Formatted like the info panel: keyword tokens, palette colours, icons.
	lines.add_child(_label(Utils.format_text(description)))
	if not footnote.is_empty():
		lines.add_child(_label(Utils.format_text(footnote)))
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0, 2)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_child(gap)
	lines.add_child(_build_close_button())

	# Centred on the card's origin, so scaling it shrinks toward its middle.
	_panel.reset_size()
	_panel.position = -(_panel.size / 2.0).round()


## The project's small button, in the tutorial card's blue. Shown on every
## card, so a returning player can skip the hold too.
func _build_close_button() -> Button:
	var button: Button = _BUTTON_SCENE.instantiate()
	var face: AtlasTexture = AtlasTexture.new()
	face.atlas = _BUTTON_TEXTURE
	face.region = Rect2(0, 0, 35, 12)
	var frames: SpriteFrames = SpriteFrames.new()
	frames.add_frame(&"default", face)
	button.get_node("AnimatedSprite2D").sprite_frames = frames
	button.hover_text_color = _BUTTON_HOVER_COLOR
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.set_button_text("REGION_ALERT_CLOSE")
	button.pressed_within_window.connect(_fold)
	_close_button = button
	return button


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


func _monitor_point() -> Vector2:
	return landing_point.call() if landing_point.is_valid() else _SHOW_AT


## Out of the monitor's screen and up into the sky: the fold played backwards,
## so the player sees where it came from.
func _unfold() -> void:
	_card.global_position = _monitor_point()
	_card.scale = Vector2.ONE * _AT_MONITOR_SCALE
	_card.modulate.a = 0.0
	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(_card, "global_position", _SHOW_AT, _UNFOLD_SECONDS) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_card, "scale", Vector2.ONE, _UNFOLD_SECONDS) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_card, "modulate:a", 1.0, _UNFOLD_SECONDS * 0.4)
	tween.tween_property(_dim, "modulate:a", 1.0, _UNFOLD_SECONDS)
	if wait_for_close:
		return
	# Paused with the game, so a pause mid-read doesn't send it away.
	var hold_seconds: float = _HOLD_SECONDS + (0.0 if footnote.is_empty() else _FOOTNOTE_HOLD_SECONDS)
	_hold_timer = get_tree().create_timer(_UNFOLD_SECONDS + hold_seconds, false)
	_hold_timer.timeout.connect(_fold)


func _on_click(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
	and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		_fold()


## Shrinks back into the monitor's screen, fading out as it gets there.
func _fold() -> void:
	if _folding or not is_inside_tree():
		return
	_folding = true
	# The cockpit is the player's again as soon as the card starts to leave.
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_close_button.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var tween: Tween = create_tween().set_parallel()
	# Slow to start, fast to finish: it gets sucked in rather than drifting.
	tween.tween_property(_card, "global_position", _monitor_point(), _FOLD_SECONDS) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(_card, "scale", Vector2.ONE * _AT_MONITOR_SCALE, _FOLD_SECONDS) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(_card, "modulate:a", 0.0, _FOLD_SECONDS * 0.4) \
		.set_delay(_FOLD_SECONDS * 0.6)
	tween.tween_property(_dim, "modulate:a", 0.0, _FOLD_SECONDS)
	tween.chain().tween_callback(func() -> void:
		landed.emit()
		queue_free()
	)


## Jumping away makes the rule moot: the card just fades where it is.
func _vanish() -> void:
	if _folding:
		return
	_folding = true
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)
