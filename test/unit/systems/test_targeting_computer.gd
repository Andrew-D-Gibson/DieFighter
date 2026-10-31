extends "res://test/helpers/die_fighter_test.gd"
## The targeting computer and where the player's dice aim: a die remembers the
## ship it was dropped against, and the reticle, the icons and a die in flight
## all keep up with a ship that slides across the formation.

const PLAYER_SCENE: PackedScene = preload("res://Source/Systems/Game/Player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://Source/Content/Enemies/enemy.tscn")
const COMPUTER_SCENE: PackedScene = preload("res://Source/Systems/Game/TargetingComputer/targeting_computer.tscn")
const DICE_SCENE: PackedScene = preload("res://Source/Systems/Game/Dice/dice.tscn")
const TILE_SCENE: PackedScene = preload("res://Source/Content/Tiles/tile.tscn")
const DAMAGE_TILE: TileResource = preload("res://Source/Content/Tiles/TileResources/damage.tres")
const INTERCEPTOR: EnemyResource = preload("res://Source/Content/Enemies/EnemyResources/interceptor.tres")

var player: Player
var computer: TargetingComputer
var manager: EnemyManager
var _animation_speed: float


func before_each() -> void:
	super()
	_animation_speed = Globals.animation_speed
	player = add_child_autofree(PLAYER_SCENE.instantiate())
	manager = autofree(EnemyManager.new())
	Globals.enemy_manager = manager
	Globals.state_manager = autofree(GameStateManager.new())
	computer = add_child_autofree(COMPUTER_SCENE.instantiate())


func after_each() -> void:
	Globals.animation_speed = _animation_speed
	super()


func _ship(at: Vector2 = Vector2.ZERO) -> Enemy:
	var ship: Enemy = ENEMY_SCENE.instantiate()
	ship.enemy_resource = INTERCEPTOR
	var state: ScenarioShipState = ScenarioShipState.new()
	state.faction = ScenarioManager.Faction.PIRATE
	ship.scenario_state = state
	# A bare GameStateManager has no save to scale hull by, and the ship asks
	# for it as it readies. The computer only needs it once a target is up.
	var state_manager: GameStateManager = Globals.state_manager
	Globals.state_manager = null
	add_child_autofree(ship)
	Globals.state_manager = state_manager
	ship.global_position = at
	manager.enemies.append(ship)
	return ship


## A die under the player node, where every die in the game lives.
func _die(face: int = 3) -> Dice:
	var die: Dice = DICE_SCENE.instantiate()
	die.value = face
	player.add_child(die)
	return die


func _target(ship: Enemy) -> void:
	computer.target_enemy(ship)


# ── A queued die remembers its target ─────────────────────────────────────────

func test_a_die_dropped_on_a_tile_remembers_the_ship_targeted_then() -> void:
	var first: Enemy = _ship()
	var second: Enemy = _ship()
	_target(first)
	var tile: Tile = TILE_SCENE.instantiate()
	tile.tile_resource = DAMAGE_TILE
	add_child_autofree(tile)
	var die: Dice = _die()

	tile._on_die_accepted(die)
	_target(second)

	assert_eq(die.aimed_at, first)
	assert_eq(computer.target_for(die), first, "it still goes where it was sent")


func test_landing_in_a_hand_forgets_the_aim() -> void:
	var ship: Enemy = _ship()
	var die: Dice = _die()
	die.aimed_at = ship
	player.dice_manager.add(die)
	assert_null(die.aimed_at, "the next drop picks its own target")


func test_a_dead_aim_falls_back_to_the_current_target() -> void:
	var first: Enemy = _ship()
	var second: Enemy = _ship()
	var die: Dice = _die()
	die.aimed_at = first
	_target(second)

	first.health.health = 0
	assert_eq(computer.target_for(die), second)


func test_a_ship_that_left_is_no_longer_an_aim() -> void:
	var first: Enemy = _ship()
	var second: Enemy = _ship()
	var die: Dice = _die()
	die.aimed_at = first
	_target(second)

	# Fled: alive, but off the roster.
	manager.enemies.erase(first)
	assert_eq(computer.target_for(die), second)


func test_a_freed_aim_falls_back_quietly() -> void:
	var first: Enemy = _ship()
	var second: Enemy = _ship()
	var die: Dice = _die()
	die.aimed_at = first
	_target(second)

	manager.enemies.erase(first)
	first.free()
	assert_eq(computer.target_for(die), second)


func test_no_die_or_a_stand_in_uses_the_current_target() -> void:
	var ship: Enemy = _ship()
	_target(ship)
	assert_eq(computer.target_for(null), ship)
	assert_eq(computer.target_for(autofree(FakeDie.new(4))), ship)


