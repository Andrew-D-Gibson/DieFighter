extends "res://test/helpers/die_fighter_test.gd"
## Things leaving the board: the player jumping away, ships fleeing or escaping
## with dice, a carrier launching a fighter, and the sector gate. What matters
## is where every die ends up, and that nothing gone keeps reacting.

const PLAYER_SCENE: PackedScene = preload("res://Source/Systems/Game/Player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://Source/Content/Enemies/enemy.tscn")
const ENEMY_MANAGER_SCENE: PackedScene = preload("res://Source/Systems/Game/EnemyManager/enemy_manager.tscn")
const COMPUTER_SCENE: PackedScene = preload("res://Source/Systems/Game/TargetingComputer/targeting_computer.tscn")
const GATE_SCENE: PackedScene = preload("res://Source/Systems/Game/JumpGate/jump_gate.tscn")
const DICE_SCENE: PackedScene = preload("res://Source/Systems/Game/Dice/dice.tscn")
const INTERCEPTOR: EnemyResource = preload("res://Source/Content/Enemies/EnemyResources/interceptor.tres")
const ATTACK_PLAYER: EnemyActionResource = preload("res://Source/Content/Enemies/EnemyActions/EnemyActionResources/attack_player.tres")

var player: Player


func before_each() -> void:
	super()
	player = add_child_autofree(PLAYER_SCENE.instantiate())
	player.num_of_dice = 4


func _pirate_state() -> ScenarioShipState:
	var state: ScenarioShipState = ScenarioShipState.new()
	state.faction = ScenarioManager.Faction.PIRATE
	return state


func _ship() -> Enemy:
	var ship: Enemy = ENEMY_SCENE.instantiate()
	ship.enemy_resource = INTERCEPTOR
	ship.scenario_state = _pirate_state()
	return add_child_autofree(ship)


## A die under the player node, where every die in the game lives.
func _die(face: int, holographic: bool = false) -> Dice:
	var die: Dice = DICE_SCENE.instantiate()
	die.value = face
	die.holographic = holographic
	player.add_child(die)
	return die


func _hears_scenario(ship: Enemy) -> bool:
	return Events.scenario_event.is_connected(Callable(ship, "_handle_scenario_event"))


# ── Jumping away ──────────────────────────────────────────────────────────────

func test_a_jump_keeps_the_hand_and_strands_what_ships_hold() -> void:
	var ship: Enemy = _ship()
	var in_hand: Dice = _die(3)
	player.dice_manager.add(in_hand)
	var held: Dice = _die(5)
	ship.dice_manager.add(held)
	var hologram: Dice = _die(2, true)
	player.dice_manager.add(hologram, true, false)
	var shop_stock: Dice = _die(6)

	Events.jump.emit()

	assert_has(player.dice_manager.queue, in_hand)
	assert_false(in_hand.draggable.dragging_allowed, "nothing is played mid-jump")
	assert_true(in_hand.transit_locked, "so arrival knows to unlock it")
	assert_eq(held.get_parent(), ship, "it rides the ship off screen")
	assert_false(held.is_in_group("Dice"), "nothing can hand it back")
	assert_true(hologram.is_queued_for_deletion())
	assert_true(shop_stock.is_queued_for_deletion())
	assert_eq(player.num_of_dice, 3, "only the stranded real die is lost")


func test_losing_dice_counts_only_real_ones_and_never_empties_the_fleet() -> void:
	var ship: Enemy = _ship()
	var lost: Array[Dice] = [_die(1), _die(2, true)]
	player.lose_dice_to(ship, lost)
	assert_eq(player.num_of_dice, 3)

	var many: Array[Dice] = [_die(1), _die(2), _die(3), _die(4)]
	player.lose_dice_to(ship, many)
	assert_eq(player.num_of_dice, 1)


# ── Ships leaving ─────────────────────────────────────────────────────────────

func test_a_fleeing_ship_stops_hearing_the_scenario_before_it_leaves() -> void:
	Globals.enemy_manager = autofree(EnemyManager.new())
	var ship: Enemy = _ship()
	assert_true(_hears_scenario(ship))

	var flee: FleeEvent = FleeEvent.new()
	flee.actor = ship
	watch_signals(Events)
	flee.resolve(null)

	assert_signal_emitted(Events, "enemy_left")
	assert_false(_hears_scenario(ship))
	assert_true(ship.is_queued_for_deletion())


func test_a_fleeing_ship_hands_every_die_to_the_others_never_itself() -> void:
	Globals.enemy_manager = autofree(EnemyManager.new())
	var ship: Enemy = _ship()
	var other: Enemy = _ship()
	Globals.enemy_manager.enemies = [ship, other] as Array[Enemy]
	var held: Array[Dice] = [_die(1), _die(2), _die(3)]
	for die: Dice in held:
		ship.dice_manager.add(die)
	# EnemyActionEvent has already taken the die it's spending out of the queue.
	var spending: Dice = _die(6)
	ship.dice_manager.add(spending)
	ship.dice_manager.remove(spending)

	var flee: FleeEvent = FleeEvent.new()
	flee.actor = ship
	flee.activator_die = spending
	flee.resolve(null)

	assert_true(ship.dice_manager.queue.is_empty())
	for die: Dice in held + [spending] as Array[Dice]:
		assert_eq(die.host_queue, other.dice_manager)


