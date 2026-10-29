class_name ArmEchoEvent
extends EffectEvent
## Puts one EchoModifier in play: the next tile activation runs twice.
##
## One echo per event. A chain that repeats arms one per pass, and each is
## spent by its own activation (see EchoModifier), so an echoed Echo Relay
## repeats the next two tiles rather than one tile four times.


func resolve(engine: ScenarioEngine) -> void:
	var source: Node2D = effect_source as Node2D
	engine.add_modifier(EchoModifier.new(source))
	if is_instance_valid(source) and source.is_inside_tree():
		Juice.callout(source, "ECHO", Globals.yellow)


## Its amount isn't an output: an Amplifier doesn't arm more echoes.
func is_amplifiable() -> bool:
	return false
