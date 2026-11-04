extends "res://test/helpers/die_fighter_test.gd"
## HazardThematicVFX: Bespoke thematic trigger VFX for timed background hazards
## (Asteroid Impact, Ion Storm, Solar Flare, Fate Rift) and verification that
## EnvironmentMonitor does not spawn redundant text popups on hazard trigger.

const MONITOR_SCENE: PackedScene = preload(
	"res://Source/Systems/Game/OverheadConsole/EnvironmentMonitor/environment_monitor.tscn"
)
const TILE_SCENE: PackedScene = preload("uid://delq7kb5loqt2")
const DIE_SCENE: PackedScene = preload("res://Source/Systems/Game/Dice/dice.tscn")

var monitor: EnvironmentMonitor
var hazard: BackgroundHazardResource
var background: BackgroundResource


func before_each() -> void:
	super()
	hazard = BackgroundHazardResource.new()
	hazard.hazard_name = "Asteroid Impact"
	hazard.color = Color(0.949, 0.612, 0.365, 1)

	background = BackgroundResource.new()
	background.hazard = hazard

	var bg_mgr: BackgroundManager = autofree(BackgroundManager.new())
	bg_mgr.current_background = background
	Globals.background_manager = bg_mgr
	Globals.show_region_alerts = false


func test_environment_monitor_hazard_trigger_spawns_no_callout_text() -> void:
	monitor = add_child_autofree(MONITOR_SCENE.instantiate())
	Events.start_scenario.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	monitor._hazard = hazard
	monitor._deployed = true
	var damage_numbers_before: int = _count_callouts(get_tree().root)
	Events.hazard_triggered.emit(hazard)
	await get_tree().process_frame

	var damage_numbers_after: int = _count_callouts(get_tree().root)
	assert_eq(damage_numbers_after, damage_numbers_before, "No redundant callout popup on hazard trigger")


func test_asteroid_impact_vfx_completes_and_flashes_tile() -> void:
	var tile: Tile = TILE_SCENE.instantiate()
	tile.tile_resource = preload("res://Source/Content/Tiles/TileResources/damage.tres")
	add_child_autofree(tile)
	tile.global_position = Vector2(160.0, 140.0)

	watch_signals(Events)

	await HazardThematicVFX.play_asteroid_impact(tile)

	assert_signal_emitted(Events, "camera_shake_large")


func test_ion_storm_discharge_completes() -> void:
	var dummy: Node2D = add_child_autofree(Node2D.new())
	dummy.global_position = Vector2(160.0, 90.0)

	watch_signals(Events)

	await HazardThematicVFX.play_ion_storm_discharge(dummy)

	assert_signal_emitted(Events, "camera_shake_large")


func test_solar_flare_sweep_completes() -> void:
	var dummy: Node2D = add_child_autofree(Node2D.new())
	dummy.global_position = Vector2(160.0, 90.0)

	watch_signals(Events)

	await HazardThematicVFX.play_solar_flare_sweep(dummy)

	assert_signal_emitted(Events, "camera_shake_large")


func test_fate_rift_die_flip_spawns_mini_tear() -> void:
	var die: Dice = add_child_autofree(DIE_SCENE.instantiate())
	die.global_position = Vector2(160.0, 90.0)

	HazardThematicVFX.play_fate_rift_die_flip(die)
	var found_tear: bool = false
	for child: Node in die.get_parent().get_children():
		if child is HazardThematicVFX.FateRiftMiniTear:
			found_tear = true
			break
	assert_true(found_tear, "Mini rift tear should be spawned at flipping die")


func test_fate_rift_strike_completes() -> void:
	var dummy: Node2D = add_child_autofree(Node2D.new())
	dummy.global_position = Vector2(160.0, 90.0)

	watch_signals(Events)

	await HazardThematicVFX.play_fate_rift_strike(dummy)

	assert_signal_emitted(Events, "camera_shake_large")


func test_play_hazard_strike_dispatches_by_name() -> void:
	var dummy: Node2D = add_child_autofree(Node2D.new())

	var ion: BackgroundHazardResource = BackgroundHazardResource.new()
	ion.hazard_name = "Ion Storm"
	ion.color = Color("#8df1f4")

	var solar: BackgroundHazardResource = BackgroundHazardResource.new()
	solar.hazard_name = "Solar Flare"
	solar.color = Color("#eed35d")

	var fate: BackgroundHazardResource = BackgroundHazardResource.new()
	fate.hazard_name = "Fate Rift"
	fate.color = Color("#c552f1")

	# Test each dispatches without throwing errors
	await HazardThematicVFX.play_hazard_strike(dummy, ion)
	await HazardThematicVFX.play_hazard_strike(dummy, solar)
	await HazardThematicVFX.play_hazard_strike(dummy, fate)
	pass_test("All hazard strikes dispatched successfully")


func _count_callouts(node: Node) -> int:
	var count: int = 1 if node is DamageNumber else 0
	for child: Node in node.get_children():
		count += _count_callouts(child)
	return count


func test_trail_timer_tolerates_an_asteroid_disappearing_before_its_tail() -> void:
	var rock: Node2D = Node2D.new()
	add_child(rock)
	Juice.trail(rock, Globals.orange, 0.02)
	rock.queue_free()
	await get_tree().create_timer(0.06).timeout
	pass_test("The trailing timer does not capture a freed particle node")
