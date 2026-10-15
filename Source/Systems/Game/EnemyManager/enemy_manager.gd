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
## How far in from each end of the spawning path the formation keeps its ships'
## footprints. The path runs to the edges of the screen; the formation already
## counts health bars as part of a ship, so this only has to keep them clear of
## the cockpit frame.
@export var formation_edge_margin: float = 14.0

## Narrowest gap between two ships' footprints. See [member EnemyFormation.min_ship_gap].
@export var formation_min_gap: float = 8.0

## How far speech boxes keep from the screen edges. A box flush against the
## edge reads as cut off.
@export var speech_edge_margin: float = 8.0

## How long a ship takes to slide to a new spot when the formation changes.
@export var reflow_time: float = 0.75

## The most ships a launch may bring the board up to. Past this the formation
## starts squeezing hulls together.
@export var max_ships_in_combat: int = 5

@export_category('Draw Order')
## The z the ships drop to while jumping away. In combat they draw above the
## main viewer, so a tractor beam can run over the tile grid and still come
## out from underneath the ship. Falling off the bottom of the screen, they
## have to pass behind the cockpit instead.
@export var jump_z_index: int = -5

var enemies_jumping: bool = false:
	set(value):
		enemies_jumping = value
		z_index = jump_z_index if value else _combat_z_index

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

## Where each awaiting ship will come to rest, kept current by the formation.
var _arrival_rest: Dictionary[Enemy, Vector2] = {}

## True from the moment the opening fly-in starts until the last ship has landed
## and been targeted. Combat-start effects wait on this so nothing fires at a
## ship that is still arriving; see Events.enemies_arrived.
var arrival_in_progress: bool = false

## The hull of a ship made of parts, and the parts riding it.
var _hull_mounts: HullMounts = HullMounts.new(formation)

## The z authored on this node, which the ships go back to once a jump is over.
@onready var _combat_z_index: int = z_index

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
		_hull_mounts.unmount(ship, enemies_jumping)
		_forget(ship)
		# Any slot that was going to act on it picks someone else, so the
		# intent the player reads stays true.
		EnemyTargetBinder.rebind_departed(ship, get_alive_enemies())
		# The survivors close the gap the loss left behind.
		refresh_formation()
	)
	Events.jump.connect(start_enemy_jump_animation)
	Events.load_scenario.connect(func(scenario: ScenarioResource) -> void:
		# Clean up any remaining jumping enemies before loading new scenario
		if enemies_jumping:
			delete_all_enemies()
		
		# A won fight doesn't come back on a reload.
		if Globals.state_manager and Globals.state_manager.is_scenario_cleared():
			return

		# Spawn the starting ships
		if len(scenario.starting_enemies) > 0:
			spawn_enemies(scenario.starting_enemies)
			_restore_enemies(scenario.starting_enemies)
			_spawn_hull(scenario)
	)
	Events.start_scenario.connect(start_enemy_fly_in)
	Events.player_turn_start.connect(generate_all_turn_actions)
	Events.combat_finished.connect(_reroll_tables_gone_hidden)
	
	
func _process(delta: float) -> void:
	if enemies_jumping:
		_update_jumping_enemies(delta)
	elif _hull_mounts.has_hull():
		_hull_mounts.carry()
	
	
func spawn_enemies(enemies_to_spawn: Array[EnemyStateRewardResource]) -> void:
	var spawned: Array[Enemy] = []
	for i: int in range(len(enemies_to_spawn)):
		var spawn: EnemyStateRewardResource = enemies_to_spawn[i]
		var enemy: Enemy = enemy_base_scene.instantiate()
		enemy.spawn_index = i
		enemy.enemy_resource = spawn.enemy_resource
		enemy.reward_resource = spawn.reward_resource
		enemy.scenario_state = spawn.starting_state
		# Set before add_child: Enemy._ready() bakes health off this.
		enemy.starting_health_fraction = spawn.starting_health_fraction

		# A part of a bigger ship rides its hull (see _spawn_hull), and never
		# bobs on its own: it moves when the hull does.
		if spawn.mounted:
			enemy.formation_pinned = true
			enemy.moving_in_world = true
			_hull_mounts.mount(enemy, spawn.mount_offset)

		# A scenario can still nail a ship to one spot when the encounter is
		# about where that ship is. Everyone else is placed by the formation.
		elif spawn.has_fixed_position():
			enemy.formation_pinned = true
			var rest: Vector2 = _resting_position(enemy, spawn.path_location_override)
			_arrival_rest[enemy] = rest
			enemy.position = rest + Vector2(0, -fly_in_range)

		enemies.append(enemy)
		spawned.append(enemy)
		if not spawn.mounted:
			_awaiting_fly_in.append(enemy)
		add_child(enemy)

		if enemy.formation_pinned:
			_reserve_pinned_ship(enemy, spawn.path_location_override)

	# Rolled once everyone is in, so each roll sees the whole roster. Ships
	# already here keep the table the player has been reading.
	_roll_turn_actions(spawned)
	refresh_formation(false)


