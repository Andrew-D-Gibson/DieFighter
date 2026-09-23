class_name EnemyManager
extends Node2D

## Resolution of the path's screen-x lookup table. Fine enough that the error
## in turning a screen x back into a path proportion is under a pixel.
const _PATH_SAMPLES: int = 96

var enemies: Array[Enemy]

@export var enemy_base_scene: PackedScene
@export var spawning_path: Path2D

@export var fly_in_range: int = 100
@export var fly_in_time: float = 1.5

@export_category('Formation')
## How far in from each end of the spawning path the formation keeps its ships.
## The path runs to the edges of the screen; ships standing there would be half
## off it, and their health bars entirely so.
@export var formation_edge_margin: float = 36.0

## Closest two ships will ever stand. See [member EnemyFormation.min_ship_spacing].
@export var formation_min_spacing: float = 40.0

## How long a ship takes to slide to a new spot when the formation changes.
@export var reflow_time: float = 0.75

## Screen-space width a ship parked by a scenario effect holds against the rest
## of the formation, so nobody reflows on top of it.
@export var pinned_ship_footprint: float = 40.0

var enemies_jumping: bool = false
var screen_size: Vector2 = Vector2(320, 180)

## Decides who stands where. See [EnemyFormation] for why placement is derived
## rather than authored.
var formation: EnemyFormation = EnemyFormation.new()

## Sampled screen-space x of the spawning path, evenly spaced in path
## proportion. The formation works in screen x; this turns an answer back into
## a point on the curve.
var _path_x_samples: PackedFloat32Array = PackedFloat32Array()

## The move each ship is currently in the middle of, so a second reflow
## arriving mid-slide replaces the first instead of racing it.
var _active_moves: Dictionary[Enemy, Tween] = {}

## Ships that have been spawned but have not yet flown in. They are part of the
## formation, but they sit above their slot rather than on it, and they snap
## rather than slide if the formation changes mid-arrival.
var _awaiting_fly_in: Array[Enemy] = []

func _ready() -> void:
	Globals.enemy_manager = self
	
	# Force the baking on the curve where we spawn enemies
	spawning_path.curve.get_baked_points()
	_build_path_sample_table()
	
	Events.player_turn_over.connect(func() -> void:
		# Don't automatically run the turn if the tutorial is handling it
		if Globals.tutorial_controls_enemy_turns:
			return
		run_enemy_turn()
	)
	Events.enemy_left.connect(func(ship: Enemy, _faction: ScenarioManager.Faction) -> void:
		if ship in enemies:
			enemies.erase(ship)
		_awaiting_fly_in.erase(ship)
		_active_moves.erase(ship)
		formation.clear_reservation(_pin_key(ship))
		# The survivors close the gap the loss left behind.
		refresh_formation()
	)
	Events.jump.connect(start_enemy_jump_animation)
	Events.load_scenario.connect(func(scenario: ScenarioResource) -> void:
		# Clean up any remaining jumping enemies before loading new scenario
		if enemies_jumping:
			delete_all_enemies()
		
		# Spawn the starting ships
		if len(scenario.starting_enemies) > 0:
			spawn_enemies(scenario.starting_enemies)
	)
	Events.start_scenario.connect(start_enemy_fly_in)
	
	
func _process(delta: float) -> void:
	if enemies_jumping:
		_update_jumping_enemies(delta)
	
	
func spawn_enemies(enemies_to_spawn: Array[EnemyStateRewardResource]) -> void:
	for spawn: EnemyStateRewardResource in enemies_to_spawn:
		var enemy: Enemy = enemy_base_scene.instantiate()
		enemy.enemy_resource = spawn.enemy_resource
		enemy.reward_resource = spawn.reward_resource
		enemy.scenario_state = spawn.starting_state
		# Set before add_child: Enemy._ready() bakes health off this.
		enemy.starting_health_fraction = spawn.starting_health_fraction

		# A scenario can still nail a ship to one spot when the encounter is
		# about where that ship is. Everyone else is placed by the formation.
		if spawn.has_fixed_position():
			enemy.formation_pinned = true
			enemy.position = _resting_position(enemy, spawn.path_location_override)

		enemies.append(enemy)
		_awaiting_fly_in.append(enemy)
		add_child(enemy)

		if enemy.formation_pinned:
			_reserve_pinned_ship(enemy, spawn.path_location_override)

	refresh_formation(false)


func start_enemy_fly_in() -> void:
	_awaiting_fly_in.clear()

	for enemy: Enemy in enemies:
		if len(Enemy.forced_actions) > 0:
			enemy.generate_turn_actions()
			
		var fly_in_tween: Tween = get_tree().create_tween()
		fly_in_tween.tween_property(
			enemy,
			"position",
			enemy.position + Vector2(0, fly_in_range),
			fly_in_time
		).set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)
		
		# Re-enable bobbing animation after spawn tween completes
		await fly_in_tween.finished
		Events.enemy_flew_in.emit()
		enemy.graphics_manager.start_bob_tween()
	
	
