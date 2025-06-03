class_name CommsManager
extends Node2D

@export var speaker_sprite: Sprite2D
@export var main_text: RichTextLabel
@export var choice_scene: PackedScene

var characters_shown: int = 0


func _ready() -> void:
	Events.targeting_computer_retargeted.connect(update_speaker)

	
func update_speaker() -> void:
	if Globals.targeting_computer:
		if Globals.targeting_computer.targeted_enemy:
			show_text(Globals.targeting_computer.targeted_enemy.get_dialogue())
			speaker_sprite.texture = Globals.targeting_computer.targeted_enemy.enemy_resource.targeting_computer_image
		else:
			main_text.text = ''
			speaker_sprite.texture = null
			
			
func show_text(dialogue: String) -> void:
	if dialogue.begins_with('[color=gray]'):
		main_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		main_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		
		main_text.text = dialogue
		return
	else:
		main_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		main_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	
	characters_shown = 0
	while characters_shown < len(dialogue):
		characters_shown += 1
		main_text.text = dialogue.substr(0, characters_shown)
		
		# Just skip ahead if we only added a space (bit of polish here)
		if dialogue.substr(characters_shown-1, 1) == ' ':
			continue
			
		await get_tree().create_timer(0.02).timeout
			

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
