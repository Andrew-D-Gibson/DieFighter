class_name ReckoningHud
extends Node2D
## What the Reckoning shows the player that the cockpit doesn't already: the
## escape-velocity meter they're racing to fill, how soon the horizon takes
## the next column, how many saved ships are still to come, and, each round,
## the face Fate threw and what it does (FateFaceResource.reckoning_text).
##
## Sits in the gap in the systems panel's top edge, between its tabs, and
## shows only while a ReckoningDirector is running.

@export var meter_origin: Vector2 = Vector2(134, 80)
@export var meter_width: int = 52

const _BAR_BACK: Color = Color("#130f38")
const _BAR_FILL: Color = Color("#c552f1")
const _BAR_DARK: Color = Color("#80359d")
const _BAR_HEAD: Color = Color("#cef0f1")
const _OUTLINE: Color = Color("#040217")
const _BANNER_SECONDS: float = 2.0

var _label: Label
var _horizon_label: Label
var _allies_label: Label
var _banner: Control
var _banner_die: TextureRect
var _banner_name: Label
var _banner_text: RichTextLabel
var _banner_tween: Tween
var _shown_escape: float = 0.0


func _ready() -> void:
	z_index = 30
	_label = _make_label(FontRoles.SMALL, 1.0, Globals.purple)
	_horizon_label = _make_label(FontRoles.SMALL, 1.0, Globals.purple)
	_allies_label = _make_label(FontRoles.SMALL, 1.0, Globals.green)
	_build_banner()
	Events.fate_die_rolled.connect(_show_roll)
	Events.escape_velocity_changed.connect(func(_v: int, _g: int) -> void: queue_redraw())
	hide()


func _make_label(role: StringName, scale: float, color: Color) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = FontRoles.slot(role, scale)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _process(delta: float) -> void:
	var director: ReckoningDirector = ReckoningDirector.active()
	visible = director != null
	if not director:
		return
	var target: float = director.escape_velocity() / float(maxi(1, director.escape_goal()))
	_shown_escape = move_toward(_shown_escape, target, delta * 0.8)
	_label.text = tr("RECKONING_ESCAPE").format({"value": director.escape_velocity(), "goal": director.escape_goal()})
	_label.position = meter_origin + Vector2((meter_width - _label.size.x) / 2.0, -12)
	# Either side of the label: the rounds until the horizon next eats (left,
	# Fate's side) and the saved ships still to come (right).
	var rounds: int = director.rounds_until_swallow()
	_horizon_label.text = str(rounds) if rounds > 0 else "-"
	_horizon_label.position = _label.position + Vector2(-4 - _horizon_label.size.x, 0)
	_allies_label.text = str(director.allies_waiting())
	_allies_label.visible = director.allies_waiting() > 0
	_allies_label.position = _label.position + Vector2(_label.size.x + 10, 0)
	queue_redraw()


func _draw() -> void:
	if not ReckoningDirector.active():
		return
	var bar: Rect2 = Rect2(meter_origin, Vector2(meter_width, 4))
	draw_rect(bar.grow(1), _OUTLINE)
	draw_rect(bar, _BAR_BACK)
	var filled: int = int(round(meter_width * clampf(_shown_escape, 0.0, 1.0)))
	if filled > 0:
		draw_rect(Rect2(bar.position, Vector2(filled, 4)), _BAR_FILL)
		draw_rect(Rect2(bar.position + Vector2(0, 3), Vector2(filled, 1)), _BAR_DARK)
		draw_rect(Rect2(bar.position + Vector2(filled - 1, 0), Vector2(1, 4)), _BAR_HEAD)
	# A little void before the horizon's count, a little pod before the allies'.
	var row_y: float = _label.position.y + _label.size.y / 2.0 - 2.0
	var void_at: Vector2 = Vector2(_horizon_label.position.x - 7, row_y).round()
	draw_rect(Rect2(void_at, Vector2(5, 5)), _BAR_DARK)
	draw_rect(Rect2(void_at + Vector2.ONE, Vector2(3, 3)), Color.BLACK)
	if _allies_label.visible:
		var pod_at: Vector2 = Vector2(_allies_label.position.x - 7, row_y).round()
		draw_rect(Rect2(pod_at + Vector2(1, 0), Vector2(3, 5)), Color("#659c2a"))
		draw_rect(Rect2(pod_at + Vector2(0, 1), Vector2(5, 3)), Color("#659c2a"))
		draw_rect(Rect2(pod_at + Vector2(2, 2), Vector2.ONE), Color("#f29c5d"))


# ── The banner: what Fate threw ─────────────────────────────────────────────

func _build_banner() -> void:
	_banner = Control.new()
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.position = Vector2(60, 26)
	_banner.size = Vector2(200, 50)
	_banner.modulate.a = 0.0
	add_child(_banner)
	_banner_die = TextureRect.new()
	_banner_die.position = Vector2(0, 2)
	_banner_die.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_child(_banner_die)
	_banner_name = Label.new()
	_banner_name.theme_type_variation = FontRoles.slot(FontRoles.SMALL, 2.0)
	_banner_name.position = Vector2(38, 0)
	_banner_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_child(_banner_name)
	_banner_text = RichTextLabel.new()
	_banner_text.bbcode_enabled = true
	_banner_text.fit_content = true
	_banner_text.scroll_active = false
	_banner_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner_text.position = Vector2(38, 18)
	_banner_text.custom_minimum_size = Vector2(160, 0)
	_banner_text.size = Vector2(160, 20)
	_banner_text.add_theme_color_override("default_color", Globals.white)
	_banner_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_child(_banner_text)


func _show_roll(_slot: int, face: int) -> void:
	var res: FateFaceResource = FateFaceCatalog.get_face(face as FateDie.Face)
	if res == null:
		return
	_banner_die.texture = FateDieArt.face_texture(face as FateDie.Face, 3)
	_banner_name.text = tr("RECKONING_FATE_ROLLS").format({"face": res.display_face_name().to_upper()})
	_banner_name.add_theme_color_override("font_color", res.color)
	_banner_text.text = Utils.format_text(res.display_reckoning_text(Globals.fate_ledger), true)
	if _banner_tween:
		_banner_tween.kill()
	_banner.scale = Vector2.ONE * 1.3
	_banner.pivot_offset = _banner.size / 2.0
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.15)
	_banner_tween.parallel().tween_property(_banner, "scale", Vector2.ONE, 0.2)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_interval(_BANNER_SECONDS)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.4)