func test_the_last_ship_to_flee_gives_its_dice_back_to_the_player() -> void:
	Globals.enemy_manager = autofree(EnemyManager.new())
	var ship: Enemy = _ship()
	Globals.enemy_manager.enemies = [ship] as Array[Enemy]
	var held: Dice = _die(4)
	ship.dice_manager.add(held)
	var spending: Dice = _die(5)
	ship.dice_manager.add(spending)
	ship.dice_manager.remove(spending)

	var give: GiveDieAwayEvent = GiveDieAwayEvent.new()
	give.actor = ship
	give.activator_die = spending
	give.resolve(null)
	# Flee after the chain has already handed the spent die on: it stays put.
	var flee: FleeEvent = FleeEvent.new()
	flee.actor = ship
	flee.activator_die = spending
	flee.resolve(null)

	assert_has(player.dice_manager.queue, held)
	assert_has(player.dice_manager.queue, spending)
	assert_eq(player.dice_manager.queue.count(spending), 1)


func test_a_ship_killed_mid_handover_passes_on_the_die_it_was_spending() -> void:
	Globals.enemy_manager = autofree(EnemyManager.new())
	Globals.targeting_computer = add_child_autofree(COMPUTER_SCENE.instantiate())
	var ship: Enemy = _ship()
	var other: Enemy = _ship()
	Globals.enemy_manager.enemies = [ship, other] as Array[Enemy]
	var spending: Dice = _die(6)
	ship.dice_manager.add(spending)
	var next_up: Dice = _die(3)
	ship.dice_manager.add(next_up)

	var action: EnemyActionEvent = EnemyActionEvent.new()
	action.enemy = ship
	action.activator_die = spending
	action.die_value = spending.value
	action.action = ATTACK_PLAYER
	var later: EnemyActionEvent = EnemyActionEvent.new()
	later.enemy = ship
	later.activator_die = next_up
	later.die_value = next_up.value
	later.action = ATTACK_PLAYER
	watch_signals(Events)
	action.resolve(null)

	# Killed while the die is still flying out in front of the hull.
	ship.health.change_health(-ship.health.health)

	assert_eq(spending.host_queue, other.dice_manager)
	assert_eq(next_up.host_queue, other.dice_manager)
	assert_false(ship.spending_tween.is_running(), "it stops pulling the die back")

	# The die it was due to spend next is someone else's now.
	later.resolve(null)
	await wait_seconds(1.5)
	assert_signal_emit_count(Events, "enemy_used_die", 1, "only the die it was already spending; a dead ship doesn't act")
	assert_has(other.dice_manager.queue, spending)
	assert_has(other.dice_manager.queue, next_up)


func test_an_escaping_ship_takes_its_dice_and_the_one_it_was_spending() -> void:
	var ship: Enemy = _ship()
	ship.dice_manager.add(_die(4))
	var spending: Dice = _die(6)

	var escape: EscapeWithDiceEvent = EscapeWithDiceEvent.new()
	escape.actor = ship
	escape.activator_die = spending
	escape.resolve(null)

	# Checked while it is still climbing off screen.
	assert_false(_hears_scenario(ship), "it can't react to its own exit")
	assert_eq(player.num_of_dice, 2)
	assert_eq(spending.get_parent(), ship)

	await wait_seconds(0.7)
	assert_false(is_instance_valid(ship))


# ── Launching ─────────────────────────────────────────────────────────────────

func test_a_launched_ship_joins_beside_its_launcher_on_its_side() -> void:
	var manager: EnemyManager = add_child_autofree(ENEMY_MANAGER_SCENE.instantiate())
	var spawn: EnemyStateRewardResource = EnemyStateRewardResource.new()
	spawn.enemy_resource = INTERCEPTOR
	spawn.starting_state = _pirate_state()
	var roster: Array[EnemyStateRewardResource] = [spawn]
	manager.spawn_enemies(roster)
	var launcher: Enemy = manager.enemies[0]

	var launched: Enemy = await manager.launch_ship(INTERCEPTOR, launcher)

	assert_eq(manager.enemies, [launcher, launched] as Array[Enemy])
	assert_eq(launched.scenario_state, launcher.scenario_state)
	assert_eq(launched.turn_actions.size(), EnemyActionSelector.SLOT_COUNT)
	assert_eq(manager.capture_enemies().size(), 1, "a launched ship isn't saved")


# ── The gate ──────────────────────────────────────────────────────────────────

func test_the_gate_survives_its_own_passage_jump_but_not_any_other() -> void:
	var gate: JumpGate = add_child_autofree(GATE_SCENE.instantiate())
	gate.open(true)
	gate.begin_passage()
	Events.jump.emit()
	assert_true(gate.is_open())

	gate.end_passage()
	gate.open(true)
	Events.jump.emit()
	assert_false(gate.is_open())


func test_a_warp_in_cut_short_does_not_leave_the_ring_glowing() -> void:
	var gate: JumpGate = add_child_autofree(GATE_SCENE.instantiate())
	gate.open(false)
	gate.close()
	gate.open(true)
	assert_eq(gate.ring.modulate, Color.WHITE)
