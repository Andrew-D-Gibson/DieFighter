class_name NoEscapeModifier
extends Modifier
## Holds the ship in combat without disabling charge-based systems.


func _init() -> void:
	modifier_name = "No Escape"
	prevents_fleeing = true
	priority = 5
