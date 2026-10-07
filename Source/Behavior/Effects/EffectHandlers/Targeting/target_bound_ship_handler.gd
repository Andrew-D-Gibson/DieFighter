class_name TargetBoundShipHandler
extends EffectHandler
## Targets the ship an enemy action was bound to when its slot was rolled.
##
## The binding is chosen up front so the intent can name the ship before the
## player commits a die; this step only checks it still stands. A bound ship
## that has since left (and couldn't be rebound) leaves no target, and the
## chain's die hand-off falls back the way it does for any empty target.
## Serves both TARGET_BOUND_ALLY and TARGET_BOUND_HOSTILE_SHIP: which kind of
## ship to bind is the binder's question, not this step's.


func apply(_data: EffectData, context: EffectContext, _engine: ScenarioEngine) -> void:
	var targets: Array[Node] = []
	var bound: Node = context.bound_target
	if is_instance_valid(bound) and bound is Enemy and (bound as Enemy).health.health > 0:
		targets.append(bound)
	context.targets = targets
