extends "res://test/helpers/die_fighter_test.gd"
## Purple (engine) tiles whose chains or checks were reworked: each one pays
## what its text says it costs and refuses a die it would only waste.

const RecordingEngine := preload("res://test/helpers/recording_engine.gd")
const ENEMY_SCENE: PackedScene = preload("res://Source/Content/Enemies/enemy.tscn")
const TILE_SCENE: PackedScene = preload("res://Source/Content/Tiles/tile.tscn")
const DICE_SCENE: PackedScene = preload("res://Source/Systems/Game/Dice/dice.tscn")
const TILES: String = "res://Source/Content/Tiles/TileResources/%s.tres"

var engine: RecordingEngine
var enemy: Enemy


func before_each() -> void:
	super()
	engine = autofree(RecordingEngine.new())
	enemy = autofree(ENEMY_SCENE.instantiate())
	enemy.scenario_state = ScenarioShipState.new()
	var computer: TargetingComputer = autofree(TargetingComputer.new())
	computer.targeted_enemy = enemy
	Globals.targeting_computer = computer


## Plays [param chain] as [param tile_id]'s, from (1, 1) of a 5x3 grid, with a
## die showing [param face] and a 3-dice player (a 10-charge drive) holding
## [param charge].
func _play(tile_id: String, face: int, charge: int, chain: EffectChain = null, passes: int = 1) -> Array[EffectEvent]:
	engine.injected.clear()
	var resource: TileResource = load(TILES % tile_id)
	Globals.player = make_player(3, charge)
	var grid: TileGrid = autofree(TileGrid.new())
	Globals.tile_grid = grid
	var tile: Tile = autofree(TILE_SCENE.instantiate())
	tile.sprite_frames = null
	tile.tile_resource = resource
	grid.tile_locations[Vector2i(1, 1)] = tile
	var die: Dice = autofree(DICE_SCENE.instantiate())
	die.value = face
	var context: EffectContext = EffectContext.new()
	context.effect_source = tile
	context.activator_die = die
	context.repetitions = passes
	await (chain if chain else resource.effect_chain).play(context, engine)
	return engine.injected.duplicate()


func _amounts(events: Array[EffectEvent], script: Script) -> Array[int]:
	var out: Array[int] = []
	for event: EffectEvent in events:
		if is_instance_of(event, script):
			out.append(event.amount)
	return out


## Whether every activation check on [param tile_id] lets a die showing
## [param face] in, for a 3-dice player holding [param charge].
func _accepts(tile_id: String, face: int, charge: int) -> bool:
	var resource: TileResource = load(TILES % tile_id)
	Globals.player = make_player(3, charge)
	var die: Dice = autofree(DICE_SCENE.instantiate())
	die.value = face
	for check: ActivationResource in resource.activation_checks:
		if check.type == ActivationResource.ActivationType.SHIP_TARGETED:
			continue
		if not check.criteria_satisfied(die):
			return false
	return true


func _turn_end_response(tile_id: String) -> EffectChain:
	var resource: TileResource = load(TILES % tile_id)
	for event: TileEvent in resource.event_responses:
		if event.event == TileEvent.EventType.ON_ENEMY_TURN_OVER:
			return resource.event_responses[event]
	return null

func test_brownout_plating_shields_only_an_empty_drive() -> void:
	var response: EffectChain = _turn_end_response("brownout_plating")
	assert_eq(_amounts(await _play("brownout_plating", 0, 0, response), ShieldEvent), [4])
	assert_eq(_amounts(await _play("brownout_plating", 0, 1, response), ShieldEvent), [], "any charge turns it off")
	var plus: EffectChain = _turn_end_response("brownout_plating_plus")
	assert_eq(_amounts(await _play("brownout_plating_plus", 0, 0, plus), ShieldEvent), [6])


func test_deadweight_drive_refuses_a_die_on_a_full_drive() -> void:
	assert_true(_accepts("deadweight_drive", 1, 9))
	assert_false(_accepts("deadweight_drive", 1, 10), "nothing missing, nothing to deal")


func test_overdraw_coil_refuses_a_die_on_an_empty_drive() -> void:
	assert_false(_accepts("overdraw_coil", 1, 0), "no charge, no damage")
	assert_true(_accepts("overdraw_coil", 1, 1))


func test_charge_spenders_cost_what_their_text_says() -> void:
	assert_eq(_amounts(await _play("repo_beam", 3, 10), SpendEngineChargeEvent), [5])
	assert_eq(_amounts(await _play("repo_beam_plus", 3, 10), SpendEngineChargeEvent), [3])
	assert_eq(_amounts(await _play("sabotage_charge", 3, 10), SpendEngineChargeEvent), [6])
	assert_eq(_amounts(await _play("sabotage_charge_plus", 3, 10), SpendEngineChargeEvent), [4])


## Every tile takes an echo now, the charge spenders too. An echoed pass is
## the chain played twice: each pass asks for its price (one it can't afford
## takes nothing), and the die is still handed on exactly once.
func test_echoed_charge_spenders_pay_each_pass_and_hand_the_die_on_once() -> void:
	for id: String in ["arc_tap", "afterburner_relay", "bootstrap_injector",
			"sabotage_charge", "repo_beam", "overdraw_coil"]:
		for suffix: String in ["", "_plus"]:
			var events: Array[EffectEvent] = await _play(id + suffix, 1, 10, null, 2)
			var handoffs: int = 0
			for event: EffectEvent in events:
				if event is GiveDieToPlayerEvent or event is GiveDieToTargetEvent \
						or event is PassDieToTileEvent:
					handoffs += 1
			assert_eq(handoffs, 1, "%s hands its die on once" % (id + suffix))
			if id != "overdraw_coil":
				assert_eq(engine.injected_of(SpendEngineChargeEvent).size(), 2,
					"%s asks for its price each pass" % (id + suffix))
