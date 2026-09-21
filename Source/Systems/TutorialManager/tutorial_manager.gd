class_name TutorialManager
extends Node2D

## Narrates the first encounter of an ordinary run.
##
## The tutorial has no save, scenario list, or ending of its own. The game
## already opens mid-ambush (see GameStateManager.starting_scenario), which is
## exactly the situation the tutorial needs to teach: a tile to fire, an enemy
## that answers with the dice it was handed, wreckage to salvage, and a jump out.
## So the tutorial runs as an overlay on that encounter and then steps aside —
## when the last step closes, the player is already in sector one of a real run.
##
## Steps are authored as TutorialStep resources; this class only sequences them
## and owns the small set of gameplay pokes they can request.

## Whether the tutorial narrates this run at all. Off means the cold open plays
## exactly as it would for a returning player.
@export var auto_start: bool = true

## Debug aid: drop this many steps, applying their forced dice/actions/rewards
## so the run state stays consistent, and start from the one after.
@export var skip_to_step: int = 0

@export var tutorial_steps: Array[TutorialStep] = []

## Applied once before anything spawns, so the opening ambush is dealt a known
## hand and a known set of enemy intents. A step can't do this: the player's
## first dice and the ambusher's first turn are both generated during scene
## setup, before any step has had a chance to run.
@export var opening_setup: TutorialStep

## Screen-space x span the tutorial's popups sit in. While the tutorial is
## narrating, the enemy formation treats this as occupied and stands clear of
## it, which is why the opening ambusher hangs off to one side during the
## tutorial and sits dead centre on every run after. Nothing else about the
## encounter changes — see [EnemyFormation].
@export var popup_screen_span: Vector2 = Vector2(140, 320)

## Seconds a step may wait on its closing signal before the tutorial gives up,
## logs, and moves on. A step whose signal never fires would otherwise hang the
## game forever with no way out. Deliberately generous — this is a bug backstop,
## not a patience limit — and steps can override it with max_wait_time.
@export var default_step_timeout: float = 120.0

## Identifies the space the tutorial holds against the enemy formation.
const _FORMATION_KEY: StringName = &"tutorial"

var tutorial_text_popup_scene: PackedScene = preload("uid://dauuk425cis74")

var current_step_index: int = -1
var current_popup: TutorialTextPopup

## Guards against a second start_tutorial() running over the first.
var is_active: bool = false

## While true, newly spawned dice are locked as they arrive. Dice spawn one at a
## time on a timer, so locking only what exists at call time would miss the rest.
var _dice_locked: bool = false


var tutorial_functions: Dictionary[TutorialStep.TutorialFunctions, Callable] = {
	TutorialStep.TutorialFunctions.REVEAL_HEALTH_BAR: _reveal_health_bar,
	TutorialStep.TutorialFunctions.TRIGGER_ENEMY_SPAWN: _spawn_enemy,
	TutorialStep.TutorialFunctions.REVEAL_SYSTEMS: _reveal_systems,
	TutorialStep.TutorialFunctions.SPAWN_DICE: _spawn_dice,
	TutorialStep.TutorialFunctions.ALLOW_DICE_DRAGGING: _allow_dice_dragging,
	TutorialStep.TutorialFunctions.REVEAL_TARGETING_COMPUTER: _reveal_targeting_computer,
	TutorialStep.TutorialFunctions.RUN_ENEMY_TURN: _run_enemy_turn,
	TutorialStep.TutorialFunctions.ALLOW_NORMAL_COMBAT: _allow_normal_combat,
	TutorialStep.TutorialFunctions.REVEAL_MAP: _reveal_map,
	TutorialStep.TutorialFunctions.ENABLE_RIGHT_CONTROL: _enable_right_control,
	TutorialStep.TutorialFunctions.ENABLE_ALL_CONTROLS: _enable_controls,
	TutorialStep.TutorialFunctions.LOCK_DICE: _lock_dice,
	TutorialStep.TutorialFunctions.UNLOCK_DICE: _unlock_dice,
	TutorialStep.TutorialFunctions.FINISH_TUTORIAL: _finish_tutorial,
	TutorialStep.TutorialFunctions.REROLL_ENEMY_INTENTS: _reroll_enemy_intents,
}


