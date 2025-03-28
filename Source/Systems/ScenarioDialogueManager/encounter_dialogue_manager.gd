extends Node2D

@export var main_text: RichTextLabel


func _ready() -> void:
	pass


func _dice_dropped_on_choice(choice_number: int) -> void:
	print('Choice: ' + str(choice_number))
	
