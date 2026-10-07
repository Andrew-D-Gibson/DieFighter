class_name ReceiveDieFromTargetHandler
extends EffectHandler
## The actor takes back a die its first target is holding. Built for the
## player's side first (Repo Beam), but nothing in it is player-only: an enemy
## actor pulls the die into its own queue the same way.


func apply(_data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	var event := ReceiveDieFromTargetEvent.new()
	_stamp(event, context)
	event.targets = context.targets.duplicate()
	engine.inject_event(event)