## Whether another ship would still fit on the board.
func has_room_to_launch() -> bool:
	return get_alive_enemies().size() < max_ships_in_combat


## Brings [param resource] into the fight from [param launcher]'s hull, on its
## side and in its scenario state, and slides it out to a spot in the formation
## beside it. A launched ship pays no reward of its own (its side's bounty still
## waits on it) and isn't part of the save: a Continue rebuilds the scenario's
## authored roster only.
func launch_ship(resource: EnemyResource, launcher: Enemy) -> Enemy:
	if not is_instance_valid(launcher):
		return null

	var ship: Enemy = enemy_base_scene.instantiate()
	ship.enemy_resource = resource
	ship.scenario_state = launcher.scenario_state
	ship.position = launcher.position
	# Next to its launcher in the roster, which is left-to-right formation
	# order, so it doesn't cross the board to reach its slot.
	var index: int = enemies.find(launcher)
	enemies.insert(index + 1 if index >= 0 else enemies.size(), ship)
	add_child(ship)
	# Below the launcher, so it reads as coming out of the hangar.
	move_child(ship, launcher.get_index())

	# A table now, so the targeting computer has something to show; the
	# next player turn rolls it again with everyone else.
	_roll_turn_actions([ship])
	Juice.ring(self, ship.global_position, Globals.orange, 22.0, 0.35, 3.0)
	refresh_formation()

	var move: Tween = _active_moves.get(ship)
	if move and move.is_valid():
		await move.finished
	return ship


## The ships still here, for the save. A starting ship with no record has died
## or left.
func capture_enemies() -> Array:
	var out: Array = []
	for enemy: Enemy in get_alive_enemies():
		if is_instance_valid(enemy) and enemy.spawn_index >= 0:
			out.append(enemy.capture_state())
	return out


## Continuing a save taken partway through a scenario: bring each starting ship
## back to how it was, and drop the ones that were already gone. Runs straight
## after spawn_enemies(), before anything has flown in or acted.
func _restore_enemies(starting_enemies: Array[EnemyStateRewardResource]) -> void:
	if not Globals.state_manager:
		return
	var restore: Dictionary = Globals.state_manager.get_restore()
	if not restore.has("enemies"):
		return

	var saved: Dictionary = {}
	for entry: Variant in restore["enemies"]:
		saved[int(entry["spawn"])] = entry

	for enemy: Enemy in enemies.duplicate():
		if saved.has(enemy.spawn_index):
			enemy.restore_state(saved[enemy.spawn_index], starting_enemies[enemy.spawn_index].starting_state)
			continue
		# Gone before the save. Freed quietly — no death, no reward, no
		# enemy_left for the scenario to react to a second time.
		_forget(enemy)
		enemy.disconnect_scenario_signals()
		enemies.erase(enemy)
		enemy.queue_free()

	refresh_formation(false)


func start_enemy_fly_in() -> void:
	arrival_in_progress = true

	# A tutorial step queued forced actions after the roster was rolled.
	if len(Enemy.forced_actions) > 0:
		generate_all_turn_actions()

	# A hull arrives first, carrying its parts with it.
	if _hull_mounts.has_hull():
		await _hull_mounts.fly_in(fly_in_time)
		Events.enemy_flew_in.emit()

	# A copy, because ships can leave while an earlier one is still arriving.
	for enemy: Enemy in enemies.duplicate():
		if not is_instance_valid(enemy) or _hull_mounts.is_mounted(enemy):
			continue

		# Ships ride the tween from above their slot down onto it, and keep
		# counting as awaiting until it ends. Ships arrive one at a time, so a
		# later ship sits above its slot for a while; if it stopped counting as
		# awaiting, a reflow in that window (the scenario's salvage claiming
		# space) would slide it onto its slot and the tween would then carry it
		# a further fly_in_range below it.
		var fly_in_tween: Tween = get_tree().create_tween()
		fly_in_tween.tween_method(
			func(progress: float) -> void: _place_arriving(enemy, progress),
			0.0,
			1.0,
			fly_in_time
		).set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)

		await fly_in_tween.finished
		_awaiting_fly_in.erase(enemy)
		_arrival_rest.erase(enemy)
		if not is_instance_valid(enemy):
			continue
		Events.enemy_flew_in.emit()
		# Re-enable bobbing animation after spawn tween completes
		enemy.graphics_manager.start_bob_tween()

	# Targeted explicitly rather than trusting the per-ship signal, which only
	# helps if some ship's arrival came after the roster was final.
	if Globals.targeting_computer:
		Globals.targeting_computer.ensure_target()
	arrival_in_progress = false
	Events.enemies_arrived.emit()


