class_name EchoModifier
extends Modifier
## An armed echo: the next tile the player activates this turn plays its whole
## chain twice.
##
## Works on the activation rather than on any one effect, so it repeats
## whatever a tile does, including tiles built after it. The doubled count is
## the same activation_repetitions an "activates twice" rule raises, so the
## chain's own last-repetition rule keeps the die hand-off to one: damage
## lands twice, the die is given (or Fed, or kept) once.
##
## Echoes queue rather than stack. Each one is spent by a single activation
## and marks it, so a second echo in play waits for the tile after. Nothing is
## spent on an activation that wouldn't happen (a refused die, a lock) or
## couldn't repeat (a tile that ignores echo, a rule holding repetitions to
## one): the echo waits for one that can use it.
##
## Lasts until spent, or until the player's turn or the fight ends. Not an
## is_temporary modifier: that sweep runs on player_turn_start, the same beat
## a turn-start tile arms its echo on, and the two must not race.


## The engine this echo is registered with, so it can take itself out.
var _engine: ScenarioEngine = null


func _init(armed_by: Node2D = null) -> void:
	modifier_name = "Echo"
	source = armed_by
	# The visual shows on the tile that armed it: the player can see an echo
	# is waiting, and where it came from.
	affected_node = armed_by
	priority = 50   # a multiplier; the clamps at 75 still overrule it


func on_registered(engine: ScenarioEngine) -> void:
	super(engine)
	_engine = engine
	Events.player_turn_over.connect(_lapse)
	Events.combat_finished.connect(_lapse)


func on_unregistered(engine: ScenarioEngine) -> void:
	if Events.player_turn_over.is_connected(_lapse):
		Events.player_turn_over.disconnect(_lapse)
	if Events.combat_finished.is_connected(_lapse):
		Events.combat_finished.disconnect(_lapse)
	_engine = null
	super(engine)


func on_before_event(event: EffectEvent, engine: ScenarioEngine) -> void:
	if event is not TileActivationEvent:
		return
	var activation: TileActivationEvent = event as TileActivationEvent
	if activation.echoed or not can_echo(activation, engine):
		return

	activation.activation_repetitions *= 2
	activation.echoed = true
	_show_echo_on(activation.tile)
	announce_triggered()
	engine.remove_modifier(self)


## Whether this activation will happen and can repeat, so the echo is worth
## spending on it.
static func can_echo(activation: TileActivationEvent, engine: ScenarioEngine) -> bool:
	var tile: Tile = activation.tile
	if not is_instance_valid(tile) or tile.on_offer or tile.tile_resource == null:
		return false
	if not tile.tile_resource.can_be_echoed:
		return false
	# Spending it on a die the tile turns away would waste it for nothing.
	if not tile.activation_refusal(activation.activator_die).is_empty():
		return false
	# A twin-dice tile's first die is only held: the echo waits for the payout.
	if tile.is_hold(activation.activator_die):
		return false
	return not repetitions_held(tile, engine)


## Whether a rule in play holds [param tile] to a single pass a turn, which
## would clamp the echo straight back off.
static func repetitions_held(tile: Tile, engine: ScenarioEngine) -> bool:
	if engine == null:
		return false
	for mod: Modifier in engine.modifiers:
		if mod is NoRepetitionModifier:
			return true
		if mod is OncePerTurnModifier and mod.get_tile_use_cap(tile) >= 0:
			return true
	return false


## How many echoes are waiting in [param engine].
static func armed_count(engine: ScenarioEngine) -> int:
	if engine == null:
		return 0
	var count: int = 0
	for mod: Modifier in engine.modifiers:
		if mod is EchoModifier:
			count += 1
	return count


func get_trigger_text() -> String:
	return "x2"


## One line however many echoes the tile has armed: the first writes it.
func get_info_text() -> String:
	var engine: ScenarioEngine = ScenarioEngine.current()
	if engine == null:
		return ""
	var count: int = 0
	var first: EchoModifier = null
	for mod: Modifier in engine.modifiers:
		if mod is EchoModifier and mod.affected_node == affected_node:
			count += 1
			if first == null:
				first = mod
	if first != self:
		return ""
	if count == 1:
		return "[color=yellow]Echo armed[/color]: the next tile you activate this turn activates twice."
	return "[color=yellow]Echo armed x%d[/color]: the next %d tiles you activate this turn each activate twice." % [count, count]


## A tile that ignores echo says so while one is waiting, so the player knows
## why it didn't take it.
func get_rule_info_text(tile: Tile) -> String:
	if tile.tile_resource == null or tile.tile_resource.can_be_echoed:
		return ""
	var engine: ScenarioEngine = ScenarioEngine.current()
	if engine == null:
		return ""
	for mod: Modifier in engine.modifiers:
		if mod is EchoModifier:
			if mod != self:
				return ""
			break
	return "[color=yellow]Echo[/color] skips this tile and waits for the next."


func _spawn_visual() -> void:
	if not is_instance_valid(affected_node):
		return
	_visual = EchoVisual.new()
	affected_node.add_child(_visual)


## The repeated tile rings yellow as it takes the echo, so the second pass
## reads as the echo's doing rather than a glitch.
func _show_echo_on(tile: Tile) -> void:
	if not is_instance_valid(tile) or not tile.is_inside_tree():
		return
	Juice.ring(tile, tile.global_position, Globals.yellow, 18.0, 0.4, 8.0)
	Juice.callout(tile, "ECHO", Globals.yellow)


func _lapse() -> void:
	if is_instance_valid(_engine) and self in _engine.modifiers:
		_engine.remove_modifier(self)
