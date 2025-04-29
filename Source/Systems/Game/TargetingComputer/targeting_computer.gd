class_name TargetingComputer
extends Node2D

@export var targeting_indicator: Sprite2D
@export var unknown_intent_indicator: Texture2D
@export var targeting_indicator_offset: Vector2 = Vector2(20, 18)
var targeted_enemy_index: int
var targeted_enemy: Enemy
var indicator_bob_tween: Tween


func _ready() -> void:
	Globals.targeting_computer = self
	
	Events.enemy_left.connect(func(_ship: Enemy, _faction: ScenarioManager.Faction) -> void:
		await get_tree().process_frame
		check_target_is_valid()
	)
	Events.start_combat.connect(check_target_is_valid)
	Events.start_scenario.connect(_initial_target)
	Events.enemy_turn_over.connect(check_target_is_valid)	 # Update the computer with the new enemy intents

	

func _initial_target() -> void:
	targeted_enemy_index = 0
	check_target_is_valid()
	

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed('target_left'):
		targeted_enemy_index -= 1
		check_target_is_valid()

		
	if event.is_action_pressed('target_right'):
		targeted_enemy_index += 1
		check_target_is_valid()
		

func _on_left_button_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	# Check for the left mouse pressed event
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		targeted_enemy_index -= 1
		check_target_is_valid()


func _on_right_button_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
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
	Events.targeting_computer_retargeted.emit()
	
	
func _update_ui() -> void:
	if !targeted_enemy:
		targeting_indicator.visible = false
		
		$TargetImage.texture = null
		for i in range(6):
			$Intents.get_child(i).texture = null
			$Intents.get_child(i).get_child(0).text = ''
		
		$TargetImageFill.z_index = 1
		
	else:
		_move_indicator()
		
		$TargetImage.texture = targeted_enemy.enemy_resource.targeting_computer_image
		for i in range(len(targeted_enemy.turn_actions)): # Should be a loop to 0 or 6
			if Globals.state_manager.state == GameStateManager.GameState.IN_COMBAT:
				$Intents.get_child(i).texture = targeted_enemy.turn_actions[i].indicator_texture
				$Intents.get_child(i).get_child(0).text = targeted_enemy.turn_actions[i].intent_amount
				
				# Change over the info on clicking this particular action indicator 
				Utils.disconnect_all_callables($Intents.get_child(i).get_child(1).clicked)
				$Intents.get_child(i).get_child(1).clicked.connect(targeted_enemy.turn_actions[i].show_info)
			else:
				$Intents.get_child(i).texture = unknown_intent_indicator
				$Intents.get_child(i).get_child(0).text = ''
				Utils.disconnect_all_callables($Intents.get_child(i).get_child(1).clicked)
				
				
		$TargetImageFill.z_index = 1
		$TargetImageFill.frame = 0
		await $TargetImageFill.animation_looped
		$TargetImageFill.z_index = -1


func _move_indicator() -> void:
	targeting_indicator.visible = true
		
	var tween_time = 0.3
	var tween = get_tree().create_tween()
	tween.tween_property(targeting_indicator, 'global_position', targeted_enemy.global_position + targeting_indicator_offset, tween_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

	tween.tween_callback(_indicator_bob)
	
	
func _indicator_bob() -> void:
	if not targeted_enemy:
		return
		
	var bob_time = 1.5
	
	if indicator_bob_tween:
		indicator_bob_tween.kill()
		
	indicator_bob_tween = get_tree().create_tween()
	indicator_bob_tween.tween_property(targeting_indicator, 'global_position', targeted_enemy.global_position + targeting_indicator_offset + Vector2(4, 4), bob_time/2.0).from(targeted_enemy.global_position + targeting_indicator_offset).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	indicator_bob_tween.tween_property(targeting_indicator, 'global_position', targeted_enemy.global_position + targeting_indicator_offset, bob_time/2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	indicator_bob_tween.set_loops()


func _show_ship_info() -> void:
	print('ship info requested')
