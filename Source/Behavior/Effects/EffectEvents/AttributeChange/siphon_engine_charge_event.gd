class_name SiphonEngineChargeEvent
extends EffectEvent
## The actor drains [member amount] engine charge from the player.
##
## Plays as a few pulses rather than one transfer: each pulse drops the gauge
## first, so the player sees what they lost, then sends a spurt of motes from
## the gauge to the thief. Draining charge before the motes leave reads as the
## enemy pulling it out; motes first read as a delivery that arrives late.
##
## Takes only what's there, and holds the chain until the last spurt lands.

## The motes' colour.
var color: Color = Color.WHITE

## What was actually taken, once resolved.
var taken: int = 0

## Most pulses a drain is split into. More than this drags on a big siphon.
const _MAX_PULSES: int = 3
## Motes in each pulse's spurt.
const _MOTES_PER_PULSE: int = 5
## How long the gauge gets to visibly drop (its own tween is 0.25 s) before
## that pulse's motes set off.
const _DROP_LEAD_SECONDS: float = 0.12
## Gap between pulses. Shorter than a spurt's flight, so the next drop lands
## while the last motes are still on their way and the drain reads as a pull.
const _PULSE_GAP_SECONDS: float = 0.22


## A drain is a loss, not an output; an Amplifier shouldn't deepen it.
func is_amplifiable() -> bool:
	return false


func resolve(_engine: ScenarioEngine) -> void:
	var player: Player = Globals.player
	if not is_instance_valid(player) or amount <= 0:
		return

	taken = mini(amount, player.engine_charge)
	# A drain is a drain even off an empty drive: whatever retaliates against
	# siphoning answers the attempt.
	if actor is Enemy:
		Events.engine_charge_drained.emit()
	if taken <= 0:
		return

	var pulses: int = mini(taken, _MAX_PULSES)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var flight_seconds: float = 0.0
	for i: int in range(pulses):
		# Spread what's taken as evenly as whole points allow, the remainder
		# going to the earliest pulses.
		var share: int = taken / pulses + (1 if i < taken % pulses else 0)
		player.engine_charge -= share
		await tree.create_timer(_DROP_LEAD_SECONDS).timeout
		flight_seconds = _send_motes()
		if i < pulses - 1:
			await tree.create_timer(_PULSE_GAP_SECONDS).timeout
	if flight_seconds > 0.0:
		await tree.create_timer(flight_seconds).timeout


## Returns how long the spurt takes to arrive, or 0 when there's nothing to
## draw between (the thief already gone).
func _send_motes() -> float:
	var thief: Node2D = actor as Node2D if is_instance_valid(actor) else null
	if thief == null or not thief.is_inside_tree():
		return 0.0
	return Juice.stream(thief, Juice.engine_anchor(Globals.player),
			Juice.anchor_of(thief), color, _MOTES_PER_PULSE)
