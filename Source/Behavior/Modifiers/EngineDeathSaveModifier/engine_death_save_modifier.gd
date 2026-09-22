class_name EngineDeathSaveModifier
extends Modifier
## Dumps a full drive to cancel a killing blow.
##
## Sits in the cancellation priority band and inspects incoming damage before
## it lands, because that is the only place a save can work: Health emits
## fatal_damage and then re-checks synchronously, while every tile event
## response resolves asynchronously through the engine's queue. By the time an
## ON_PLAYER_FATAL_DAMAGE chain could heal, death has already been declared.
##
## Self-limiting rather than counted. Saving costs the entire bar, so the next
## save needs a full recharge — the resource is the cooldown, the same way Arc
## Tap's price limits it.


func _init() -> void:
	modifier_name = "Dead Man's Switch"
	priority = 5    # cancellation; must run before anything scales the damage
	is_temporary = false


func on_before_event(event: EffectEvent, _engine: ScenarioEngine) -> void:
	if event is not DamageEvent:
		return
	if not is_instance_valid(Globals.player):
		return
	if Globals.player not in event.targets:
		return
	if not Globals.player.is_engine_charged():
		return

	# Only a blow that would actually kill trips the switch. Shields count:
	# spending the drive to survive a hit the shields were going to eat anyway
	# would be a trap rather than a save.
	var health: Health = Globals.player.health
	if event.amount < health.shields + health.health:
		return

	event.canceled = true
	Globals.player.engine_charge = 0
	Events.camera_shake_large.emit(true)
