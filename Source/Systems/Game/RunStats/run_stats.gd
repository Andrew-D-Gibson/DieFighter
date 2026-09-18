class_name RunStats
extends Node
## Tallies what the player actually did this run, for the end-of-run summary.
##
## Deliberately small: four numbers a player can read in one glance and compare
## against their last attempt. A run that ends with nothing to say about it is a
## run that doesn't invite another one.

var sectors_reached: int = 1
var encounters_cleared: int = 0
var ships_destroyed: int = 0
var credits_earned: int = 0

## Last seen money total, so credit *gains* can be separated from spending.
var _last_money: int = 0


func _ready() -> void:
	Globals.run_stats = self

	Events.sector_advanced.connect(func(sector_index: int) -> void:
		sectors_reached = sector_index + 1
	)
	Events.combat_finished.connect(func() -> void:
		encounters_cleared += 1
	)
	Events.enemy_left.connect(_on_enemy_left)
	Events.set_money.connect(_on_money_changed)


## enemy_left also fires when a ship flees or when combat ends peacefully, so
## only count the ones that actually died.
func _on_enemy_left(ship: Enemy, _faction: ScenarioManager.Faction) -> void:
	if is_instance_valid(ship) and ship.health.health <= 0:
		ships_destroyed += 1


func _on_money_changed(value: int) -> void:
	if value > _last_money:
		credits_earned += value - _last_money
	_last_money = value


## One-line arcade-style summary for the end-of-run screen.
func get_summary_text() -> String:
	var total_sectors: int = Globals.state_manager.demo_sector_count
	return "SECTOR %d/%d   %d ENCOUNTERS   %d SHIPS DOWN   %d CREDITS" % [
		sectors_reached, total_sectors, encounters_cleared, ships_destroyed, credits_earned
	]
