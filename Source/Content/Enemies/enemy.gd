class_name Enemy
extends Node2D

const _SHIELDS_HIT_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/enemy_shields_hit.tres")
const _HEALTH_HIT_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/enemy_health_hit.tres")
const _DEATH_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/enemy_death_explosion.tres")
const _PRE_DEATH_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/enemy_pre_death.tres")

## How long the finishing blow holds the frame, in real time.
const _KILL_HOLD_MSEC: int = 340
## How long the kill's white flash takes to fade once time resumes.
const _KILL_FLASH_FADE_SECONDS: float = 0.3
## How close to the middle of the screen a ship has to be to pick its launch
## side at random, in pixels.
const _LAUNCH_CENTRE_DEADZONE: float = 6.0
## How much a launched wreck climbs for each unit it travels sideways.
const _LAUNCH_RISE: float = 0.2

## The possible attitudes an enemy can have
enum Attitude {FRIENDLY, NEUTRAL, AGGRESSIVE}

## The resource containing the enemy's base stats and behavior
@export var enemy_resource: EnemyResource

## The current state of the enemy in the scenario
@export var scenario_state: ScenarioShipState

## The resource containing the rewards for defeating this enemy
@export var reward_resource: RewardResource

@export_category('Components')
## Manages the enemy's dice queue
@export var dice_manager: EnemyDiceManager

## Manages showing the enemy's dialogue
@export var dialogue_manager: EnemyDialogueManager

## Manages all visual aspects of the enemy
@export var graphics_manager: EnemyGraphicsManager

## Tracks the enemy's health and shields
@export var health: Health

## The scene to instantiate when showing action popups
@export var action_popup: PackedScene

## The clickable region to target this enemy
@export var clickable_region: CollisionShape2D

## The actions the enemy will take this turn
var turn_actions: Array[EnemyActionResource]
var moving_in_world: bool = false

## True once something has deliberately placed this ship — a scenario that
## authored a fixed spot, or an effect that flew it somewhere. The formation
## then leaves it where it is and reflows the other ships around it.
var formation_pinned: bool = false

## The number of turns this enemy has lived
var turns_alive: int = 0

## Dice this ship held onto itself on its last turn (KEEP_DIE_WITH_ACTOR), as
## opposed to dice it was handed. Only these load a kept-face action (see
## EnemyActionOptionResource.fills_kept_faces). Cleared when it next acts.
var kept_dice: Array[Dice] = []

## The die this ship has taken out of its queue to spend, and the tween
## carrying it out in front of the hull. Set by EnemyActionEvent. Out of the
## queue, the die would be missed if the ship died with it in hand, so death
## hands it on along with the rest. Left stale afterwards on purpose:
## give_away_dice() ignores a die that has since gone to someone else. Check
## is_instance_valid() before using it: a spent hologram is freed.
var spending_die: Dice = null
var spending_tween: Tween = null

## How many ships of this enemy's own faction have died since it arrived.
## Drives PoolSelection.SQUAD_LOSSES.
var squad_losses: int = 0

## How many full combat rounds have elapsed since this enemy arrived, counted
## whether or not it was given any dice. Drives PoolSelection.COMBAT_ROUNDS.
##
## Incremented on enemy_turn_over rather than player_turn_start so it's already
## settled by the time generate_turn_actions() reads it — the latter also runs
## off player_turn_start, and depending on signal connection order for
## correctness is a trap.
var rounds_in_combat: int = 0

## The held-dice total that trips this ship's breaker right now. Starts at
## EnemyResource.overload_threshold and climbs each time it overloads. 0 means
## the ship never overloads.
var overload_threshold: int = 0

const _OVERLOAD_GAUGE: PackedScene = preload("res://Source/Content/Enemies/Components/OverloadGauge/overload_gauge.tscn")

## Optional: force specific actions (used by tutorial)
static var forced_actions: Array[EnemyActionResource] = []

## Set by EnemyManager from the scenario's EnemyStateRewardResource before this
## node enters the tree. See that resource for why it exists.
var starting_health_fraction: float = 1.0

## Whoever landed the latest hit: the player, another ship, or null for
## something with no shooter (a hazard). Set by DamageEvent.
var last_damaged_by: Node = null

