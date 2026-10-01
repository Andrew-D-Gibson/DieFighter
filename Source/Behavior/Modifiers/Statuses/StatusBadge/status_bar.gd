class_name StatusBar
extends Node2D
## A row of StatusBadges beside a ship's health ring.

## Badge width plus room for a two-digit stack count.
const _SPACING: int = 18


func _ready() -> void:
	# Badges free themselves when their status ends; close the gap they leave.
	child_order_changed.connect(_layout)


func add_badge(badge: StatusBadge) -> void:
	add_child(badge)
	_layout()


func _layout() -> void:
	var index: int = 0
	for child: Node in get_children():
		if child is StatusBadge and not child.is_queued_for_deletion():
			(child as Node2D).position = Vector2(index * _SPACING, 0)
			index += 1
