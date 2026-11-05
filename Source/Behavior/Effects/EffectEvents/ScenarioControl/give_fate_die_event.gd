class_name GiveFateDieEvent
extends EffectEvent
## The Inbound pilgrim hands the player Fate's Die (LORE.md §5).


func is_amplifiable() -> bool:
	return false


func resolve(_engine: ScenarioEngine) -> void:
	if Globals.fate_ledger:
		Globals.fate_ledger.give_die()
