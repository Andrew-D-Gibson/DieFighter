class_name SailCatchEvent
extends EffectEvent
## One die in hand charging the Outrigger's sail at the end of a turn
## (OutriggerSail): a stream of light runs from the die up the mast, the drive
## gains the die's face as it lands, as far as the jump gate, and the die then
## goes to the target like any spent die.
##
## The charge and the hand-off are a ChangeEngineChargeEvent and a
## GiveDieToTargetEvent injected behind this one, so modifiers see an
## ordinary charge gain and an ordinary die given away.

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
		engine.inject_event(OutriggerSail.hand_off(die))
		return

	var gauge: Node2D = engine.get_tree().get_first_node_in_group(&"engine_charger") as Node2D
	var color: Color = SailGauge.SAIL_COLOR
	Juice.die_flare(die, color)
	Events.play_sound.emit(_SAIL_SFX)
	# The light pours into the foot of the mast, then climbs it (the gauge
	# plays the climb when it lands).
	var into: Vector2 = gauge.get_foot_anchor() if is_instance_valid(gauge) and gauge.has_method("get_foot_anchor") \
			else Juice.engine_anchor(Globals.player)
	var flight: float = Juice.stream(Globals.player, die.global_position, into, color, die.value * 2 + 4)

	await engine.get_tree().create_timer(flight * (0.6 if order == 0 else 0.5)).timeout
	if engine.is_shut_down():
		return

	var charge: ChangeEngineChargeEvent = ChangeEngineChargeEvent.new()
	charge.actor = actor
	charge.effect_source = effect_source
	charge.amount = gain
	engine.inject_event(charge)
	# Charged, the die carries on to the target: a spent die, like any other.
	if is_instance_valid(die):
		engine.inject_event(OutriggerSail.hand_off(die))

	if is_instance_valid(gauge) and gauge.has_method("catch_light"):
		gauge.catch_light(gain, last, order)
