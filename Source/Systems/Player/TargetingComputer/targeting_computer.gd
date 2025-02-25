class_name TargetingComputer
extends Node2D

@export var targeting_indicator_offset: Vector2 = Vector2(20, 18)
var targeted_enemy_index: int
var targeted_enemy: Enemy

func _ready() -> void:
	targeted_enemy_index = 0
	check_target_is_valid()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed('target_left'):
		targeted_enemy_index -= 1
		check_target_is_valid()

		
	if event.is_action_pressed('target_right'):
		targeted_enemy_index += 1
		check_target_is_valid()
		

func _on_left_button_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	# Check for the left mouse pressed event
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		targeted_enemy_index -= 1
		check_target_is_valid()


func _on_right_button_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	# Check for the left mouse pressed event
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		targeted_enemy_index += 1
		check_target_is_valid()


func check_target_is_valid() -> void:
	if not Globals.enemy_manager:
		_update_ui()
		return
		
	var enemies = Globals.enemy_manager.get_alive_enemies()
	
	# Check that there even are enemies to target
	if len(enemies) == 0:
		targeted_enemy = null
		targeted_enemy_index = -1
	
	# Check if we need to wrap around to the last enemy
	elif targeted_enemy_index <= -1:
		targeted_enemy_index = len(enemies) - 1
		targeted_enemy = enemies[targeted_enemy_index]
		
	# Check if we need to wrap around to the first enemy
	elif targeted_enemy_index >= len(enemies):
		targeted_enemy_index = 0
		targeted_enemy = enemies[targeted_enemy_index]
		
	# Given that there are enemies and we're within a valid range, target is valid
	else:
		targeted_enemy = enemies[targeted_enemy_index]

	_update_ui()
	
	
func _update_ui() -> void:
	if !targeted_enemy:
		$TargetingIndicator.visible = false
		$TargetImage.texture = null
		$Screen.play('static')
		
	else:
		_move_indicator()
		
		$Screen.z_index += 1
		$Screen.play('static')
		await $Screen.animation_looped
		$Screen.z_index -= 1
		$Screen.play('default')
		
		_set_target_image_and_intents()


func _set_target_image_and_intents() -> void:
	if targeted_enemy.enemy_resource.targeting_computer_image:
			$TargetImage.texture = targeted_enemy.enemy_resource.targeting_computer_image

	if targeted_enemy.turn_actions:
		for i in range(6):
			$Intents.get_child(i).texture = targeted_enemy.turn_actions[i].indicator_texture
			$Intents.get_child(i).get_child(0).text = targeted_enemy.turn_actions[i].intent_amount
			$Intents.get_child(i).get_child(1).clicked.connect(targeted_enemy.turn_actions[i].show_info)
	else:
		for i in range(6):
			$Intents.get_child(i).texture = null
			$Intents.get_child(i).get_child(0).text = ''
			if $Intents.get_child(i).get_child(1).clicked.is_connected(targeted_enemy.turn_actions[i].show_info):
				$Intents.get_child(i).get_child(1).clicked.disconnect(targeted_enemy.turn_actions[i].show_info)


func _move_indicator() -> void:
	$TargetingIndicator.visible = true
		
	var tween_time = 0.3
	var tween = get_tree().create_tween()
	tween.tween_property($TargetingIndicator, 'global_position', targeted_enemy.global_position + targeting_indicator_offset, tween_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

	tween.tween_callback(_indicator_bob)
	
	
func _indicator_bob() -> void:
	var bob_time = 1.5
	var bob_tween = get_tree().create_tween()
	bob_tween.tween_property($TargetingIndicator, 'global_position', targeted_enemy.global_position + targeting_indicator_offset + Vector2(4, 4), bob_time/2.0).from(targeted_enemy.global_position + targeting_indicator_offset).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob_tween.tween_property($TargetingIndicator, 'global_position', targeted_enemy.global_position + targeting_indicator_offset, bob_time/2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob_tween.set_loops()
