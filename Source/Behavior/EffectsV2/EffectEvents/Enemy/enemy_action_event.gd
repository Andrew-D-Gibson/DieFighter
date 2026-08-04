class_name EnemyActionEvent
extends EffectEvent

var enemy: Enemy
var action: EnemyActionResource
var action_popup: PackedScene = preload("uid://b8gjt5a2dcrbn")

## How many times the full effect chain plays for this single activation.
## Defaults to 1; modifiers may multiply this in on_before_event() (e.g.
## "tiles activated by a 4 activate twice").
var activation_repetitions: int = 1


func resolve(engine: ScenarioEngine) -> void:
	if not is_instance_valid(enemy):
		return

	# Remove die from the visual stacking queue
	# It's about to fly in front of the enemy
	activator_die.draggable.state = Draggable.DragState.MOVING_WITH_CODE
	enemy.dice_manager.remove(activator_die)

	Globals.targeting_computer.target_enemy(enemy)

	# Tween the die to in front of the enemy
	var tween_time: float = 0.75
	var adjusted_tween_time: float = tween_time / Globals.animation_speed
	var tween: Tween = enemy.get_tree().create_tween()
	tween.tween_property(
		activator_die, 
		"global_position", 
		enemy.global_position + Vector2(0,12), 
		adjusted_tween_time
	).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	
	await enemy.get_tree().create_timer(0.25).timeout
	
	# Make an action indicator popup
	var popup_time: float = 0.75
	var action_indicator: Node2D = action_popup.instantiate()
	enemy.add_child(action_indicator)
	action_indicator.sprite.texture = action.info_texture
	action_indicator.popup_time = popup_time
	action_indicator.global_position = activator_die.global_position + Vector2(0,12)
		

	# Build the EffectContext for this activation
	var context: EffectContext = EffectContext.new()
	context.actor = enemy
	context.effect_source = enemy
	context.activator_die = activator_die
	context.repetitions = activation_repetitions
	
	
	# Play the v2 effect chain — this enqueues more events; the engine's while-loop
	# picks them up automatically because they're appended to the same event_queue.
	if action.effect_chain_v2:
		await action.effect_chain_v2.play(context, engine)
