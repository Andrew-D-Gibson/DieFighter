extends "res://test/helpers/die_fighter_test.gd"
## A destroyed ship's dice change hands at once. Bound for another ship, they
## leave the wreck together, a beat apart, each on that ship's tractor beam.
## Bound for the player, because nobody is left fighting, they hang at the
## wreck and then cross home, slowly enough to follow. Who inherits is decided
## once the scenario has reacted to the loss, so a fight the death just ended
## sends them straight home.

const PLAYER_SCENE: PackedScene = preload("res://Source/Systems/Game/Player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://Source/Content/Enemies/enemy.tscn")
const DICE_SCENE: PackedScene = preload("res://Source/Systems/Game/Dice/dice.tscn")
const INTERCEPTOR: EnemyResource = preload("res://Source/Content/Enemies/EnemyResources/interceptor.tres")
const CIVILIAN: EnemyResource = preload("res://Source/Content/Enemies/EnemyResources/civilian_transport.tres")
const PIRATE_VS_CIVILIAN: String = "res://Source/Content/ScenarioResources/Scenarios/EVENT_PiratesAttackingCivilian/"

var player: Player
var dying: Enemy
var heir: Enemy
var die: Dice


func before_each() -> void:
	super()
	player = add_child_autofree(PLAYER_SCENE.instantiate())
	Globals.enemy_manager = autofree(EnemyManager.new())
	dying = _ship(Vector2(60, 40))
	heir = _ship(Vector2(200, 40))
	Globals.enemy_manager.enemies = [dying, heir] as Array[Enemy]
	die = _held_by(dying, 5)


func _ship(at: Vector2, attitude: Enemy.Attitude = Enemy.Attitude.AGGRESSIVE) -> Enemy:
	var ship: Enemy = ENEMY_SCENE.instantiate()
	ship.enemy_resource = INTERCEPTOR
	var state: ScenarioShipState = ScenarioShipState.new()
	state.faction = ScenarioManager.Faction.PIRATE
	state.attitude = attitude
	ship.scenario_state = state
	add_child_autofree(ship)
	ship.global_position = at
	return ship


func _held_by(ship: Enemy, face: int) -> Dice:
	var held: Dice = _loose_die(face)
	ship.dice_manager.add(held)
	TractorBeam.release(held)
	held.global_position = held.draggable.home_position
	return held


func _loose_die(face: int) -> Dice:
	var loose: Dice = DICE_SCENE.instantiate()
	loose.value = face
	player.add_child(loose)
	return loose


func _kill(ship: Enemy) -> void:
	ship.health.change_health(-ship.health.health)


## The shot that finished [param ship], arriving for it a moment after the
## death, as a damage tile's GiveDieToTargetEvent does.
func _killing_shot_at(ship: Enemy, face: int) -> Dice:
	var shot: Dice = _loose_die(face)
	shot.global_position = ship.global_position
	var give: GiveDieToTargetEvent = GiveDieToTargetEvent.new()
	give.activator_die = shot
	give.targets = [ship] as Array[Node]
	give.resolve(null)
	return shot


func _beam_on(held: Dice) -> TractorBeam:
	var beam: TractorBeam = TractorBeam._active.get(held)
	return beam if is_instance_valid(beam) else null


func _handoff(held: Dice) -> Tween:
	return held.get("_handoff_tween") as Tween


func _stagger() -> float:
	return EnemyDiceManager.DEATH_VOLLEY_STAGGER_SECONDS / Globals.animation_speed


# --- Another ship takes them: a volley of beams ---------------------------

func test_the_die_changes_hands_at_once() -> void:
	_kill(dying)
	assert_eq(die.host_queue, heir.dice_manager, "the new holder has it straight away")


func test_every_die_goes_on_its_own_beam() -> void:
	var hold: Array[Dice] = [die, _held_by(dying, 2), _held_by(dying, 6)]
	_kill(dying)
	await wait_seconds(_stagger() * 3.0)

	var beams: Array[TractorBeam] = []
	for held: Dice in hold:
		assert_eq(held.host_queue, heir.dice_manager)
		var beam: TractorBeam = _beam_on(held)
		assert_not_null(beam, "die %d is being pulled" % held.value)
		if beam:
			assert_eq(beam.get("_enemy"), heir, "by the ship that took it")
			assert_false(beam in beams, "on a beam of its own")
			beams.append(beam)


