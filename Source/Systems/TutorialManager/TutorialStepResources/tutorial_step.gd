class_name TutorialStep
extends Resource

@export var description: String
@export var text_position: Vector2
@export var forced_dice: Array[int]
@export var forced_enemy_actions: Array[EnemyActionResource]

# Trigger system - what event should trigger the next step
@export var wait_for_action: String # e.g. "die_placed", "enemy_turn_end", "player_turn_start", etc.

# Optional: Skip this step if condition is met
@export var skip_if_condition: String # e.g. "player_has_dice", "enemy_has_die"

# Optional: Custom validation function name
@export var custom_validation: String

# Optional: Highlight specific UI elements
@export var highlight_elements: Array[String] # e.g. ["dice_queue", "end_turn_button"]

# Optional: Disable certain game interactions during this step
@export var disable_interactions: Array[String] # e.g. ["dice_dragging", "tile_clicking"]

func play() -> void:
	Events.show_tutorial_text.emit(description, text_position)
	
	# Apply forced dice if specified
	if forced_dice.size() > 0:
		Dice.forced_rolls = forced_dice
		
	# Apply forced enemy actions if specified
	if forced_enemy_actions.size() > 0:
		Enemy.forced_actions = forced_enemy_actions
	
	# Handle highlighting
	if highlight_elements.size() > 0:
		Events.tutorial_highlight_elements.emit(highlight_elements)
	
	# Handle interaction disabling
	if disable_interactions.size() > 0:
		Events.tutorial_disable_interactions.emit(disable_interactions)

func should_skip() -> bool:
	if skip_if_condition.is_empty():
		return false
		
	match skip_if_condition:
		"player_has_dice":
			return Globals.player and Globals.player.dice_manager.queue.size() > 0
		"enemy_has_die":
			return Globals.enemy_manager and Globals.enemy_manager.get_all_enemies().any(func(enemy: Enemy) -> bool: return enemy.dice_manager.queue.size() > 0)
		"player_health_low":
			return Globals.player and Globals.player.health.current_health <= 2
		"combat_active":
			return Globals.state_manager and Globals.state_manager.state == GameStateManager.GameState.IN_COMBAT
		_:
			return false

func is_trigger_met(trigger_event: String) -> bool:
	if wait_for_action.is_empty():
		return true
		
	# Handle custom validation
	if not custom_validation.is_empty():
		return _call_custom_validation()
	
	# Handle standard triggers
	return wait_for_action == trigger_event

func _call_custom_validation() -> bool:
	# This could be extended to call specific validation functions
	# For now, return true to allow custom validation to be implemented later
	return true
