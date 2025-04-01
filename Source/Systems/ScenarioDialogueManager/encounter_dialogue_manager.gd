extends Node2D

@export var main_text: RichTextLabel
@export var choice_scene: PackedScene


func _ready() -> void:
	visible = false
	Events.show_choice_dialogue.connect(_show_choices)


func _dice_dropped_on_choice(choice_number: int) -> void:
	visible = false
	print('Choice: ' + str(choice_number))
	Events.choice_made.emit(choice_number)
	

func _show_choices(text:String, choices: Array[ChoiceResource]) -> void:
	assert(len(choices) == 6)
	visible = true
	main_text.text = text
	
	var options_offset: Vector2 = Vector2(88, -30)
	for i in range(6):
		var choice = choice_scene.instantiate()
		choice.choice_resource = choices[i]
		choice.choice_number = i + 1
		choice.choice_selected.connect(func(): _dice_dropped_on_choice(i+1))
		add_child(choice)
		choice.position = options_offset + Vector2(0, 12 * i)
