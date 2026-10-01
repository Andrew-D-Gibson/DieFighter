class_name ApplyStatusEvent
extends EffectEvent
## Puts a status on each target, or adds to one it already has.
##
## amount is the stacks. It stays amplifiable on purpose: an Amplifier or
## Booster Stage beside a status tile applies more of it.
##
## Going through an event (rather than a handler adding the modifier itself)
## means a modifier can cancel it — an immunity rule needs nothing new.

var status_id: StringName


func resolve(engine: ScenarioEngine) -> void:
	if amount <= 0:
		return

	for target: Node in targets:
		# Statuses are enemy-side for now: only Enemy has a StatusBar.
		if not is_instance_valid(target) or target is not Enemy:
			continue
		if (target as Enemy).health.health <= 0:
			continue

		var incoming: StatusModifier = StatusCatalog.create(status_id, target as Enemy, amount)
		if incoming == null:
			return

		var existing: StatusModifier = engine.find_status(target, status_id)
		if existing:
			existing.merge(incoming)
		else:
			engine.add_modifier(incoming)
