## DoubleDamageModifier
## ============================================================
## Example Modifier: doubles the player's outgoing damage.
##
## This replaces what used to be a MULTIPLICATIVE GlobalModifier
## in the old GlobalModifierManager system.
##
## HOW TO REGISTER:
##   When setting up the ScenarioEngine at scenario start, do:
##     engine.add_modifier(DoubleDamageModifier.new())
##   Or, if this comes from a player upgrade resource:
##     engine.add_modifier(my_upgrade.create_modifier())
##
## PRIORITY: 50 (multiplicative range, runs after additive flat modifiers)
## ============================================================

class_name DoubleDamageModifier
extends Modifier


func _init() -> void:
	priority = 50
	modifier_name = "Double Damage"


func on_before_event(event: EffectEvent, _engine: ScenarioEngine) -> void:
	# Only apply to damage events where the player is the attacker.
	if not event is DamageEvent:
		return
	if event.actor != Globals.player:
		return

	event.amount *= 2
