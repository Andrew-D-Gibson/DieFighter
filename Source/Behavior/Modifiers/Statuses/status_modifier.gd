class_name StatusModifier
extends Modifier
## A Modifier that sits on one ship, counts stacks, and removes itself.
##
## Statuses are ordinary modifiers, so they hook events through the same
## before/after pipeline as everything else. This class adds the four things a
## status needs on top: stacks, a turn tick, cleanup when its ship leaves, and a
## badge on that ship's StatusBar.
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
## A palette colour name ("red", "orange", ...) for the badge and info panel.
var title_color: String = "orange"
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


## Called once per round by ScenarioEngine.tick_statuses(), which the enemy
## manager runs as the player's turn ends and before any ship acts.
func on_status_tick() -> void:
	pass


## The ship this status is on, if it is still around.
func host() -> Node2D:
	return affected_node if is_instance_valid(affected_node) else null


func on_registered(engine: ScenarioEngine) -> void:
	_host_engine = engine
	super(engine)
	if not Events.enemy_left.is_connected(_on_ship_left):
		Events.enemy_left.connect(_on_ship_left)


func on_unregistered(engine: ScenarioEngine) -> void:
	super(engine)
	if Events.enemy_left.is_connected(_on_ship_left):
		Events.enemy_left.disconnect(_on_ship_left)
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
