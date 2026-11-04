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
## Everything a status shows (name, rule, colour, icons) lives in its
## StatusResource, which also names this script; the script holds only the
## behaviour, and the numbers the rule quotes (rule_values()).
##
## SUBCLASSING:
##   1. Extend StatusModifier and set priority in _init().
##   2. Hook events in on_before_event/on_after_event, or override
##      on_status_tick() for something that happens once per round.
##   3. Spend stacks with consume(); the status removes itself at zero. Keep
##      every number the rule mentions in a constant and return it from a
##      static rule_values(), so the rule reads it as a {placeholder}.
##   4. Add a StatusResource for it to the keywords folder (see
##      StatusResource); its file name is the status's id. StatusCatalog
##      finds it there.

const _BADGE_SCENE: PackedScene = preload("res://Source/Behavior/Modifiers/Statuses/StatusBadge/status_badge.tscn")

## In play_player_alert(), how long the status's name holds the screen after
## its badge has flashed, before what the status does lands.
const _ALERT_READ_SECONDS: float = 0.35

## The file that describes this status. Set by StatusCatalog.create() (via
## StatusResource.create_modifier()); a status built bare, as some tests do,
## has none and shows nothing.
var definition: StatusResource:
	set(value):
		definition = value
		status_id = StringName(value.id()) if value else &""
## Stable key used in authored effects (EffectData.string_param) and lookups:
## its StatusResource's file name.
var status_id: StringName
## The status's palette colour, for its badge, info panel and callouts.
var color: Color:
	get:
		return definition.palette_color() if definition else Globals.orange
## 11x11, for the badge.
var icon: Texture2D:
	get:
		return definition.icon if definition else null
## 24x24, for the info panel.
var info_icon: Texture2D:
	get:
		return definition.info_icon if definition else null
var stacks: int = 1

var _host_engine: ScenarioEngine
var _badge: StatusBadge


## The status's name, in the current language: its keyword's title.
func display_name() -> String:
	return definition.display_title() if definition else ""


## The numbers the status's rules quote, by {placeholder} name, read from the
## constants that apply them so the text can't drift from the code. A
## subclass whose rule names a number redeclares this.
static func rule_values() -> Dictionary:
	return {}


## Whether the status hurts the ship it sits on. Every status does except
## Phased, so moving statuses (TransferStatusesEvent) shifts only these, never
## a ship's own cloak.
func is_harmful() -> bool:
	return true


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
	Juice.callout(ship, "+%d %s" % [stacks_added, display_name().to_upper()], tint)


## Statuses have no source tile to light up, so the ship they sit on reacts
## instead. The badge pulses on its own as consume() spends the stack.
func announce_triggered() -> void:
	announce_triggered_at(host())


## announce_triggered() with the flourish drawn on [param anchor] rather than
## the host: a player status that acts on a tile (Jammed, Scrambled) shows up
## on that tile, where the player is looking, not on the health bar.
func announce_triggered_at(anchor: Node2D) -> void:
	super.announce_triggered()
	# The player's badges sit apart from the health bar and the tiles they
	# act on; the flash ties what just happened back to the badge.
	if is_on_player() and is_instance_valid(_badge):
		_badge.play_alert()
	if not is_instance_valid(anchor):
		return
	var tint: Color = get_trigger_color()
	if anchor is Enemy:
		(anchor as Enemy).graphics_manager.flash(tint, 0.3)
	Juice.sparkle(anchor, Juice.anchor_of(anchor), tint, 8, 35.0)
	Juice.callout(anchor, get_trigger_text(), tint)


## The beat before a status acts on the player: its badge flashes, its name
## pops up (off [param anchor], a tile it acts on, or off the badge), and only
## then does what it does land, so the player sees which of their statuses is
## the cause. A hook awaits this, which holds the event it hooks. Without a
## live engine to pace (a unit test's bare one) it just announces.
func play_player_alert(anchor: Node2D = null) -> void:
	if not _paces_alerts():
		announce_triggered_at(anchor if anchor else host())
		return
	var tree: SceneTree = _host_engine.get_tree()
	_badge.play_alert()
	await tree.create_timer(StatusBadge.alert_seconds(), false).timeout

	super.announce_triggered()
	var tint: Color = get_trigger_color()
	var text: String = display_name().to_upper()
	if is_instance_valid(anchor):
		Juice.sparkle(anchor, Juice.anchor_of(anchor), tint, 8, 35.0)
		Juice.callout(anchor, text, tint)
	elif is_instance_valid(_badge):
		var bar: Node = _badge.get_parent()
		Juice.sparkle(bar, _badge.global_position, tint, 8, 35.0)
		Juice.callout_at(bar, _badge.global_position, text, tint)
	await tree.create_timer(_ALERT_READ_SECONDS / Globals.animation_speed, false).timeout


func get_trigger_text() -> String:
	return display_name().to_upper()


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


## The Keywords term id whose rule explains this status where it sits. A
## status that works differently on the player has its own "_you" term.
func rule_term() -> String:
	var player_term: String = String(status_id) + Keywords.PLAYER_SUFFIX
	if is_on_player() and not Keywords.definition(player_term).is_empty():
		return player_term
	return String(status_id)


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


## Whether play_player_alert() can hold the game for its beat: a status on
## the player, with its badge up, in a scenario that is being played.
func _paces_alerts() -> bool:
	return is_on_player() and is_instance_valid(_badge) and _badge.is_inside_tree() \
		and is_instance_valid(_host_engine) and _host_engine.is_inside_tree()


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
