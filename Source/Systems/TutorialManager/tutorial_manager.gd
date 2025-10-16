class_name TutorialManager
extends Node2D

@export var auto_start: bool = true
@export var skip_to_step: int = 0
@export var time_to_wait_before_tutorial: float = 3
@export var tutorial_steps: Array[TutorialStep] = []


var tutorial_text_popup_scene: PackedScene = preload("uid://dauuk425cis74")

var current_step_index: int = -1
var current_popup: TutorialTextPopup
var is_active: bool = false

var tutorial_will_trigger_enemy_turns: bool = false


var tutorial_functions: Dictionary[TutorialStep.TutorialFunctions, Callable] = {
	TutorialStep.TutorialFunctions.REVEAL_HEALTH_BAR: _reveal_health_bar,
	TutorialStep.TutorialFunctions.TRIGGER_ENEMY_SPAWN: _spawn_enemy,
	TutorialStep.TutorialFunctions.REVEAL_SYSTEMS: _reveal_systems,
	TutorialStep.TutorialFunctions.SPAWN_DICE: _spawn_dice,
	TutorialStep.TutorialFunctions.ALLOW_DICE_DRAGGING: _allow_dice_dragging,
	TutorialStep.TutorialFunctions.REVEAL_TARGETING_COMPUTER: _reveal_targeting_computer,
	TutorialStep.TutorialFunctions.RUN_ENEMY_TURN: _run_enemy_turn,
	TutorialStep.TutorialFunctions.ALLOW_NORMAL_COMBAT: _allow_normal_combat,
	TutorialStep.TutorialFunctions.REVEAL_MAP: _reveal_map,
}


func _ready() -> void:
	Globals.tutorial_manager = self
	
	await get_tree().create_timer(time_to_wait_before_tutorial).timeout

	if auto_start and tutorial_steps.size() > 0:
		is_active = true
		tutorial_will_trigger_enemy_turns = true
		
		for skipped_step: int in range(skip_to_step):
			var step: TutorialStep = tutorial_steps.pop_front()
			
			# Apply forced dice if specified
			if step.forced_dice.size() > 0:
				Dice.forced_rolls.append_array(step.forced_dice)
		
			# Apply forced enemy actions if specified
			if step.forced_enemy_actions.size() > 0:
				Enemy.forced_actions.append_array(step.forced_enemy_actions)
				
			# Apply forced rewards from enemies if specified
			if step.forced_rewards.size() > 0:
				Reward.forced_rewards.append_array(step.forced_rewards)
			
			if step.tutorial_function in tutorial_functions:
				print("Step: ", skipped_step, " -> ", step.tutorial_function)
				tutorial_functions[step.tutorial_function].call()
			
		start_tutorial()


func create_tutorial_popup(text: String, global_pos: Vector2, close_button: bool = true, auto_close_time: float = 0) -> void:
	if current_popup and is_instance_valid(current_popup):
		current_popup.close()
		
	current_popup = tutorial_text_popup_scene.instantiate()
	add_child(current_popup)

	current_popup.setup(text, global_pos, close_button, auto_close_time)
	

func start_tutorial() -> void:
	for i: int in range(len(tutorial_steps)):
		var step: TutorialStep = tutorial_steps[i]
		if i == 0:
			await play_step(step, true)
		else:
			await play_step(step)
		await current_popup.popup_closed
	
	is_active  = false


func play_step(step: TutorialStep, force_open: bool = false) -> void:
	if not force_open:
		match step.open_on_signal:
			TutorialStep.TutorialSignals.CLICKED_OUT_OF_INFO:
				await Events.info_graphic_closed
	
	# Apply forced dice if specified
	if step.forced_dice.size() > 0:
		Dice.forced_rolls.append_array(step.forced_dice)
		
	# Apply forced enemy actions if specified
	if step.forced_enemy_actions.size() > 0:
		Enemy.forced_actions.append_array(step.forced_enemy_actions)
		
	# Apply forced rewards from enemies if specified
	if step.forced_rewards.size() > 0:
		Reward.forced_rewards.append_array(step.forced_rewards)
	
	# Handle highlighting
	if step.highlight_texture:
		# Tween in the highlight sprite
		pass
		
	# Create the text popup
	if step.close_on_signal == TutorialStep.TutorialSignals.CLOSED_MANUALLY:
		create_tutorial_popup(step.tutorial_text, step.text_position, true)
	elif step.close_on_signal == TutorialStep.TutorialSignals.CLOSED_AFTER_TIME:
		create_tutorial_popup(step.tutorial_text, step.text_position, false, step.time_to_auto_close)
	else:
		create_tutorial_popup(step.tutorial_text, step.text_position, false)
		
		match step.close_on_signal:
			TutorialStep.TutorialSignals.TILE_CLICKED_FOR_INFO:
				Events.tile_clicked_for_info.connect(current_popup.close)
				
			TutorialStep.TutorialSignals.TILE_ACTIVATED:
				Events.tile_activation_complete.connect(current_popup.close)
				
			TutorialStep.TutorialSignals.PLAYER_TURN_OVER:
				Events.player_turn_over.connect(current_popup.close)
				
			TutorialStep.TutorialSignals.ENEMY_DEFEATED:
				Events.combat_finished.connect(current_popup.close)
				
			TutorialStep.TutorialSignals.REWARD_CLAIMED:
				Events.reward_picked.connect(current_popup.close)
				
			TutorialStep.TutorialSignals.MAP_OPENED:
				Events.map_shown.connect(current_popup.close)
				
			TutorialStep.TutorialSignals.ON_JUMP:
				Events.jump.connect(current_popup.close)
				
				
	# Handle calling tutorial functions
	if step.tutorial_function in tutorial_functions:
		current_popup.all_text_displayed.connect(
			tutorial_functions[step.tutorial_function]
		)


func _reveal_health_bar() -> void:
	Events.health_bar_startup.emit()
	
	
func _spawn_enemy() -> void:
	Globals.enemy_manager.start_enemy_fly_in()
	Events.start_combat.emit()
	
	
func _reveal_systems() -> void:
	Events.systems_startup.emit()
	
	
func _spawn_dice() -> void:
	await Globals.player.spawn_dice()
	for die: Dice in Globals.player.dice_manager.queue:
		die.draggable.dragging_allowed = false
		

func _allow_dice_dragging() -> void:
	for die: Dice in Globals.player.dice_manager.queue:
		die.draggable.dragging_allowed = true
		
		
func _reveal_targeting_computer() -> void:
	Events.targeting_computer_startup.emit()


func _run_enemy_turn() -> void:
	Globals.enemy_manager.run_enemy_turn()
	
	
func _allow_normal_combat() -> void:
	tutorial_will_trigger_enemy_turns = false
	
	
func _reveal_map() -> void:
	Events.map_startup.emit()
