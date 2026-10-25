class_name HazardEvent
extends EffectEvent
## Wraps a background hazard's chain so it resolves in the engine's normal order
## rather than jumping the queue, and gives it a build-up first.
##
## Hazards have no activator die — they're the environment acting, not a ship —
## so any chain assigned to one must avoid die-dependent effects.
##
## A flare that simply happened (a flash and three damage) read as the game
## blinking. The countdown says when, but the moment itself needs a beat of
## its own: the screen's edges swell in the hazard's colour, its name goes up
## (HazardWarning), the region's art acts up, and only then does it strike.

## How long the build-up runs before the strike, at animation speed 1.
const WIND_UP_SECONDS: float = 1.6

## The hazard going off. Null plays the chain with no build-up.
var hazard: BackgroundHazardResource

## The hazard chain to play.
var chain: EffectChain


func resolve(engine: ScenarioEngine) -> void:
	if chain == null:
		return

	if hazard:
		await _wind_up(engine)
		if engine.is_shut_down():
			return
		Events.hazard_struck.emit(hazard)
		Juice.screen_flash(engine, hazard.color, 0.45, 0.4)
		# The environment hitting the whole board should land harder than any
		# one ship's attack, so it gets the big shake.
		Events.camera_shake_large.emit(true)

	var context: EffectContext = EffectContext.new()
	context.actor = actor
	context.effect_source = effect_source

	await chain.play(context, engine)


func _wind_up(engine: ScenarioEngine) -> void:
	var seconds: float = WIND_UP_SECONDS / Globals.animation_speed
	Events.hazard_winding_up.emit(hazard, seconds)
	HazardWarning.show_for(engine, hazard, seconds)
	await engine.get_tree().create_timer(seconds).timeout