## One frame of a ship's fly-in. [param progress] is 0 above the slot and 1 on
## it; the slot is read every frame because the formation may still move it.
func _place_arriving(ship: Enemy, progress: float) -> void:
	if not is_instance_valid(ship):
		return
	if not _arrival_rest.has(ship):
		_arrival_rest[ship] = ship.position
	var rest: Vector2 = _arrival_rest[ship]
	ship.position = rest + Vector2(0.0, -fly_in_range * (1.0 - progress))


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
	var computer: TargetingComputer = Globals.targeting_computer
	var retarget_indicator: bool = computer != null and computer.hide_indicator_while_moving(ship)

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

	if retarget_indicator and is_instance_valid(computer):
		computer.show_indicator_after_move(ship)


## Re-derives everyone's spot from the roster and whatever space is currently
## free, then moves them there. Cheap enough to call on any change; ships
## already standing in the right place are left alone.
func refresh_formation(animate: bool = true) -> void:
	# Mid-jump the whole formation is drifting off the bottom of the screen on
	# purpose. Anything we did here would fight that.
	if enemies_jumping:
		return

	var members: Array[Enemy] = _formation_members()
	# Health bars hang off each ship's side, which is the clearest place for
	# them. Only when the wing can't fit that way do they tuck above the hulls,
	# all together, so the board doesn't mix the two looks.
	var compact: bool = not formation.fits(_footprints(members, false))
	var slots: PackedFloat32Array = formation.solve_footprints(_footprints(members, compact))
	for enemy: Enemy in members:
		enemy.set_health_bar_compact(compact, reflow_time if animate else 0.0)

	_point_speech(members, slots)

	for i: int in range(members.size()):
		var enemy: Enemy = members[i]
		var proportion: float = proportion_for_screen_x(slots[i])
		var target: Vector2 = _resting_position(enemy, proportion)

		# A ship that has not flown in yet is holding above its slot. Snap it
		# across so its arrival tween still ends where the formation wants it.
		if enemy in _awaiting_fly_in:
			_arrival_rest[enemy] = target
			enemy.position = target + Vector2(0, -fly_in_range)
			continue

		if animate:
			# A ship can already be where it belongs while still sliding away
			# from it: a reflow that started and was overruled in the same
			# frame, when a reward claims the gap a dying ship left.
			if not enemy.position.is_equal_approx(target) or _active_moves.has(enemy):
				_slide_ship_to(enemy, target, reflow_time)
		else:
			enemy.position = target


## Turns each ship's speech box toward the clearer side of it, judged from
## where everyone is headed rather than where they are mid-slide. Pinned ships
## count too: they stand at the middle of the space they hold.
func _point_speech(members: Array[Enemy], slots: PackedFloat32Array) -> void:
	var ships: Array[Enemy] = members.duplicate()
	var xs: PackedFloat32Array = slots.duplicate()
	for enemy: Enemy in enemies:
		if is_instance_valid(enemy) and enemy.formation_pinned:
			var held: Vector2 = formation.get_reservation(EnemyFormation.ship_key(enemy))
			ships.append(enemy)
			xs.append((held.x + held.y) * 0.5)

	for i: int in range(ships.size()):
		var others: PackedFloat32Array = xs.duplicate()
		others.remove_at(i)
		var points_left: bool = formation.speech_points_left(xs[i], others)
		var room: Vector2 = formation.speech_room(xs[i], others)
		ships[i].dialogue_manager.point(points_left, room.x if points_left else room.y)


## Claims screen-space x for something that is not a ship — the shop panel, the
## tutorial's popups — so the formation stands clear of it.
func reserve_formation_space(key: StringName, min_x: float, max_x: float) -> void:
	if formation.reserve(key, Vector2(min_x, max_x)):
		refresh_formation()


## Hands that space back.
func clear_formation_space(key: StringName) -> void:
	if formation.clear_reservation(key):
		refresh_formation()


## What each of [param ships] takes up, laid out with its health bar beside the
## hull or, with [param compact], above it.
func _footprints(ships: Array[Enemy], compact: bool) -> PackedVector2Array:
	var footprints: PackedVector2Array = PackedVector2Array()
	for ship: Enemy in ships:
		footprints.append(ship.formation_footprint(compact))
	return footprints


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


