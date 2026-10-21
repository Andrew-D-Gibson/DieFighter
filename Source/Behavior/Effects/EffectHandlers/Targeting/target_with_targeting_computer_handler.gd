class_name TargetWithTargetingComputerHandler
extends EffectHandler

func apply(_data: EffectData, context: EffectContext, _engine: ScenarioEngine) -> void:
	# The ship the die was dropped against, not necessarily the one targeted
	# now: the die may have waited in a queue while the player moved on.
	var target: Enemy = Globals.targeting_computer.target_for(context.activator_die)

	if not is_instance_valid(target):
		context.targets = []
		return

	context.targets = [target as Node]
