class_name JumpManager
extends Node2D

## Hyperspace through a jump gate is gold rather than the usual blue, so leaving
## a sector never reads as one more hop between tiles.
const _GATE_TINT: Color = Color(0.933, 0.827, 0.365)
const _GATE_PARTICLE_TINT: Color = Color(1.0, 0.93, 0.7)
## How long the gate's hyperspace holds before the new sector loads. Long
## enough for the sector title to be read.
const _GATE_HYPERSPACE_TIME: float = 2.4

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
	Globals.jump_gate.begin_passage()
	Events.jump.emit()

	Globals.background_manager.set_jump_tint(_GATE_TINT, _GATE_PARTICLE_TINT)
	await Globals.jump_gate.play_passage()
	Globals.background_manager.cut_to_hyperspace()
	Globals.jump_gate.fade_flash(0.6)
	Globals.jump_gate.show_sector_title(sector_number, sector_count)

	await get_tree().create_timer(_GATE_HYPERSPACE_TIME).timeout
	Events.load_scenario.emit(scenario)
	await Globals.background_manager.play_jump_outro()
	Globals.background_manager.reset_jump_tint()

	Globals.jump_gate.end_passage()
	Events.start_scenario.emit()


## The last gate: through the ring and out of the run. Leaves the ship in gold
## hyperspace behind the white-out, for the victory screen to settle over.
func leave_through_final_gate() -> void:
	Globals.jump_gate.begin_passage()
	Events.jump.emit()

	Globals.background_manager.set_jump_tint(_GATE_TINT, _GATE_PARTICLE_TINT)
	await Globals.jump_gate.play_passage()
	Globals.background_manager.cut_to_hyperspace()