func test_the_volley_leaves_together_a_beat_apart() -> void:
	var hold: Array[Dice] = [die, _held_by(dying, 2), _held_by(dying, 6)]
	_kill(dying)

	var pulled: int = hold.filter(func(held: Dice) -> bool: return _beam_on(held) != null).size()
	assert_eq(pulled, 1, "the first beam locks on at once")
	# The last of three is two beats behind the first.
	await wait_seconds(_stagger() * 2.0 + 0.05)
	pulled = hold.filter(func(held: Dice) -> bool: return _beam_on(held) != null).size()
	assert_eq(pulled, 3, "and the rest within a fraction of a second")


func test_a_beam_keeps_hold_while_its_ship_slides_into_the_gap() -> void:
	var wreck: Vector2 = die.global_position
	_kill(dying)
	assert_not_null(_beam_on(die))
	# The survivors close up, rearranging their dice every frame as they go.
	heir.moving_in_world = true
	# And the die's Draggable runs after the ship's rearranging but before its
	# beam each frame, as it can in the game.
	die.draggable.process_priority = 100
	_beam_on(die).process_priority = 200
	await wait_frames(6)
	assert_almost_eq(die.global_position, wreck, Vector2.ONE * 0.01,
		"still where the beam is reaching for it, not homing to the hull")


func test_a_landed_die_is_handed_back_to_its_draggable() -> void:
	_kill(dying)
	await wait_seconds(TractorBeam.seconds_to_land(die.value) + 0.1)
	assert_false(die.draggable.held_by_code)
	assert_eq(die.draggable.state, Draggable.DragState.ENEMY_HOLDING)


func test_a_die_waits_at_the_wreck_for_its_beam() -> void:
	var second: Dice = _held_by(dying, 3)
	var wreck: Vector2 = die.global_position
	_kill(dying)
	# Whichever die is second in the volley hasn't been taken yet.
	var waiting: Dice = die if _beam_on(second) else second
	if waiting == second:
		wreck = second.global_position
	assert_null(_beam_on(waiting))
	assert_true(waiting.is_handing_off())
	await wait_frames(2)
	assert_almost_eq(waiting.global_position, wreck, Vector2.ONE * 0.01, "still hanging where the ship died")

	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	waiting.draggable.state = Draggable.DragState.DEFAULT
	waiting.draggable._on_input_event(null, press, 0)
	assert_ne(waiting.draggable.state, Draggable.DragState.DRAGGING, "and can't be picked up")


func test_the_shot_that_killed_it_joins_the_volley() -> void:
	_kill(dying)
	var shot: Dice = _killing_shot_at(dying, 4)

	assert_eq(shot.host_queue, heir.dice_manager, "it goes where the rest of the hold went")
	assert_null(_beam_on(shot), "after the dice already on their way")
	await wait_seconds(_stagger() + 0.05)
	var beam: TractorBeam = _beam_on(shot)
	assert_not_null(beam, "on its own beam")
	if beam:
		assert_eq(beam.get("_enemy"), heir)


func test_a_ship_spending_the_die_takes_it_off_the_wreck() -> void:
	_held_by(dying, 3)
	_kill(dying)
	for held: Dice in heir.dice_manager.queue:
		held.cancel_handoff()
		assert_false(held.is_handing_off())
		assert_false(held.draggable.held_by_code)


func test_a_beam_takes_as_long_as_the_engine_is_told() -> void:
	assert_almost_eq(die.hand_off_after_death(0.0), TractorBeam.seconds_to_land(die.value), 0.001,
		"a die bound for a ship lands when its beam does")


# --- Nobody left fighting: straight home -----------------------------------

func test_with_nobody_left_fighting_the_dice_go_home() -> void:
	heir.scenario_state.attitude = Enemy.Attitude.NEUTRAL
	var second: Dice = _held_by(dying, 2)
	_kill(dying)

	for held: Dice in [die, second]:
		assert_eq(held.host_queue, player.dice_manager, "the player's, not a bystander's")
		assert_null(_beam_on(held), "and nothing tractors it anywhere")
		assert_true(held.is_handing_off(), "it crosses home from the wreck")


