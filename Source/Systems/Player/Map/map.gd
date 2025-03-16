class_name Map
extends Node2D

@export var map_viewport: SubViewport
@export var map_camera: Camera2D
@export var encounter_spacing: int = 14
@export var encounter_list: Array[EncounterResource]
var encounter_sprites: Array[Sprite2D]
@export var current_encounter_index: int

@export_category('Map Textures')
@export var current_encounter_icon: Texture2D
@export var timeline_icon: Texture2D
@export var connector_sprite: Texture2D

@export_category('Components')
@export var LeftDiceReceptacle: DiceReceptacle
@export var RightDiceReceptacle: DiceReceptacle
@export var map_button_label: RichTextLabel
@export var map_button: Clickable
var tween: Tween
@onready var desired_encounter: int = current_encounter_index
@export var empty_encounter: EncounterResource


func _ready() -> void:
	LeftDiceReceptacle.dice_queue.die_added.connect(_update_desired_encounter)
	LeftDiceReceptacle.dice_queue.die_removed.connect(_update_desired_encounter)
	RightDiceReceptacle.dice_queue.die_added.connect(_update_desired_encounter)
	RightDiceReceptacle.dice_queue.die_removed.connect(_update_desired_encounter)
	
	map_button.clicked.connect(_jump)
	Events.start_encounter.connect(_create_encounter_sprites)

	
func _create_encounter_sprites() -> void:
	# Delete any old map
	for child in map_viewport.get_children():
		if child is Sprite2D:
			child.queue_free()
	encounter_sprites = []
		
	for i in range(len(encounter_list)):
		# Create a timeline bar to the next location
		if i < len(encounter_list) - 1:
			var timeline_bar_sprite = Sprite2D.new()
			timeline_bar_sprite.texture = timeline_icon
			timeline_bar_sprite.position = Vector2((i * encounter_spacing) + 7, 0)
			map_viewport.add_child(timeline_bar_sprite)
			
			
		# Add the sprite for this encounter
		var encounter_sprite: Sprite2D = Sprite2D.new()
		encounter_sprite.position = Vector2(i * encounter_spacing, 0)
		
		# Mark the encounter as either our present location or 
		# a possible destination with a map icon
		if current_encounter_index == i:
			encounter_sprite.texture = current_encounter_icon
			map_camera.position = encounter_sprite.position
		else:
			encounter_sprite.texture = encounter_list[i].map_icon
			
			# Offset the icon up or down
			encounter_sprite.position += Vector2(0, -13 if i%2==0 else 13)
		
			# Add the connector sprite
			# Add the timeline connector sprite
			var timeline_connector_sprite: Sprite2D = Sprite2D.new()
			timeline_connector_sprite.position = Vector2(i * encounter_spacing, -4 if i%2==0 else 4)
			timeline_connector_sprite.texture = connector_sprite
			map_viewport.add_child(timeline_connector_sprite)
			
		map_viewport.add_child(encounter_sprite)
		encounter_sprites.append(encounter_sprite)
		
	_update_desired_encounter()


func _on_visibility_changed() -> void:	
	if not visible:
		return
	
	if Globals.state_manager.state == GameStateManager.GameState.IN_COMBAT:
		$Background/LeftArrow.frame = 1
		$Background/RightArrow.frame = 1

	elif Globals.state_manager.state == GameStateManager.GameState.OUT_OF_COMBAT:
		$Background/LeftArrow.frame = 0
		$Background/RightArrow.frame = 0
		
	_update_desired_encounter()
		

func _update_desired_encounter() -> void:
	# Sum the dice values in the left selector
	var left_offset = 0
	for die in LeftDiceReceptacle.dice_queue.queue:
		left_offset += die.value
		
	# Sum the dice values in the right selector
	var right_offset = 0
	for die in RightDiceReceptacle.dice_queue.queue:
		right_offset += die.value
	
	# Sum the values to find the new desired encounter's index
	desired_encounter = current_encounter_index + right_offset - left_offset
	
	# Clamp the desired location to within the map
	desired_encounter = clampi(desired_encounter, 0, len(encounter_list) - 1)
	
	# Tween the camera to center on the desired encounter
	var camera_tween_time = 0.5
	var camera_tween = get_tree().create_tween()
	camera_tween.tween_property(map_camera, 'position', Vector2(desired_encounter * encounter_spacing, 0), camera_tween_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Use the map's tween to animate the desired encounter's sprite
	# We use a singular tween to make sure only one tween is running at a time
	var tween_time = 0.75
	if tween:
		tween.kill()
		# Make sure the other sprites are scaled properly,
		# in case we killed the tween midway
		for sprite in encounter_sprites:
			sprite.scale = Vector2(1,1)
	
	if desired_encounter != current_encounter_index:
		tween = get_tree().create_tween()
		tween.tween_property(encounter_sprites[desired_encounter], 'scale', Vector2(1.5,1.5), tween_time).from(Vector2(1,1))
		tween.tween_property(encounter_sprites[desired_encounter], 'scale', Vector2(1,1), tween_time)
		tween.set_loops()
	
	_update_map_button()


func _update_map_button() -> void:
	if desired_encounter != current_encounter_index:
		map_button_label.text = '[color=#eed35d][wave amp=15.0 freq=5.0 connected=1]JUMP![/wave][/color]'
	else:
		map_button_label.text = '[color=#f29c5d]CHOOSE:[/color]'


func _jump() -> void:
	if desired_encounter != current_encounter_index:
		# Set the current index encounter to empty
		encounter_list[current_encounter_index] = empty_encounter

		# Move to the new encounter
		current_encounter_index = desired_encounter
		Events.load_encounter.emit(encounter_list[desired_encounter])
