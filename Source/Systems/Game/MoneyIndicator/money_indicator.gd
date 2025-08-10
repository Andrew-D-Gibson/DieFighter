class_name MoneyIndicator
extends Node2D

@export var money_label: RichTextLabel

func _ready() -> void:
	Globals.money_indicator = self
	Events.set_money.connect(func(value: int):
			money_label.text = str(value)
	)
