extends "res://test/helpers/die_fighter_test.gd"
## Enemies passing dice to each other: Feed Ally hands over the die it was
## given, Holo Loader conjures one. The rule that matters most is that a relay
## chain can never loop, and that's kept at selection time: the binder never
## points a relay where it could lead back to itself, and rerolls the slot when
## no ally qualifies.

const Ships := preload("res://test/helpers/ships.gd")
const RecordingEngine := preload("res://test/helpers/recording_engine.gd")
const Faction := ScenarioManager.Faction
const Relay := EnemyActionResource.Relay


func before_each() -> void:
	super()
	RNGManager.seed_scenario(4242)


func _ship(faction: Faction = Faction.PIRATE, hull: int = 10) -> Enemy:
	var made: Enemy = Ships.ship(faction, hull)
	autofree(made.health)
	return autofree(made)


## A table of six of the same action, fresh copies so bindings don't share.
func _table_of(make: Callable) -> Array[EnemyActionResource]:
	var actions: Array[EnemyActionResource] = []
	for i: int in range(6):
		actions.append(make.call())
	return actions


func _hologram(face: int) -> EnemyActionResource:
	var action := Ships.loader()
	action.intent_amount = face
	return action


## Every (ship, face) walked forward through the relays ends, never revisiting
## a node.
func _assert_no_loops(roster: Array[Enemy]) -> void:
	for ship: Enemy in roster:
		for face: int in range(1, 7):
			var seen: Dictionary[String, bool] = {}
			var at: Array = [ship, face]
			while not at.is_empty():
				var key: String = "%d:%d" % [(at[0] as Enemy).get_instance_id(), at[1]]
				if seen.has(key):
					fail_test("relay loop through %s face %d" % [(at[0] as Enemy).enemy_resource.enemy_name, at[1]])
					return
				seen[key] = true
				at = EnemyTargetBinder.next_hop(at[0], at[1])


# ── What a relay is, read off its chain ────────────────────────────────────────

func test_a_relay_feeds_and_binds_an_ally() -> void:
	var relay := Ships.relay()
	assert_eq(relay.get_relay(), Relay.FEED)
	assert_eq(relay.get_binding(), EnemyActionResource.Binding.ALLY)
	assert_eq(relay.relay_face(4), 4)


func test_a_loader_lands_its_hologram_on_its_intent_amount() -> void:
	var loader := _hologram(5)
	assert_eq(loader.get_relay(), Relay.HOLOGRAM)
	assert_eq(loader.get_binding(), EnemyActionResource.Binding.ALLY)
	assert_eq(loader.relay_face(2), 5)
	loader.intent_amount = 9
	assert_eq(loader.relay_face(2), 6, "clamped to a die face")


func test_an_ordinary_action_relays_nothing() -> void:
	assert_eq(Ships.attack().get_relay(), Relay.NONE)
	assert_eq(Ships.attack().relay_face(3), 0)


func test_a_relay_by_itself_threatens_nobody() -> void:
	assert_eq(Ships.relay().get_threat(), EnemyActionResource.Threat.NEUTRAL,
		"it shields itself; the feed is only a hand-off")


func test_the_shipped_relay_actions_do_what_they_say() -> void:
	# Ordinals in .tres files are raw ints; this is what catches a Relay that
	# quietly spawns holograms instead.
	var relay: EnemyActionResource = load("res://Source/Content/Enemies/EnemyActions/EnemyActionResources/relay.tres")
	var loader: EnemyActionResource = load("res://Source/Content/Enemies/EnemyActions/EnemyActionResources/holo_loader.tres")
	assert_eq(relay.get_relay(), Relay.FEED)
	assert_eq(loader.get_relay(), Relay.HOLOGRAM)
	assert_true(relay.is_safe_while_hidden())
	assert_true(loader.is_safe_while_hidden())


# ── Loop detection ─────────────────────────────────────────────────────────────

func test_feeding_back_to_whoever_fed_you_on_the_same_face_loops() -> void:
	var a := _ship()
	var b := _ship()
	Ships.set_table(a, _table_of(Ships.relay))
	Ships.set_table(b, _table_of(Ships.relay))
	a.turn_actions[3].bound_target = b
	assert_true(EnemyTargetBinder.would_loop(b, 4, a, 4), "B's 4 to A, whose 4 feeds B")
	assert_false(EnemyTargetBinder.would_loop(b, 3, a, 3), "A's 3 isn't bound to anyone")


