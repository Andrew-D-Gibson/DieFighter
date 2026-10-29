class_name DelayedPayload
extends DelayedEffect
## A DelayedEffectData's steps planted on a ship, to play on a later turn
## (DELAY_EFFECTS: the Time Bomb). Shows on that ship's status bar as a badge
## counting the turns down, and plays through a DelayedPayloadEvent when they
## run out.
##
## The ship can leave first. The payload then moves to another hostile ship
## that's still fighting (a random one, from the TARGETING stream), and the
## badge with it. With none left it fizzles. It never moves to a ship that
## isn't hostile, so a merchant or a civilian caught in a fight is never
## handed one.
##
## Not a status: Purge Vents and the like move statuses about, and this
## mustn't change sides.

## The status badge's scene. It wears DelayBadge's script instead. Loaded
## when needed, not preloaded: DelayBadge names this class, and a preload here
## would load the scene halfway through loading its own script.
const _BADGE_SCENE_PATH: String = "res://Source/Behavior/Modifiers/Statuses/StatusBadge/status_badge.tscn"

## The steps, icon and text.
var payload: DelayedEffectData
## The running amount it was armed with.
var amount: int = 0

var _badge: DelayBadge


func _init(host: Node2D = null, armed_by: Node2D = null, data: DelayedEffectData = null,
		armed_amount: int = 0) -> void:
	modifier_name = "Delayed Payload"
	affected_node = host
	source = armed_by
	payload = data
	amount = armed_amount
	turns_left = maxi(1, data.amount) if data else 1


## The ship it's planted on, if it is still around.
func host() -> Node2D:
	return affected_node if is_instance_valid(affected_node) else null


func color() -> Color:
	return payload.color if payload else Globals.white


func title() -> String:
	if payload and not payload.badge_title.is_empty():
		return payload.badge_title
	return modifier_name


## What it'll do when it goes off, with the amount filled in.
func describe() -> String:
	var text: String = payload.badge_text if payload else ""
	return text.replace("{amount}", str(amount))


func on_registered(engine: ScenarioEngine) -> void:
	super(engine)
	Events.enemy_left.connect(_on_ship_left)


func on_unregistered(engine: ScenarioEngine) -> void:
	if Events.enemy_left.is_connected(_on_ship_left):
		Events.enemy_left.disconnect(_on_ship_left)
	super(engine)
	_badge = null


func get_info_text() -> String:
	return "[color=#%s]%s[/color] in %d: %s" % [color().to_html(false), title(),
			turns_left, describe()]


## It just took hold: the ship rings in its colour and calls out the count.
func play_armed_feedback() -> void:
	var ship: Node2D = host()
	if ship == null or not ship.is_inside_tree():
		return
	var at: Vector2 = Juice.anchor_of(ship)
	Juice.ring(ship, at, color(), 22.0, 0.4, -6.0)
	Juice.callout(ship, "ARMED %d" % turns_left, color())


func _on_turns_changed() -> void:
	if is_instance_valid(_badge):
		_badge.set_stacks(turns_left, true)


func _on_due(engine_now: ScenarioEngine) -> void:
	var ship: Node2D = host()
	if ship == null or engine_now == null or engine_now.is_shut_down():
		return
	var event := DelayedPayloadEvent.new()
	event.actor = Globals.player
	# The tile that armed it, if it's still on the grid, so the hit is that
	# tile's (an Amplifier beside it then, Weakened on the player then).
	event.effect_source = source if is_instance_valid(source) else Globals.player
	event.targets = [ship]
	event.amount = amount
	if payload:
		event.effects = payload.delayed_effects
	engine_now.queue_event(event)


## Its ship is leaving. It moves to another hostile ship, or fizzles.
func _on_ship_left(ship: Enemy, _faction: ScenarioManager.Faction) -> void:
	if ship != affected_node or not is_pending():
		return
	var next: Enemy = _next_host(ship)
	if next == null:
		_drop()
		return
	var engine: ScenarioEngine = _engine
	# Re-registered so the badge moves with it.
	engine.remove_modifier(self)
	affected_node = next
	engine.add_modifier(self)
	play_armed_feedback()


func _next_host(leaving: Enemy) -> Enemy:
	if not is_instance_valid(Globals.enemy_manager):
		return null
	var candidates: Array[Enemy] = []
	for enemy: Enemy in Globals.enemy_manager.get_alive_enemies():
		if enemy != leaving and is_instance_valid(enemy) and not enemy.is_queued_for_deletion() \
		and _is_hostile(enemy):
			candidates.append(enemy)
	if candidates.is_empty():
		return null
	return RNGManager.pick_random(RNGManager.Bucket.TARGETING, candidates) as Enemy


static func _is_hostile(enemy: Enemy) -> bool:
	return enemy.scenario_state != null \
		and enemy.scenario_state.attitude == Enemy.Attitude.AGGRESSIVE


func _spawn_visual() -> void:
	var ship: Node2D = host()
	if ship == null or not ship.has_method("get_status_bar"):
		return
	var bar: StatusBar = ship.get_status_bar()
	if bar == null:
		return
	var badge: Node = (load(_BADGE_SCENE_PATH) as PackedScene).instantiate()
	badge.set_script(DelayBadge)
	_badge = badge as DelayBadge
	_badge.setup_delay(self)
	bar.add_badge(_badge)
	# The base class frees _visual on unregister.
	_visual = _badge
