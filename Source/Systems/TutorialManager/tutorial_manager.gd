class_name TutorialManager
extends Node2D

@export var auto_start: bool = true
@export var skip_to_step: int = 0
@export var tutorial_steps: Array[TutorialStep] = []
@export var tutorial_game_save: GameSaveResource

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
	TutorialStep.TutorialFunctions.ENABLE_RIGHT_CONTROL: _enable_right_control,
	TutorialStep.TutorialFunctions.ENABLE_ALL_CONTROLS: _enable_controls,
	TutorialStep.TutorialFunctions.LOCK_DICE: _lock_dice,
	TutorialStep.TutorialFunctions.UNLOCK_DICE: _unlock_dice,
	TutorialStep.TutorialFunctions.LOAD_MAIN_GAME: _load_main_game,
}


func _ready() -> void:
	Globals.tutorial_manager = self

	if auto_start and tutorial_steps.size() > 0:
		is_active = true
		tutorial_will_trigger_enemy_turns = true
		
		Globals.map.disable_controls()
		
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


func create_tutorial_popup(text: String, global_pos: Vector2, highlight_texture: Texture2D = null, time_delay: float = 0, close_button: bool = true, auto_close_time: float = 0) -> void:
	if current_popup and is_instance_valid(current_popup):
		current_popup.close()
		
	current_popup = tutorial_text_popup_scene.instantiate()
	add_child(current_popup)

	current_popup.setup(text, global_pos, highlight_texture, time_delay, close_button, auto_close_time)
	

func start_tutorial() -> void:
	for i: int in range(len(tutorial_steps)):
		var step: TutorialStep = tutorial_steps[i]
			
		await get_tree().create_timer(step.time_delay).timeout
	
		await play_step(step)
		await current_popup.popup_closed
	
	is_active  = false


func play_step(step: TutorialStep, force_open: bool = false) -> void:
	match step.open_on_signal:
		TutorialStep.TutorialSignals.CLICKED_OUT_OF_INFO:
			await Events.info_graphic_closed
			
		TutorialStep.TutorialSignals.ON_ENEMY_FLY_IN:
			await Events.enemy_flew_in
			
		TutorialStep.TutorialSignals.REWARD_CLAIMED:
			await Events.reward_picked
	
	# Apply forced dice if specified
	if step.forced_dice.size() > 0:
		Dice.forced_rolls.append_array(step.forced_dice)
		
	# Apply forced enemy actions if specified
	if step.forced_enemy_actions.size() > 0:
		Enemy.forced_actions.append_array(step.forced_enemy_actions)
		
	# Apply forced rewards from enemies if specified
	if step.forced_rewards.size() > 0:
		Reward.forced_rewards.append_array(step.forced_rewards)
		
	# Create the text popup
	if step.close_on_signal == TutorialStep.TutorialSignals.CLOSED_MANUALLY:
		create_tutorial_popup(step.tutorial_text, step.text_position, step.highlight_texture, step.time_delay, true)
	elif step.close_on_signal == TutorialStep.TutorialSignals.CLOSED_AFTER_TIME:
		create_tutorial_popup(step.tutorial_text, step.text_position, step.highlight_texture, step.time_delay, false, step.time_to_auto_close)
	else:
		create_tutorial_popup(step.tutorial_text, step.text_position, step.highlight_texture, step.time_delay, false)
		
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
				
			TutorialStep.TutorialSignals.ON_TARGET_SWITCH:
				Events.targeting_computer_retargeted.connect(current_popup.close)
				
				
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
	
	
func _enable_right_control() -> void:
	Globals.map.right_arrow_tile.can_accept_dice.enabled = true
	
	
func _enable_controls() -> void:
	Globals.map.enable_controls()
	Events.show_map.emit()
	
	
func _lock_dice() -> void:
	for die: Dice in Globals.player.dice_manager.queue:
		die.draggable.dragging_allowed = false
		
		
func _unlock_dice() -> void:
	for die: Dice in Globals.player.dice_manager.queue:
		die.draggable.dragging_allowed = true
		
		
func _load_main_game() -> void:
	await get_tree().create_timer(3).timeout
	Globals.state_manager.fade_out_to_main_menu()
