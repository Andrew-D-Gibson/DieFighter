class_name SpawnHitParticlesEvent
extends EffectEvent

## Particle tint. Set from EffectData.color.
var color: Color = Color.WHITE

var _hit_particles_scene: PackedScene = preload("uid://doi43icsr46q0")


func resolve(_engine: ScenarioEngine) -> void:
	var spawn_nodes: Array[Node] = targets if not targets.is_empty() else (
		[effect_source] as Array[Node] if is_instance_valid(effect_source) else [] as Array[Node]
	)
	for node: Node in spawn_nodes:
		if not is_instance_valid(node):
			continue
		var particles: Node = _hit_particles_scene.instantiate()
		particles.color = color
		particles.amount = max(1, amount) * 10
		if is_instance_valid(effect_source):
			particles.rotation = (PI / 2.0) + effect_source.global_position.angle_to_point(
				node.global_position
			)
		node.add_child(particles)
