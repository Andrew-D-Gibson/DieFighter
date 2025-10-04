class_name TutorialManager
extends Node2D

@export var time_to_wait_before_tutorial: float = 3
@export var tutorial_steps: Array[TutorialStep] = []
@export var auto_start: bool = true
@export var can_skip: bool = true

var tutorial_text_popup_scene: PackedScene = preload("uid://dauuk425cis74")

var current_step_index: int = -1
var current_popup: TutorialTextPopup
var is_active: bool = false
var is_paused: bool = false


var tutorial_functions: Dictionary[TutorialStep.TutorialFunctions, Callable] = {
	TutorialStep.TutorialFunctions.REVEAL_HEALTH_BAR: _reveal_health_bar,
	TutorialStep.TutorialFunctions.TRIGGER_ENEMY_SPAWN: _spawn_enemy,
	TutorialStep.TutorialFunctions.REVEAL_MAIN_VIEWER: _reveal_main_viewer,
	TutorialStep.TutorialFunctions.SPAWN_DICE: _spawn_dice,
}


func _ready() -> void:
	Globals.tutorial_manager = self

	if auto_start and tutorial_steps.size() > 0:
		await get_tree().create_timer(time_to_wait_before_tutorial).timeout
		start_tutorial()


func create_tutorial_popup(text: String, global_pos: Vector2, close_button: bool = true, auto_close_time: float = 0) -> void:
	if current_popup and is_instance_valid(current_popup):
		current_popup.close()
		
	current_popup = tutorial_text_popup_scene.instantiate()
	add_child(current_popup)

	current_popup.setup(text, global_pos, close_button, auto_close_time)
	

func start_tutorial() -> void:
	for step: TutorialStep in tutorial_steps:
		await play_step(step)
		await current_popup.popup_closed


func play_step(step: TutorialStep) -> void:
	print('playing step: ')
	print(step.tutorial_text)
	
	match step.open_on_signal:
		TutorialStep.TutorialSignals.CLICKED_OUT_OF_INFO:
			await Events.info_graphic_closed
	
	# Apply forced dice if specified
	if step.forced_dice.size() > 0:
		Dice.forced_rolls = step.forced_dice
		
	# Apply forced enemy actions if specified
	if step.forced_enemy_actions.size() > 0:
		Enemy.forced_actions = step.forced_enemy_actions
	
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
	
	
func _reveal_main_viewer() -> void:
	Events.main_viewer_startup.emit()
	
	
func _spawn_dice() -> void:
	Globals.player.spawn_dice()
