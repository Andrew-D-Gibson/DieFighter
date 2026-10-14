extends StatusModifier
## A status that only reports its tick, for tests about when statuses tick.

signal ticked()


func on_status_tick() -> void:
	ticked.emit()
