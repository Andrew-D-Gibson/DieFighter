class_name ShieldBlackoutModifier
extends Modifier
## No ship can raise shields while this is active.
##
## Ionized gas bleeds a shield capacitor flat as fast as it charges, so the
## whole shielding axis is simply off. Only shield *gains* are cancelled —
## effects that strip shields still land, because the point is that shielding
## is unavailable, not that shields are protected.
##
## The ships already in the region when the rule goes up have been sitting in
## the same gas, so they lose the shields they were authored with: a pulsar
## fight starts with every ship bare, not just the player.


func _init() -> void:
	modifier_name = "Shield Blackout"
	priority = 5    # cancellation; runs before anything tries to scale it


func on_registered(engine: ScenarioEngine) -> void:
	super(engine)
	if is_instance_valid(Globals.enemy_manager):
		drain(Globals.enemy_manager.enemies)


## Flattens every one of [param ships]' shields, quietly: set rather than
## damaged, since nothing hit them. Ships are still above the screen when a
## region's rule goes up on arrival, so the player only ever sees them bare.
static func drain(ships: Array[Enemy]) -> void:
	for ship: Enemy in ships:
		if is_instance_valid(ship) and ship.health:
			ship.health.shields = 0


func on_before_event(event: EffectEvent, _engine: ScenarioEngine) -> void:
	if event is ShieldEvent and event.amount > 0:
		event.canceled = true
		announce_triggered()


func get_trigger_text() -> String:
	return "NO SHIELDS"
