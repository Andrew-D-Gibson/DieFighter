class_name HorizonModifier
extends Modifier
## The Reckoning's standing rule: there is no jumping out from inside the
## event horizon. The drive still charges, and the charge goes to the escape
## (ReckoningDirector), so the map's arrows stay dark for the whole fight.


func _init() -> void:
	modifier_name = "Event Horizon"
	prevents_fleeing = true
	priority = 0
