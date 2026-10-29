class_name ScenarioEngine
extends Node

signal event_resolved(event: EffectEvent)
## A modifier canceled this event before it resolved.
signal event_canceled(event: EffectEvent)
signal began_processing_queue()
signal finished_processing_queue()
signal modifier_added(mod: Modifier)
signal modifier_removed(mod: Modifier)

## Ceiling on how many events one drain of the queue may resolve.
##
## A runaway chain — two tiles activating each other, a repetition that feeds
## itself — would spin the loop below forever and hard-freeze the game with no
## error anywhere. Nothing legitimate comes close to this number: a full
## three-enemy turn resolves a few hundred events, and a single tile activation
## a couple of dozen.
const _MAX_EVENTS_PER_RUN: int = 2000

## Beat between one effect chain finishing and the next one starting, so a
## tile going off, a ship acting or a burn ticking each lands on its own
## instead of running into whatever was queued behind it. Game time, divided
## by the Animation Speed option like every other beat: hitstop freezes it
## (so it never overlaps a Hit Pause, it just follows one) and the
## AutoPilot's fixed-fps clock fast-forwards it. Only the chains in
## _settles_after() owe it.
const CHAIN_SETTLE_SECONDS: float = 0.2

## How much longer than a dying ship's dice hand-off (Dice.death_handoff_seconds())
## the next chain waits after a ship is destroyed, so the dice have landed
## with their new holders before anything else moves.
const _DEATH_BEAT_PADDING_SECONDS: float = 0.15

var _inject_index: int = 0

var currently_processing_queue: bool = false
var event_queue: Array[EffectEvent]

var modifiers: Array[Modifier]

## Set by shutdown(). A drain suspended in an await checks this on resuming
## and bails, rather than carrying on inside an engine that is being freed.
var _shut_down: bool = false

## Events that start an effect chain of their own: everything queued, as
## opposed to injected into the chain already resolving. The settle between
## chains goes in front of these. See _pause_before().
var _chain_starts: Dictionary[EffectEvent, bool] = {}

## The settle the chain resolving now owes the next one, in seconds. Cleared
## at the end of a drain: a new drain is a fresh input (the player dropping a
## die, a ship's turn coming round) with its own pacing.
var _settle_owed: float = 0.0

## Runs out when the next chain may start after a ship's death. Null when no
## death is holding anything back. See hold_next_chain().
var _beat_timer: SceneTreeTimer = null


## The engine for the scenario being played, or null between scenarios (after
## a jump has shut the old one down and before the next has loaded).
##
## The single way to reach the engine. Nodes used to hold their own pushed
## reference, which went stale on every jump and was never handed to a tile
## that arrived mid-scenario, so it silently did nothing.
static func current() -> ScenarioEngine:
	if not is_instance_valid(Globals.scenario_manager):
		return null
	var engine: ScenarioEngine = Globals.scenario_manager.engine
	if not is_instance_valid(engine) or engine.is_shut_down():
		return null
	return engine


func _ready() -> void:
	Events.player_turn_start.connect(clear_temporary_modifiers)
	Events.enemy_destroyed.connect(_on_enemy_destroyed)

	
## Event functions
func queue_event(event: EffectEvent) -> void:
	_chain_starts[event] = true
	event_queue.append(event)
	process_event_queue()
	
	
## Inserts an event to resolve right after the one currently resolving (and
## after anything else it has already injected). Outside a drain there is no
## "current" event, so this is just a queue.
func inject_event(event: EffectEvent) -> void:
	if not currently_processing_queue:
		queue_event(event)
		return
	event_queue.insert(_inject_index, event)
	_inject_index += 1


