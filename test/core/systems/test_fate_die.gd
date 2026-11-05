extends "res://test/helpers/die_fighter_test.gd"
## Fate's Die and the run's memory behind the secret fight (LORE.md §5-§7):
## how faces carve, how the Tally replays the kills, where the pilgrim is
## dealt, and that all of it survives a save.

const F := FateDie.Face


# ── Carving ──────────────────────────────────────────────────────────────────

func test_carvings_fill_blank_faces_in_order() -> void:
	var die: FateDie = FateDie.new()
	assert_true(die.is_blank())
	assert_eq(die.carve(F.MERCY), 0)
	assert_eq(die.carve(F.RUIN), 1)
	assert_eq(die.face_at(0), F.MERCY)
	assert_eq(die.blank_count(), FateDie.FACE_COUNT - 2)


func test_a_full_die_carves_only_over_a_chosen_face() -> void:
	var die: FateDie = FateDie.new()
	for i: int in FateDie.FACE_COUNT:
		die.carve(F.RUIN)
	assert_true(die.is_full())
	assert_eq(die.carve(F.MERCY), -1, "nowhere blank: the player must choose")
	assert_eq(die.count(F.RUIN), FateDie.FACE_COUNT, "a refused carving changes nothing")
	assert_eq(die.carve_over(2, F.MERCY), F.RUIN, "carve_over hands back what it replaced")
	assert_eq(die.face_at(2), F.MERCY)


func test_blank_is_never_a_carving() -> void:
	var die: FateDie = FateDie.new()
	assert_eq(die.carve(F.BLANK), -1)
	die.carve(F.DUTY)
	assert_eq(die.carve_over(0, F.BLANK), F.BLANK)
	assert_eq(die.face_at(0), F.DUTY)


func test_a_die_survives_its_save_data_and_bad_data() -> void:
	var die: FateDie = FateDie.new()
	die.carve(F.HUNGER)
	die.carve(F.STRANGE)
	assert_eq(FateDie.from_data(die.to_data()).faces, die.faces)
	# A face renamed away, a short list, garbage: blank faces, no failure.
	var odd: FateDie = FateDie.from_data(["mercy", "no_such_face"])
	assert_eq(odd.face_at(0), F.MERCY)
	assert_eq(odd.face_at(1), F.BLANK)
	assert_true(FateDie.from_data(null).is_blank())


func test_a_ledger_needs_the_die_before_anything_carves() -> void:
	var ledger: FateLedger = autofree(FateLedger.new())
	ledger.request_carve(F.MERCY)
	assert_true(ledger.die.is_blank(), "Fate only notices people holding its die")
	ledger.give_die()
	ledger.request_carve(F.MERCY)
	assert_eq(ledger.die.face_at(0), F.MERCY)


func test_a_carving_on_a_full_die_waits_for_the_players_choice() -> void:
	var ledger: FateLedger = autofree(FateLedger.new())
	ledger.give_die()
	for i: int in FateDie.FACE_COUNT:
		ledger.request_carve(F.RUIN)
	ledger.request_carve(F.MERCY)
	assert_true(ledger.has_pending())
	assert_eq(ledger.die.count(F.MERCY), 0)
	ledger.resolve_pending(4)
	assert_false(ledger.has_pending())
	assert_eq(ledger.die.face_at(4), F.MERCY)
	# Letting one pass keeps the die as it was.
	ledger.request_carve(F.DUTY)
	ledger.resolve_pending(-1)
	assert_eq(ledger.die.count(F.DUTY), 0)


# ── The Tally ────────────────────────────────────────────────────────────────

func _kills(ids: Array) -> Array[Dictionary]:
	var kill_log: Array[Dictionary] = []
	for id: Variant in ids:
		kill_log.append({"enemy": str(id), "faction": "rearguard" if str(id).begins_with("r") else "undertow"})
	return kill_log


func test_the_tally_plays_kills_backwards_and_ends_on_the_first() -> void:
	var waves: Array[Array] = FateLedger.tally_waves(_kills(["a", "b", "c", "d", "e"]), [], 6, 2)
	assert_eq(waves, [["e", "d"], ["c", "b"], ["a"]] as Array[Array])


func test_a_long_run_keeps_its_latest_kills_and_still_ends_on_the_first() -> void:
	var ids: Array = []
	for i: int in 30:
		ids.append("k%d" % i)
	var waves: Array[Array] = FateLedger.tally_waves(_kills(ids), [], 3, 2)
	assert_eq(waves.size(), 3)
	assert_eq(waves[0], ["k29", "k28"])
	assert_eq(waves.back(), ["k0"])


func test_the_tally_can_leave_a_faction_out() -> void:
	var waves: Array[Array] = FateLedger.tally_waves(_kills(["a", "r1", "b"]), ["rearguard"], 6, 3)
	assert_eq(waves, [["b"], ["a"]] as Array[Array])
	assert_eq(FateLedger.tally_waves([] as Array[Dictionary]), [] as Array[Array])


# ── The pilgrim ──────────────────────────────────────────────────────────────

func test_the_pilgrim_is_dealt_past_the_first_jump_without_drawing() -> void:
	var combat := ScenarioResource.new()
	var pilgrim := ScenarioResource.new()
	var shop := ScenarioResource.new()
	var before: int = RNGManager.get_rng(RNGManager.Bucket.RUN).state
	for placement_seed: int in 30:
		var scenarios: Array[ScenarioResource] = [shop, combat, combat]
		for i: int in 14:
			scenarios.append(combat)
		scenarios.append(shop)
		var arrival: int = 2
		SectorGenerator.place_fate_pilgrim(scenarios, arrival, [combat] as Array[ScenarioResource],
			pilgrim, placement_seed)
		assert_eq(scenarios.count(pilgrim), 1)
		assert_gt(scenarios.find(pilgrim), arrival + 6, "out of the first jump's reach")
		assert_eq(scenarios.back(), shop, "never the last stop")
	assert_eq(RNGManager.get_rng(RNGManager.Bucket.RUN).state, before)


# ── Saves ────────────────────────────────────────────────────────────────────

func test_the_ledger_comes_back_from_a_json_save() -> void:
	var ledger: FateLedger = autofree(FateLedger.new())
	ledger.give_die()
	ledger.request_carve(F.PLUNDER)
	for i: int in FateDie.FACE_COUNT:
		ledger.request_carve(F.DUTY)
	ledger.kills.append({"enemy": "gaff", "faction": "undertow", "sector": 1})
	ledger.allies.append({"enemy": "hauler", "kind": FateLedger.KIND_ALLY})
	ledger.record_deed(FateLedger.DEED_TITHE_REFUSED)
	ledger.in_reckoning = true
	ledger.reckoning_seed = 12345
	ledger.knew_secret = true

	# Through JSON, as the save goes: every number comes back a float.
	var state: Variant = JSON.parse_string(JSON.stringify(ledger.get_state()))
	var loaded: FateLedger = autofree(FateLedger.new())
	loaded.load_state(state)
	assert_true(loaded.has_die)
	assert_eq(loaded.die.faces, ledger.die.faces)
	assert_eq(loaded.pending, ledger.pending)
	assert_eq(loaded.kills, ledger.kills)
	assert_eq(loaded.allies, ledger.allies)
	assert_true(loaded.refused_every_tithe())
	assert_true(loaded.in_reckoning)
	assert_eq(loaded.reckoning_seed, 12345)
	assert_true(loaded.fate_route_open())
