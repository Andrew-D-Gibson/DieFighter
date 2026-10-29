class_name DelayedEffect
extends Modifier
## Something set up now to happen on a later turn of the same fight: a die
## held over (HeldDieDelay), a payload armed on a ship (DelayedPayload).
##
## The countdown is in the player's turns. Each player_turn_start takes one
## off, and the one that reaches zero is the turn it happens on, before the
## player acts. The turn it was set up on never counts: a fight's opening turn
## announces itself with first_turn_start instead, which this doesn't hear,
## so a delay set up while the ships fly in still waits a whole turn.
##
## It lives in the scenario engine like any modifier, so it goes wherever the
## fight goes:
##   - the fight ends (combat_finished): dropped, nothing happens;
##   - the player jumps away: the engine shuts down and drops it;
##   - a Continue: checkpoints are never taken mid-fight, so a save never
##     holds one. The fight replays from the top, and the delay with it if
##     the player sets it up again.
## And it never goes off out of a fight: a turn that starts with no fight on
## (an enemy turn run out of combat hands the turn back too) drops it.
##
## SUBCLASSING: set turns_left, override _on_due() for what happens, and
## optionally _on_turns_changed() (a countdown to show) and _on_dropped().

## Player turn starts still to come before this happens. 1 = next turn.
var turns_left: int = 1

## The engine this is registered with, so it can take itself out.
var _engine: ScenarioEngine = null


func on_registered(engine: ScenarioEngine) -> void:
	_engine = engine
	super(engine)
	Events.player_turn_start.connect(_on_player_turn_start)
	Events.combat_finished.connect(_drop)


func on_unregistered(engine: ScenarioEngine) -> void:
	if Events.player_turn_start.is_connected(_on_player_turn_start):
		Events.player_turn_start.disconnect(_on_player_turn_start)
	if Events.combat_finished.is_connected(_drop):
		Events.combat_finished.disconnect(_drop)
	_engine = null
	super(engine)


## Whether this is still waiting in an engine.
func is_pending() -> bool:
	return is_instance_valid(_engine) and self in _engine.modifiers


## Every delay waiting in [param engine].
static func all_in(engine: ScenarioEngine) -> Array[DelayedEffect]:
	var found: Array[DelayedEffect] = []
	if engine == null:
		return found
	for mod: Modifier in engine.modifiers:
		if mod is DelayedEffect:
			found.append(mod as DelayedEffect)
	return found


func _on_player_turn_start() -> void:
	if not is_pending():
		return
	if not _in_combat():
		_drop()
		return
	turns_left -= 1
	if turns_left > 0:
		_on_turns_changed()
		return
	var engine: ScenarioEngine = _engine
	engine.remove_modifier(self)
	_on_due(engine)


## Takes this out of play without it happening.
func _drop() -> void:
	if not is_pending():
		return
	_engine.remove_modifier(self)
	_on_dropped()


static func _in_combat() -> bool:
	return Globals.state_manager != null \
		and Globals.state_manager.state == GameStateManager.GameState.IN_COMBAT


## Its turn has come. Already out of the engine's modifiers.
func _on_due(_engine_now: ScenarioEngine) -> void:
	pass


## A turn went by and it's still waiting.
func _on_turns_changed() -> void:
	pass


## The fight ended, or a turn started out of one, before it came due.
func _on_dropped() -> void:
	pass
