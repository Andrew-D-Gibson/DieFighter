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

## Ends the current _await_open_signal(), whichever of its signal and its
## timeout comes first.
signal _open_wait_over

## Whether the tutorial narrates this run at all. Off means the cold open plays
## exactly as it would for a returning player. Even when on, it only runs while
## Globals.show_tutorial is set: a player's first game, or after they turn it
## back on in Options.
@export var auto_start: bool = true

## The run the tutorial plays in. The forced dice and intents fix the opening
## fight, but the map the player is shown, the credits they're paid and the
## fight they jump into come from the run's RNG. Seeding it means every new
## player sees the same thing and the steps can promise what's on screen. 21
## puts a shop beside the opening fight and an ordinary fight at every distance
## the hand they leave it with can jump (4, 5 or 6).
@export var run_seed: int = 21

## Debug aid: drop this many steps, applying their forced dice/actions/rewards
## so the run state stays consistent, and start from the one after.
@export var skip_to_step: int = 0

@export var tutorial_steps: Array[TutorialStep] = []

## Applied once before anything spawns, so the opening ambush is dealt a known
## hand and a known set of enemy intents. A step can't do this: the player's
## first dice and the ambusher's first turn are both generated during scene
## setup, before any step has had a chance to run.
@export var opening_setup: TutorialStep

## Screen-space x span the tutorial's popups sit in. While the opening fight
## is narrated, the enemy formation treats this as occupied and stands clear of
## it, which is why the opening ambusher hangs off to the right during the
## tutorial and sits dead centre on every run after. Nothing else about the
## encounter changes — see [EnemyFormation]. Given back at the jump, so the
## next fight's ships fly in to their usual places.
@export var popup_screen_span: Vector2 = Vector2(0, 180)

## Seconds a step may wait on the game before the tutorial gives up, logs, and
## moves on. A step whose signal never fires would otherwise hang the game
## forever with no way out. Deliberately generous — this is a bug backstop,
## not a patience limit — and steps can override it with max_wait_time.
## Steps waiting on the player get no default deadline: see _PLAYER_DRIVEN.
@export var default_step_timeout: float = 120.0

## Closing signals that wait on the player rather than the game. A player can
## take as long as they like over these, and giving up on one is worse than
## waiting: closing the End Turn prompt early runs the enemy turn without the
## player's End Turn, and the player's next turn then never starts. The game
## isn't stuck meanwhile; the player can always still do the thing asked.
const _PLAYER_DRIVEN: Array[TutorialStep.TutorialSignals] = [
	TutorialStep.TutorialSignals.CLOSED_MANUALLY,
	TutorialStep.TutorialSignals.TILE_CLICKED_FOR_INFO,
	TutorialStep.TutorialSignals.TILE_ACTIVATED,
	TutorialStep.TutorialSignals.PLAYER_TURN_OVER,
	TutorialStep.TutorialSignals.ENEMY_DEFEATED,
	TutorialStep.TutorialSignals.REWARD_CLAIMED,
	TutorialStep.TutorialSignals.MAP_OPENED,
	TutorialStep.TutorialSignals.ON_JUMP,
	TutorialStep.TutorialSignals.ON_TARGET_SWITCH,
	TutorialStep.TutorialSignals.ENEMY_RECEIVED_DIE,
]

## Identifies the space the tutorial holds against the enemy formation.
const _FORMATION_KEY: StringName = &"tutorial"

var tutorial_text_popup_scene: PackedScene = preload("uid://dauuk425cis74")

var current_step_index: int = -1
var current_popup: TutorialTextPopup

## Set when the player presses End Turn, cleared when their next turn starts.
## A step that asks them to end the turn may open after they already have.
var _turn_ended: bool = false

## Set once the ambush's salvage has been taken.
var _reward_claimed: bool = false

## Bumped by every _await_open_signal(), so a stale timeout from an earlier
## wait can't end a later one.
var _open_wait_id: int = 0

