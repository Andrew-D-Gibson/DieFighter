extends Node2D

@onready var engine: ScenarioEngine = $ScenarioEngine

func _ready() -> void:
	var test_effect_data = EffectData.new()
	test_effect_data.category = EffectEnums.Category.UTILITY
	test_effect_data.subtype = EffectEnums.UtilitySubtype.PRINT_DEBUG
	test_effect_data.string_param = "Hello Effect Chain V2!"
	
	var context := EffectContext.new()
	
	var chain = EffectChainV2.new()
	chain.effects = [test_effect_data] as Array[EffectData]

	await chain.play(context, engine)
	await engine.process_event_queue()
