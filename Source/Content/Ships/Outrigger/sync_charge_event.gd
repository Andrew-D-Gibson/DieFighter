class_name SyncChargeEvent
extends EffectEvent
## The Outrigger's turn-end charge (OutriggerSync): light pours from the top
## of both pods' thrust columns on the gauge into the drive, and the drive
## gains the lower pod's thrust ([member amount]) as it lands, as far as the
## jump gate.
##
## The charge itself is a ChangeEngineChargeEvent injected behind this one,
## so modifiers see an ordinary charge gain (an engine blackout cancels it).

const _SYNC_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/upgrade_trigger.tres")
## Motes per pip of thrust synced, and at least this many, from each pod.
const _MOTES_PER_PIP: int = 2
const _MIN_MOTES: int = 4

## Both pods were exactly level: the gauge celebrates the sync.
var level: bool = false


## The amount is the pods' thrust copied in, not an output to amplify.
func is_amplifiable() -> bool:
	return false


func resolve(engine: ScenarioEngine) -> void:
	if not is_instance_valid(Globals.player):
		return
	# Worked out now rather than when the turn ended: something queued ahead
	# of it may have moved the drive since.
	var gain: int = mini(amount, Globals.player.missing_charge())
	if gain <= 0:
		return

	# A bare engine (a test) has no tree, and nothing to show.
	var tree: SceneTree = engine.get_tree() if engine.is_inside_tree() else null
	var gauge: SyncGauge = tree.get_first_node_in_group(&"engine_charger") as SyncGauge if tree else null
	if is_instance_valid(gauge) and gauge.is_visible_in_tree():
		Events.play_sound.emit(_SYNC_SFX)
		var into: Vector2 = gauge.get_juice_anchor()
		var motes: int = maxi(_MIN_MOTES, gain * _MOTES_PER_PIP)
		var flight: float = 0.0
		for pod: OutriggerSync.Pod in [OutriggerSync.Pod.PORT, OutriggerSync.Pod.STARBOARD]:
			flight = maxf(flight, Juice.stream(gauge, gauge.get_column_head(pod), into, gauge.charge_color(), motes))
		await tree.create_timer(flight * 0.8).timeout
		if engine.is_shut_down():
			return

	var charge: ChangeEngineChargeEvent = ChangeEngineChargeEvent.new()
	charge.actor = actor
	charge.effect_source = effect_source
	charge.amount = gain
	engine.inject_event(charge)
	if is_instance_valid(gauge):
		gauge.sync_landed(gain, level)
