class_name SpawnExplosionParticlesEvent
extends EffectEvent

## Particle tint. Set from EffectData.color.
var color: Color = Color.WHITE

var _explosion_particles_scene: PackedScene = preload("uid://566ykra4buin")


func resolve(_engine: ScenarioEngine) -> void:
	var spawn_nodes: Array[Node]
	
	if not targets.is_empty():
		spawn_nodes = targets as Array[Node]
	elif is_instance_valid(effect_source):
		spawn_nodes = [effect_source]
	else:
		return

	for node: Node in spawn_nodes:
		if not is_instance_valid(node):
			continue
		var particles: Node = _explosion_particles_scene.instantiate()
		particles.color = color
		particles.amount = max(1, amount) * 2
		node.add_child(particles)
