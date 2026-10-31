class_name JumpManager
extends Node2D

## Hyperspace through a jump gate is gold rather than the usual blue, so leaving
## a sector never reads as one more hop between tiles.
const _GATE_TINT: Color = Color(0.933, 0.827, 0.365)
const _GATE_PARTICLE_TINT: Color = Color(1.0, 0.93, 0.7)
## How long the gate's hyperspace holds before the new sector loads. Long
## enough for the sector title to be read.
const _GATE_HYPERSPACE_TIME: float = 2.4
const _TILE_UNLOCK_POPUP: PackedScene = preload("res://Source/Systems/UI/TileUnlockPopup/tile_unlock_popup.tscn")

func _ready() -> void:
	Globals.jump_manager = self
	Globals.map.request_jump_to_scenario.connect(jump_to_scenario)


## Plays the full hyperspace transition into a scenario: intro animation,
## scenario load, outro, then scenario start.
func jump_to_scenario(scenario: ScenarioResource) -> void:
	Events.jump.emit()

	# The dice shake harder as the drive spools up, and drop still the moment
	# hyperspace punches in.
	Globals.player.rattle_dice_for_jump(BackgroundManager.JUMP_RAMP_UP_TIME)
	await Globals.background_manager.play_jump_intro()
	Globals.player.settle_dice_after_jump()
	await get_tree().create_timer(2).timeout
	Events.load_scenario.emit(scenario)
	await Globals.background_manager.play_jump_outro()

	Events.start_scenario.emit()


## Leaves a sector through its open jump gate and arrives in the next one. The
## ship flies through the ring and the screen whites out into gold hyperspace,
## with the new sector's number across it, instead of the usual run-up.
func jump_through_gate(scenario: ScenarioResource, sector_number: int, sector_count: int) -> void:
	await _fly_through_gate()
	Globals.jump_gate.fade_flash(0.6)
	Globals.jump_gate.show_sector_title(sector_number, sector_count)

	await get_tree().create_timer(_GATE_HYPERSPACE_TIME).timeout
	await _unlock_tile_family(sector_number - 1)
	Events.load_scenario.emit(scenario)
	await Globals.background_manager.play_jump_outro()
	Globals.background_manager.reset_jump_tint()

	Globals.jump_gate.end_passage()
	Events.start_scenario.emit()


## Each new sector reached, in any run, unlocks the next tile family for good
## (TileUnlocks), on a card the jump holds in hyperspace for. Its tiles are on
## offer from the sector being entered, and one of them is in its first offer.
func _unlock_tile_family(sector_index: int) -> void:
	var claim: String = TileUnlocks.claim_for(RNGManager.current_run_seed, sector_index)
	var family: TileFamilyResource = TileUnlocks.unlock_for(claim)
	if family == null:
		return
	var opened: Array[TileResource] = TileUnlocks.tiles_opened_by(family)
	var featured: TileResource = Globals.reward_manager.pick_weighted_tile_reward(opened)
	if featured:
		Reward.forced_rewards.append(featured)

	var popup: TileUnlockPopup = _TILE_UNLOCK_POPUP.instantiate()
	add_child(popup)
	popup.global_position = Vector2.ZERO
	popup.open(family, opened, TileUnlocks.unlocked_count(), TileUnlocks.families().size())
	await popup.closed
	popup.queue_free()


## The last gate: through the ring and out of the run. Leaves the ship in gold
## hyperspace behind the white-out, for the victory screen to settle over.
func leave_through_final_gate() -> void:
	await _fly_through_gate()


## The run-up every gate passage shares, ending on the white frame with
## hyperspace behind it. The dice play it like any jump, with the ring's rush
## standing in for the drive spooling up.
func _fly_through_gate() -> void:
	Globals.jump_gate.begin_passage()
	Events.jump.emit()

	Globals.player.rattle_dice_for_jump(Globals.jump_gate.passage_duration())
	Globals.background_manager.set_jump_tint(_GATE_TINT, _GATE_PARTICLE_TINT)
	await Globals.jump_gate.play_passage()
	Globals.player.settle_dice_after_jump()
	Globals.background_manager.cut_to_hyperspace()