func test_with_nothing_left_to_target_there_is_no_target() -> void:
	var ship: Enemy = _ship()
	var die: Dice = _die()
	die.aimed_at = ship
	ship.health.health = 0
	computer.check_target_is_valid()
	assert_null(computer.target_for(die))


func test_targeting_handler_hits_the_remembered_ship() -> void:
	var first: Enemy = _ship()
	var second: Enemy = _ship()
	var die: Dice = _die()
	die.aimed_at = first
	_target(second)

	var context := EffectContext.new()
	context.activator_die = die
	TargetWithTargetingComputerHandler.new().apply(null, context, null)
	assert_eq(context.targets, [first] as Array[Node])

	first.health.health = 0
	TargetWithTargetingComputerHandler.new().apply(null, context, null)
	assert_eq(context.targets, [second] as Array[Node])


func test_targeting_checks_ask_about_the_remembered_ship() -> void:
	var first: Enemy = _ship()
	var second: Enemy = _ship()
	var die: Dice = _die()
	die.aimed_at = first
	_target(second)
	second.health.shields = 0
	first.health.shields = 3

	var shields := ActivationResource.new()
	shields.type = ActivationResource.ActivationType.TARGETED_SHIP_HAS_SHIELDS
	assert_true(shields.criteria_satisfied(die), "the die's own target has shields")
	assert_false(shields.criteria_satisfied(null), "the current one doesn't")

	var targeted := ActivationResource.new()
	targeted.type = ActivationResource.ActivationType.SHIP_TARGETED
	assert_true(targeted.criteria_satisfied(die))


# ── Following a moving ship ───────────────────────────────────────────────────

func test_the_reticle_follows_a_targeted_ship_as_it_slides() -> void:
	var ship: Enemy = _ship(Vector2(100, 40))
	_target(ship)
	await wait_seconds(0.4)
	_assert_reticle_on(ship)

	ship.global_position = Vector2(180, 40)
	await wait_physics_frames(2)
	_assert_reticle_on(ship)


func test_the_reticle_follows_mid_glide_too() -> void:
	var first: Enemy = _ship(Vector2(60, 40))
	var second: Enemy = _ship(Vector2(200, 40))
	_target(first)
	await wait_seconds(0.4)
	_target(second)
	# Halfway through the glide, the ship it's headed for moves.
	await wait_seconds(0.1)
	second.global_position = Vector2(260, 40)
	await wait_seconds(0.35)
	_assert_reticle_on(second)


func test_a_redraw_for_the_same_target_does_not_restart_the_glide() -> void:
	var ship: Enemy = _ship(Vector2(100, 40))
	_target(ship)
	await wait_seconds(0.4)
	computer.check_target_is_valid()
	assert_eq(computer._indicator_glide, 1.0, "still settled on the ship")


func _assert_reticle_on(ship: Enemy) -> void:
	var anchor: Vector2 = ship.global_position + computer.targeting_indicator_offset
	var offset: Vector2 = computer.targeting_indicator.global_position - anchor
	assert_true(computer.targeting_indicator.visible)
	# The hover swings it up to (4, 4) off the anchor.
	assert_between(offset.x, -0.01, 4.01, "x within the hover")
	assert_between(offset.y, -0.01, 4.01, "y within the hover")


func test_a_die_in_flight_lands_on_a_ship_that_moved() -> void:
	Globals.animation_speed = 4.0
	var ship: Enemy = _ship(Vector2(100, 40))
	var die: Dice = _die()
	die.global_position = Vector2(160, 200)
	die.draggable.state = Draggable.DragState.MOVING_WITH_CODE

	var attack := AttackTweenEvent.new()
	attack.actor = player
	attack.activator_die = die
	attack.targets = [ship as Node]
	attack.resolve(null)

	await wait_seconds(0.1)
	ship.global_position = Vector2(220, 40)
	await wait_seconds(0.3)
	assert_almost_eq(die.global_position, ship.global_position, Vector2.ONE)


func test_a_die_in_flight_at_a_ship_that_vanishes_lands_where_it_was() -> void:
	Globals.animation_speed = 4.0
	var ship: Enemy = _ship(Vector2(100, 40))
	var die: Dice = _die()
	die.global_position = Vector2(160, 200)
	die.draggable.state = Draggable.DragState.MOVING_WITH_CODE

	var attack := AttackTweenEvent.new()
	attack.actor = player
	attack.activator_die = die
	attack.targets = [ship as Node]
	attack.resolve(null)

	await wait_seconds(0.1)
	manager.enemies.erase(ship)
	ship.free()
	await wait_seconds(0.3)
	assert_almost_eq(die.global_position, Vector2(100, 40), Vector2.ONE)


