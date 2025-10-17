class_name Map
extends Node2D

@export_category('Game Data')
var scenario_list: Array[ScenarioResource]
var current_scenario_index: int

var left_fate_index: int
var right_fate_index: int
var left_scenarios_in_danger: int 
var right_scenarios_in_danger: int

@export_category('Map Textures')
@export var current_scenario_icon: Texture2D
@export var timeline_icon: Texture2D
@export var connector_sprite: Texture2D
@export var fate: PackedScene
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
	
	_on_map_view_slider_value_changed(0)
	_update_ui()
	
	
func _load_game_save(game_save: GameSaveResource) -> void:
	scenario_list = game_save.sector_scenarios
	
	current_scenario_index = game_save.current_scenario_index
	
	left_fate_index = -1
	right_fate_index = len(scenario_list)
	left_scenarios_in_danger = randi_range(1,3)
	right_scenarios_in_danger = randi_range(1,3)
	
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
		
	# Add the fate sprites
	var left_fate: Node2D = fate.instantiate()
	var right_fate: Node2D = fate.instantiate()
	right_fate.scale = Vector2(-1, 1)
	left_fate.position = Vector2((left_fate_index-1) * sprite_spacing, 0)
	right_fate.position = Vector2((right_fate_index+1) * sprite_spacing, 0)
	left_fate.z_index = -1
	right_fate.z_index = -1
	map_viewport.add_child(left_fate)
	map_viewport.add_child(right_fate)
	
	# Show and move the danger area as needed
	var left_danger: Sprite2D = danger_area.instantiate()
	var right_danger: Sprite2D = danger_area.instantiate()
	right_danger.flip_h = true
	left_danger.position = Vector2(-82 + (sprite_spacing * (left_fate_index + left_scenarios_in_danger)), 0)
	right_danger.position = Vector2(82 + (sprite_spacing * (right_fate_index - right_scenarios_in_danger)), 0)
	left_danger.z_index = -2
	right_danger.z_index = -2
	map_viewport.add_child(left_danger)
	map_viewport.add_child(right_danger)
	
		
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
			_look_at_scenario_index(i)
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
		
	# Reset the map view slider to match the camera position
	_update_slider_from_camera_position()


func is_valid_destination(desired_scenario_index: int) -> bool:
	return len(scenario_list) > 0 and \
	desired_scenario_index >= 0 and \
	desired_scenario_index < len(scenario_list) and \
	desired_scenario_index != current_scenario_index
		
		
func _tween_map_to_index(index: int) -> void:
	# Calculate the desired camera position with bounds
	var max_position: int = max(
			(len(scenario_list)-5) * sprite_spacing,
			0
		)
	var min_position: int = 2 * sprite_spacing
	var desired_camera_position: int = clamp(index * sprite_spacing, min_position, max_position)
	
	# Tween the camera to center on the desired encounter
	var camera_tween_time = 0.5
	var camera_movement_tween: Tween = get_tree().create_tween()
	camera_movement_tween.tween_property(map_camera, 'position', \
		Vector2(desired_camera_position, 0), camera_tween_time)\
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
	
	# Update slider to match final camera position
	_update_slider_from_camera_position()


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

	# OLD: Destroy scenarios in danger	
	#scenario_list = scenario_list.slice(scenarios_in_danger)
	#current_scenario_index -= scenarios_in_danger
	
	# Have "Fate" empty the scenarios in danger
	for idx: int in range(left_fate_index, left_fate_index + left_scenarios_in_danger):
		scenario_list[idx] = empty_scenario
	for idx: int in range(right_fate_index, right_fate_index + right_scenarios_in_danger):
		scenario_list[idx] = empty_scenario
	
	# Set up which scenarios are in danger next
	left_scenarios_in_danger = randi_range(1,3)
	right_scenarios_in_danger = randi_range(1,3)
	
	Events.start_scenario.emit()
	


func _on_map_view_slider_value_changed(value: float) -> void:
	var max_position: int = max(
			(len(scenario_list)-5) * sprite_spacing,
			0
		)
	var min_position: int = 2 * sprite_spacing
	var desired_camera_position: int = min_position + int(max_position * value)

	map_camera.position = Vector2(desired_camera_position, 0)


func _look_at_scenario_index(idx: int) -> void:
	print('looking at index ', idx)
	var max_position: int = max(
			(len(scenario_list)-5) * sprite_spacing,
			0
		)
	var min_position: int = 2 * sprite_spacing
	var desired_camera_position: int = clamp(idx * sprite_spacing, min_position, max_position)

	map_camera.position = Vector2(desired_camera_position, 0)
	_update_slider_from_camera_position()


func _update_slider_from_camera_position() -> void:
	if len(scenario_list) == 0:
		return
		
	var max_position: int = max(
			(len(scenario_list)-5) * sprite_spacing,
			0
		)
	var min_position: int = 2 * sprite_spacing
	
	# Calculate slider value based on camera position within bounds
	var slider_value: float = 0.0
	if max_position > min_position:
		slider_value = float(map_camera.position.x - min_position) / float(max_position - min_position)
		slider_value = clampf(slider_value, 0.0, 1.0)
	
	%MapViewSlider.value = slider_value
