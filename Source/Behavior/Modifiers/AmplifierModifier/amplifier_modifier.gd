class_name AmplifierModifier
extends Modifier

var amplify_amount: int


func _init(tile: Tile, amount: int) -> void:
	modifier_name = "Amplifier"
	affected_node = tile
	amplify_amount = amount
	priority = 20        # flat additive; runs before multipliers
	is_temporary = true
	status_visual_scene = preload("uid://gqptast4ha57")


func on_registered(engine: ScenarioEngine) -> void:
	super.on_registered(engine)
	if is_instance_valid(_visual):
		(_visual as AmplifierVisual).amount = amplify_amount


func on_before_event(event: EffectEvent, _engine: ScenarioEngine) -> void:
	if event.effect_source == affected_node and event.is_amplifiable():
		event.amount += amplify_amount
		if amplify_amount != 0:
			announce_triggered()


func get_trigger_text() -> String:
	return "%+d" % amplify_amount


## Amplifiers stack, so the panel shows one line with their sum: the first
## amplifier on the tile writes it and the rest stay quiet.
func get_info_text() -> String:
	var engine: ScenarioEngine = ScenarioEngine.current()
	if engine == null:
		return ""
	var total: int = 0
	var first: AmplifierModifier = null
	for mod: Modifier in engine.modifiers:
		if mod is AmplifierModifier and mod.affected_node == affected_node:
			total += (mod as AmplifierModifier).amplify_amount
			if first == null:
				first = mod
	if first != self or total == 0:
		return ""
	return "[color=green]Amplified %+d[/color]: this tile's effects get %+d this turn." % [total, total]
