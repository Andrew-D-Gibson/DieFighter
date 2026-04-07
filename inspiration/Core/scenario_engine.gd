## ScenarioEngine
## ============================================================
## The central traffic controller for ALL gameplay effects.
## One instance is created when the player enters a scenario
## (combat, shop, event node, etc.) and freed when they leave.
##
## Responsibilities:
##   - Owns the event queue (FIFO).
##   - Owns the active modifier list (player upgrades, passives, statuses).
##   - Processes events asynchronously so animations can play between them.
##   - Routes each event through modifier before/after hooks.
##
## USAGE:
##   1. Your scenario scene creates a ScenarioEngine node as a child.
##   2. Player upgrades are registered as Modifier instances via add_modifier().
##   3. Tiles and enemies call effect_chain_v2.play(context, engine) to queue effects.
##   4. The activation caller then does: await engine.process_events()
##
## NOTE on re-entrancy:
##   If process_events() is already running when called again, the second call
##   is a no-op — but the *currently running* loop will keep draining the queue,
##   so any events enqueued mid-loop are still processed in order.
## ============================================================

class_name ScenarioEngine
extends Node

## Emitted once after every event resolves successfully (not emitted if canceled).
signal event_resolved(event: EffectEvent)

## Emitted when the queue has been fully drained.
signal all_events_processed


# ── State ─────────────────────────────────────────────────────────────────────

var event_queue: Array[EffectEvent] = []
var modifiers: Array[Modifier] = []

var _processing: bool = false


# ── Public API ─────────────────────────────────────────────────────────────────

## Add an event to the back of the queue.
## The event will be processed the next time process_events() drains the queue.
func enqueue_event(event: EffectEvent) -> void:
	event_queue.append(event)


## Register a modifier with this engine.
## Modifiers are kept sorted by priority (lower number = runs first).
func add_modifier(mod: Modifier) -> void:
	modifiers.append(mod)
	modifiers.sort_custom(func(a: Modifier, b: Modifier) -> bool:
		return a.priority < b.priority
	)


## Unregister a modifier. Call this when a status expires or a buff is removed.
func remove_modifier(mod: Modifier) -> void:
	modifiers.erase(mod)


## Returns true if there are unprocessed events in the queue.
func has_pending_events() -> bool:
	return not event_queue.is_empty()


## Process all queued events until the queue is empty.
## This is an async function — awaiting it will pause the caller until every
## event (including any follow-up events enqueued by modifiers) has resolved.
##
## Typical call site (in Tile.activate):
##   effect_chain_v2.play(context, self)  # enqueues events
##   await engine.process_events()        # resolves them all
func process_events() -> void:
	# Guard against re-entrant calls. Any new events added to the queue
	# while we're already processing will be picked up by the running loop.
	if _processing:
		return

	_processing = true

	while not event_queue.is_empty():
		var event: EffectEvent = event_queue.pop_front()

		# ── Before hooks ──────────────────────────────────────────────────────
		# Modifiers may adjust event.amount, change targets, or cancel the event.
		for mod: Modifier in modifiers:
			if event.canceled:
				break
			await mod.on_before_event(event, self)

		# ── Resolution ────────────────────────────────────────────────────────
		# If nothing canceled the event, let it resolve (apply damage, etc.).
		if not event.canceled:
			await event.resolve(self)
			event_resolved.emit(event)

			# ── After hooks ───────────────────────────────────────────────────
			# After-hooks only run if the event actually resolved.
			# They can enqueue new follow-up events (e.g., "gain 1 shield when
			# you deal damage") — those get appended to event_queue and will be
			# processed in the next iteration of this while loop.
			for mod: Modifier in modifiers:
				await mod.on_after_event(event, self)

	_processing = false
	all_events_processed.emit()


# ── Setup helpers ──────────────────────────────────────────────────────────────

## Convenience: register all modifiers from a list at once.
## Call this during scenario setup to load the player's upgrades.
##
## Example (in your scenario scene's _ready or a combat_manager):
##   for upgrade in Globals.player.upgrade_list:
##       engine.add_modifier(upgrade.create_modifier())
func register_modifiers(modifier_list: Array[Modifier]) -> void:
	for mod: Modifier in modifier_list:
		add_modifier(mod)


## Remove all modifiers. Useful for testing or resetting state.
func clear_modifiers() -> void:
	modifiers.clear()


## Clear the event queue without processing. Use sparingly (e.g. game-over).
func clear_events() -> void:
	event_queue.clear()
