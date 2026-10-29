@tool
class_name AmplifierVisual
extends Node2D

const _FONT: Font = preload("res://Assets/Fonts/m5x7/m5x7_ui.tres")
## m5x7 at 16 keeps one font pixel to one world pixel.
const _FONT_SIZE: int = 16

## Numbers rise out of the same patch as the particles, at their pace, so the
## two read as one effect.
const _NUMBER_SPAWN_AREA: Rect2 = Rect2(-10.0, 0.0, 20.0, 12.0)
const _NUMBER_RISE_PIXELS: Vector2 = Vector2(10.0, 18.0)
const _NUMBER_LIFETIME_SECONDS: float = 2.5
const _NUMBER_INTERVAL_SECONDS: float = 1.3

## This visual's own modifier's bonus. Set by AmplifierModifier on register.
var amount: int = 0

## Numbers alternate halves of the spawn area so one rising past the next
## never overprints it.
var _spawn_on_right: bool = false


func _ready() -> void:
	var tween: Tween = create_tween().set_loops()
	tween.tween_property(%ColorMod, "modulate:a", 0.3, 2.0)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(%ColorMod, "modulate:a", 0.05, 2.0)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	if Engine.is_editor_hint():
		return
	var numbers: Tween = create_tween().set_loops()
	numbers.tween_callback(_spawn_number)
	numbers.tween_interval(_NUMBER_INTERVAL_SECONDS)


## The amplified tile flares as the bonus lands. Drives self_modulate, since
## the idle breathing loop above owns modulate.
func on_modifier_triggered() -> void:
	var flare: Tween = create_tween()
	flare.tween_property(%ColorMod, "self_modulate", Color.WHITE, 0.3) \
		.from(Color(3.0, 3.0, 3.0)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	Juice.sparkle(self, global_position + Vector2(0, 4), Globals.yellow, 6, 30.0, true)


## Stacked amplifiers each bring a visual. Only the first on the tile floats
## numbers, and they show the sum, so two +2s read as +4 rather than a
## crowd of +2s.
func _spawn_number() -> void:
	var host: Node = get_parent()
	if host == null:
		return
	var total: int = 0
	var lead: AmplifierVisual = null
	for child: Node in host.get_children():
		if child is AmplifierVisual and not child.is_queued_for_deletion():
			total += (child as AmplifierVisual).amount
			if lead == null:
				lead = child
	if lead != self or total == 0:
		return

	var label: Label = Label.new()
	label.text = "%+d" % total
	label.add_theme_font_override("font", _FONT)
	label.add_theme_font_size_override("font_size", _FONT_SIZE)
	label.add_theme_color_override("font_color", Globals.green)
	label.add_theme_color_override("font_outline_color", Globals.dark_gray)
	label.add_theme_constant_override("outline_size", 4)
	add_child(label)
	label.reset_size()
	var half_width: float = _NUMBER_SPAWN_AREA.size.x / 2.0
	var x_from: float = half_width if _spawn_on_right else 0.0
	_spawn_on_right = not _spawn_on_right
	var start: Vector2 = _NUMBER_SPAWN_AREA.position + Vector2(
		RNGManager.randf_range(RNGManager.Bucket.COSMETIC, x_from, x_from + half_width),
		RNGManager.randf_range(RNGManager.Bucket.COSMETIC, 0.0, _NUMBER_SPAWN_AREA.size.y))
	# Whole pixels, so the pixel font stays crisp as it drifts.
	label.position = (start - label.size / 2.0).round()
	label.modulate.a = 0.0

	var rise: float = RNGManager.randf_range(RNGManager.Bucket.COSMETIC,
			_NUMBER_RISE_PIXELS.x, _NUMBER_RISE_PIXELS.y)
	var drift: Tween = label.create_tween()
	drift.tween_method(func(offset: float) -> void:
		label.position.y = roundf(start.y - label.size.y / 2.0 - offset),
		0.0, rise, _NUMBER_LIFETIME_SECONDS)
	drift.parallel().tween_property(label, "modulate:a", 1.0, _NUMBER_LIFETIME_SECONDS * 0.25)
	drift.parallel().tween_property(label, "modulate:a", 0.0, _NUMBER_LIFETIME_SECONDS * 0.4) \
		.set_delay(_NUMBER_LIFETIME_SECONDS * 0.6)
	drift.finished.connect(label.queue_free)