## This ship's index in its scenario's starting_enemies, so a save can say
## which authored ship each record belongs to. -1 for a ship spawned any other
## way.
var spawn_index: int = -1

## Set when a save restores this ship. Whatever state it was in, that state's
## effects_on_enter already ran before the save (a medic's arrival heal, a
## toll's charge), and their results are in the save; running them again on
## load would pay out twice. Scene setup those effects did (opening the shop)
## is restored from the save directly instead.
var _skip_next_enter_effects: bool = false

## Whether the health bar is tucked above the hull because the formation is
## too crowded for it to hang off the side. See set_health_bar_compact().
var health_bar_compact: bool = false

var explosion_particles: PackedScene = preload("uid://566ykra4buin")


## Initializes the enemy and connects all necessary signals
func _ready() -> void:
	assert(enemy_resource)
	_update_resource()
	
	_connect_health_signals()
	_connect_scenario_signals()
	_connect_combat_signals()
	_connect_dice_manager_signals()


func _process(_delta: float) -> void:
	if moving_in_world:
		dice_manager.update_dice_locations()
		

## Connects all health-related signals
func _connect_health_signals() -> void:
	health.death.connect(_on_death)
	health.shields_damaged.connect(graphics_manager.on_shields_hit)
	health.shields_damaged.connect(func() -> void:
		Events.play_sound.emit(_SHIELDS_HIT_SFX)
	)
	
	health.health_damaged.connect(graphics_manager.on_health_hit)
	health.health_damaged.connect(func() -> void:
		# The killing blow gets the pre-death sound instead. Health emits
		# death before health_damaged, so is_dead is already set here.
		if not health.is_dead:
			Events.play_sound.emit(_HEALTH_HIT_SFX)
	)


## Connects all scenario-related signals
func _connect_scenario_signals() -> void:
	Events.scenario_event.connect(_handle_scenario_event)
	Events.start_scenario.connect(trigger_state_effects)


## Safe to call more than once: a ship that died is disconnected on death, and
## again when a jump clears the board.
func disconnect_scenario_signals() -> void:
	if Events.scenario_event.is_connected(_handle_scenario_event):
		Events.scenario_event.disconnect(_handle_scenario_event)
	if Events.start_scenario.is_connected(trigger_state_effects):
		Events.start_scenario.disconnect(trigger_state_effects)
	

func _handle_scenario_event(event: ScenarioManager.ScenarioEvent) -> void:
		var new_state: ScenarioShipState = scenario_state.handle_scenario_event(event)
		graphics_manager.set_health_bar_attitude(new_state.attitude)
		
		if new_state != scenario_state:
			scenario_state = new_state
			trigger_state_effects()
		

## Connects all combat-related signals
func _connect_combat_signals() -> void:
	# With the fight over, nobody is left to pass dice between: a ship that
	# survives it (a civilian, a shopkeeper) hands them home. Passing them to
	# another survivor would keep them aboard, and dice an enemy holds are lost
	# when the player jumps.
	Events.combat_finished.connect(func() -> void:
		await get_tree().process_frame
		dice_manager.return_dice_to_player()
	)

	# Turn tables are rolled by EnemyManager, every ship together, so a roll
	# can see the rest of the board.
	Events.enemy_turn_over.connect(func() -> void:
		rounds_in_combat += 1
	)
	Events.enemy_left.connect(_on_other_enemy_left)
	

## Counts losses among this enemy's own faction. Only actual deaths count — the
## same signal fires when a ship flees or when combat ends peacefully, and
## neither of those is something to get angry about.
func _on_other_enemy_left(ship: Enemy, faction: ScenarioManager.Faction) -> void:
	if ship == self or not is_instance_valid(ship):
		return
	if not scenario_state or faction != scenario_state.faction:
		return
	if ship.health.health > 0:
		return

	squad_losses += 1


## Connects the signals for the dice manager
func _connect_dice_manager_signals() -> void:
	dice_manager.die_added.connect(Events.enemy_received_die.emit)
	dice_manager.die_removed.connect(Events.enemy_lost_die.emit)
	

