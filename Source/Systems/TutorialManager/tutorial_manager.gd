class_name TutorialManager
extends Node2D

@export var tutorial_steps: Array[TutorialStep] = []
@export var auto_start: bool = true
@export var can_skip: bool = true

var tutorial_text_popup_scene: PackedScene = preload("uid://dauuk425cis74")

var current_step_index: int = -1
var current_popup: TutorialTextPopup
var is_active: bool = false
var is_paused: bool = false

func _ready() -> void:
	Globals.tutorial_manager = self
	
	# Connect to tutorial text display
	Events.show_tutorial_text.connect(_spawn_tutorial_text)
	
	# Connect to game events for tutorial triggers
	_connect_game_events()
	
	# Auto-start if enabled
	if auto_start and tutorial_steps.size() > 0:
		start_tutorial()
		
	
	Events.start_scenario.connect(
		func() -> void:
			create_tutorial_popup(
				"This is a test tutorial popup!", 
				Vector2(160, 45)
			)
	)
		

func create_tutorial_popup(text: String, global_pos: Vector2) -> void:
	var popup: TutorialTextPopup = tutorial_text_popup_scene.instantiate()
	add_child(popup)
	
	popup.setup(text, global_pos)
	

func _connect_game_events() -> void:
	# Game sequencing events
	Events.player_turn_start.connect(_on_player_turn_start)
	Events.player_turn_over.connect(_on_player_turn_over)
	Events.enemy_turn_over.connect(_on_enemy_turn_over)
	Events.enemy_received_die.connect(_on_enemy_received_die)
	Events.enemy_used_die.connect(_on_enemy_used_die)
	Events.tile_activation_complete.connect(_on_tile_activation_complete)
	Events.die_added.connect(_on_die_added)
	Events.die_placed_on_tile.connect(_on_die_placed_on_tile)
	Events.combat_finished.connect(_on_combat_finished)
	Events.start_combat.connect(_on_start_combat)
	Events.enemy_acted.connect(_on_enemy_acted)
	Events.scenario_event.connect(_on_scenario_event)
	Events.reward_picked.connect(_on_reward_picked)
	Events.open_shop.connect(_on_shop_opened)
	Events.close_shop.connect(_on_shop_closed)
	
	# Tutorial-specific events
	Events.tutorial_step_completed.connect(_on_tutorial_step_completed)
	Events.tutorial_completed.connect(_on_tutorial_completed)
	Events.tutorial_skipped.connect(_on_tutorial_skipped)

func start_tutorial() -> void:
	if is_active or tutorial_steps.size() == 0:
		return
		
	is_active = true
	current_step_index = 0
	_next_step()

func stop_tutorial() -> void:
	is_active = false
	current_step_index = -1
	_clear_current_popup()
	Events.tutorial_completed.emit()

func pause_tutorial() -> void:
	is_paused = true

func resume_tutorial() -> void:
	is_paused = false

func skip_tutorial() -> void:
	if can_skip:
		stop_tutorial()
		Events.tutorial_skipped.emit()

func _next_step() -> void:
	if not is_active or is_paused:
		return
		
	# Check if we've completed all steps
	if current_step_index >= tutorial_steps.size():
		stop_tutorial()
		return
	
	var current_step: TutorialStep = tutorial_steps[current_step_index]
	
	# Check if this step should be skipped
	if current_step.should_skip():
		current_step_index += 1
		_next_step()
		return
	
	# Play the current step
	current_step.play()

func _check_trigger(event_name: String) -> void:
	if not is_active or is_paused:
		return
		
	if current_step_index < 0 or current_step_index >= tutorial_steps.size():
		return
		
	var current_step: TutorialStep = tutorial_steps[current_step_index]
	
	if current_step.is_trigger_met(event_name):
		current_step_index += 1
		Events.tutorial_step_completed.emit()
		_next_step()

func _spawn_tutorial_text(text: String, global_pos: Vector2) -> void:
	_clear_current_popup()
	
	if text.is_empty():
		return
		
	current_popup = tutorial_text_popup_scene.instantiate()
	current_popup.setup(text, global_pos)
	add_child(current_popup)

func _clear_current_popup() -> void:
	if current_popup:
		current_popup.queue_free()
		current_popup = null

# Event handlers for tutorial triggers
func _on_player_turn_start() -> void:
	_check_trigger("player_turn_start")

func _on_player_turn_over() -> void:
	_check_trigger("player_turn_over")

func _on_enemy_turn_over() -> void:
	_check_trigger("enemy_turn_over")

func _on_enemy_received_die() -> void:
	_check_trigger("enemy_received_die")

func _on_enemy_used_die(_enemy: Enemy, _die_value: int) -> void:
	_check_trigger("enemy_used_die")

func _on_tile_activation_complete() -> void:
	_check_trigger("tile_activation_complete")

func _on_die_added() -> void:
	_check_trigger("die_added")

func _on_die_placed_on_tile(_die: Dice, _tile: Tile) -> void:
	_check_trigger("die_placed_on_tile")

func _on_combat_finished() -> void:
	_check_trigger("combat_finished")

func _on_start_combat() -> void:
	_check_trigger("start_combat")

# Additional trigger handlers for more specific events
func _on_enemy_acted(_enemy_name: String, _action_name: String) -> void:
	_check_trigger("enemy_acted")

func _on_scenario_event(_event: ScenarioManager.ScenarioEvent) -> void:
	_check_trigger("scenario_event")

func _on_reward_picked() -> void:
	_check_trigger("reward_picked")

func _on_shop_opened() -> void:
	_check_trigger("shop_opened")

func _on_shop_closed() -> void:
	_check_trigger("shop_closed")

# Tutorial event handlers
func _on_tutorial_step_completed() -> void:
	# Could add step completion effects here
	pass

func _on_tutorial_completed() -> void:
	# Could add tutorial completion effects here
	pass

func _on_tutorial_skipped() -> void:
	# Could add tutorial skip effects here
	pass

# Public API for external systems
func add_tutorial_step(step: TutorialStep) -> void:
	tutorial_steps.append(step)

func insert_tutorial_step(step: TutorialStep, index: int) -> void:
	tutorial_steps.insert(index, step)

func remove_tutorial_step(index: int) -> void:
	if index >= 0 and index < tutorial_steps.size():
		tutorial_steps.remove_at(index)

func get_current_step() -> TutorialStep:
	if current_step_index >= 0 and current_step_index < tutorial_steps.size():
		return tutorial_steps[current_step_index]
	return null

func is_tutorial_active() -> bool:
	return is_active

func get_tutorial_progress() -> float:
	if tutorial_steps.size() == 0:
		return 1.0
	return float(current_step_index) / float(tutorial_steps.size())