func test_a_hologram_moves_the_chain_to_another_face() -> void:
	var a := _ship()
	var b := _ship()
	Ships.set_table(a, _table_of(Ships.relay))
	Ships.set_table(b, _table_of(Ships.attack))
	# A's 2 conjures a 5 for B; B's 5 feeds A; would A's 5 feeding B loop?
	a.turn_actions[1] = _hologram(5)
	a.turn_actions[1].bound_target = b
	b.turn_actions[4] = Ships.relay()
	b.turn_actions[4].bound_target = a
	assert_true(EnemyTargetBinder.would_loop(a, 5, b, 5))
	assert_false(EnemyTargetBinder.would_loop(a, 3, b, 3))


func test_a_dead_ally_ends_the_walk() -> void:
	var a := _ship()
	var b := _ship()
	Ships.set_table(a, _table_of(Ships.relay))
	Ships.set_table(b, _table_of(Ships.relay))
	a.turn_actions[0].bound_target = b
	b.health.health = 0
	assert_true(EnemyTargetBinder.next_hop(a, 1).is_empty())


# ── Binding ────────────────────────────────────────────────────────────────────

func test_two_ships_full_of_relays_never_feed_each_other_in_a_circle() -> void:
	var a := _ship()
	var b := _ship()
	var relay_and_attack: Array[EnemyActionOptionResource] = [Ships.option(Ships.relay(), 5.0), Ships.option(Ships.attack(), 1.0)]
	Ships.give_pool(a, relay_and_attack)
	Ships.give_pool(b, relay_and_attack)
	Ships.set_table(a, _table_of(Ships.relay))
	Ships.set_table(b, _table_of(Ships.relay))

	var roster := Ships.roster([a, b])
	EnemyTargetBinder.bind(roster, roster)
	_assert_no_loops(roster)

	# A bound all six to B first, so every one of B's relays had to give way.
	for face: int in range(6):
		assert_eq(a.turn_actions[face].bound_target, b)
		assert_eq(b.turn_actions[face].get_relay(), Relay.NONE, "B's %d was rerolled" % (face + 1))


func test_every_relay_that_stays_is_bound_to_a_living_ally() -> void:
	var a := _ship()
	var b := _ship()
	var c := _ship()
	var options: Array[EnemyActionOptionResource] = [Ships.option(Ships.relay(), 3.0), Ships.option(Ships.attack(), 1.0)]
	for ship: Enemy in [a, b, c]:
		Ships.give_pool(ship, options)
	var roster := Ships.roster([a, b, c, _ship(Faction.CIVILIAN)])
	var pirates := Ships.roster([a, b, c])
	for ship: Enemy in pirates:
		ship.generate_turn_actions(EnemyActionSituation.for_ship(ship, roster))
	EnemyTargetBinder.bind(pirates, roster)

	for ship: Enemy in pirates:
		for action: EnemyActionResource in ship.turn_actions:
			if action.get_relay() == Relay.NONE:
				continue
			assert_not_null(action.bound_target)
			assert_ne(action.bound_target, ship)
			assert_eq(action.bound_target.scenario_state.faction, Faction.PIRATE)


func test_fuzzed_rosters_never_bind_a_loop() -> void:
	# The selection-time guarantee, hammered: relay-heavy pools, holograms on
	# every face, two to four ships, three hundred seeds.
	var options: Array[EnemyActionOptionResource] = [
		Ships.option(Ships.relay(), 4.0),
		Ships.option(Ships.loader(), 2.0, 1, 6),
		Ships.option(Ships.attack(), 1.0),
	]
	var bound_relays: Dictionary[Relay, int] = {Relay.FEED: 0, Relay.HOLOGRAM: 0}
	var unbound_relays: int = 0
	for run: int in range(300):
		RNGManager.seed_scenario(run)
		var pirates: Array[Enemy] = []
		for i: int in range(2 + run % 3):
			var ship := _ship()
			Ships.give_pool(ship, options)
			pirates.append(ship)
		for ship: Enemy in pirates:
			ship.generate_turn_actions(EnemyActionSituation.for_ship(ship, pirates))
		EnemyTargetBinder.bind(pirates, pirates)
		_assert_no_loops(pirates)
		if is_failing():
			gut.p("failed on seed %d" % run)
			return
		for ship: Enemy in pirates:
			for action: EnemyActionResource in ship.turn_actions:
				var relay: Relay = action.get_relay()
				if relay == Relay.NONE:
					continue
				if action.bound_target:
					bound_relays[relay] += 1
				else:
					unbound_relays += 1

	assert_eq(unbound_relays, 0, "a relay that can't be bound safely is rerolled, not left hanging")
	assert_gt(bound_relays[Relay.FEED], 300, "feeds were exercised")
	assert_gt(bound_relays[Relay.HOLOGRAM], 100, "holograms were exercised")