## Whether the shot that finished this ship came from another ship (a pirate
## raiding it), rather than the player.
func was_killed_by_ship() -> bool:
	return last_damaged_by is Enemy and last_damaged_by != self


## Called when the enemy dies
func _on_death() -> void:
	# Stop reacting to the scenario before announcing the death: enemy_left
	# drives PIRATES_DEFEATED / COMBAT_ENDED, and a corpse still subscribed
	# would change state and queue its on-enter effects mid death animation.
	disconnect_scenario_signals()
	# Finish the die's trip out in front of the hull at once, so the handover
	# tween stops pulling it back here while it flies to its new holder.
	# Stepped rather than killed: EnemyActionEvent is awaiting its finish.
	if spending_tween and spending_tween.is_running():
		spending_tween.custom_step(1000.0)
	# spending_die is left stale on purpose (see its comment), so it may be a
	# hologram that's been spent and freed since; a freed object can't even
	# be passed as a Dice.
	dice_manager.give_away_dice(spending_die if is_instance_valid(spending_die) else null)
	Events.enemy_left.emit(self, scenario_state.faction)
	
	Events.play_sound.emit(_PRE_DEATH_SFX)
	# Another ship's kill isn't the player's to celebrate, or to loot.
	var killed_by_ship: bool = was_killed_by_ship()
	var launch_direction: Vector2 = Vector2.ZERO
	graphics_manager.pixelate()
	if not killed_by_ship:
		launch_direction = await _play_kill_confirm()
	Events.play_sound.emit(_DEATH_SFX)
	
	# Create explosion particles. They stay where the blow landed while the
	# wreck flies off, on the pixel grid with it.
	var explosion: CPUParticles2D = explosion_particles.instantiate()
	explosion.color = Globals.red
	explosion.amount = health.max_health * 5
	JuicePixelated.spawn(self, explosion, 0)

	# Spawn rewards. A launched fighter carries none of its own.
	if not killed_by_ship and reward_resource:
		Events.spawn_reward.emit(
			global_position,
			reward_resource
		)
	
	if launch_direction != Vector2.ZERO:
		await graphics_manager.launch(launch_direction)
	await graphics_manager.play_death_animation()
	queue_free()


## The finishing blow, framed like a fighting game's: time stops, the camera
## pushes in, the world dims behind a white-hot silhouette and speed lines
## close in while the ship shudders. Then everything lets go at once, and the
## caller sends the wreck flying.
##
## The freeze is only worth holding because so much keeps moving through it;
## a freeze where nothing moves reads as the game hitching.
##
## Resolves once the freeze ends, with the direction to knock the wreck.
## Everything after it waits too: anything spawned into a stopped clock would
## hang on its first frame instead of bursting out when time resumes.
func _play_kill_confirm() -> Vector2:
	var hold_seconds: float = _KILL_HOLD_MSEC / 1000.0
	var direction: Vector2 = _launch_direction()

	graphics_manager.set_ship_raised(true)
	# Game-time fade, so it holds at full white through the freeze and only
	# fades as the ship flies.
	graphics_manager.flash(Color.WHITE, _KILL_FLASH_FADE_SECONDS)
	graphics_manager.play_kill_focus(hold_seconds)
	graphics_manager.play_kill_shudder(direction, hold_seconds)
	Events.camera_kill_cam.emit(global_position, hold_seconds)
	await TimeDirector.hitstop(_KILL_HOLD_MSEC)

	# The release. The rings go on the manager rather than the ship, which is
	# about to be freed.
	graphics_manager.set_ship_raised(false)
	Events.camera_shake_large.emit(false)
	Juice.screen_flash(self, Color.WHITE)
	Juice.screen_ripple(self, global_position, 1.5)
	Juice.ring(get_parent(), global_position, Globals.white, 56.0, 0.5, 8.0)
	Juice.ring(get_parent(), global_position, Globals.red, 36.0, 0.4, 4.0)
	return direction


