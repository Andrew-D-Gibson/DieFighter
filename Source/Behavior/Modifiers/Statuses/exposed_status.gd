class_name ExposedStatus
extends StatusModifier
## Every hit the other side lands on the ship deals extra damage equal to its
## Exposed, and spends 1 of it: a tile's hit on an enemy, an enemy's on the
## player. Spending one at a time rather than all at once keeps a big stack
## from cashing in as a single overwhelming hit.
##
## Only single-target hits cash it in: a DamageEvent carries one amount for
## all its targets, so an area hit would hand the bonus to every ship. Burn
## and other sourceless damage don't count either — it has to be a tile or
## a ship.
##
## Priority 25: a flat addition, alongside the Amplifier, before multipliers.


func _init() -> void:
	status_id = &"exposed"
	display_name = "Exposed"
	color = Globals.red
	icon = preload("res://Assets/Textures/Statuses/exposed.png")
	info_icon = preload("res://Assets/Textures/Statuses/exposed_info.png")
	priority = 25


func on_before_event(event: EffectEvent, _engine: ScenarioEngine) -> void:
	if event is not DamageEvent or stacks <= 0:
		return
	if not _is_hostile_hit(event):
		return
	if event.targets.size() != 1 or event.targets[0] != affected_node:
		return
	if event.amount <= 0:
		return

	event.amount += stacks
	announce_triggered()
	consume(1)


## A hit from the side this ship is fighting: a tile's for an enemy, an enemy
## ship's for the player.
func _is_hostile_hit(event: EffectEvent) -> bool:
	if is_on_player():
		return event.effect_source is Enemy
	return event.effect_source is Tile
