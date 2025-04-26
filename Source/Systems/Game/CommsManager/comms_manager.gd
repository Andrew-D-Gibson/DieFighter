class_name CommsManager
extends Node2D

@export var speaker_sprite: Sprite2D
@export var main_text: RichTextLabel
@export var choice_scene: PackedScene

func _ready() -> void:
	Events.targeting_computer_retargeted.connect(update_speaker)

	
func update_speaker() -> void:
	if Globals.targeting_computer:
		if Globals.targeting_computer.targeted_enemy:
			main_text.text = Globals.targeting_computer.targeted_enemy.get_dialogue()
			speaker_sprite.texture = Globals.targeting_computer.targeted_enemy.enemy_resource.targeting_computer_image
		else:
			main_text.text = ''
			speaker_sprite.texture = null
			

func _dice_dropped_on_choice(choice_number: int) -> void:
	visible = false
	Events.choice_made.emit(choice_number)
	

func _show_choices(text:String, choices: Array[ChoiceResource]) -> void:
	assert(len(choices) == 6)
	visible = true
	main_text.text = text
	
	var options_offset: Vector2 = Vector2(-39, 17)
	for i in range(6):
		var choice = choice_scene.instantiate()
		choice.choice_resource = choices[i]
		choice.choice_number = i + 1
		choice.choice_selected.connect(func(): _dice_dropped_on_choice(i+1))
		add_child(choice)
		
		choice.position = options_offset
		choice.position += floor(i / 2) * Vector2(39, 0)
		if i % 2 == 1:
			choice.position += Vector2(0, 12)
