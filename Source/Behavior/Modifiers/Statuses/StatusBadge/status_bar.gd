class_name StatusBar
extends Node2D
## A row of StatusBadges beside a ship's health ring.

## Badge width plus room for a two-digit stack count.
const _SPACING: int = 18

## Badges per row before the next row starts; 0 for one long row. The
## player's bar wraps, so it stays clear of the systems panel beside it.
@export var per_row: int = 0
## How far each further row sits from the first. Negative stacks upward.
@export var row_step: int = -13


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
			var column: int = index % per_row if per_row > 0 else index
			var row: int = index / per_row if per_row > 0 else 0
			(child as Node2D).position = Vector2(column * _SPACING, row * row_step)
			index += 1
