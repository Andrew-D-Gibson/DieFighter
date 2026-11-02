class_name HazardWarning
extends CanvasLayer
## The hazard's name slammed across the top of the screen while it builds to
## its strike, with a warning beat that quickens toward the hit, and under it
## the effect in plain words (its banner: "SHIELDS DOWN!").
##
## The name alone said which hazard, not what it was about to do, so the
## board changing a moment later still had to be puzzled out. The effect line
## stays up a little after the strike, while the player looks for what
## changed; the name bursts away at the hit.
##
## Spawned by HazardEvent and gone once the hazard has struck. It sits over
## the game but under Juice.screen_flash, so the strike's flash washes it out.

const _FONT: Font = preload("res://Assets/Fonts/m5x7/m5x7_ui.tres")
const _BEAT_SFX: SoundEffectResource = preload(
	"res://Source/Resources/SoundEffectResources/SoundEffects/die_dread_thunk.tres"
)
## One world pixel per font pixel; the layer is scaled to the game's grid.
const _FONT_SIZE: int = 16
const _PIXEL_SCALE: float = 6.0
## Where the title sits on the 320x180 grid: in the open band between the
## ships and the top of the cockpit.
const _TITLE_Y: float = 60.0
## Drawn at twice the font's size, in whole pixels.
const _REST_SCALE: float = 2.0
## Warning beats across the build-up, closer together toward the strike.
const _BEATS: Array[float] = [0.0, 0.45, 0.75, 0.92]
## Where the effect line sits: just under the title.
const _EFFECT_Y: float = 75.0
## How long the effect line outstays the strike, so it can be read against
## the board it just changed.
const _EFFECT_LINGER_SECONDS: float = 1.4
const _OUTLINE_COLOR: Color = Color(0.0156863, 0.00784314, 0.0901961, 1)

var _label: Label
## The effect in words. Null for a hazard authored without a banner.
var _effect_label: Label
var _hazard: BackgroundHazardResource
var _seconds: float = 1.0


## Shows [param hazard]'s warning for [param seconds], anchored to
## [param context]'s tree.
static func show_for(context: Node, hazard: BackgroundHazardResource, seconds: float) -> void:
	if not is_instance_valid(context) or not context.is_inside_tree():
		return
	var warning: HazardWarning = HazardWarning.new()
	warning._hazard = hazard
	warning._seconds = seconds
	context.get_tree().root.add_child(warning)


func _ready() -> void:
	layer = 85
	scale = Vector2.ONE * _PIXEL_SCALE
	Events.jump.connect(queue_free)
	Events.hazard_struck.connect(func(_hazard: BackgroundHazardResource) -> void: _strike())

	_label = _make_label("!! %s !!" % _hazard.display_name().to_upper(), _hazard.color, _TITLE_Y)
	_label.scale = Vector2(2.4, 0.2) * _REST_SCALE
	_label.modulate.a = 0.0

	# Slams in flat and wide, then settles to full size.
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_label, "scale", Vector2.ONE * _REST_SCALE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_label, "modulate:a", 1.0, 0.1)

	var banner: String = _hazard.display_banner()
	if not banner.is_empty():
		# A beat after the title, so the eye takes the name, then the effect.
		_effect_label = _make_label(banner, Globals.white, _EFFECT_Y)
		_effect_label.modulate.a = 0.0
		_effect_label.scale = Vector2(1.0, 0.2)
		tween.tween_property(_effect_label, "modulate:a", 1.0, 0.1).set_delay(0.15)
		tween.tween_property(_effect_label, "scale", Vector2.ONE, 0.16).set_delay(0.15) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	for at: float in _BEATS:
		get_tree().create_timer(at * _seconds, false).timeout.connect(_beat)


## One warning beat: a thud, and the title kicks and flickers.
func _beat() -> void:
	if not is_instance_valid(_label):
		return
	Events.play_sound.emit(_BEAT_SFX)
	_label.scale = Vector2.ONE * _REST_SCALE * 1.25
	var tween: Tween = create_tween()
	tween.tween_property(_label, "scale", Vector2.ONE * _REST_SCALE, 0.16) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var flare: float = 1.0 + Juice.soften_flash(1.0)
	_label.modulate = Color(flare, flare, flare, 1.0)
	tween.parallel().tween_property(_label, "modulate", Color.WHITE, 0.16)


## The hit: the title bursts outward and fades, and the effect line kicks
## and holds a moment longer before it goes too.
func _strike() -> void:
	if not is_instance_valid(_label):
		queue_free()
		return
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_label, "scale", Vector2.ONE * _REST_SCALE * 1.6, 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_label, "modulate:a", 0.0, 0.5).set_delay(0.15)
	if _effect_label:
		_effect_label.scale = Vector2.ONE * 1.3
		tween.tween_property(_effect_label, "scale", Vector2.ONE, 0.2) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(_effect_label, "modulate:a", 0.0, 0.3) \
			.set_delay(_EFFECT_LINGER_SECONDS)
	tween.chain().tween_callback(queue_free)


## A centred, outlined line of the warning, its middle at [param y].
func _make_label(text: String, color: Color, y: float) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_override("font", _FONT)
	label.add_theme_font_size_override("font_size", _FONT_SIZE)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", _OUTLINE_COLOR)
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	label.reset_size()
	label.pivot_offset = label.size / 2.0
	label.position = Vector2(Globals.SCREEN_SIZE.x / 2.0, y) - label.size / 2.0
	return label
