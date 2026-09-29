## DamageNumber
## A floating number that pops off a ship when it takes damage.
##
## Spawned by DamageEvent rather than authored per tile, so every hit in the
## game shows one, and the number is the damage that actually landed after
## modifiers — not a guess made earlier in the chain.
class_name DamageNumber
extends Node2D

const _FONT: Font = preload("res://Assets/Fonts/m5x7/m5x7.ttf")

## m5x7 is drawn at 16 so one font pixel is one world pixel; larger hits scale
## the whole node by whole numbers to stay crisp.
const _FONT_SIZE: int = 16

## Hits at or above this read as big and get the doubled number.
const _BIG_HIT: int = 6

const _RISE_PIXELS: float = 10.0
const _LIFETIME_SECONDS: float = 0.8

## Repeated hits on the same ship scatter sideways instead of stacking into
## one unreadable pile.
const _SCATTER_PIXELS: float = 6.0

var _label: Label


## Spawns a number for `amount` above `target`. Parented beside the target
## rather than under it, so a killing blow's number outlives the ship.
static func spawn(target: Node2D, amount: int, color: Color) -> void:
	if amount <= 0 or not is_instance_valid(target) or target.get_parent() == null:
		return

	var number: DamageNumber = DamageNumber.new()
	number._build(amount, color)
	target.get_parent().add_child(number)
	number.global_position = target.global_position + Vector2(
		RNGManager.randf_range(RNGManager.Bucket.COSMETIC, -_SCATTER_PIXELS, _SCATTER_PIXELS),
		-10.0
	)
	number._animate(amount >= _BIG_HIT)


func _build(amount: int, color: Color) -> void:
	# Above ships, particles and the cockpit frame.
	z_index = 100

	_label = Label.new()
	_label.text = str(amount)
	_label.add_theme_font_override("font", _FONT)
	_label.add_theme_font_size_override("font_size", _FONT_SIZE)
	_label.add_theme_color_override("font_color", color)
	_label.add_theme_color_override("font_outline_color", Globals.dark_gray)
	_label.add_theme_constant_override("outline_size", 4)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_label)
	# Centre the label on this node so scaling pops from the middle.
	_label.reset_size()
	_label.position = -_label.size / 2.0


## Pops in past full size, drifts up, and fades out on the way.
func _animate(big: bool) -> void:
	var rest_scale: Vector2 = Vector2.ONE * (2.0 if big else 1.0)
	scale = rest_scale * 0.4

	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", rest_scale * 1.4, 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", rest_scale, 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "position:y", position.y - _RISE_PIXELS, _LIFETIME_SECONDS) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "modulate:a", 0.0, _LIFETIME_SECONDS * 0.4) \
		.set_delay(_LIFETIME_SECONDS * 0.6)
	tween.finished.connect(queue_free)
