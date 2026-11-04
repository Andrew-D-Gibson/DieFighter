extends "res://test/helpers/die_fighter_test.gd"
## RECEIVE_DIE_FROM_TARGET (Repo Beam): the handler aims the event at the
## chain's targets, and the event moves the target's newest die to the actor.

const RecordingEngine := preload("res://test/helpers/recording_engine.gd")
const _DICE_SCENE: PackedScene = preload("res://Source/Systems/Game/Dice/dice.tscn")


## A ship-shaped holder whose queue is in the tree (DiceQueue.add reads its
## global position) and whose dice are not (Dice reach for game systems).
func _ship(faces: Array[int]) -> Player:
	var ship: Player = autofree(Player.new())
	ship.dice_manager = add_child_autofree(DiceQueue.new())
	for face: int in faces:
		var die: Dice = autofree(_DICE_SCENE.instantiate())
		die.value = face
		ship.dice_manager.queue.append(die)
		die.host_queue = ship.dice_manager
	return ship


func test_handler_aims_the_event_at_the_chain_targets() -> void:
	var engine: RecordingEngine = autofree(RecordingEngine.new())
	var context := EffectContext.new()
	var target: Player = _ship([])
	context.targets = [target]
	var data := Effects.data(EffectEnums.Category.DICE_CONTROL,
		EffectEnums.DiceControlSubtype.RECEIVE_DIE_FROM_TARGET)
	await EffectRegistry.get_handler(data.category, data.subtype).apply(data, context, engine)

	var events: Array[EffectEvent] = engine.injected_of(ReceiveDieFromTargetEvent)
	assert_eq(events.size(), 1)
	assert_eq(events[0].targets, [target] as Array[Node])


func test_event_moves_the_targets_newest_die_to_the_actor() -> void:
	var target: Player = _ship([3, 5])
	var actor: Player = _ship([])
	var newest: Dice = target.dice_manager.queue[-1]

	var event := ReceiveDieFromTargetEvent.new()
	event.actor = actor
	event.targets = [target]
	event.resolve(null)

	assert_eq(target.dice_manager.queue.size(), 1)
	assert_eq(actor.dice_manager.queue, [newest] as Array[Dice])
	assert_eq(newest.host_queue, actor.dice_manager)


func test_event_does_nothing_when_the_target_holds_no_dice() -> void:
	var actor: Player = _ship([])
	var event := ReceiveDieFromTargetEvent.new()
	event.actor = actor
	event.targets = [_ship([])]
	event.resolve(null)
	assert_eq(actor.dice_manager.queue.size(), 0)
