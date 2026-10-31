class_name PhasedStatus
extends StatusModifier
## The next hit from the other side passes straight through the ship: an enemy
## ship's hit on the player, or a tile's hit on an enemy. Each stack lets one
## hit through and is spent doing it.
##
## The hit misses outright rather than landing for 0. The ship is taken out of
## the hit's targets before anything else reads it, so the shields keep every
## point, a death save never sees a blow to save, and nothing that listens for
## being hit or attacked hears it. Any other ship the hit was aimed at still
## takes it.
##
## Burn, hazards and a tile's own cost to the player's hull have no ship on the
## other side behind them, so they get through.
##
## It wears off at the status tick: for the player as the enemy turn ends (so
## a cloak raised on your turn covers the enemy turn that follows it), for an
## enemy as its own turn starts.
##
## Priority 1: a cancellation, ahead of the death save (5) and everything that
## grows or shrinks a hit, which would otherwise read a hit that never lands.


func _init() -> void:
	status_id = &"phased"
	display_name = "Phased"
	color = Globals.blue
	icon = preload("res://Assets/Textures/Statuses/phased.png")
	info_icon = preload("res://Assets/Textures/Statuses/phased_info.png")
	priority = 1


func on_before_event(event: EffectEvent, _engine: ScenarioEngine) -> void:
	if event is not DamageEvent or stacks <= 0 or event.amount <= 0:
		return
	var ship: Node2D = host()
	if ship == null or ship not in event.targets or not _is_hostile_hit(event):
		return

	event.targets.erase(ship)
	if event.targets.is_empty():
		event.canceled = true
	announce_triggered()
	consume(1)


## A hit from the side this ship is fighting: an enemy ship's for the player,
## a tile's for an enemy.
func _is_hostile_hit(event: EffectEvent) -> bool:
	if is_on_player():
		return event.actor is Enemy
	return event.effect_source is Tile


## However many stacks are left, the cloak drops at the tick.
func on_status_tick() -> void:
	consume(stacks)


## The cockpit glass flashes blue as the shot passes through, where the
## player is looking for the hit.
func announce_triggered() -> void:
	super()
	if is_on_player():
		Events.vignette_pulse.emit(get_trigger_color())


func get_trigger_text() -> String:
	return "PHASED"


func is_harmful() -> bool:
	return false