func get_point_along_path(proportion: float) -> Vector2:
	var total_length: float = spawning_path.curve.get_baked_length()
	return spawning_path.curve.sample_baked(proportion * total_length)


## The same point in screen space. The curve is a child of this node at the
## origin today, so the two agree — but the formation reasons about where
## things are on screen, and that should not quietly depend on a transform.
func get_global_point_along_path(proportion: float) -> Vector2:
	return spawning_path.to_global(get_point_along_path(proportion))


## Slides a ship to a spot on the path and parks it there. Used both by the
## formation and by scenario effects; a scenario effect additionally pins the
## ship, since a move it asked for should survive the next reflow.
func move_ship_to_point_on_path(ship: Enemy, proportion: float) -> void:
	if not is_instance_valid(ship):
		return

	ship.formation_pinned = true
	_reserve_pinned_ship(ship, proportion)
	refresh_formation()

	await _slide_ship_to(ship, _resting_position(ship, proportion), reflow_time)


## Moves one ship, keeping the bits that have to be switched off while it is
## travelling — the bobbing idle, and the targeting reticle that tracks it —
## in step with the move.
func _slide_ship_to(ship: Enemy, target: Vector2, duration: float) -> void:
	var retarget_indicator: bool = (
		Globals.targeting_computer
		and ship == Globals.targeting_computer.targeted_enemy
	)
	if retarget_indicator:
		Globals.targeting_computer.indicator_bob_tween.kill()
		Globals.targeting_computer.targeting_indicator.visible = false

	ship.moving_in_world = true
	ship.graphics_manager.stop_bob_tween()

	var previous: Tween = _active_moves.get(ship)
	if previous and previous.is_valid():
		previous.kill()

	var tween: Tween = get_tree().create_tween()
	_active_moves[ship] = tween
	tween.tween_property(ship, 'position', target, duration)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN_OUT)
	await tween.finished

	if not is_instance_valid(ship):
		return

	# A move that was superseded leaves the ship to whoever replaced it.
	if _active_moves.get(ship) != tween:
		return
	_active_moves.erase(ship)

	ship.moving_in_world = false
	ship.graphics_manager.start_bob_tween()

	if retarget_indicator and ship == Globals.targeting_computer.targeted_enemy:
		Globals.targeting_computer._move_indicator()


## Re-derives everyone's spot from the roster and whatever space is currently
## free, then moves them there. Cheap enough to call on any change; ships
## already standing in the right place are left alone.
func refresh_formation(animate: bool = true) -> void:
	# Mid-jump the whole formation is drifting off the bottom of the screen on
	# purpose. Anything we did here would fight that.
	if enemies_jumping:
		return

	var members: Array[Enemy] = _formation_members()
	var slots: PackedFloat32Array = formation.solve(members.size())

	for i: int in range(members.size()):
		var enemy: Enemy = members[i]
		var proportion: float = proportion_for_screen_x(slots[i])
		var target: Vector2 = _resting_position(enemy, proportion)

		# A ship that has not flown in yet is holding above its slot. Snap it
		# across so its arrival tween still ends where the formation wants it.
		if enemy in _awaiting_fly_in:
			enemy.position = target + Vector2(0, -fly_in_range)
			continue

		if animate:
			if not enemy.position.is_equal_approx(target):
				_slide_ship_to(enemy, target, reflow_time)
		else:
			enemy.position = target


## Claims screen-space x for something that is not a ship — the shop panel, the
## tutorial's popups — so the formation stands clear of it.
func reserve_formation_space(key: StringName, min_x: float, max_x: float) -> void:
	if formation.reserve(key, Vector2(min_x, max_x)):
		refresh_formation()


## Hands that space back.
func clear_formation_space(key: StringName) -> void:
	if formation.clear_reservation(key):
		refresh_formation()


## Everyone the formation is free to place: alive, still valid, and not nailed
## down by a scenario effect. Scenario order is left-to-right order.
func _formation_members() -> Array[Enemy]:
	var members: Array[Enemy] = []
	for enemy: Enemy in enemies:
		if not is_instance_valid(enemy) or enemy.formation_pinned:
			continue
		members.append(enemy)
	return members


## Where a ship sits when it is standing still at [param proportion] along the
## path. The graphics offset is part of the resting spot rather than something
## the spawn adds once, so a ship does not lurch the first time it reflows.
func _resting_position(ship: Enemy, proportion: float) -> Vector2:
	return get_point_along_path(proportion) + ship.enemy_resource.graphics_scene_offset


## A pinned ship holds its own patch of screen, so the rest of the formation
## reflows around it instead of through it.
func _reserve_pinned_ship(ship: Enemy, proportion: float) -> void:
	var centre_x: float = get_global_point_along_path(proportion).x
	formation.reserve(
		_pin_key(ship),
		Vector2(centre_x - pinned_ship_footprint * 0.5, centre_x + pinned_ship_footprint * 0.5)
	)


func _pin_key(ship: Enemy) -> StringName:
	return StringName("ship_%d" % ship.get_instance_id())


