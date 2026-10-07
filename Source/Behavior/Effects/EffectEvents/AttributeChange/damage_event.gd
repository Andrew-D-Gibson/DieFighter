class_name DamageEvent
extends EffectEvent


var _hit_particles_scene: PackedScene = preload("uid://doi43icsr46q0")
var _explosion_particles_scene: PackedScene = preload("uid://566ykra4buin")


func resolve(_engine: ScenarioEngine) -> void:
	if targets.is_empty():
		return

	for target: Node in targets:
		if not is_instance_valid(target):
			continue

		_spawn_hit_particles(target)

		Globals.state_manager.state = GameStateManager.GameState.IN_COMBAT
		if actor is Player and target is Enemy:
			Events.player_attacked_ship.emit(target, target.scenario_state.faction)

		# Read before the hit lands: afterwards the shields it spent are gone.
		var number_color: Color = Globals.blue if target.health.shields >= amount else Globals.red
		var hull_before: int = target.health.health
		target.health.take_damage(amount)
		if target is Enemy and not target.health.invulnerable:
			DamageNumber.spawn(target, amount, number_color)
		# Player tiles author their own impact hitstop; enemy fire doesn't, so
		# a hit to the hull gets a short one here to give it weight.
		if target is Player and target.health.health < hull_before:
			TimeDirector.hitstop(45)


## Spawn directional hit particles + an explosion at the target's position.
## Color is based on whether the damage will reach HP or be shield-absorbed.
func _spawn_hit_particles(target: Node) -> void:
	# Blue if shields will absorb all the damage, red otherwise.
	var color: Color = Globals.blue if target.health.shields >= amount else Globals.red

	# Directional hit burst: points from source to target.
	var hit: Node = _hit_particles_scene.instantiate()
	hit.color = color
	hit.amount = 10 * amount
	if effect_source:
		hit.rotation = (PI / 2.0) + effect_source.global_position.angle_to_point(
			target.global_position
		)
	target.add_child(hit)

	# Non-directional explosion at the target.
	var explosion: Node = _explosion_particles_scene.instantiate()
	explosion.color = color
	explosion.amount = 2 * amount
	target.add_child(explosion)
