class_name StealHullEvent
extends DamageEvent
## Leeching Shot's "Steal hull": a hit that goes straight past the shields to
## the hull, then heals the actor by the hull it actually took. A ship with
## less hull than the hit can only give up what it has, and a hit that takes
## none (Phased, an invulnerable ship) heals nothing.
##
## Being a DamageEvent, the hit is grown and shrunk like any other (an
## Amplifier, Weakened, Exposed); the heal follows whatever landed. The heal is
## a HealEvent of its own, injected to resolve right after, so anything that
## caps or blocks a heal (a repair blackout) still sees it.

## The hull the hit took, across every target, once resolved.
var hull_taken: int = 0


func soaked_by_shields() -> bool:
	return false


func resolve(engine: ScenarioEngine) -> void:
	var hull_before: Dictionary[Node, int] = {}
	for target: Node in targets:
		if is_instance_valid(target):
			hull_before[target] = target.health.health
	super(engine)
	for target: Node in hull_before:
		if is_instance_valid(target):
			hull_taken += maxi(0, hull_before[target] - target.health.health)
		else:
			# Freed by the hit itself: it gave up everything it had.
			hull_taken += hull_before[target]

	if hull_taken <= 0 or not is_instance_valid(actor) or not ("health" in actor):
		return
	var heal := HealEvent.new()
	heal.actor = actor
	heal.effect_source = effect_source
	heal.activator_die = activator_die
	heal.die_value = die_value
	heal.amount = hull_taken
	heal.targets = [actor] as Array[Node]
	engine.inject_event(heal)
