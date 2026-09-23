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
	Events.load_game_save.connect(_load_game_save)


## Picks the tallies up from the save. Also re-baselines the money tracker on
## the saved balance, which Player restores through set_money: without that,
## every Continue counted the whole bank as credits earned. Works whichever of
## the two load_game_save listeners runs first — both land on absolute values.
func _load_game_save(game_save: GameSaveResource) -> void:
	_last_money = game_save.money
	# A save from before stats were recorded restores to zeros, which beats
	# the bank-as-earnings count set_money may already have added.
	sectors_reached = game_save.run_stats.get("sectors_reached", game_save.sector_index + 1)
	encounters_cleared = game_save.run_stats.get("encounters_cleared", 0)
	ships_destroyed = game_save.run_stats.get("ships_destroyed", 0)
	credits_earned = game_save.run_stats.get("credits_earned", 0)


func get_state() -> Dictionary:
	return {
		"sectors_reached": sectors_reached,
		"encounters_cleared": encounters_cleared,
		"ships_destroyed": ships_destroyed,
		"credits_earned": credits_earned,
	}


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
