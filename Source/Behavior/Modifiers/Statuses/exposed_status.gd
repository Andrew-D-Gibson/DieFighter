class_name ExposedStatus
extends StatusModifier
## The next hit a tile lands on the ship deals extra damage equal to its
## Exposed, and spends all of it. Stacking Exposed sets up one big hit.
##
## Only single-target hits cash it in: a DamageEvent carries one amount for
## all its targets, so an area hit would hand the bonus to every ship. Burn
## and other sourceless damage don't count either — it has to be a tile.
##
## Priority 25: a flat addition, alongside the Amplifier, before multipliers.


func _init() -> void:
	status_id = &"exposed"
	display_name = "Exposed"
	title_color = "red"
	icon = preload("res://Assets/Textures/Statuses/exposed.png")
	info_icon = preload("res://Assets/Textures/Statuses/exposed_info.png")
	priority = 25
	is_temporary = false


func on_before_event(event: EffectEvent, _engine: ScenarioEngine) -> void:
	if event is not DamageEvent or stacks <= 0:
		return
	if event.effect_source is not Tile:
		return
	if event.targets.size() != 1 or event.targets[0] != affected_node:
		return
	if event.amount <= 0:
		return

	event.amount += stacks
	consume(stacks)
