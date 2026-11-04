class_name StatusBadge
extends Node2D
## One status on a ship: its icon and stack count. Click it for the rules.

const _PULSE_SCALE: float = 1.5
const _PULSE_SECONDS: float = 0.25

## A status acting on the player flashes its badge this many times, each a
## swell to _ALERT_SCALE and back, so the eye finds which badge it was.
const ALERT_FLASHES: int = 2
const _ALERT_SCALE: float = 2.0
const _ALERT_FLASH_SECONDS: float = 0.22
## How far past white the flash brightens the badge.
const _ALERT_BRIGHTNESS: float = 2.2
## Over the neighbouring badges while it swells, so it doesn't vanish under them.
const _ALERT_Z_INDEX: int = 5

var _status: StatusModifier
var _pulse_tween: Tween

@onready var _icon: Sprite2D = %Icon
@onready var _count: Label = %Count
@onready var _clickable: Clickable = %Clickable


## Call before adding the badge to the tree.
func setup(status: StatusModifier) -> void:
	_status = status


func _ready() -> void:
	_icon.texture = _status.icon
	_count.add_theme_color_override("font_color", _status.color)
	_clickable.clicked.connect(_show_info)
	# Arriving is the moment the player most needs to notice it.
	set_stacks(_status.stacks, true)


func set_stacks(stacks: int, pulse: bool) -> void:
	if not is_node_ready():
		return
	_count.text = str(stacks)
	if pulse:
		_pulse()


## Seconds the alert flashes take at the current Animation Speed.
static func alert_seconds() -> float:
	return ALERT_FLASHES * _ALERT_FLASH_SECONDS / Globals.animation_speed


## Flashes the badge and swells its icon, ALERT_FLASHES times. Fire and
## forget: callers wait out alert_seconds() on a timer rather than on this
## tween, which dies with the badge if the status clears meanwhile.
func play_alert() -> void:
	if not is_node_ready():
		return
	if _pulse_tween:
		_pulse_tween.kill()
	var half: float = _ALERT_FLASH_SECONDS * 0.5 / Globals.animation_speed
	var lit: float = lerpf(1.0, _ALERT_BRIGHTNESS, Juice.soften_flash(1.0))
	var bright: Color = Color(lit, lit, lit)
	z_index = _ALERT_Z_INDEX
	_pulse_tween = create_tween()
	for _flash: int in range(ALERT_FLASHES):
		_pulse_tween.tween_property(_icon, "scale", Vector2.ONE * _ALERT_SCALE, half) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_pulse_tween.parallel().tween_property(self, "modulate", bright, half)
		_pulse_tween.tween_property(_icon, "scale", Vector2.ONE, half) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_pulse_tween.parallel().tween_property(self, "modulate", Color.WHITE, half)
	_pulse_tween.tween_property(self, "z_index", 0, 0.0)


func _pulse() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
	# An alert cut short by this pulse mustn't leave the badge lit or raised.
	modulate = Color.WHITE
	z_index = 0
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(_icon, "scale", Vector2.ONE, _PULSE_SECONDS)\
		.from(Vector2.ONE * _PULSE_SCALE)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _show_info() -> void:
	var info: InfoResource = InfoResource.new()
	info.title_label_text = "[color=#%s]%s[/color]" % [_status.color.to_html(false), _status.display_name()]
	info.top_label_text = tr_n(&"STATUS_BADGE_STACKS", &"STATUS_BADGE_STACKS_PLURAL", _status.stacks)\
		.format({"n": _status.stacks})
	info.texture = _status.info_icon if _status.info_icon else _status.icon
	info.bottom_label_text = Keywords.definition(_status.rule_term())
	Events.show_info.emit(info)
