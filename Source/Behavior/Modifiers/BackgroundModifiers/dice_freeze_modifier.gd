class_name DiceFreezeModifier
extends Modifier
## No die's face can change while this is active: no reroll, no Bump, no flip
## of 1s and 6s, no merge, no Scrambled turning a die over as it's handed on.
## Whatever a die came up as is what it stays until it next rolls home.
##
## The choke point is EffectEvent.changes_die_values(): every event that
## changes a face says so, and this cancels them all, so a new one is frozen
## without touching this file. The one change made outside an event,
## Scrambled's, asks active_on() instead.


func _init() -> void:
	modifier_name = "Dice Freeze"
	priority = 5    # cancellation; nothing downstream should see the event


func on_before_event(event: EffectEvent, _engine: ScenarioEngine) -> void:
	if event.changes_die_values():
		event.canceled = true
		announce_triggered()


func get_trigger_text() -> String:
	return tr("MOD_TRIGGER_FROZEN")


## The freeze in force on [param engine], or null. For a face change that
## doesn't go through an event, which has to stop itself and call
## announce_triggered() on what this returns.
static func active_on(engine: ScenarioEngine) -> DiceFreezeModifier:
	if engine == null:
		return null
	for mod: Modifier in engine.modifiers:
		if mod is DiceFreezeModifier:
			return mod
	return null
