class_name StatusModifier
extends Modifier
## A Modifier that sits on one ship, counts stacks, and removes itself.
##
## Statuses are ordinary modifiers, so they hook events through the same
## before/after pipeline as everything else. This class adds the four things a
## status needs on top: stacks, a turn tick, cleanup when its ship leaves, and a
## badge on that ship's StatusBar.
##
## A status can sit on an enemy or on the player. It is the same idea on either
## side, but the player plays dice onto tiles where an enemy spends them on its
## table, so a status that hooks dice reads is_on_player() and hooks the
## player's side of it. Player statuses tick as the enemy turn ends (the start
## of the player's own turn) and clear when the fight does.
##
## Stacks are the only number a status has. Each status decides what a stack
## means — damage per tick, dice to flip, bonus on the next hit — so merging,
## spending and the badge all stay generic.
##
## SUBCLASSING:
##   1. Extend StatusModifier and set status_id, display_name, icon and
##      priority in _init().
##   2. Hook events in on_before_event/on_after_event, or override
##      on_status_tick() for something that happens once per round.
##   3. Spend stacks with consume(); the status removes itself at zero.
##   4. Add it to StatusCatalog and give it a keyword in Keywords.

const _BADGE_SCENE: PackedScene = preload("res://Source/Behavior/Modifiers/Statuses/StatusBadge/status_badge.tscn")

## Stable key used in authored effects (EffectData.string_param) and lookups.
var status_id: StringName
## The keyword term in Keywords that explains this status.
var display_name: String
## The status's palette colour, for its badge, info panel and callouts.
var color: Color = Globals.orange
## 11x11, for the badge.
var icon: Texture2D
## 24x24, for the info panel.
var info_icon: Texture2D
var stacks: int = 1

var _host_engine: ScenarioEngine
var _badge: StatusBadge


## Folds a second application of the same status into this one. The default
## adds the stacks together; override for statuses that should refresh instead.
func merge(incoming: StatusModifier) -> void:
	stacks += incoming.stacks
	_refresh_badge(true)


## Spends stacks, removing the status once none are left.
func consume(amount: int = 1) -> void:
	stacks -= amount
	if stacks <= 0:
		if _host_engine:
			_host_engine.remove_modifier(self)
		return
	_refresh_badge(true)


## A fresh dose just landed on the ship: it flashes the status colour and
## calls out how much it got, so the player sees a status take hold rather
## than spotting a new badge later.
func play_applied_feedback(stacks_added: int) -> void:
	var ship: Node2D = host()
	if ship == null:
		return
	var tint: Color = get_trigger_color()
	if ship is Enemy:
		(ship as Enemy).graphics_manager.flash(tint, 0.35)
	elif ship is Player:
		# The player's ship has no hull on screen to flash; the cockpit
		# glass takes the colour instead, as it does for any hit.
		Events.vignette_pulse.emit(tint)
	var at: Vector2 = Juice.anchor_of(ship)
	Juice.ring(ship, at, tint, 22.0, 0.4, 6.0)
	Juice.sparkle(ship, at, tint, 12, 40.0, true)
	Juice.callout(ship, "+%d %s" % [stacks_added, display_name.to_upper()], tint)


## Statuses have no source tile to light up, so the ship they sit on reacts
## instead. The badge pulses on its own as consume() spends the stack.
func announce_triggered() -> void:
	announce_triggered_at(host())


## announce_triggered() with the flourish drawn on [param anchor] rather than
## the host: a player status that acts on a tile (Jammed, Scrambled) shows up
## on that tile, where the player is looking, not on the health bar.
func announce_triggered_at(anchor: Node2D) -> void:
	super.announce_triggered()
	if not is_instance_valid(anchor):
		return
	var tint: Color = get_trigger_color()
	if anchor is Enemy:
		(anchor as Enemy).graphics_manager.flash(tint, 0.3)
	Juice.sparkle(anchor, Juice.anchor_of(anchor), tint, 8, 35.0)
	Juice.callout(anchor, get_trigger_text(), tint)


func get_trigger_text() -> String:
	return display_name.to_upper()


func get_trigger_color() -> Color:
	return color


## Called once per round by ScenarioEngine.tick_statuses(): for an enemy as
## its turn starts, before any ship acts; for the player as the enemy turn
## ends, before the player's turn starts.
func on_status_tick() -> void:
	pass


## The ship this status is on, if it is still around.
func host() -> Node2D:
	return affected_node if is_instance_valid(affected_node) else null


## Whether this status sits on the player's ship rather than an enemy.
func is_on_player() -> bool:
	return affected_node is Player


## The Keywords term whose rule explains this status where it sits. A status
## that works differently on the player has its own "(you)" term.
func rule_term() -> String:
	var player_term: String = display_name + Keywords.PLAYER_SUFFIX
	if is_on_player() and not Keywords.definition(player_term).is_empty():
		return player_term
	return display_name


func on_registered(engine: ScenarioEngine) -> void:
	_host_engine = engine
	super(engine)
	if not Events.enemy_left.is_connected(_on_ship_left):
		Events.enemy_left.connect(_on_ship_left)
	# A player's statuses are the fight's doing, and end with it; out of
	# combat there is no enemy turn left to tick them away.
	if is_on_player() and not Events.combat_finished.is_connected(_on_combat_finished):
		Events.combat_finished.connect(_on_combat_finished)


func on_unregistered(engine: ScenarioEngine) -> void:
	super(engine)
	if Events.enemy_left.is_connected(_on_ship_left):
		Events.enemy_left.disconnect(_on_ship_left)
	if Events.combat_finished.is_connected(_on_combat_finished):
		Events.combat_finished.disconnect(_on_combat_finished)
	_badge = null
	_host_engine = null


## Puts a badge on the host's StatusBar rather than parenting a visual to the
## host directly, so several statuses line up instead of stacking on one spot.
func _spawn_visual() -> void:
	var bar: StatusBar = _find_status_bar()
	if bar == null:
		return
	_badge = _BADGE_SCENE.instantiate()
	_badge.setup(self)
	bar.add_badge(_badge)
	# The base class frees _visual on unregister.
	_visual = _badge


func _refresh_badge(pulse: bool) -> void:
	if is_instance_valid(_badge):
		_badge.set_stacks(stacks, pulse)


func _find_status_bar() -> StatusBar:
	var ship: Node2D = host()
	if ship == null or not ship.has_method("get_status_bar"):
		return null
	return ship.get_status_bar()


## enemy_left fires at the start of a death (and on a flee), before the wreck
## is freed, so a status can't tick on a ship that is already gone.
func _on_ship_left(ship: Enemy, _faction: ScenarioManager.Faction) -> void:
	if ship == affected_node and _host_engine:
		_host_engine.remove_modifier(self)


func _on_combat_finished() -> void:
	if _host_engine:
		_host_engine.remove_modifier(self)
