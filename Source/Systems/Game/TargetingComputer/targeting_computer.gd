class_name TargetingComputer
extends Node2D

@export var targeting_indicator: Sprite2D
@export var unknown_intent_indicator: Texture2D
@export var targeting_indicator_offset: Vector2 = Vector2(20, 18)
var targeted_enemy_index: int
var targeted_enemy: Enemy
var indicator_bob_tween: Tween
var intent_scale_tweens: Array[Tween] = []

@onready var die_sprites: Array[AnimatedSprite2D] = [
	%DieSprite1, 
	%DieSprite2, 
	%DieSprite3, 
	%DieSprite4, 
	%DieSprite5, 
	%DieSprite6, 
]

func _ready() -> void:
	Globals.targeting_computer = self
	intent_scale_tweens.resize(6)
	
	Events.enemy_left.connect(func(_ship: Enemy, _faction: ScenarioManager.Faction) -> void:
		await get_tree().process_frame
		check_target_is_valid()
	)
	Events.enemy_used_die.connect(_on_enemy_used_die)
	Events.enemy_flew_in.connect(_initial_target)
	Events.enemy_received_die.connect(_update_ui)
	Events.start_scenario.connect(_update_ui)
	Events.player_turn_start.connect(func() -> void:
		await get_tree().create_timer(0.5).timeout
		_update_ui()
	)
	Events.enemy_turn_over.connect(check_target_is_valid)	 # Update the computer with the new enemy intents

	Events.targeting_computer_startup.connect(_startup)

	%RevealOverlay.material = %RevealOverlay.material.duplicate()
	%RevealOverlay.material.set_shader_parameter("progress", 0.0)

	_initial_target()
	
	

func _initial_target() -> void:
	if !targeted_enemy:
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
		
	var enemies: Array[Enemy] = Globals.enemy_manager.get_alive_enemies()
	
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
	
	
func _on_enemy_used_die(enemy: Enemy, die_value: int) -> void:
	# Only animate for the currently targeted enemy
	if enemy != targeted_enemy:
		return
	
	# Convert die value (1-6) to intents index (0-5)
	var intent_index: int = clamp(die_value - 1, 0, 5)
	var intent_node: Node2D = $Intents.get_child(intent_index)
	
	# If a previous tween exists for this intent, stop it
	if intent_scale_tweens[intent_index]:
		intent_scale_tweens[intent_index].kill()
	
	# Pulse the intent scale up then back down
	var up_scale: Vector2 = Vector2(1.4, 1.4)
	var base_scale: Vector2 = Vector2.ONE
	var tween_time: float = 0.5
	
	var tween: Tween = get_tree().create_tween()
	intent_scale_tweens[intent_index] = tween
	tween.tween_property(intent_node, 'scale', up_scale, tween_time).from(base_scale).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(intent_node, 'scale', base_scale, tween_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	
func target_enemy(enemy: Enemy) -> void:
	if not enemy:
		return
		
	if not Globals.enemy_manager:
		_update_ui()
		return
		
	var enemies: Array[Enemy] = Globals.enemy_manager.get_alive_enemies()
	
	var enemy_index: int = enemies.find(enemy)
	if enemy_index != -1: # We found the enemy
		targeted_enemy_index = enemy_index
	
	check_target_is_valid()

	
func _update_ui() -> void:
	if !targeted_enemy:
		targeting_indicator.visible = false
		
		$TargetImage.texture = null
		for i: int in range(6):
			$Intents.get_child(i).texture = null
			$Intents.get_child(i).get_child(0).text = ''
			
			# De-highlight the die sprites
			die_sprites[i].frame = i
		
		$TargetImageFill.z_index = 1
		
	else:
		_move_indicator()
		
		$TargetImage.texture = targeted_enemy.enemy_resource.targeting_computer_image
		for i: int in range(len(targeted_enemy.turn_actions)): # Should always loop 0 to 5
			if Globals.state_manager.state == GameStateManager.GameState.IN_COMBAT:
				# Set up the intent die properly
				if targeted_enemy.dice_manager.has_value(i+1):
					die_sprites[i].frame = i + 6
				else:
					die_sprites[i].frame = i
					
				# Set up the action texture
				$Intents.get_child(i).texture = targeted_enemy.turn_actions[i].indicator_texture
				
				# Set up the action amount text
				$Intents.get_child(i).get_child(0).text = targeted_enemy.turn_actions[i].intent_amount

				# Change over the info on clicking this particular action indicator 
				Utils.disconnect_all_callables($Intents.get_child(i).get_child(1).clicked)
				$Intents.get_child(i).get_child(1).clicked.connect(targeted_enemy.turn_actions[i].show_info)
				
				if targeted_enemy.turn_actions[i].name != "":
					$Intents.get_child(i).get_child(1).hover_for_info = true
			else:
				$Intents.get_child(i).texture = unknown_intent_indicator
				$Intents.get_child(i).get_child(0).text = ""
				Utils.disconnect_all_callables($Intents.get_child(i).get_child(1).clicked)
				$Intents.get_child(i).get_child(1).hover_for_info = false
				
				
		$TargetImageFill.z_index = 1
		$TargetImageFill.frame = 0
		await $TargetImageFill.animation_looped
		$TargetImageFill.z_index = -2


func _move_indicator() -> void:
	targeting_indicator.visible = true
		
	var tween_time: float = 0.3
	var tween: Tween = get_tree().create_tween()
	tween.tween_property(targeting_indicator, 'global_position', targeted_enemy.global_position + targeting_indicator_offset, tween_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

	tween.tween_callback(_indicator_bob)
	
	
func _indicator_bob() -> void:
	if not targeted_enemy:
		return
		
	var bob_time: float = 1.5
	
	if indicator_bob_tween:
		indicator_bob_tween.kill()
		
	indicator_bob_tween = get_tree().create_tween()
	indicator_bob_tween.tween_property(targeting_indicator, 'global_position', targeted_enemy.global_position + targeting_indicator_offset + Vector2(4, 4), bob_time/2.0).from(targeted_enemy.global_position + targeting_indicator_offset).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	indicator_bob_tween.tween_property(targeting_indicator, 'global_position', targeted_enemy.global_position + targeting_indicator_offset, bob_time/2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	indicator_bob_tween.set_loops()


func _startup() -> void:
	_reveal_tween()
	
	
func _reveal_tween() -> void:
	var tween: Tween = get_tree().create_tween()
	var reveal_time: float = 3
	var max_progress: float = 29
	
	tween.tween_property(
		%RevealOverlay, 
		"material:shader_parameter/progress", 
		max_progress, 
		reveal_time
	).from(0)
	
	await tween.finished
	%RevealOverlay.hide()
