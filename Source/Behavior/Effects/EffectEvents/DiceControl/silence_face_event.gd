class_name SilenceFaceEvent
extends EffectEvent
## Each target's intent for [member face] does nothing until its table is
## next rolled (Enemy.silence_face()). Counter-Battery: hand the ship a 6 and
## its 6 is the one intent it can't play.

## The face whose intent goes quiet.
var face: int = 0


## A face, not an output: an Amplifier can't silence a different one.
func is_amplifiable() -> bool:
	return false


func resolve(_engine: ScenarioEngine) -> void:
	for target: Node in targets:
		if target is Enemy and is_instance_valid(target) and (target as Enemy).health.health > 0:
			(target as Enemy).silence_face(face)
