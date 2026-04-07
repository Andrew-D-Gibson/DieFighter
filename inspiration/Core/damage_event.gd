## DamageEvent
## ============================================================
## Resolves damage against one or more targets.
##
## This event is created by DealDamageHandler and carries:
##   - targets   : the nodes to damage (already set by a targeting handler)
##   - amount    : base damage, potentially modified by Modifier before-hooks
##   - actor     : who is dealing the damage (for state/signal purposes)
##
## Resolution:
##   For each target, this event:
##     1. Spawns directional hit particles and explosion particles.
##     2. Updates game state (IN_COMBAT) if a player is attacking an enemy.
##     3. Emits Events.player_attacked_ship for scenario tracking.
##     4. Calls target.health.take_damage(amount).
##
## NOTE ON PARTICLES:
##   Particle color is decided at resolution time based on shield vs. HP:
##     - Blue  → damage will be fully absorbed by shields
##     - Red   → damage will hit HP (at least partially)
##
## FUTURE EXTENSION:
##   Particle spawning could be extracted into a separate SpawnParticlesEvent
##   enqueued as a follow-up, enabling visual-only event processing or headless
##   simulation mode. For now, particles live here for simplicity.
## ============================================================

class_name DamageEvent
extends EffectEvent

# Preload the particle scenes. These UIDs match the existing project assets.
var _hit_particles_scene: PackedScene = preload("uid://doi43icsr46q0")
var _explosion_particles_scene: PackedScene = preload("uid://566ykra4buin")


func resolve(_engine: ScenarioEngine) -> void:
	if targets.is_empty():
		return

	for target: Node in targets:
		if not is_instance_valid(target):
			continue

		_spawn_hit_particles(target)

		# Update global game state and emit scenario signals when the player
		# attacks an enemy. This mirrors what DamageEffect used to do.
		if actor is Player and target is Enemy:
			Globals.state_manager.state = GameStateManager.GameState.IN_COMBAT
			Events.player_attacked_ship.emit(target, target.scenario_state.faction)

		target.health.take_damage(amount)


# ── Private ────────────────────────────────────────────────────────────────────

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
