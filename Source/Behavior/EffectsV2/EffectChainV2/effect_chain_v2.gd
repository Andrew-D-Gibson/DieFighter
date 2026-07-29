## EffectChainV2
## This holds Array[EffectData] — pure data describing intent.
## Each entry is processed by the appropriate EffectHandler, which
## either modifies the context (targeting) or enqueues events (combat/visual),
## or both.
##
## AUTHORING:
##   1. Create a new resource of type EffectChainV2.
##   2. Add EffectData entries to the 'effects' array.
##      Order matters — entries execute top to bottom.
##   3. Assign it to TileResource.effect_chain_v2.
##
## TYPICAL USAGE IN Tile.activate():
##   var context := EffectContext.new()
##   context.actor = Globals.player
##   context.effect_source = self
##   context.activator_die = activator_die
##   await tile_resource.effect_chain_v2.play(context, scenario_engine)
##   await scenario_engine.process_events()


class_name EffectChainV2
extends Resource


## The ordered list of effects in this chain.
## Each entry is processed in sequence for each repetition.
## NOTE: entries with category == REPETITION are not valid here — see
## 'repetition_conditions' below. A REPETITION entry inside this array is
## always an authoring mistake (it would try to change the loop it's part
## of) and is skipped with a push_error at runtime.
@export var effects: Array[EffectData] = []

## Fixed, author-time repeat count for this chain (e.g. "this attack always
## hits twice"). Multiplies into the repetition count once, before any
## looping begins.
@export var base_repetitions: int = 1

## Conditional repeat rules (e.g. "if activator die is odd, hit once more").
## Evaluated exactly once, before the repeating loop starts — NOT part of
## 'effects'. Each entry's branches may contain an AMOUNT_MODIFIER +
## REPETITION/ADD_REPETITIONS pair; this is the only place that combo is
## safe to use, since it can never re-trigger itself.
@export var repetition_conditions: Array[ConditionalEffectData] = []


## Execute the chain for the given context and engine.
##   - Records the die's starting position before the first loop.
##   - Combines base_repetitions, repetition_conditions, and whatever
##     repetition count the caller already put on context (e.g. an outer
##     "activates twice" modifier) into a single total, captured ONCE.
##   - Resets the die position (via a queued SnapDieToPositionEvent, so it
##     resolves in sequence with the rest of the repetition's events) at the
##     start of every repetition after the first.
func play(context: EffectContext, engine: ScenarioEngine) -> void:
	# Cache the die's start position so each repetition begins identically.
	var die_start_position: Vector2 = Vector2.ZERO
	if context.activator_die:
		die_start_position = context.activator_die.global_position

	context.repetitions *= base_repetitions

	# Evaluate conditional repeat rules exactly once, before any looping.
	for cond: ConditionalEffectData in repetition_conditions:
		var cond_handler: EffectHandler = EffectRegistry.get_handler(cond.category, cond.subtype)
		if cond_handler == null:
			continue
		await cond_handler.apply(cond, context, engine)

	# Capture the total by value — the for-loop below is bounded by this,
	# NOT by context.repetitions, so nothing that runs during the loop can
	# extend its own iteration count.
	var total_repetitions: int = context.repetitions

	for i: int in total_repetitions:
		# Keep context.repetitions live as an INFORMATIONAL "how many
		# repetitions remain after this one" counter — handlers like
		# GiveDieToTargetHandler read it to detect "am I on the last
		# repetition?". It has no effect on how many times this loop runs;
		# that's fixed by total_repetitions above.
		context.repetitions = total_repetitions - i - 1

		# Reset die position for every repetition after the first — the die
		# is already there for i == 0 (placed by TileActivationEvent).
		# Injected as an event (not tweened inline) so it resolves in its
		# correct sequential slot after the previous repetition's own queued
		# events (particles, damage, give-die, etc.) — handlers only enqueue
		# events rather than awaiting them, so an inline tween here would run
		# well ahead of the visuals it's supposed to follow.
		if i > 0 and context.activator_die:
			var reset_event := SnapDieToPositionEvent.new()
			reset_event.actor          = context.actor
			reset_event.activator_die  = context.activator_die
			reset_event.target_position = die_start_position
			engine.inject_event(reset_event)

		# Reset running amount for this repetition.
		context.running_amount = 0

		# Execute each effect in order.
		for data: EffectData in effects:
			if data.category == EffectEnums.Category.REPETITION:
				push_error(
					"EffectChainV2: REPETITION effects are not valid inside 'effects' " +
					"(they would try to modify the loop they're part of). " +
					"Use 'repetition_conditions' instead."
				)
				continue
			var handler: EffectHandler = EffectRegistry.get_handler(data.category, data.subtype)
			if handler == null:
				push_error(
					"EffectChainV2: no handler registered for category=" +
					EffectEnums.Category.find_key(data.category) +
					" subtype=" +
					str(data.subtype) +
					"\nAdd a _register() call in effect_registry.gd._ready()."
				)
				continue
			await handler.apply(data, context, engine)