## Away from the middle of the screen and a little up, so the wreck clears
## the dice below it and heads for the nearer edge. A ship dead centre picks
## a side at random.
func _launch_direction() -> Vector2:
	var side: float = 0.0
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera:
		var away: float = global_position.x - (camera.get_screen_center_position().x - camera.offset.x)
		if absf(away) > _LAUNCH_CENTRE_DEADZONE:
			side = signf(away)
	if side == 0.0:
		side = 1.0 if RNGManager.randf(RNGManager.Bucket.COSMETIC) < 0.5 else -1.0
	return Vector2(side, -_LAUNCH_RISE).normalized()


## Updates the enemy's components based on the enemy resource
func _update_resource() -> void:
	graphics_manager.update_ship_graphics(enemy_resource.ship_graphics_scene)
	dice_manager.position = enemy_resource.dice_queue_position
	dialogue_manager.anchor = enemy_resource.dialogue_offset
	_update_health_from_resource()
	_update_health_bar()
	_update_overload()
	# The first table is rolled by EnemyManager once the whole roster is in,
	# so a roll can see who else is on the board.


## A ship with a breaker shows how close it is to tripping.
func _update_overload() -> void:
	overload_threshold = enemy_resource.overload_threshold
	if overload_threshold <= 0:
		return
	var gauge: OverloadGauge = _OVERLOAD_GAUGE.instantiate()
	gauge.enemy = self
	gauge.position = enemy_resource.overload_gauge_position
	graphics_manager.add_child(gauge)


## The face total of every die this ship is holding.
func held_heat() -> int:
	var heat: int = 0
	for die: Dice in dice_manager.queue:
		if is_instance_valid(die):
			heat += die.value
	return heat


## Whether the dice it holds are enough to trip its breaker.
func is_overloaded() -> bool:
	return overload_threshold > 0 and held_heat() >= overload_threshold


## Sends every held die home and makes the next overload harder. Called by
## OverloadEvent.
func vent_overload() -> void:
	overload_threshold += enemy_resource.overload_threshold_growth
	dice_manager.return_dice_to_player()


## Updates the health component's values, scaled by how deep into the run the
## player is. This is the single choke point every spawned enemy passes through,
## so it's the one place run difficulty needs to be applied.
func _update_health_from_resource() -> void:
	var scale_factor: float = 1.0
	if Globals.state_manager:
		scale_factor = Globals.state_manager.get_difficulty_multiplier()

	health.max_health = ceili(enemy_resource.max_health * scale_factor)
	# Clamped to at least 1: a ship authored as badly damaged should still need
	# one more hit, never spawn already dead.
	health.health = clampi(
		ceili(health.max_health * starting_health_fraction), 1, health.max_health
	)
	health.starting_shields = ceili(enemy_resource.starting_shields * scale_factor)
	health.shields = health.starting_shields


## Updates the health bar's position and values
func _update_health_bar() -> void:
	graphics_manager.set_health_bar_attitude(scenario_state.attitude)
	graphics_manager.set_health_bar_position(_health_bar_position())
	graphics_manager.set_health_bar_health(health)


## How far this ship's drawing reaches to the left (x) and right (y) of its
## centre: its hull, and its health bar wherever that hangs. With
## [param compact], as it would be with the bar tucked above the hull. The
## formation spaces ships by this. See [method EnemyFormation.solve_footprints].
func formation_footprint(compact: bool = health_bar_compact) -> Vector2:
	var half_hull: float = enemy_resource.formation_width * 0.5
	var bar: Vector2 = enemy_resource.compact_health_bar_position if compact \
		else enemy_resource.health_bar_position
	return Vector2(
		maxf(half_hull, EnemyHealthBar.REACH_LEFT - bar.x),
		maxf(half_hull, bar.x + EnemyHealthBar.REACH_RIGHT)
	)


## Moves the health bar between its usual spot beside the hull and its compact
## one above it. EnemyManager calls this when the formation gets too crowded
## for health bars to hang off the side.
func set_health_bar_compact(compact: bool, duration: float = 0.0) -> void:
	if compact == health_bar_compact:
		return
	health_bar_compact = compact
	graphics_manager.set_health_bar_position(_health_bar_position(), duration)


func _health_bar_position() -> Vector2:
	return enemy_resource.compact_health_bar_position if health_bar_compact \
		else enemy_resource.health_bar_position


