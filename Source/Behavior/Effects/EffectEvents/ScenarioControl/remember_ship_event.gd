class_name RememberShipEvent
extends EffectEvent
## A ship the player saved or spared remembers them (LORE.md §7: allies fill
## the gap the horizon eats).

var kind: String = FateLedger.KIND_ALLY


func is_amplifiable() -> bool:
	return false


func resolve(_engine: ScenarioEngine) -> void:
	if Globals.fate_ledger and actor is Enemy and is_instance_valid(actor):
		Globals.fate_ledger.remember_ship(actor as Enemy, kind)