## A pinned ship holds its own patch of screen, health bar and all, so the rest
## of the formation reflows around it instead of through it. Pinned ships keep
## their health bar beside the hull: it is the spot the scenario was laid out
## around.
func _reserve_pinned_ship(ship: Enemy, proportion: float) -> void:
	var centre_x: float = get_global_point_along_path(proportion).x
	ship.set_health_bar_compact(false)
	var reach: Vector2 = ship.formation_footprint(false)
	formation.reserve(EnemyFormation.ship_key(ship), Vector2(centre_x - reach.x, centre_x + reach.y))


## Drops everything the formation was tracking for a ship that has gone.
func _forget(ship: Enemy) -> void:
	_awaiting_fly_in.erase(ship)
	_arrival_rest.erase(ship)
	_active_moves.erase(ship)
	formation.clear_reservation(EnemyFormation.ship_key(ship))


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
	formation.min_ship_gap = formation_min_gap
	formation.speech_span = Vector2(
		speech_edge_margin,
		Globals.SCREEN_SIZE.x - speech_edge_margin
	)


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


## Rolls every ship's intent table for the coming turn, in roster order, so
## the result is the same on a replay.
func generate_all_turn_actions() -> void:
	_roll_turn_actions(get_alive_enemies())


func _roll_turn_actions(ships: Array[Enemy], take_forced: bool = true) -> void:
	EnemyTurn.roll_tables(ships, get_alive_enemies(), take_forced)


## The survivors of a fight (the civilian it was over) go back to unreadable
## intents, and the table they last rolled in the open may hold a Flee. Only
## those tables are rerolled, and the tutorial's forced actions are left for
## the ships they were queued for.
func _reroll_tables_gone_hidden() -> void:
	var unsafe: Array[Enemy] = []
	for enemy: Enemy in get_alive_enemies():
		if is_instance_valid(enemy) and not enemy.is_turn_table_safe_while_hidden():
			unsafe.append(enemy)
	_roll_turn_actions(unsafe, false)


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
	await EnemyTurn.play(get_alive_enemies, get_tree())


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
		
	var parallax_level: int = 1  # Match the far scrolling objects
	var speed: float = Globals.background_manager.global_speed * \
					  Globals.background_manager.get_parallax_speed(parallax_level)

	# The hull falls away at the same speed as its parts, so they stay seated.
	_hull_mounts.fall(delta * speed, Globals.SCREEN_SIZE.y + 80)
	
	for i: int in range(len(enemies) - 1, -1, -1):
		var enemy: Enemy = enemies[i]
		if not enemy or not is_instance_valid(enemy):
			enemies.remove_at(i)
			continue
			
		enemy.global_position.y += delta * speed
		
		if enemy.global_position.y > Globals.SCREEN_SIZE.y + 50:  # Off-screen offset
			# Ships that fly off this way never announce leaving, so whatever
			# they held (a pinned spot, a seat on a hull) is let go here, or
			# the next scenario's formation inherits it.
			_forget(enemy)
			_hull_mounts.forget(enemy)
			enemy.disconnect_scenario_signals()
			enemy.queue_free()
			enemies.remove_at(i)
	
	# Reset flag when all enemies are gone. A hull still falling goes with
	# them: once the jump is over nothing carries it any further.
	if len(enemies) == 0:
		_hull_mounts.free_hull()
		enemies_jumping = false


func delete_all_enemies() -> void:
	# Needs to be queue_free'ed, not health reduced to 0
	# so we don't spawn rewards
	for i: int in range(len(enemies)-1, -1, -1):
		if is_instance_valid(enemies[i]):
			formation.clear_reservation(EnemyFormation.ship_key(enemies[i]))
			enemies[i].disconnect_scenario_signals()
			enemies[i].queue_free()
	enemies = []
	_awaiting_fly_in.clear()
	_arrival_rest.clear()
	_active_moves.clear()
	_hull_mounts.free_hull()
	enemies_jumping = false


func kill_all_enemies() -> void:
	damage_all_enemies(10000)
		
		
func shield_all_enemies(amount: int) -> void:
	for enemy: Enemy in enemies:
		enemy.health.change_shields(amount)
		
		
func damage_all_enemies(amount: int) -> void:
	for i: int in range(len(enemies)-1, -1, -1):
		enemies[i].health.take_damage(amount)
		



## Stands up the hull a scenario's mounted ships are parts of, once they and
## any saved state are in.
func _spawn_hull(scenario: ScenarioResource) -> void:
	var spec: ShipHullResource = scenario.hull
	var path_location: float = spec.path_location if spec else 0.5
	var rest: Vector2 = get_point_along_path(path_location) + (spec.offset if spec else Vector2.ZERO)
	var centre_x: float = get_global_point_along_path(path_location).x
	_hull_mounts.build(spec, self, rest, centre_x, fly_in_range, scenario.starting_enemies, enemies)
	if _hull_mounts.has_hull():
		refresh_formation(false)
