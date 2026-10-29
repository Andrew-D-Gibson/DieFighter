class_name DelayBadge
extends StatusBadge
## A DelayedPayload's countdown on a ship's status bar: its icon and the
## turns left. Click it for what it'll do. Rides the StatusBar beside the
## ship's statuses, though it isn't one.

var _delay: DelayedPayload


## Call before adding the badge to the tree, instead of setup().
func setup_delay(delay: DelayedPayload) -> void:
	_delay = delay


func _ready() -> void:
	_icon.texture = _delay.payload.badge_icon if _delay.payload else null
	_count.add_theme_color_override("font_color", _delay.color())
	_clickable.clicked.connect(_show_info)
	set_stacks(_delay.turns_left, true)


func _show_info() -> void:
	var info: InfoResource = InfoResource.new()
	info.title_label_text = "[color=#%s]%s[/color]" % [_delay.color().to_html(false), _delay.title()]
	var turns: int = _delay.turns_left
	info.top_label_text = "Next turn" if turns <= 1 else "In %d turns" % turns
	if _delay.payload:
		info.texture = _delay.payload.badge_info_icon if _delay.payload.badge_info_icon \
			else _delay.payload.badge_icon
	info.bottom_label_text = "[color=yellow]%s[/color] -> %s" % [info.top_label_text, _delay.describe()]
	Events.show_info.emit(info)
