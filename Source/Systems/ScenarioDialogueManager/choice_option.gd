class_name ChoiceOption
extends Node2D

var choice_resource: ChoiceResource
var choice_number: int
@export var text_label: RichTextLabel
@export var sprite: Sprite2D
@export var can_accept_dice: CanAcceptDice

@export var red_choice_sprites: Array[Texture2D]
@export var yellow_choice_sprites: Array[Texture2D]
@export var green_choice_sprites: Array[Texture2D]
@export var blue_choice_sprites: Array[Texture2D]
@export var purple_choice_sprites: Array[Texture2D]

signal choice_selected()

enum ChoiceColor {
	RED,
	YELLOW,
	GREEN,
	BLUE,
	PURPLE
}


func _ready() -> void:
	assert(choice_resource != null)
	assert(choice_number != null)
	
	text_label.text = choice_resource.text
	
	match choice_resource.color:
		ChoiceColor.RED:
			sprite.texture = red_choice_sprites[choice_number-1]
		
		ChoiceColor.YELLOW:
			sprite.texture = yellow_choice_sprites[choice_number-1]
			
		ChoiceColor.GREEN:
			sprite.texture = green_choice_sprites[choice_number-1]
		
		ChoiceColor.BLUE:
			sprite.texture = blue_choice_sprites[choice_number-1]
			
		ChoiceColor.PURPLE:
			sprite.texture = purple_choice_sprites[choice_number-1]
	

func _check_dice_drop(die: Dice) -> void:
	if die.value == choice_number:
		choice_selected.emit()