## Which of the enemy's action pools this turn's six slots are drawn from.
## The pool only changes which table the slots come from — the resolved slots
## are still shown in full before the player commits a die, so the telegraph
## stays honest either way.
func _current_pool_index() -> int:
	var pool_count: int = len(enemy_resource.action_options)
	if pool_count <= 1:
		return 0

	match enemy_resource.pool_selection:
		EnemyResource.PoolSelection.HEALTH_THRESHOLD:
			if health.max_health <= 0:
				return 0
			# Full health lands in the first pool, near-death in the last.
			var hurt: float = 1.0 - (float(health.health) / float(health.max_health))
			return clampi(int(hurt * pool_count), 0, pool_count - 1)

		EnemyResource.PoolSelection.SQUAD_LOSSES:
			return clampi(squad_losses, 0, pool_count - 1)

		EnemyResource.PoolSelection.COMBAT_ROUNDS:
			return clampi(rounds_in_combat, 0, pool_count - 1)

		_:
			return turns_alive % pool_count


## Which faces this turn's stronger actions lean toward: the current pool's
## own bias when it sets one, the enemy's otherwise.
func _current_face_bias() -> float:
	var pool_index: int = _current_pool_index()
	if pool_index < enemy_resource.action_options.size():
		var pool: EnemyTurnActionList = enemy_resource.action_options[pool_index]
		if pool and pool.override_face_bias:
			return pool.face_bias
	return enemy_resource.face_bias


## Rolls this turn's six intent slots. Call EnemyManager's
## generate_all_turn_actions() rather than this: it rolls every ship against
## the same roster and then binds the slots that act on another ship.
func generate_turn_actions(situation: EnemyActionSituation, take_forced: bool = true) -> void:
	# The tutorial's forced actions are a queue shared by every ship: each
	# roll takes the next six.
	var forced: Array[EnemyActionResource] = []
	if take_forced:
		forced = forced_actions.slice(0, EnemyActionSelector.SLOT_COUNT)
		forced_actions = forced_actions.slice(forced.size())

	turn_actions = EnemyActionSelector.roll(
		enemy_resource.action_options[_current_pool_index()],
		situation,
		forced,
		_current_face_bias()
	)
	

## Swaps one slot for a fresh roll that relays nothing. See
## EnemyTargetBinder: it's how a Feed that could only loop gets out of the way.
func reroll_slot_without_relays(slot: int, situation: EnemyActionSituation) -> void:
	EnemyActionSelector.reroll_slot_without_relays(
		enemy_resource.action_options[_current_pool_index()],
		situation,
		turn_actions,
		slot
	)


## What a die of [param face] does once this ship spends it: the worst of
## every step along any relay, to the ally that ends up using it. A Feed by
## itself hurts nobody; the slot it feeds into might.
func threat_of_face(face: int) -> EnemyActionResource.Threat:
	var threat: EnemyActionResource.Threat = EnemyActionResource.Threat.DEAD
	var ship: Enemy = self
	var visited: Array[Enemy] = []
	while true:
		if face < 1 or face > ship.turn_actions.size() or ship.turn_actions[face - 1] == null:
			return maxi(threat, EnemyActionResource.Threat.NEUTRAL) as EnemyActionResource.Threat
		var action: EnemyActionResource = ship.turn_actions[face - 1]
		threat = maxi(threat, action.get_threat()) as EnemyActionResource.Threat
		var next: Enemy = action.bound_target
		if action.get_relay() == EnemyActionResource.Relay.NONE \
		or not FeedAllyEvent.can_feed(next, []) or next in visited:
			return threat
		visited.append(ship)
		face = action.relay_face(face)
		ship = next
	return threat


## Whether every slot of this turn's table could stand while its intents
## read "?".
func is_turn_table_safe_while_hidden() -> bool:
	for action: EnemyActionResource in turn_actions:
		if action and not action.is_safe_while_hidden():
			return false
	return true


