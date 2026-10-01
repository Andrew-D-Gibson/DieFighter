class_name StatusBadge
extends Node2D
## One status on a ship: its icon and stack count. Click it for the rules.

const _PULSE_SCALE: float = 1.5
const _PULSE_SECONDS: float = 0.25

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
	_count.add_theme_color_override("font_color", Globals.get(_status.title_color))
	_clickable.clicked.connect(_show_info)
	# Arriving is the moment the player most needs to notice it.
	set_stacks(_status.stacks, true)


func set_stacks(stacks: int, pulse: bool) -> void:
	if not is_node_ready():
		return
	_count.text = str(stacks)
	if pulse:
		_pulse()


func _pulse() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(_icon, "scale", Vector2.ONE, _PULSE_SECONDS)\
		.from(Vector2.ONE * _PULSE_SCALE)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _show_info() -> void:
	var info: InfoResource = InfoResource.new()
	info.title_label_text = "[color=%s]%s[/color]" % [_status.title_color, _status.display_name]
	info.top_label_text = "%d stack%s" % [_status.stacks, "" if _status.stacks == 1 else "s"]
	info.texture = _status.info_icon if _status.info_icon else _status.icon
	info.bottom_label_text = Keywords.definition(_status.display_name)
	Events.show_info.emit(info)
