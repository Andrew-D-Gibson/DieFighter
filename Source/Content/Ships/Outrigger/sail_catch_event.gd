class_name SailCatchEvent
extends EffectEvent
## One die in hand charging the Outrigger's sail at the end of a turn
## (OutriggerSail): a stream of light runs from the die up the mast, and the
## drive gains the die's face as it lands, as far as the jump gate.
##
## The charge itself is a ChangeEngineChargeEvent injected behind this one,
## so modifiers that block or cap charge see an ordinary charge gain.

const _SAIL_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/upgrade_trigger.tres")

## Which die of this turn's catch this is, from 0. Later dice wait a beat less,
## so a full hand reads as one rising sweep rather than a queue.
var order: int = 0
## The last die of the catch: the gauge gets to celebrate after it lands.
var last: bool = false


## The amount is a die face copied in, not an output to amplify.
func is_amplifiable() -> bool:
	return false


func resolve(engine: ScenarioEngine) -> void:
	var die: Dice = activator_die as Dice
	if not is_instance_valid(die) or not is_instance_valid(Globals.player):
		return
	# Worked out now rather than when the turn ended: an earlier die may have
	# filled the drive, or something else moved it since.
	var gain: int = mini(amount, Globals.player.missing_charge())
	if gain <= 0:
		return

	var gauge: Node2D = engine.get_tree().get_first_node_in_group(&"engine_charger") as Node2D
	var color: Color = Globals.purple
	Juice.die_flare(die, color)
	Events.play_sound.emit(_SAIL_SFX)
	var flight: float = Juice.stream(Globals.player, die.global_position,
			Juice.engine_anchor(Globals.player), color, die.value + 4)

	if die.holographic:
		_burn_hologram(die)

	# Charge starts climbing as the first motes reach the mast, so the gauge
	# rises with the light rather than after it.
	await engine.get_tree().create_timer(flight * (0.55 if order == 0 else 0.45)).timeout
	if engine.is_shut_down():
		return

	var charge: ChangeEngineChargeEvent = ChangeEngineChargeEvent.new()
	charge.actor = actor
	charge.effect_source = effect_source
	charge.amount = gain
	engine.inject_event(charge)

	if is_instance_valid(gauge) and gauge.has_method("catch_light"):
		gauge.catch_light(gain, last)


## A hologram is light already: it pours into the sail and is gone.
func _burn_hologram(die: Dice) -> void:
	if die.host_queue:
		die.host_queue.remove(die)
	Juice.sparkle(Globals.player, die.global_position, Globals.blue, 10, 30.0, true)
	die.queue_free()