# ── Icons on a target switch ──────────────────────────────────────────────────

func test_switching_target_stops_a_pulse_and_rests_the_icon() -> void:
	var first: Enemy = _ship()
	var second: Enemy = _ship()
	_target(first)
	computer._pulse_intent(first, 3)
	await wait_seconds(0.2)
	var pulse: Tween = computer.intent_scale_tweens[2]
	assert_true(pulse.is_running())

	_target(second)
	assert_false(pulse.is_valid(), "the old ship's pulse is gone")
	assert_eq(computer._intent(2).scale, Vector2.ONE)


func test_a_redraw_for_the_same_target_lets_a_pulse_finish() -> void:
	var ship: Enemy = _ship()
	_target(ship)
	computer._pulse_intent(ship, 5)
	var pulse: Tween = computer.intent_scale_tweens[4]
	computer.check_target_is_valid()
	assert_true(pulse.is_running(), "nothing changed, so nothing is cut short")


func test_losing_every_target_rests_the_icons_too() -> void:
	var ship: Enemy = _ship()
	_target(ship)
	computer._pulse_intent(ship, 1)
	await wait_seconds(0.2)

	ship.health.health = 0
	computer.check_target_is_valid()
	assert_null(computer.targeted_enemy)
	assert_eq(computer._intent(0).scale, Vector2.ONE)
	assert_false(computer.targeting_indicator.visible)


# ── Arcs to the ships a slot is bound to ──────────────────────────────────────

const REPAIR_ALLY: EnemyActionResource = preload(
	"res://Source/Content/Enemies/EnemyActions/EnemyActionResources/repair_ally.tres"
)
const AEGIS_ALLY: EnemyActionResource = preload(
	"res://Source/Content/Enemies/EnemyActions/EnemyActionResources/aegis_ally.tres"
)


## [param source]'s slot [param slot] repairs (or, with [param action],
## does that to) [param ally].
func _bind(source: Enemy, slot: int, ally: Enemy, action: EnemyActionResource = REPAIR_ALLY) -> void:
	var bound: EnemyActionResource = action.duplicate()
	bound.bound_target = ally
	# A ship that hasn't rolled its table yet has no slots at all; a real
	# table always fills all six.
	while source.turn_actions.size() < 6:
		source.turn_actions.append(EnemyActionResource.new())
	source.turn_actions[slot] = bound


## Intents (and so the arcs) only show in a fight.
func _fight() -> void:
	for ship: Enemy in manager.enemies:
		ship.scenario_state.attitude = Enemy.Attitude.AGGRESSIVE


func _arrows() -> Array[BoundIntentArrow]:
	var out: Array[BoundIntentArrow] = []
	for child: Node in computer.get_children():
		if child is BoundIntentArrow and not child.is_queued_for_deletion():
			out.append(child)
	return out


func test_slots_bound_to_one_ship_share_an_arc() -> void:
	var tender: Enemy = _ship(Vector2(100, 40))
	var escort: Enemy = _ship(Vector2(200, 40))
	_bind(tender, 0, escort)
	_bind(tender, 3, escort, AEGIS_ALLY)
	_fight()
	_target(tender)

	var arrows: Array[BoundIntentArrow] = _arrows()
	assert_eq(arrows.size(), 1)
	assert_eq(arrows[0].source, tender)
	assert_eq(arrows[0].target, escort)
	assert_eq(arrows[0].slots, [0, 3] as Array[int])
	assert_false(arrows[0].hostile)


func test_each_bound_ship_gets_its_own_arc() -> void:
	var tender: Enemy = _ship(Vector2(160, 40))
	_bind(tender, 0, _ship(Vector2(80, 40)))
	_bind(tender, 1, _ship(Vector2(240, 40)))
	_fight()
	_target(tender)
	assert_eq(_arrows().size(), 2)


func test_retargeting_clears_the_old_arcs() -> void:
	var tender: Enemy = _ship(Vector2(100, 40))
	var escort: Enemy = _ship(Vector2(200, 40))
	_bind(tender, 0, escort)
	_fight()
	_target(tender)
	_target(escort)
	assert_eq(_arrows().size(), 0, "the escort binds nothing")


func test_no_arcs_while_intents_are_hidden() -> void:
	var tender: Enemy = _ship(Vector2(100, 40))
	_bind(tender, 0, _ship(Vector2(200, 40)))
	_target(tender)
	assert_eq(_arrows().size(), 0)


