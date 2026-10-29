class_name MultiplyStatusesEvent
extends EffectEvent
## Multiplies every status on each target by [member multiplier].
##
## It adds the difference as an ApplyStatusEvent per status rather than
## rewriting the stacks: the status takes hold the way any application does
## (badge, flash, callout), a rule that cancels applications cancels this too,
## and the tiles that answer the player applying a status (Hex Coil) hear one
## application per status multiplied.

var multiplier: float = 2.0


## Its own amount means nothing. The applications it makes are ordinary ones,
## so an Amplifier beside the tile grows each of them as it would any status.
func is_amplifiable() -> bool:
	return false


## Stacks a status of [param stacks] gains when multiplied by
## [param by], rounded down.
static func extra_stacks(stacks: int, by: float) -> int:
	return maxi(floori(stacks * by) - stacks, 0)


func resolve(engine: ScenarioEngine) -> void:
	for target: Node in targets:
		if not is_instance_valid(target) or not (target is Enemy or target is Player):
			continue
		if target.health.health <= 0:
			continue
		for status: StatusModifier in engine.statuses_on(target):
			var extra: int = extra_stacks(status.stacks, multiplier)
			if extra <= 0:
				continue
			var more: ApplyStatusEvent = ApplyStatusEvent.new()
			more.actor = actor
			more.effect_source = effect_source
			more.activator_die = activator_die
			more.die_value = die_value
			more.status_id = status.status_id
			more.amount = extra
			more.targets = [target] as Array[Node]
			engine.inject_event(more)
