extends "res://test/helpers/die_fighter_test.gd"
## OverheadConsole: waits up in the ceiling and drops down only while one of
## its readouts needs it. The MoneyIndicator holds it down from the run's
## first credits (or the first payout coin taking off) for the rest of the run;
## a region rule holds it down for the EnvironmentMonitor's flap. It goes back
## up once none of them does.
##
## The console is in the tree, so it listens to the real Events; the signals
## the game would send are emitted by hand. The readouts' timings are cut short
## so the tests don't sit through a real count.

const CONSOLE_SCENE: PackedScene = preload(
	"res://Source/Systems/Game/OverheadConsole/overhead_console.tscn"
)
const RULE: BackgroundModifierResource = preload(
	"res://Source/Resources/BackgroundResources/BackgroundModifiers/dead_systems.tres"
)

var console: OverheadConsole
var money: MoneyIndicator
var monitor: EnvironmentMonitor


func before_each() -> void:
	super()
	Globals.show_region_alerts = false
	Globals.player = make_player()
	console = add_child_autofree(CONSOLE_SCENE.instantiate())
	money = console.get_node("%MoneyIndicator")
	monitor = console.get_node("%EnvironmentMonitor")
	money.grace_period = 0.01
	money.max_countdown_time = 0.05


func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


## Long enough for a short count to finish and the deferred answer.
func _outlast_the_count() -> void:
	await wait_seconds(0.5)
	await _settle()


func test_it_starts_up_in_the_ceiling() -> void:
	await _settle()
	assert_false(console._down)
	assert_false(console.visible)


func test_the_first_credits_bring_it_down_for_good() -> void:
	Globals.player.money = 12
	await _settle()
	assert_true(console._down, "down once credits come in")
	assert_true(console.visible)

	await _outlast_the_count()
	assert_eq(money.money_label.text, "12", "the count finished")
	assert_true(console._down, "still down once the count settles")

	Globals.player.money = 0
	await _outlast_the_count()
	assert_true(console._down, "still down with the credits spent")


func test_a_save_from_partway_through_a_run_brings_it_down() -> void:
	var save: GameSaveResource = GameSaveResource.new()
	save.run_stats = {"credits_earned": 20}
	Events.load_game_save.emit(save)
	await _settle()
	assert_true(console._down, "credits were earned, even if they're spent")


func test_a_fresh_save_leaves_it_up() -> void:
	Events.load_game_save.emit(GameSaveResource.new())
	await _settle()
	assert_false(console._down)


## A stand-in coin: the readout only cares when it leaves the tree. A real
## one drifts and can land in the catch area before the test is done.
func test_the_first_coin_brings_it_down_before_any_credits_land() -> void:
	var coin: Node = autofree(Node.new())
	add_child(coin)
	money.track_coin(coin)
	await _outlast_the_count()
	assert_true(console._down, "a coin is on its way")

	remove_child(coin)
	await _outlast_the_count()
	assert_false(console._down, "it never paid out, so no credits yet")


func test_a_region_rule_holds_it_down_before_any_credits() -> void:
	Events.start_scenario.emit()
	Events.background_modifier_applied.emit(RULE)
	await _outlast_the_count()
	assert_true(console._down, "the rule still needs the flap")
	assert_true(console.is_requested(&"environment"))
	assert_false(console.is_requested(&"credits"))

	Events.jump.emit()
	await _settle()
	monitor._motion_tween.custom_step(5.0)
	await _settle()
	assert_false(console._down, "up once the flap has folded")


func test_the_flap_waits_for_the_console_to_land() -> void:
	Events.start_scenario.emit()
	Events.background_modifier_applied.emit(RULE)
	await _settle()
	assert_almost_eq(monitor._arm.scale.y, 0.0, 0.01, "still folded while the console drops")
	assert_false(monitor._clickable.input_pickable)

	monitor._motion_tween.custom_step(5.0)
	assert_almost_eq(monitor._arm.scale.y, 1.0, 0.01)
	assert_true(monitor._clickable.input_pickable)


func test_coins_aim_where_the_readout_will_be_not_where_it_is() -> void:
	await _settle()
	var resting: Vector2 = console.global_position + money.position
	assert_ne(money.global_position, resting, "stowed, it's up in the ceiling")
	assert_eq(money.coin_target(), resting)