## Samples the path's screen-space x at even steps along it, so a screen x can
## be turned back into a proportion. The curve runs left to right without
## doubling back, which is what makes that inversion well defined.
func _build_path_sample_table() -> void:
	_path_x_samples = PackedFloat32Array()
	for i: int in range(_PATH_SAMPLES + 1):
		_path_x_samples.append(
			get_global_point_along_path(float(i) / float(_PATH_SAMPLES)).x
		)

	formation.usable_span = Vector2(
		_path_x_samples[0] + formation_edge_margin,
		_path_x_samples[-1] - formation_edge_margin
	)
	formation.min_ship_spacing = formation_min_spacing


## The point along the path that sits at screen x [param target_x].
func proportion_for_screen_x(target_x: float) -> float:
	if _path_x_samples.is_empty():
		return 0.5

	for i: int in range(1, _path_x_samples.size()):
		var left: float = _path_x_samples[i - 1]
		var right: float = _path_x_samples[i]
		if target_x > right:
			continue

		var step: float = 1.0 / float(_PATH_SAMPLES)
		if is_equal_approx(left, right):
			return float(i - 1) * step
		var within: float = clampf((target_x - left) / (right - left), 0.0, 1.0)
		return (float(i - 1) + within) * step

	return 1.0


func get_alive_enemies() -> Array[Enemy]:
	_remove_dead_enemies()
	return enemies
	
	
func get_faction_ships(faction: ScenarioManager.Faction) -> Array[Enemy]:
	var faction_ships: Array[Enemy] = []
	_remove_dead_enemies()
	for enemy: Enemy in enemies:
		if enemy.scenario_state.faction == faction:
			faction_ships.append(enemy)
	return faction_ships
	

func _remove_dead_enemies() -> void:
	for i: int in range(len(enemies)-1, -1, -1):
		if not enemies[i] or enemies[i].health.health == 0:
			enemies.remove_at(i)
			
			
func run_enemy_turn() -> void:
	# Create a copy of the enemies array to iterate over
	# This prevents issues if enemies are removed during iteration
	var current_enemies: Array[Enemy] = enemies.duplicate()
	
	var engine: ScenarioEngine = ScenarioEngine.current()
	if not engine:
		return
	var queued_anything: bool = false
	for enemy: Enemy in current_enemies:
		if not enemy or not is_instance_valid(enemy):
			continue
			
		if len(enemy.dice_manager.queue) <= 0:
			continue
			
		enemy.run_turn()
		queued_anything = true

	# finished_processing_queue only fires if there was a queue to finish. An
	# enemy turn where nobody was handed a die queues nothing, and a turn that
	# resolves without ever yielding is already done by the time we get here —
	# awaiting the signal in either case hangs the game, because the player's
	# next turn is started by enemy_turn_over and it would never be emitted.
	if queued_anything and engine.currently_processing_queue:
		await engine.finished_processing_queue
	else:
		await get_tree().process_frame

	# A jump resolved inside the turn shuts the engine down, which releases
	# the await above. That turn belongs to a scenario we have already left;
	# announcing its end would start a player turn in the new one.
	if not is_instance_valid(engine) or engine.is_shut_down():
		return

	Events.enemy_turn_over.emit()


func start_enemy_jump_animation() -> void:
	enemies_jumping = true
	for enemy: Enemy in enemies:
		if not enemy or not is_instance_valid(enemy):
			continue
		enemy.moving_in_world = true
		enemy.graphics_manager.stop_bob_tween()
		# Disable clickable region
		if enemy.clickable_region:
			enemy.clickable_region.disabled = true


func _update_jumping_enemies(delta: float) -> void:
	if not Globals.background_manager:
		return
		
	var parallax_level: int = 1  # Match medium debris
	var speed: float = Globals.background_manager.global_speed * \
					  Globals.background_manager.get_parallax_speed(parallax_level)
	
	for i: int in range(len(enemies) - 1, -1, -1):
		var enemy: Enemy = enemies[i]
		if not enemy or not is_instance_valid(enemy):
			enemies.remove_at(i)
			continue
			
		enemy.global_position.y += delta * speed
		
		if enemy.global_position.y > screen_size.y + 50:  # Off-screen offset
			enemy.disconnect_scenario_signals()
			enemy.queue_free()
			enemies.remove_at(i)
	
	# Reset flag when all enemies are gone
	if len(enemies) == 0:
		enemies_jumping = false


func delete_all_enemies() -> void:
	# Needs to be queue_free'ed, not health reduced to 0
	# so we don't spawn rewards
	for i: int in range(len(enemies)-1, -1, -1):
		formation.clear_reservation(_pin_key(enemies[i]))
		enemies[i].disconnect_scenario_signals()
		enemies[i].queue_free()
	enemies = []
	_awaiting_fly_in.clear()
	_active_moves.clear()
	enemies_jumping = false


func kill_all_enemies() -> void:
	damage_all_enemies(10000)
		
		
func shield_all_enemies(amount: int) -> void:
	for enemy: Enemy in enemies:
		enemy.health.change_shields(amount)
		
		
func damage_all_enemies(amount: int) -> void:
	for i: int in range(len(enemies)-1, -1, -1):
		enemies[i].health.take_damage(amount)
		
