class_name IonDamageEvent
extends DamageEvent
## Ion damage: [member amount] is the hit, and it comes off the shields twice
## over (Health.take_ion_damage). The hull is never touched, so whatever the
## shields can't absorb is lost, and a ship with no shields takes nothing.
##
## A DamageEvent so whatever shapes damage in general (an Amount Cap region,
## Double Damage) shapes this too; modifiers that only care about the hull
## check reaches_hull().


func reaches_hull() -> bool:
	return false


func resolve(_engine: ScenarioEngine) -> void:
	for target: Node in targets:
		if not is_instance_valid(target) or target.get("health") == null:
			continue

		if is_instance_valid(Globals.state_manager):
			Globals.state_manager.state = GameStateManager.GameState.IN_COMBAT
		if actor is Player and target is Enemy:
			Events.player_attacked_ship.emit(target, target.scenario_state.faction)
		elif actor is Enemy and target is Enemy and actor != target:
			Events.ship_attacked_ship.emit(actor, target)
		if target is Enemy:
			(target as Enemy).last_damaged_by = actor

		var stripped: int = (target.health as Health).take_ion_damage(amount)
		if stripped > 0:
			_spawn_ion_sparks(target, stripped)
			DamageNumber.spawn(target, stripped, Globals.blue)


## The shield hit's burst, sized by what came off rather than the authored
## hit, and always in shield blue: ion never reaches the hull.
func _spawn_ion_sparks(target: Node, stripped: int) -> void:
	var hit: Node = _hit_particles_scene.instantiate()
	hit.color = Globals.blue
	hit.amount = 10 * stripped
	if effect_source is Node2D and target is Node2D:
		hit.rotation = (PI / 2.0) + (effect_source as Node2D).global_position.angle_to_point(
			(target as Node2D).global_position
		)
	target.add_child(hit)
