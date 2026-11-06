class_name CarveFateFaceEvent
extends EffectEvent
## A choice carves a face into Fate's Die (LORE.md §5).

var face: FateDie.Face = FateDie.Face.BLANK
## The scenario state whose arrival carved it (its file path), so the die can
## name the choice. Empty when the carving didn't come from a ship's state.
var source: String = ""


func is_amplifiable() -> bool:
	return false


func resolve(_engine: ScenarioEngine) -> void:
	if Globals.fate_ledger:
		Globals.fate_ledger.request_carve(face, source)
