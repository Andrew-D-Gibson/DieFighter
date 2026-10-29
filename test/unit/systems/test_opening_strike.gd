extends "res://test/helpers/die_fighter_test.gd"
## The opening ambusher's shot keeps its own books: the extra hull a fresh run
## starts with, what a checkpoint takes off for it, and giving it back when
## there's no ship to fire.

const PLAYER_SCENE: PackedScene = preload("res://Source/Systems/Game/Player/player.tscn")

var save: GameSaveResource


func before_each() -> void:
	super()
	save = GameSaveResource.new()
	save.player_max_health = 32
	save.player_health = 24
	Globals.enemy_manager = null


func test_owing_raises_the_runs_hull_by_the_shot() -> void:
	var strike: OpeningStrike = OpeningStrike.owe(save)
	assert_eq(save.player_health, 24 + OpeningStrike.DAMAGE)
	assert_eq(strike.hull_owed(), OpeningStrike.DAMAGE)


func test_owing_stops_at_max_hull() -> void:
	save.player_health = 30
	var strike: OpeningStrike = OpeningStrike.owe(save)
	assert_eq(save.player_health, 32)
	assert_eq(strike.hull_owed(), 2)


func test_a_run_starting_at_full_hull_owes_nothing() -> void:
	save.player_health = 32
	assert_null(OpeningStrike.owe(save))
	assert_eq(save.player_health, 32)


func test_with_no_ship_to_fire_the_hull_is_taken_back() -> void:
	var player: Player = add_child_autofree(PLAYER_SCENE.instantiate())
	Globals.player = player
	var strike: OpeningStrike = OpeningStrike.owe(save)
	player.health.health = save.player_health

	assert_false(strike.arm(save), "nobody to fire it")
	assert_eq(save.player_health, 24)
	assert_eq(player.health.health, 24)
	assert_eq(strike.hull_owed(), 0, "checkpoints take nothing off")
	assert_false(strike.holds_die())


func test_playing_settles_the_debt_once() -> void:
	var strike: OpeningStrike = OpeningStrike.owe(save)
	# Unarmed and with no fight on, it can't fire, but it's still over.
	await strike.play()
	assert_eq(strike.hull_owed(), 0)
	await strike.play()
	assert_eq(strike.hull_owed(), 0, "a second play does nothing")
