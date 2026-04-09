extends Node2D

@onready var engine: ScenarioEngine = $ScenarioEngine

func _ready() -> void:
	# Create a ConditionalEffectData that prints different messages
   # depending on whether the activator die value is odd.
   var cond_data := ConditionalEffectData.new()
   cond_data.category = EffectEnums.Category.CONDITIONAL
   cond_data.subtype  = EffectEnums.ConditionalSubtype.IF_ACTIVATOR_ODD

   var true_step := EffectData.new()
   true_step.category = EffectEnums.Category.UTILITY
   true_step.subtype  = EffectEnums.UtilitySubtype.PRINT_DEBUG
   true_step.string_param = "Die was odd!"
   cond_data.if_true_effects = [true_step]

   var false_step := EffectData.new()
   false_step.category = EffectEnums.Category.UTILITY
   false_step.subtype  = EffectEnums.UtilitySubtype.PRINT_DEBUG
   false_step.string_param = "Die was even!"
   cond_data.if_false_effects = [false_step]

   var chain := EffectChainV2.new()
   chain.effects = [cond_data]

   var my_die: Dice = load("res://Source/Systems/Game/Dice/dice.tscn").instantiate()
   my_die.value = 3

   var context := EffectContext.new()
   context.activator_die = my_die  # set die.value to 3 (odd)
   await chain.play(context, engine)
   await engine.process_event_queue()
   # Should print "Die was odd!"
