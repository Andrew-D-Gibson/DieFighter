class_name SailSettleEvent
extends EffectEvent
## The end of the Outrigger's sail moment (OutriggerSail): holds the queue
## until every die it handed to a ship has landed, since EnemyTurn only waits
## for beams before it starts, and the sail's own beams set off after that.


func is_amplifiable() -> bool:
	return false


func resolve(engine: ScenarioEngine) -> void:
	await TractorBeam.wait_for_landings(engine.get_tree())