## Whether a tile activation is still waiting in the queue, or is part way
## through and hasn't announced its completion yet. A die placed on a tile
## behind another tile's activation has left the hand but not been played, so
## the turn isn't over until this goes false.
## Holds back whichever chain would start next for at least [param seconds]
## of game time from now, on top of the usual settle (the longer of the two
## wins, they don't add up). For a moment that needs the screen to itself,
## like a destroyed ship's dice crossing to their new holders.
func hold_next_chain(seconds: float) -> void:
	if seconds <= 0.0 or not is_inside_tree():
		return
	if _beat_timer and _beat_timer.time_left >= seconds:
		return
	# Pausable, so the beat waits out the pause menu along with everything
	# it's waiting for.
	_beat_timer = get_tree().create_timer(seconds, false)


func has_pending_tile_activation() -> bool:
	for event: EffectEvent in event_queue:
		if event is TileActivationEvent or event is TileActivationCompleteEvent:
			return true
	return false


## Modifier functions	
func add_modifier(mod: Modifier) -> void:
	modifiers.append(mod)
	sort_modifiers()
	mod.on_registered(self)   # modifier spawns its visual here
	modifier_added.emit(mod)  # for any other listeners (HUD, tutorial, etc.)
	
	
func remove_modifier(mod: Modifier) -> void:
	modifiers.erase(mod)
	mod.on_unregistered(self)   # modifier frees its visual here
	modifier_removed.emit(mod)
	
	
func sort_modifiers() -> void:
	modifiers.sort_custom(func(a: Modifier, b: Modifier) -> bool:
		return a.priority < b.priority
	)
	

func clear_temporary_modifiers() -> void:
	var to_remove: Array[Modifier] = []
	for mod: Modifier in modifiers:
		if mod.is_temporary:
			to_remove.append(mod)
	for mod: Modifier in to_remove:
		remove_modifier(mod)
	
	
## The status with this id on host, or null if it has none.
func find_status(host: Node, status_id: StringName) -> StatusModifier:
	for mod: Modifier in modifiers:
		if mod is StatusModifier and mod.affected_node == host \
				and (mod as StatusModifier).status_id == status_id:
			return mod
	return null


func statuses_on(host: Node) -> Array[StatusModifier]:
	var result: Array[StatusModifier] = []
	for mod: Modifier in modifiers:
		if mod is StatusModifier and mod.affected_node == host:
			result.append(mod)
	return result


## Gives one side's statuses their once-a-round tick: the enemies' as their
## turn starts, before any ship acts, and the player's (with [param player_side])
## as it ends, before the player's turn starts. Both are called from EnemyTurn.
func tick_statuses(player_side: bool = false) -> void:
	# A tick can spend a status's last stack and remove it from the list.
	for mod: Modifier in modifiers.duplicate():
		if mod is StatusModifier and mod in modifiers \
				and (mod as StatusModifier).is_on_player() == player_side:
			(mod as StatusModifier).on_status_tick()


func clear_modifiers() -> void:
	# Iterate a copy: remove_modifier() erases from the live array.
	for mod: Modifier in modifiers.duplicate():
		remove_modifier(mod)


## Tears the engine down before it is freed.
##
## Freeing an engine mid-drain (a jump resolved from inside the queue) would
## otherwise strand everything waiting on finished_processing_queue, and leave
## modifier status visuals parented to tiles that outlive the scenario.
func shutdown() -> void:
	event_queue.clear()
	_chain_starts.clear()
	_settle_owed = 0.0
	_beat_timer = null
	clear_modifiers()
	_inject_index = 0
	if currently_processing_queue:
		currently_processing_queue = false
		finished_processing_queue.emit()
	_shut_down = true


func is_shut_down() -> bool:
	return _shut_down
	
	
