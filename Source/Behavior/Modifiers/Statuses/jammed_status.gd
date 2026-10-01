class_name JammedStatus
extends StatusModifier
## Each die the ship uses does nothing and comes back to the player, spending
## one Jammed.
##
## Rather than cancel the ship's action, which would strand the die in its
## queue, the action is swapped for Do Nothing — whose chain already hands
## the die back.
##
## Priority 35, past the flat-modifier band: anything that later rewrites
## enemy actions should sit below it, so a jam always has the last word.

const _DO_NOTHING: EnemyActionResource = preload("res://Source/Content/Enemies/EnemyActions/EnemyActionResources/do_nothing.tres")


func _init() -> void:
	status_id = &"jammed"
	display_name = "Jammed"
	title_color = "yellow"
	icon = preload("res://Assets/Textures/Statuses/jammed.png")
	info_icon = preload("res://Assets/Textures/Statuses/jammed_info.png")
	priority = 35
	is_temporary = false


func on_before_event(event: EffectEvent, _engine: ScenarioEngine) -> void:
	if event is not EnemyActionEvent or stacks <= 0:
		return
	var action_event: EnemyActionEvent = event as EnemyActionEvent
	if action_event.enemy != affected_node:
		return

	action_event.action = _DO_NOTHING
	consume(1)
