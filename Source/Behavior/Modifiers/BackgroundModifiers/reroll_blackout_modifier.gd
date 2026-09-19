class_name RerollBlackoutModifier
extends Modifier
## Dice cannot be rerolled while this is active.
##
## Freezes the luck axis specifically: whatever the dice came up as is what
## the player has to work with. Aimed squarely at builds that lean on
## rerolling into a good face — a region that is cheap for one build and
## punishing for another is the whole point of terrain.


func _init() -> void:
	modifier_name = "Reroll Blackout"
	priority = 5    # cancellation; nothing downstream should see the event
	is_temporary = false


func on_before_event(event: EffectEvent, _engine: ScenarioEngine) -> void:
	if event is RerollActivatorEvent or event is RerollAllDiceEvent:
		event.canceled = true