## Main Process Function
func process_event_queue() -> void:
	# Allow for multiple calls to happen without breaking
	if currently_processing_queue or _shut_down:
		return
		
	began_processing_queue.emit()
	currently_processing_queue = true

	var resolved_count: int = 0

	while not event_queue.is_empty():
		# The beat between chains. Taken before the next chain's event leaves
		# the queue, so a tile activation still counts as pending
		# (has_pending_tile_activation) while it waits its turn.
		var pause: float = _pause_before(event_queue[0])
		if pause > 0.0:
			await get_tree().create_timer(pause, false).timeout
			if _shut_down:
				return
			# Something may have been injected meanwhile; look again.
			continue

		resolved_count += 1
		if resolved_count > _MAX_EVENTS_PER_RUN:
			push_error(
				"ScenarioEngine: aborted after %d events in a single queue drain. " % _MAX_EVENTS_PER_RUN +
				"This is almost certainly a chain feeding itself — check for tiles " +
				"that activate each other, or a repetition that re-adds repetitions. " +
				"Dropping %d queued events to keep the game responsive." % event_queue.size()
			)
			event_queue.clear()
			break

		_inject_index = 0
		
		var event: EffectEvent = event_queue.pop_front()
		# A chain owes its settle only once this, its first event, has
		# resolved: a canceled chain did nothing, so it owes nothing.
		var starts_chain: bool = _chain_starts.erase(event)
		
		# Handle any changes that need to happen BEFORE we 
		# process the event. Hooks run against a snapshot, because a hook
		# can await, and anything resolving meanwhile may add or remove
		# modifiers.
		for mod: Modifier in modifiers.duplicate():
			if event.canceled or _shut_down:
				break
			if mod not in modifiers:
				continue
			await mod.on_before_event(event, self)

		if _shut_down:
			return

		# Check for cancelation
		if event.canceled:
			event_canceled.emit(event)
			continue
			
		# Handle the event itself
		await event.resolve(self)
		if _shut_down:
			return
		
		# Handle any changes that need to happen AFTER we 
		# process the event
		for mod: Modifier in modifiers.duplicate():
			if _shut_down:
				return
			if mod not in modifiers:
				continue
			await mod.on_after_event(event, self)
			
		# Tell everyone we're done!
		event_resolved.emit(event)

		if starts_chain and _settles_after(event):
			_settle_owed = CHAIN_SETTLE_SECONDS / Globals.animation_speed

	_inject_index = 0
	_settle_owed = 0.0
	currently_processing_queue = false
	finished_processing_queue.emit()


## How long to wait before resolving [param next], and clears what that wait
## pays off. Only an event that starts a new chain waits: injected ones belong
## to the chain still resolving.
func _pause_before(next: EffectEvent) -> float:
	# A drain outside the tree (a unit test's bare engine) has no clock to
	# wait on, and its callers expect it to run straight through.
	if not is_inside_tree() or not _chain_starts.has(next):
		return 0.0
	var pause: float = _beat_timer.time_left if _beat_timer else 0.0
	# A queued wait is a beat of its own (a ship's settle after each action),
	# and stands in for this one rather than following it.
	if next is not WaitEvent:
		pause = maxf(pause, _settle_owed)
	_settle_owed = 0.0
	_beat_timer = null
	return pause


## The chains that read as one thing happening on screen, and so get a beat to
## themselves before the next starts: a tile going off, a ship acting or
## overloading, a hazard, a ship's arrival effects, a burn or redline tick.
## Plumbing (waits, sail catches, combat ending) runs straight on, as do
## events nothing here knows about, so a new event's pacing is opt-in.
static func _settles_after(event: EffectEvent) -> bool:
	return event is TileActivationEvent \
		or event is TileEventTriggeredEvent \
		or event is EnemyActionEvent \
		or event is OverloadEvent \
		or event is HazardEvent \
		or event is ScenarioStateEffectsEvent \
		or event is DamageEvent


## A destroyed ship's dice linger at the wreck and then cross to their new
## holders (Dice.hand_off_after_death()). Nothing else starts until they land,
## or the next action would play out while the player is still watching the
## dice to see who got them.
func _on_enemy_destroyed(_ship: Enemy) -> void:
	hold_next_chain(Dice.death_handoff_seconds() + _DEATH_BEAT_PADDING_SECONDS / Globals.animation_speed)
		