func _ready() -> void:
	Globals.tutorial_manager = self
	_assert_every_function_is_wired()

	# These are statics and Globals is an autoload, so both outlive a return to
	# the main menu. Clear them here rather than trusting the last run to have
	# consumed everything it queued.
	Dice.forced_rolls.clear()
	Enemy.forced_actions.clear()
	Reward.forced_rewards.clear()
	Globals.tutorial_active = false
	Globals.tutorial_controls_enemy_turns = false

	# A player who picked Continue has seen all of this already.
	if not auto_start or tutorial_steps.is_empty() or Globals.pending_load_save:
		return

	Globals.tutorial_active = true
	Globals.tutorial_controls_enemy_turns = true
	_claim_formation_space()

	if opening_setup:
		_apply_step_forcing(opening_setup)

	Globals.map.disable_controls()

	for _skipped: int in range(mini(skip_to_step, tutorial_steps.size())):
		var step: TutorialStep = tutorial_steps.pop_front()
		_apply_step_forcing(step)
		if step.tutorial_function in tutorial_functions:
			tutorial_functions[step.tutorial_function].call()

	start_tutorial()


## Keeps the enemy formation out from under the tutorial's popups. Claimed
## before the first scenario loads, so the opening ambusher is placed off to
## the side from the moment it spawns rather than sliding over afterwards.
func _claim_formation_space() -> void:
	if not Globals.enemy_manager:
		push_warning("TutorialManager: no EnemyManager to reserve popup space with.")
		return
	Globals.enemy_manager.reserve_formation_space(
		_FORMATION_KEY, popup_screen_span.x, popup_screen_span.y
	)


## Catches a TutorialFunctions value that was added to the enum but never
## wired to a Callable — otherwise the step just silently does nothing, which
## is a miserable thing to debug from the authoring side.
func _assert_every_function_is_wired() -> void:
	for value: int in TutorialStep.TutorialFunctions.values():
		if value == TutorialStep.TutorialFunctions.NONE:
			continue
		assert(
			value in tutorial_functions,
			"TutorialManager has no Callable for TutorialFunctions value %d" % value
		)


func create_tutorial_popup(text: String, global_pos: Vector2, highlight_texture: Texture2D = null, time_delay: float = 0, close_button: bool = true, auto_close_time: float = 0) -> void:
	if current_popup and is_instance_valid(current_popup):
		current_popup.close()
		
	current_popup = tutorial_text_popup_scene.instantiate()
	add_child(current_popup)

	current_popup.setup(text, global_pos, highlight_texture, time_delay, close_button, auto_close_time)
	

func start_tutorial() -> void:
	if is_active:
		return
	is_active = true

	for i: int in range(len(tutorial_steps)):
		current_step_index = i
		var step: TutorialStep = tutorial_steps[i]

		await get_tree().create_timer(step.time_delay).timeout

		await play_step(step)
		await _await_popup_closed(step)

	is_active = false


func play_step(step: TutorialStep) -> void:
	match step.open_on_signal:
		TutorialStep.TutorialSignals.CLICKED_OUT_OF_INFO:
			await Events.info_graphic_closed
			
		TutorialStep.TutorialSignals.ON_ENEMY_FLY_IN:
			await Events.enemy_flew_in
			
		TutorialStep.TutorialSignals.REWARD_CLAIMED:
			await Events.reward_picked

	_apply_step_forcing(step)

	# Create the text popup
	if step.close_on_signal == TutorialStep.TutorialSignals.CLOSED_MANUALLY:
		create_tutorial_popup(step.tutorial_text, step.text_position, step.highlight_texture, step.time_delay, true)
	elif step.close_on_signal == TutorialStep.TutorialSignals.CLOSED_AFTER_TIME:
		create_tutorial_popup(step.tutorial_text, step.text_position, step.highlight_texture, step.time_delay, false, step.time_to_auto_close)
	else:
		create_tutorial_popup(step.tutorial_text, step.text_position, step.highlight_texture, step.time_delay, false)

		var closing_signal: Signal = _closing_signal_for(step)
		if closing_signal:
			closing_signal.connect(current_popup.close)

	# Handle calling tutorial functions
	if step.tutorial_function in tutorial_functions:
		current_popup.all_text_displayed.connect(
			tutorial_functions[step.tutorial_function]
		)


## Applies whatever this step rigs about the run: the player's next dice, the
## enemy's next set of intents, the next reward drop. Shared by play_step() and
## the skip loop so a skipped step leaves the same state behind as a played one.
func _apply_step_forcing(step: TutorialStep) -> void:
	if step.forced_dice.size() > 0:
		Dice.forced_rolls.append_array(step.forced_dice)

	if step.forced_enemy_actions.size() > 0:
		Enemy.forced_actions.append_array(step.forced_enemy_actions)

	if step.forced_rewards.size() > 0:
		Reward.forced_rewards.append_array(step.forced_rewards)


