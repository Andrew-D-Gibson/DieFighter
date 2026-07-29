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


func on_before_event(event: EffectEvent, _engine: ScenarioEngine) -> void:
	if event.effect_source == affected_node:
		#and (event is DamageEvent or event is AddAmplifierModifierEvent):
		event.amount += amplify_amount