func test_a_relay_whose_target_dies_is_rebound_only_where_it_cannot_loop() -> void:
	var a := _ship()
	var b := _ship()
	var c := _ship()
	for ship: Enemy in [a, b, c]:
		Ships.set_table(ship, _table_of(Ships.attack))
	a.turn_actions[3] = Ships.relay()
	a.turn_actions[3].bound_target = b
	b.turn_actions[3] = Ships.relay()
	b.turn_actions[3].bound_target = c

	# C leaves. B's 4 could only go to A, whose 4 feeds B: it stays unbound.
	EnemyTargetBinder.rebind_departed(c, Ships.roster([a, b]))
	assert_null(b.turn_actions[3].bound_target)
	assert_eq(b.turn_actions[3].get_relay(), Relay.FEED, "a visible action isn't rerolled mid-turn")


# ── Threat follows the die ─────────────────────────────────────────────────────

func test_a_relay_slot_carries_the_threat_of_where_the_die_ends_up() -> void:
	var a := _ship()
	var b := _ship()
	Ships.set_table(a, _table_of(Ships.relay))
	Ships.set_table(b, _table_of(Ships.attack))
	a.turn_actions[2].bound_target = b
	assert_eq(a.threat_of_face(3), EnemyActionResource.Threat.DANGEROUS)
	assert_eq(b.threat_of_face(3), EnemyActionResource.Threat.DANGEROUS)
	# Unbound, the relay falls back to its own (shield-only) threat.
	assert_eq(a.threat_of_face(2), EnemyActionResource.Threat.NEUTRAL)


# ── The handlers ───────────────────────────────────────────────────────────────

func test_feed_ally_hands_off_once_with_the_actor_marked_visited() -> void:
	var engine: RecordingEngine = autofree(RecordingEngine.new())
	var actor := _ship()
	var ally := _ship()
	var context := EffectContext.new()
	context.actor = actor
	context.activator_die = autofree(FakeDie.new(4))
	context.bound_target = ally
	context.feed_depth = 1
	context.repetitions = 0
	var data := Effects.data(EffectEnums.Category.DICE_CONTROL, EffectEnums.DiceControlSubtype.FEED_ALLY)

	FeedAllyHandler.new().apply(data, context, engine)
	var feeds := engine.injected_of(FeedAllyEvent)
	assert_eq(feeds.size(), 1)
	var feed: FeedAllyEvent = feeds[0]
	assert_eq(feed.ally, ally)
	assert_eq(feed.feed_depth, 1)
	assert_eq_deep(feed.relay_visited, [actor] as Array[Node])


func test_feed_ally_waits_for_the_last_repetition() -> void:
	var engine: RecordingEngine = autofree(RecordingEngine.new())
	var context := EffectContext.new()
	context.actor = _ship()
	context.activator_die = autofree(FakeDie.new(2))
	context.repetitions = 1
	FeedAllyHandler.new().apply(Effects.data(EffectEnums.Category.DICE_CONTROL, EffectEnums.DiceControlSubtype.FEED_ALLY), context, engine)
	assert_true(engine.injected.is_empty())


func test_a_hologram_takes_the_intent_amount_as_its_face() -> void:
	var engine: RecordingEngine = autofree(RecordingEngine.new())
	var context := EffectContext.new()
	context.actor = _ship()
	context.bound_target = _ship()
	context.enemy_intent_amount = 8
	context.repetitions = 0
	SpawnHologramForAllyHandler.new().apply(Effects.data(EffectEnums.Category.DICE_CONTROL, EffectEnums.DiceControlSubtype.SPAWN_HOLOGRAM_FOR_ALLY), context, engine)
	var spawns := engine.injected_of(SpawnHologramForAllyEvent)
	assert_eq(spawns.size(), 1)
	assert_eq((spawns[0] as SpawnHologramForAllyEvent).amount, 6)


func test_nobody_already_in_the_chain_can_be_fed_again() -> void:
	var a := _ship()
	var b := _ship()
	Ships.set_table(b, _table_of(Ships.attack))
	assert_true(FeedAllyEvent.can_feed(b, [a] as Array[Node]))
	assert_false(FeedAllyEvent.can_feed(b, [a, b] as Array[Node]))
	b.health.health = 0
	assert_false(FeedAllyEvent.can_feed(b, [] as Array[Node]))