## Runs a full turn using all the dice in the queue,
## executing their actions sequentially 
func run_turn() -> void:
	# Last turn's loaded dice are being spent now; only what this turn keeps
	# loads the next table.
	kept_dice.clear()

	# Stuffed past its breaker: no actions this turn, just the overload.
	if is_overloaded():
		var overload: OverloadEvent = OverloadEvent.new()
		overload.enemy = self
		var overload_engine: ScenarioEngine = ScenarioEngine.current()
		if overload_engine:
			overload_engine.queue_event(overload)
		turns_alive += 1
		return

	var enemy_action_events: Array[EnemyActionEvent] = []
	
	for i in range(len(dice_manager.queue)):
		if not is_instance_valid(dice_manager.queue[i]):
			continue
		
		var die := dice_manager.queue[i]
		
		# Get the action for the chosen die
		var action := turn_actions[die.value - 1]

		var event := EnemyActionEvent.new()
		event.enemy = self
		event.activator_die = die
		event.die_value = die.value
		event.action = action
		
		enemy_action_events.append(event)
		
	var engine: ScenarioEngine = ScenarioEngine.current()
	if engine:
		for event: EnemyActionEvent in enemy_action_events:
			engine.queue_event(event)
	turns_alive += 1
	

## Triggers any effects associated with the current scenario state
func trigger_state_effects() -> void:
	dialogue_manager.show_dialogue(scenario_state.dialogue, scenario_state.faction)

	if _skip_next_enter_effects:
		_skip_next_enter_effects = false
		return

	var engine: ScenarioEngine = ScenarioEngine.current()
	if not scenario_state.effects_on_enter or not engine:
		return

	var event: ScenarioStateEffectsEvent = ScenarioStateEffectsEvent.new()
	event.enemy = self
	event.chain = scenario_state.effects_on_enter
	engine.queue_event(event)


## Where this ship's status badges go. StatusModifier looks for this method.
func get_status_bar() -> StatusBar:
	return get_node_or_null("%StatusBar") as StatusBar


## Re-targets the computer for this enemy
func _on_clicked() -> void:
	Globals.targeting_computer.target_enemy(self)
	


## This ship as save data. See EnemyManager.capture_enemies().
func capture_state() -> Dictionary:
	return {
		"spawn": spawn_index,
		"state": _state_key(scenario_state),
		"health": health.health,
		"shields": health.shields,
		"squad_losses": squad_losses,
		"turns_alive": turns_alive,
	}


## Inverse of capture_state(), applied right after the ship spawns in its
## starting state. starting_state is where the saved state is looked up from.
func restore_state(entry: Dictionary, starting_state: ScenarioShipState) -> void:
	var saved_state: ScenarioShipState = _find_state(starting_state, str(entry.get("state", "")))
	_skip_next_enter_effects = true
	if saved_state and saved_state != scenario_state:
		scenario_state = saved_state
		graphics_manager.set_health_bar_attitude(scenario_state.attitude)

	health.health = int(entry.get("health", health.health))
	health.shields = int(entry.get("shields", health.shields))
	squad_losses = int(entry.get("squad_losses", 0))
	turns_alive = int(entry.get("turns_alive", 0))


## A state's identity across a save: its file for a state saved as its own
## .tres, or its id inside the scenario file for one embedded there.
static func _state_key(state: ScenarioShipStateBase) -> String:
	if state == null:
		return ""
	if not state.resource_path.is_empty() and not state.resource_path.contains("::"):
		return state.resource_path
	return "#" + state.resource_scene_unique_id


## Walks the state graph reachable from start (through probability
## transitions too) for the state with the given key.
static func _find_state(start: ScenarioShipStateBase, key: String) -> ScenarioShipState:
	if key.is_empty():
		return null
	var seen: Dictionary = {}
	var stack: Array[ScenarioShipStateBase] = [start]
	while not stack.is_empty():
		var state: ScenarioShipStateBase = stack.pop_back()
		if state == null or seen.has(state):
			continue
		seen[state] = true
		if state is ScenarioShipStateProbabilityTransition:
			for next: ScenarioShipStateBase in state.weighted_probabilities.keys():
				stack.append(next)
			continue
		if _state_key(state) == key:
			return state
		for next: ScenarioShipStateBase in state.transitions.values():
			stack.append(next)
	push_warning("Enemy: saved ship state '%s' not found; keeping the starting state." % key)
	return null
