extends Node2D

@export var choice_number: int

@export var sprite: Sprite2D
@export var text: RichTextLabel
@export var can_accept_dice: CanAcceptDice

signal choice_selected()


func _check_dice_drop(die: Dice) -> void:
	if die.value == choice_number:
		choice_selected.emit()
