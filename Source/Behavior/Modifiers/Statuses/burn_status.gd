class_name BurnStatus
extends StatusModifier
## Each round, before the ship acts, it takes damage equal to its Burn, then
## the Burn drops by one. Five Burn is 5 + 4 + 3 + 2 + 1 over five rounds.

## Burn the ship loses each round, after it burns.
const LOST_PER_TICK: int = 1

## The player's burn wash: a faint flash of the fire over the whole screen as
## the tick lands, on top of the hull hit's red edges.
const _PLAYER_WASH_ALPHA: float = 0.25
const _PLAYER_WASH_SECONDS: float = 0.25

## The hit the player's burn just queued, until it comes up to resolve.
var _tick_hit: DamageEvent


func _init() -> void:
	# First to see its own tick hit, so the burn burns down however anything
	# after it rules on that hit (a death save canceling it).
	priority = 0


static func rule_values() -> Dictionary:
	return {"lost": LOST_PER_TICK}


func on_status_tick() -> void:
	var ship: Node2D = host()
	if ship == null or _host_engine == null:
		return

	# On an enemy, the player lit it, so it is the player's damage: hitting a
	# neutral ship with it angers that ship like any other attack. On the
	# player it is the ship's own fire, like the redline's bleed. Either way no
	# tile or ship is the source, so it never cashes in Exposed or an Amplifier.
	var event: DamageEvent = DamageEvent.new()
	event.actor = Globals.player
	event.amount = stacks
	event.targets = [ship]
	if is_on_player():
		# The player's burn announces itself and burns down as the hit comes
		# up (on_before_event), so its beat plays right before the damage.
		_tick_hit = event
		_host_engine.queue_event(event)
		return
	_host_engine.queue_event(event)

	announce_triggered()
	consume(LOST_PER_TICK)


func on_before_event(event: EffectEvent, _engine: ScenarioEngine) -> void:
	if _tick_hit == null or event != _tick_hit:
		return
	_tick_hit = null
	await play_player_alert()
	var ship: Node2D = host()
	if ship:
		var tint: Color = get_trigger_color()
		Juice.screen_flash(ship, tint, _PLAYER_WASH_ALPHA, _PLAYER_WASH_SECONDS)
		Juice.sparkle(ship, Juice.anchor_of(ship), tint, 12, 50.0)
	consume(LOST_PER_TICK)


## On an enemy the damage number already says how much it burned for; the
## orange flash and embers say why. The player's burn names itself in
## play_player_alert().
func get_trigger_text() -> String:
	return ""