## The gameplay event that ends this step, or an empty Signal for the step
## kinds that close themselves (manually, or on a timer).
func _closing_signal_for(step: TutorialStep) -> Signal:
	match step.close_on_signal:
		TutorialStep.TutorialSignals.TILE_CLICKED_FOR_INFO:
			return Events.tile_clicked_for_info
		TutorialStep.TutorialSignals.TILE_ACTIVATED:
			return Events.tile_activation_complete
		TutorialStep.TutorialSignals.PLAYER_TURN_OVER:
			return Events.player_turn_over
		TutorialStep.TutorialSignals.ENEMY_DEFEATED:
			return Events.combat_finished
		TutorialStep.TutorialSignals.REWARD_CLAIMED:
			return Events.reward_picked
		TutorialStep.TutorialSignals.MAP_OPENED:
			return Events.map_shown
		TutorialStep.TutorialSignals.ON_JUMP:
			return Events.jump
		TutorialStep.TutorialSignals.ON_TARGET_SWITCH:
			return Events.targeting_computer_retargeted
	return Signal()


## Waits for the step's popup to close, but not forever. If the gameplay event
## a step is waiting on never fires — a bug anywhere else in the game can cause
## that — the tutorial would otherwise sit on screen with no way forward and no
## way back. Timing out and moving on is worse than working, and much better
## than a soft lock.
func _await_popup_closed(step: TutorialStep) -> void:
	var popup: TutorialTextPopup = current_popup
	var timeout: float = step.max_wait_time if step.max_wait_time > 0 else default_step_timeout

	# Rather than race two awaits, let the deadline close the popup itself —
	# then there is only one thing to wait on, and the normal path is unchanged.
	if timeout > 0:
		get_tree().create_timer(timeout).timeout.connect(func() -> void:
			if not is_instance_valid(popup) or popup != current_popup:
				return
			push_warning(
				"TutorialManager: step %d ('%s') never got its closing signal after %.0fs; advancing."
				% [current_step_index, step.tutorial_text.left(40), timeout]
			)
			popup.close()
		)

	await popup.popup_closed


func _reveal_health_bar() -> void:
	Events.health_bar_startup.emit()
	
	
func _spawn_enemy() -> void:
	Globals.enemy_manager.start_enemy_fly_in()
	Events.start_combat.emit()
	
	
func _reveal_systems() -> void:
	Events.systems_startup.emit()
	
	
func _spawn_dice() -> void:
	await Globals.player.spawn_dice()
	_lock_dice()
		

func _allow_dice_dragging() -> void:
	_unlock_dice()
		
		
func _reveal_targeting_computer() -> void:
	Events.targeting_computer_startup.emit()


func _run_enemy_turn() -> void:
	Globals.enemy_manager.run_enemy_turn()
	
	
func _allow_normal_combat() -> void:
	Globals.tutorial_controls_enemy_turns = false
	
	
func _reveal_map() -> void:
	Events.map_startup.emit()
	
	
func _enable_right_control() -> void:
	Globals.map.right_arrow_tile.can_accept_dice.enabled = true
	
	
func _enable_controls() -> void:
	Globals.map.enable_controls()
	Events.show_map.emit()


## Re-rolls every live enemy's intent table so a step's forced_enemy_actions
## take effect on the turn that is already telegraphed, rather than the turn
## after. Enemies otherwise only regenerate on player_turn_start.
func _reroll_enemy_intents() -> void:
	for enemy: Enemy in Globals.enemy_manager.get_alive_enemies():
		enemy.generate_turn_actions()


func _lock_dice() -> void:
	_dice_locked = true
	if not Globals.player.dice_manager.die_added.is_connected(_lock_newest_die):
		Globals.player.dice_manager.die_added.connect(_lock_newest_die)

	for die: Dice in Globals.player.dice_manager.queue:
		die.draggable.dragging_allowed = false


func _lock_newest_die() -> void:
	if not _dice_locked or Globals.player.dice_manager.queue.is_empty():
		return
	Globals.player.dice_manager.queue[-1].draggable.dragging_allowed = false


func _unlock_dice() -> void:
	_dice_locked = false
	if Globals.player.dice_manager.die_added.is_connected(_lock_newest_die):
		Globals.player.dice_manager.die_added.disconnect(_lock_newest_die)

	for die: Dice in Globals.player.dice_manager.queue:
		die.draggable.dragging_allowed = true


## Hands the run back. Everything the tutorial held down goes back to normal and
## the player carries on from wherever they are — no fade, no menu, no reset.
func _finish_tutorial() -> void:
	_unlock_dice()
	Globals.tutorial_controls_enemy_turns = false
	Globals.map.enable_controls()
	Globals.tutorial_active = false

	# No more popups, so the formation gets the right-hand side of the screen
	# back and any surviving ships spread into it.
	if Globals.enemy_manager:
		Globals.enemy_manager.clear_formation_space(_FORMATION_KEY)
