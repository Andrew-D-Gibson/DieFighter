class_name CarveFateFaceEvent
extends EffectEvent
## A choice carves a face into Fate's Die (LORE.md §5).

var face: FateDie.Face = FateDie.Face.BLANK


func is_amplifiable() -> bool:
	return false


func resolve(_engine: ScenarioEngine) -> void:
	if Globals.fate_ledger:
		Globals.fate_ledger.request_carve(face)