func test_a_die_going_home_lingers_at_the_wreck() -> void:
	heir.scenario_state.attitude = Enemy.Attitude.NEUTRAL
	var wreck: Vector2 = die.global_position
	_kill(dying)
	_handoff(die).custom_step(0.3 / Globals.animation_speed)
	assert_almost_eq(die.global_position, wreck, Vector2.ONE * 0.01,
		"still hanging where the ship died")


func test_a_die_going_home_lands_in_the_hand_and_is_let_go() -> void:
	heir.scenario_state.attitude = Enemy.Attitude.NEUTRAL
	_kill(dying)
	_handoff(die).custom_step(Dice.death_handoff_seconds() + 0.01)

	assert_almost_eq(die.global_position, die.draggable.home_position, Vector2.ONE * 0.01)
	assert_false(die.is_handing_off())
	assert_false(die.draggable.held_by_code, "its holder's Draggable has it again")


func test_a_loss_that_ends_the_fight_sends_the_dice_home() -> void:
	# The scenario's reaction to the death: the last hostile ship stands down.
	var stand_down: Callable = func(_ship: Enemy, _faction: ScenarioManager.Faction) -> void:
		heir.scenario_state.attitude = Enemy.Attitude.FRIENDLY
	Events.enemy_left.connect(stand_down)
	_kill(dying)
	Events.enemy_left.disconnect(stand_down)

	assert_eq(die.host_queue, player.dice_manager)


func test_a_loss_that_starts_a_fight_arms_the_ship_it_angered() -> void:
	heir.scenario_state.attitude = Enemy.Attitude.NEUTRAL
	var anger: Callable = func(_ship: Enemy, _faction: ScenarioManager.Faction) -> void:
		heir.scenario_state.attitude = Enemy.Attitude.AGGRESSIVE
	Events.enemy_left.connect(anger)
	_kill(dying)
	Events.enemy_left.disconnect(anger)

	assert_eq(die.host_queue, heir.dice_manager)


func test_a_pirate_downed_over_a_civilian_returns_every_die_to_the_player() -> void:
	# The pirate-attacking-civilian event as authored: the player has joined
	# in, so the pirate is fighting and the civilian is cheering them on.
	var manager: ScenarioManager = add_child_autofree(ScenarioManager.new())
	manager.current_scenario = load(PIRATE_VS_CIVILIAN + "EVENT_pirate_attacking_civilian.tres")
	var pirate: Enemy = dying
	pirate.scenario_state = load(PIRATE_VS_CIVILIAN + "pirate_combatant.tres")
	var civilian: Enemy = heir
	civilian.enemy_resource = CIVILIAN
	civilian.scenario_state = load(PIRATE_VS_CIVILIAN + "civilian_hopeful.tres")
	var second: Dice = _held_by(pirate, 6)
	var arrivals: Array[Dice] = []
	civilian.dice_manager.die_arriving.connect(arrivals.append)

	_kill(pirate)
	var shot: Dice = _killing_shot_at(pirate, 3)

	for held: Dice in [die, second, shot]:
		assert_eq(held.host_queue, player.dice_manager, "die %d goes straight home" % held.value)
		assert_null(_beam_on(held), "with no beam toward the civilian")
	assert_eq(arrivals.size(), 0, "the civilian never held any of them")
	assert_ne(civilian.scenario_state, load(PIRATE_VS_CIVILIAN + "civilian_hopeful.tres"),
		"the civilian had already reacted to the pirates' defeat")


# --- Fleeing ---------------------------------------------------------------

func test_a_fleeing_ship_hands_its_dice_straight_over() -> void:
	# No wreck to watch: a ship leaving under its own power just passes them on.
	var flee: FleeEvent = FleeEvent.new()
	flee.actor = dying
	flee.resolve(null)

	assert_eq(die.host_queue, heir.dice_manager)
	assert_false(die.is_handing_off())


func test_the_last_hostile_ship_fleeing_hands_its_dice_home() -> void:
	heir.scenario_state.attitude = Enemy.Attitude.NEUTRAL
	var flee: FleeEvent = FleeEvent.new()
	flee.actor = dying
	flee.resolve(null)

	assert_eq(die.host_queue, player.dice_manager, "not to a bystander who'd send it back")
