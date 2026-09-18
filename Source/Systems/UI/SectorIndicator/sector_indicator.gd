class_name SectorIndicator
extends RichTextLabel
## Shows how far through the run the player is ("SECTOR 2/3").
##
## Sits in the Systems/Map tab strip so it's legible from either view — sector
## depth is run-level information, not map-specific.

## How long the label pulses after the player breaks into a new sector.
const _ADVANCE_FLASH_SECONDS: float = 2.5

## Dimmed so the label sits behind the two tab buttons in the reading order.
const _RESTING_DIM: float = 0.45


func _ready() -> void:
	Events.load_game_save.connect(func(_game_save: GameSaveResource) -> void:
		_refresh()
	)
	Events.sector_advanced.connect(_on_sector_advanced)
	_refresh()


func _refresh() -> void:
	if not Globals.state_manager:
		return

	var sector_number: int = Globals.state_manager.current_game_save.sector_index + 1
	var total: int = Globals.state_manager.demo_sector_count
	text = "[color=%s]SECTOR %d/%d[/color]" % [
		Globals.white.darkened(_RESTING_DIM).to_html(false), sector_number, total
	]


## A new sector is the only thing in a run that resets the whole map, so it
## earns a moment of attention before settling back into the background.
func _on_sector_advanced(sector_index: int) -> void:
	var sector_number: int = sector_index + 1
	var total: int = Globals.state_manager.demo_sector_count
	text = "[color=%s][wave amp=10.0 freq=6.0 connected=1]SECTOR %d/%d[/wave][/color]" % [
		Globals.purple.to_html(false), sector_number, total
	]

	await get_tree().create_timer(_ADVANCE_FLASH_SECONDS).timeout
	_refresh()
