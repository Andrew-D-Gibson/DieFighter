class_name RecordDeedEvent
extends EffectEvent
## Counts a deed in the run's ledger, for Fate's hidden conditions.

var deed: String = ""


func is_amplifiable() -> bool:
	return false


func resolve(_engine: ScenarioEngine) -> void:
	if Globals.fate_ledger:
		Globals.fate_ledger.record_deed(deed)