var tutorial_functions: Dictionary[TutorialStep.TutorialFunctions, Callable] = {
	TutorialStep.TutorialFunctions.REVEAL_HEALTH_BAR: _reveal_health_bar,
	TutorialStep.TutorialFunctions.TRIGGER_ENEMY_SPAWN: _spawn_enemy,
	TutorialStep.TutorialFunctions.REVEAL_SYSTEMS: _reveal_systems,
	TutorialStep.TutorialFunctions.SPAWN_DICE: _spawn_dice,
	TutorialStep.TutorialFunctions.ALLOW_DICE_DRAGGING: _unlock_dice,
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
	_assert_every_function_is_wired()

	# These are statics and Globals is an autoload, so both outlive a return to
	# the main menu. Clear them here rather than trusting the last run to have
	# consumed everything it queued.
	Dice.forced_rolls.clear()
	Enemy.forced_actions.clear()
	Reward.forced_rewards.clear()
	Globals.tutorial_controls_enemy_turns = false

	# A player who picked Continue has seen all of this already.
	if not auto_start or not Globals.show_tutorial or tutorial_steps.is_empty() \
	or Globals.pending_load_save:
		return

	# GameStateManager rolls the run after this, in its own _ready().
	RNGManager.next_run_seed = run_seed
	Globals.tutorial_controls_enemy_turns = true
	Events.player_turn_over.connect(_on_player_turn_over)
	Events.player_turn_start.connect(_on_player_turn_start)
	Events.reward_picked.connect(_on_reward_picked)
	_claim_formation_space()
	# Only the opening fight is narrated over its ships. The steps after the
	# jump sit clear of a centred formation, so the next fight's ships fly
	# straight to their usual places instead of off to the side.
	Events.jump.connect(_release_formation_space, CONNECT_ONE_SHOT)

	if opening_setup:
		_apply_step_forcing(opening_setup)

	Globals.map.disable_controls()
	# Out of sight until the step that teaches jumping, so the map tour doesn't
	# show the player two arrows they aren't allowed to use yet.
	Globals.map.set_jump_arrows_visible(false, false)

	for _skipped: int in range(mini(skip_to_step, tutorial_steps.size())):
		var step: TutorialStep = tutorial_steps.pop_front()
		_apply_step_forcing(step)
		if step.tutorial_function in tutorial_functions:
			tutorial_functions[step.tutorial_function].call()

	start_tutorial()


func _on_player_turn_over() -> void:
	_turn_ended = true


func _on_player_turn_start() -> void:
	_turn_ended = false


func _on_reward_picked() -> void:
	_reward_claimed = true


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


func _release_formation_space() -> void:
	if Globals.enemy_manager:
		Globals.enemy_manager.clear_formation_space(_FORMATION_KEY)


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


func create_tutorial_popup(text: String, global_pos: Vector2, highlight_texture: Texture2D = null, close_button: bool = true, auto_close_time: float = 0) -> void:
	if current_popup and is_instance_valid(current_popup):
		current_popup.close()
		
	current_popup = tutorial_text_popup_scene.instantiate()
	add_child(current_popup)

	current_popup.setup(text, global_pos, highlight_texture, close_button, auto_close_time)
	

func start_tutorial() -> void:
	for i: int in range(len(tutorial_steps)):
		current_step_index = i
		var step: TutorialStep = tutorial_steps[i]

		await get_tree().create_timer(step.time_delay).timeout

		await play_step(step)
		await _await_popup_closed(step)


func play_step(step: TutorialStep) -> void:
	match step.open_on_signal:
		TutorialStep.TutorialSignals.CLICKED_OUT_OF_INFO:
			await _await_open_signal(Events.info_graphic_closed, step)

		TutorialStep.TutorialSignals.ON_ENEMY_FLY_IN:
			await _await_open_signal(Events.enemy_flew_in, step)

		TutorialStep.TutorialSignals.REWARD_CLAIMED:
			await _await_open_signal(Events.reward_picked, step)

	_apply_step_forcing(step)

	# Create the text popup
	if step.close_on_signal == TutorialStep.TutorialSignals.CLOSED_MANUALLY:
		create_tutorial_popup(step.tutorial_text, step.text_position, step.highlight_texture, true)
	elif step.close_on_signal == TutorialStep.TutorialSignals.CLOSED_AFTER_TIME:
		create_tutorial_popup(step.tutorial_text, step.text_position, step.highlight_texture, false, step.time_to_auto_close)
	else:
		create_tutorial_popup(step.tutorial_text, step.text_position, step.highlight_texture, false)

		var closing_signal: Signal = _closing_signal_for(step)
		if _already_satisfied(step):
			# Still shown, briefly, so the step's function runs and the
			# player sees the line they've already acted on go by.
			current_popup.all_text_displayed.connect(current_popup.close)
		elif closing_signal:
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
		TutorialStep.TutorialSignals.ENEMY_RECEIVED_DIE:
			return Events.enemy_received_die
		TutorialStep.TutorialSignals.PLAYER_TURN_STARTED:
			return Events.player_turn_start
	return Signal()


## Whether the player already did what this step asks before it opened. The
## popups don't block play, so a player can end their turn, finish the fight
## or open the map while still reading the step before; the event the step
## waits on has then been and gone. Only the steps that wait on a state change
## are checked: anything else is an instruction the player still has to follow.
func _already_satisfied(step: TutorialStep) -> bool:
	match step.close_on_signal:
		TutorialStep.TutorialSignals.PLAYER_TURN_OVER:
			return _turn_ended
		TutorialStep.TutorialSignals.ENEMY_DEFEATED:
			return Globals.state_manager.state != GameStateManager.GameState.IN_COMBAT
		TutorialStep.TutorialSignals.REWARD_CLAIMED:
			return _reward_claimed
		TutorialStep.TutorialSignals.MAP_OPENED:
			return Globals.map.visible
	return false


## Waits for the gameplay event that opens a step, but, like the closing wait,
## not forever: a step whose event never comes would stop the tutorial short
## of FINISH_TUTORIAL and leave the map's controls locked.
func _await_open_signal(opening_signal: Signal, step: TutorialStep) -> void:
	_open_wait_id += 1
	var wait_id: int = _open_wait_id
	var timeout: float = step.max_wait_time if step.max_wait_time > 0 else default_step_timeout
	var finish: Callable = func(timed_out: bool) -> void:
		if wait_id != _open_wait_id:
			return
		_open_wait_id += 1
		if timed_out:
			push_warning(
				"TutorialManager: step %d ('%s') never got its opening signal after %.0fs; opening anyway."
				% [current_step_index, step.tutorial_text.left(40), timeout]
			)
		_open_wait_over.emit()

	opening_signal.connect(finish.bind(false), CONNECT_ONE_SHOT)
	get_tree().create_timer(timeout).timeout.connect(finish.bind(true))
	await _open_wait_over


## Waits for the step's popup to close. A step waiting on the game gets a
## deadline: if its event never fires — a bug anywhere else in the game can
## cause that — the tutorial would otherwise sit on screen with no way forward
## and no way back. Timing out and moving on is worse than working, and much
## better than a soft lock. Steps waiting on the player wait as long as it takes.
func _await_popup_closed(step: TutorialStep) -> void:
	var popup: TutorialTextPopup = current_popup
	var timeout: float = _closing_timeout(step)

	# Rather than race two awaits, let the deadline close the popup itself —
	# then there is only one thing to wait on, and the normal path is unchanged.
	var deadline: SceneTreeTimer = null
	var give_up: Callable = func() -> void:
		if popup != current_popup:
			return
		push_warning(
			"TutorialManager: step %d ('%s') never got its closing signal after %.0fs; advancing."
			% [current_step_index, step.tutorial_text.left(40), timeout]
		)
		popup.close()
	if timeout > 0:
		deadline = get_tree().create_timer(timeout)
		deadline.timeout.connect(give_up)

	await popup.popup_closed

	# The lambda holds the popup, which is freed now; calling it later logs an
	# error even though it would return straight away.
	if deadline and deadline.timeout.is_connected(give_up):
		deadline.timeout.disconnect(give_up)


## How long _await_popup_closed() waits before giving up; 0 for never.
func _closing_timeout(step: TutorialStep) -> float:
	if step.max_wait_time > 0:
		return step.max_wait_time
	if step.close_on_signal in _PLAYER_DRIVEN:
		return 0.0
	return default_step_timeout


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
		

func _reveal_targeting_computer() -> void:
	Events.targeting_computer_startup.emit()


func _run_enemy_turn() -> void:
	Globals.enemy_manager.run_enemy_turn()
	
	
func _allow_normal_combat() -> void:
	Globals.tutorial_controls_enemy_turns = false
	
	
func _reveal_map() -> void:
	Events.map_startup.emit()
	
	
## The jump step teaches the right arrow alone, so the left one stays hidden
## until the tutorial hands the run back.
func _enable_right_control() -> void:
	Globals.map.set_jump_arrows_visible(false, true)
	Globals.map.right_arrow_tile.can_accept_dice.enabled = true
	
	
func _enable_controls() -> void:
	Globals.map.set_jump_arrows_visible(true, true)
	Globals.map.enable_controls()
	Events.show_map.emit()


## Re-rolls every live enemy's intent table so a step's forced_enemy_actions
## take effect on the turn that is already telegraphed, rather than the turn
## after. Enemies otherwise only regenerate on player_turn_start.
func _reroll_enemy_intents() -> void:
	Globals.enemy_manager.generate_all_turn_actions()


## Locks the hand, and every die that lands in it until unlocked: dice spawn
## one at a time on a timer, so locking only what exists now would miss the rest.
func _lock_dice() -> void:
	if not Globals.player.dice_manager.die_added.is_connected(_lock_newest_die):
		Globals.player.dice_manager.die_added.connect(_lock_newest_die)

	for die: Dice in Globals.player.dice_manager.queue:
		die.draggable.dragging_allowed = false


func _lock_newest_die() -> void:
	if Globals.player.dice_manager.queue.is_empty():
		return
	Globals.player.dice_manager.queue[-1].draggable.dragging_allowed = false


func _unlock_dice() -> void:
	if Globals.player.dice_manager.die_added.is_connected(_lock_newest_die):
		Globals.player.dice_manager.die_added.disconnect(_lock_newest_die)

	for die: Dice in Globals.player.dice_manager.queue:
		die.draggable.dragging_allowed = true


## Hands the run back. Everything the tutorial held down goes back to normal and
## the player carries on from wherever they are — no fade, no menu, no reset.
func _finish_tutorial() -> void:
	_unlock_dice()
	Globals.tutorial_controls_enemy_turns = false
	Globals.map.set_jump_arrows_visible(true, true)
	Globals.map.enable_controls()

	# Anything a step queued and the fight didn't use up would otherwise rig
	# the next fight.
	Dice.forced_rolls.clear()
	Enemy.forced_actions.clear()
	Reward.forced_rewards.clear()

	# Seen once is enough; Options can turn it back on.
	Globals.show_tutorial = false
	Events.save_options_config.emit()

	# Normally given back at the jump already; this covers a skipped or
	# timed-out step, so surviving ships always get the whole screen back.
	_release_formation_space()
