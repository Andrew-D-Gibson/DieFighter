class_name NoEvasionModifier
extends Modifier
## Every enemy hit lands: the drive's charge buys no evasion here.
##
## The Reckoning's sky (RECKONING_ENDINGS.md §1). Its escape is the engine
## charger filling toward three drives' worth and never banking away, so
## evasion (EvasionModifier, 3% a charge) would sit at its cap for most of
## the fight. Fleeing stays possible: a full bank is the way out.


func _init() -> void:
	modifier_name = "No Evasion"
	prevents_evasion = true
	priority = 5
