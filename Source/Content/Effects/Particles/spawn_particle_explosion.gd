class_name SpawnParticleExplosionEffect
extends Effect

@export var color: Color
@export var amount: int = 36

enum Location {
	TARGETS,
	SOURCE
}
@export var location: Location

var _particle_explosion_scene: PackedScene = load("uid://566ykra4buin")


func play(effect_variables: EffectVariables) -> void:
	if location == Location.TARGETS:
		if len(effect_variables.targets) <= 0:
			print("SpawnParticleExplosionEffect does not have a target object to spawn particles in the tree!")
			return
			
		for target in effect_variables.targets:
			if not target:
				continue
				
			var particles: CPUParticles2D = _particle_explosion_scene.instantiate()
			particles.color = color
			particles.amount = amount
			
			target.add_child(particles)
		
			
	elif location == Location.SOURCE:
		if not effect_variables.effect_source:
			print("SpawnParticleExplosionEffect does not have a source object to spawn particles in the tree!")
			return
			
		var particles: CPUParticles2D = _particle_explosion_scene.instantiate()
		particles.color = color
		particles.amount = amount
			
		effect_variables.effect_source.add_child(particles)
