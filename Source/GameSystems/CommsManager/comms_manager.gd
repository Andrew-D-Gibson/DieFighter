class_name CommsManager
extends Node2D

@export var speaker_sprite: Sprite2D
@export var main_text: RichTextLabel
@export var choice_scene: PackedScene

func _ready() -> void:
	_hide()
	Events.show_comms.connect(_show)
	Events.show_map.connect(_hide)
	Events.show_tile_grid.connect(_hide)
	
	Events.targeting_computer_retargeted.connect(_update_speaker)
	
	
func on_tab_clicked() -> void:
	Events.show_comms.emit()
	
	
func _show() -> void:
	var children = get_children()
	for i in range(1, len(children)):
		children[i].visible = true
		
	_update_speaker()
	

func _hide() -> void:
	var children = get_children()
	for i in range(1, len(children)):
		children[i].visible = false
	
	
func _update_speaker() -> void:
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