func test_an_arc_shows_each_kind_once_and_no_amount_when_they_differ() -> void:
	var tender: Enemy = _ship(Vector2(100, 40))
	var escort: Enemy = _ship(Vector2(200, 40))
	_bind(tender, 0, escort)
	_bind(tender, 2, escort)
	_bind(tender, 4, escort, AEGIS_ALLY)
	_fight()
	_target(tender)
	var arrow: BoundIntentArrow = _arrows()[0]
	assert_eq(arrow._icons(), [REPAIR_ALLY.indicator_texture, AEGIS_ALLY.indicator_texture] as Array[Texture2D])
	assert_eq(arrow._shared_amount(), "", "two kinds: the computer's row has the amounts")


func test_an_arc_shows_the_amount_its_faces_share() -> void:
	var tender: Enemy = _ship(Vector2(100, 40))
	var escort: Enemy = _ship(Vector2(200, 40))
	_bind(tender, 1, escort, AEGIS_ALLY)
	_bind(tender, 3, escort, AEGIS_ALLY)
	tender.turn_actions[1].intent_amount = 3
	tender.turn_actions[3].intent_amount = 3
	_fight()
	_target(tender)
	var arrow: BoundIntentArrow = _arrows()[0]
	assert_eq(arrow._shared_amount(), "3")
	tender.turn_actions[3].intent_amount += 1
	assert_eq(arrow._shared_amount(), "", "the faces differ now")


func test_a_slot_is_live_while_its_die_is_held() -> void:
	var tender: Enemy = _ship(Vector2(100, 40))
	_bind(tender, 2, _ship(Vector2(200, 40)))
	assert_false(computer.is_slot_live(tender, 2))
	var die: Dice = _die(3)
	tender.dice_manager.add(die)
	assert_true(computer.is_slot_live(tender, 2))
	assert_false(computer.is_slot_live(tender, 0))


func test_the_arc_rises_over_the_ships_but_stays_on_screen() -> void:
	var low: Vector2 = BoundIntentArrow.control_point(Vector2(100, 40), Vector2(200, 40))
	assert_lt(low.y, 40.0, "it arcs over")
	var high: Vector2 = BoundIntentArrow.control_point(Vector2(40, 6), Vector2(280, 6))
	var apex_y: float = (6.0 + high.y) * 0.5
	assert_gte(apex_y, BoundIntentArrow._MIN_APEX_Y - 0.001)


# ── The arrows that step the target ───────────────────────────────────────────

func _shift_buttons() -> Array[TargetShiftButton]:
	return [computer.get_node("%LeftShiftButton"), computer.get_node("%RightShiftButton")]


## Long enough for both to slide out, swing level and pop up.
func _let_buttons_settle() -> void:
	await wait_seconds(1.4)


func test_one_ship_leaves_the_arrows_folded_away() -> void:
	_target(_ship())
	await _let_buttons_settle()
	for button: TargetShiftButton in _shift_buttons():
		assert_false(button.is_out())
		assert_false(button.visible)


func test_a_second_ship_brings_both_arrows_out_and_live() -> void:
	var first: Enemy = _ship()
	_target(first)
	_ship()
	computer.ensure_target()
	for button: TargetShiftButton in _shift_buttons():
		assert_true(button.visible)
		assert_false(button.is_live(), "pushed in until both are out")
	await _let_buttons_settle()
	for button: TargetShiftButton in _shift_buttons():
		assert_true(button.is_live())
		assert_eq(button._cap.position.y, 0.0, "popped up proud")


func test_down_to_one_ship_folds_the_arrows_away() -> void:
	var first: Enemy = _ship()
	var second: Enemy = _ship()
	_target(first)
	await _let_buttons_settle()

	manager.enemies.erase(second)
	computer.check_target_is_valid()
	await wait_seconds(0.6)
	for button: TargetShiftButton in _shift_buttons():
		assert_false(button.is_out())
		assert_false(button.visible)


func test_clicking_an_arrow_steps_the_target_and_bottoms_it_out() -> void:
	var first: Enemy = _ship()
	var second: Enemy = _ship()
	_target(first)
	await _let_buttons_settle()

	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	var right: TargetShiftButton = _shift_buttons()[1]
	right._clickable.input_event.emit(get_viewport(), click, 0)
	assert_eq(computer.targeted_enemy, second)
	assert_eq(right._cap.position.y, TargetShiftButton._TRAVEL)


func test_a_folded_arrow_ignores_presses() -> void:
	_target(_ship())
	var left: TargetShiftButton = _shift_buttons()[0]
	left.press()
	assert_false(left.is_live())
	assert_false(left.visible)


func test_the_right_arrow_hitbox_mirrors_the_left() -> void:
	var left: PackedVector2Array = _shift_buttons()[0]._hitbox.polygon
	var right: PackedVector2Array = _shift_buttons()[1]._hitbox.polygon
	assert_eq(left.size(), right.size())
	for i: int in range(left.size()):
		assert_eq(right[i], Vector2(-left[i].x, left[i].y))
