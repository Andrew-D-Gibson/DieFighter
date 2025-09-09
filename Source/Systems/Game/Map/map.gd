class_name Map
extends Node2D

@export_category('Game Data')
var scenario_list: Array[ScenarioResource]
var current_scenario_index: int
@onready var scenarios_in_danger: int = 1

@export_category('Map Textures')
@export var current_scenario_icon: Texture2D
@export var timeline_icon: Texture2D
@export var connector_sprite: Texture2D
@export var fate_animated_sprite: PackedScene
@export var danger_area: PackedScene

@export_category('Components')
@export var map_viewport: SubViewport
@export var map_camera: Camera2D
@export var left_arrow_tile: Tile
@export var right_arrow_tile: Tile


@export_category('Behavior')
@export var empty_scenario: ScenarioResource
@export var sprite_spacing: int = 14

var scenario_sprites: Array[Sprite2D]

func _ready() -> void:
	Globals.map = self
	
	Events.load_game_save.connect(_load_game_save)
	Events.start_scenario.connect(func() -> void:
		_update_map_sprites()
		_update_ui()
	)
	Events.engine_charge_changed.connect(_update_ui)
	
	_update_ui()
	
	
func _load_game_save(game_save: GameSaveResource) -> void:
	scenario_list = game_save.sector_scenarios
	
	current_scenario_index = game_save.current_scenario_index
	_update_map_sprites()
	
	
func _on_visibility_changed() -> void:
	_update_ui()
	
	
func _update_ui() -> void:
	if not Globals.player:
		return
	
	if Globals.player.engine_charge >= Globals.player.max_engine_charge:
		left_arrow_tile.set_highlight(true)
		left_arrow_tile.set_gray_out(false)
		right_arrow_tile.set_highlight(true)
		right_arrow_tile.set_gray_out(false)
	else:
		left_arrow_tile.set_highlight(false)
		left_arrow_tile.set_gray_out(true)
		right_arrow_tile.set_highlight(false)
		right_arrow_tile.set_gray_out(true)


func _update_map_sprites() -> void:
	# Delete any old map
	for child in map_viewport.get_children():
		if child is Sprite2D:
			child.queue_free()
	scenario_sprites = []
	
	# Shouldn't ever return here, but still
	if len(scenario_list) == 0:
		return
		
	# Add the fate sprite
	var fate: AnimatedSprite2D = fate_animated_sprite.instantiate()
	fate.position = Vector2(-45, 0)
	map_viewport.add_child(fate)
	
	# Show and move the danger area as needed
	var danger: Sprite2D = danger_area.instantiate()
	danger.position = Vector2(-82 + (sprite_spacing * scenarios_in_danger), 0)
	map_viewport.add_child(danger)
	
		
	for i in range(len(scenario_list)):
		# Create a timeline bar to the next location
		if i < len(scenario_list) - 1:
			var timeline_bar_sprite = Sprite2D.new()
			timeline_bar_sprite.texture = timeline_icon
			timeline_bar_sprite.position = Vector2((i * sprite_spacing) + 7, 4)
			map_viewport.add_child(timeline_bar_sprite)
			
			
		# Add the sprite for this encounter
		var scenario_sprite: Sprite2D = Sprite2D.new()
		scenario_sprite.position = Vector2(i * sprite_spacing, 4)
		
		# Mark the encounter as either our present location or 
		# a possible destination with a map icon
		if current_scenario_index == i:
			scenario_sprite.texture = current_scenario_icon
			map_camera.position = scenario_sprite.position + Vector2(0, -4)
		else:
			scenario_sprite.texture = scenario_list[i].map_icon
			
			# Offset the icon up or down
			scenario_sprite.position += Vector2(0, -13 if i%2==0 else 13)
		
			# Add the connector sprite
			# Add the timeline connector sprite
			var timeline_connector_sprite: Sprite2D = Sprite2D.new()
			timeline_connector_sprite.position = Vector2(i * sprite_spacing, 0 if i%2==0 else 8)
			timeline_connector_sprite.texture = connector_sprite
			map_viewport.add_child(timeline_connector_sprite)
			
		map_viewport.add_child(scenario_sprite)
		scenario_sprites.append(scenario_sprite)
		
	# Reset the map view slider
	var max_position: int = len(scenario_list) * sprite_spacing
	%MapViewSlider.value = map_camera.position.x / max_position


func is_valid_destination(desired_scenario_index: int) -> bool:
	return len(scenario_list) > 0 and \
	desired_scenario_index >= 0 and \
	desired_scenario_index < len(scenario_list) and \
	desired_scenario_index != current_scenario_index
		
		
func _tween_map_to_index(index: int) -> void:
	# Tween the camera to center on the desired encounter
	var camera_tween_time = 0.5
	var camera_movement_tween: Tween = get_tree().create_tween()
	camera_movement_tween.tween_property(map_camera, 'position', \
		Vector2(index * sprite_spacing, 0), camera_tween_time)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)

	# Use the map's tween to animate the desired encounter's sprite
	# We use a singular tween to make sure only one tween is running at a time
	var tween_time = 1
	var scenario_zoom_tween: Tween = get_tree().create_tween()
	scenario_zoom_tween.tween_property(
		scenario_sprites[index], 
		'scale', 
		Vector2(1.5,1.5), 
		tween_time
	).from(Vector2(1,1))
	
	await scenario_zoom_tween.finished


func jump(desired_scenario_index: int) -> void:
	if not is_valid_destination(desired_scenario_index):
		printerr("Attempted to jump to an invalid destination: ", desired_scenario_index)
		return
		
	await _tween_map_to_index(desired_scenario_index)
		
	Events.jump.emit()
	
	# Set the current index scenario to empty
	scenario_list[current_scenario_index] = empty_scenario

	# Move to the new encounter
	current_scenario_index = desired_scenario_index
	Events.load_scenario.emit(
		scenario_list[desired_scenario_index]
	)

	# Destroy the scenarios in danger
	scenario_list = scenario_list.slice(scenarios_in_danger)
	
	current_scenario_index -= scenarios_in_danger
	
	# Set up which scenarios are in danger next
	scenarios_in_danger = min(randi_range(1,3), current_scenario_index + 1)
	
	Events.start_scenario.emit()
	


func _on_map_view_slider_value_changed(value: float) -> void:
	var max_position: int = max(
			(len(scenario_list)-4) * sprite_spacing,
			0
		)
	var desired_camera_position: int = max_position * value

	map_camera.position = Vector2(desired_camera_position, 0)
