class_name EnemyActionEvent
extends EffectEvent

var enemy: Enemy
var action: EnemyActionResource
var action_popup: PackedScene = preload("uid://b8gjt5a2dcrbn")

## How long the die takes to travel out in front of the enemy, by face value.
##
## This is the most repeated moment in the game and the whole thesis of it —
## you armed them, and now you watch what you armed them with. A 1 should skip
## over weightlessly; a 6 should drag. Making the *value* legible in pure body
## language means a turn's worth of handovers has a felt threat-texture before
## the player re-reads a single intent.
const _LIGHT_HANDOVER_SECONDS: float = 0.45
const _HEAVY_HANDOVER_SECONDS: float = 0.95

## Beat between the die arriving and the action firing. Scales the same way, so
## a heavy die also hangs there a moment longer before it goes off.
const _LIGHT_HOLD_SECONDS: float = 0.15
const _HEAVY_HOLD_SECONDS: float = 0.45

## How many times the full effect chain plays for this single activation.
## Defaults to 1; modifiers may multiply this in on_before_event() (e.g.
## "tiles activated by a 4 activate twice").
var activation_repetitions: int = 1


func resolve(engine: ScenarioEngine) -> void:
	if not enemy and is_instance_valid(enemy):
		return

	# Remove die from the visual stacking queue
	# It's about to fly in front of the enemy
	activator_die.draggable.state = Draggable.DragState.MOVING_WITH_CODE
	enemy.dice_manager.remove(activator_die)

	Globals.targeting_computer.target_enemy(enemy)

	# Tween the die to in front of the enemy, weighted by its face value.
	var weight: float = (clampf(die_value, 1, 6) - 1.0) / 5.0
	var tween_time: float = lerpf(_LIGHT_HANDOVER_SECONDS, _HEAVY_HANDOVER_SECONDS, weight)
	var adjusted_tween_time: float = tween_time / Globals.animation_speed
	var tween: Tween = enemy.get_tree().create_tween()
	tween.tween_property(
		activator_die, 
		"global_position", 
		enemy.global_position + Vector2(0,12), 
		adjusted_tween_time
	).set_ease(Tween.EASE_IN_OUT)
	# A heavy die also grows slightly as it arrives, so the value reads even
	# with the screen shaking.
	tween.parallel().tween_property(
		activator_die,
		"scale",
		Vector2.ONE * lerpf(0.8, 1.15, weight),
		adjusted_tween_time
	).set_ease(Tween.EASE_OUT)
	await tween.finished
	
	# Just in case.
	# This only happens when an enemy flees with multiple dice I think,
	# and I don't love this but it's fine.
	if not enemy and is_instance_valid(enemy):
		return
		
	await enemy.get_tree().create_timer(
		lerpf(_LIGHT_HOLD_SECONDS, _HEAVY_HOLD_SECONDS, weight)
	).timeout
	
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
	context.enemy_intent_amount = action.intent_amount
	
	
	# Play the effect chain — this enqueues more events; the engine's while-loop
	# picks them up automatically because they're appended to the same event_queue.
	if action.effect_chain:
		await action.effect_chain.play(context, engine)
