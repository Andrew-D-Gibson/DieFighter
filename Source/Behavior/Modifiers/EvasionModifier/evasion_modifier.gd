class_name EvasionModifier
extends Modifier
## A charged drive makes the ship harder to hit: each enemy hit on the player
## has a chance to miss outright, 3% per point of engine charge, up to 50%.
##
## Every scenario's engine gets one (ScenarioManager), so it's a rule of the
## drive rather than something a tile grants, and it stays out of sight until
## it fires: no badge, just the chance on the engine tile's info panel.
##
## A miss works like Phased: the player is taken out of the hit's targets
## before anything else reads it, so the shields keep every point, a death
## save never sees a blow to save, and nothing listening for the player being
## hit or attacked hears it. Burn, hazards and the player's own costs have no
## ship behind them and always land, as they get through Phased.
##
## Charge past the jump gate (redline) adds nothing. Tiles can add a bonus on
## top (Jink Thrusters, add_bonus()) that lasts until the enemy turn ends, and
## the total is still held to the cap.
##
## Rolls come from their own RNG bucket, seeded per scenario, so a replay
## dodges the same hits and a miss never shifts the enemies' own rolls.
##
## Priority 2: a cancellation, behind Phased (1), which is a sure miss and
## shouldn't waste a roll, and ahead of the death save (5).

const PERCENT_PER_CHARGE: int = 3
const MAX_PERCENT: int = 50

## Percentage points added by tiles this round, cleared as the enemy turn
## ends and when the fight does.
var bonus: int = 0

var _engine: ScenarioEngine = null


func _init() -> void:
	modifier_name = "Evasion"
	priority = 2


## The evasion rule in play on [param engine], or null.
static func find(engine: ScenarioEngine) -> EvasionModifier:
	if engine == null:
		return null
	for mod: Modifier in engine.modifiers:
		if mod is EvasionModifier:
			return mod
	return null


## The chance, in percent, that the next enemy hit on the player misses.
func chance_percent() -> int:
	return clampi(_charge_percent() + bonus, 0, MAX_PERCENT)


## Adds [param percent] points of evasion until the enemy turn ends.
func add_bonus(percent: int) -> void:
	bonus = maxi(0, bonus + percent)


func _charge_percent() -> int:
	var player: Player = Globals.player
	if not is_instance_valid(player):
		return 0
	return mini(player.engine_charge, player.max_engine_charge) * PERCENT_PER_CHARGE


func on_registered(engine: ScenarioEngine) -> void:
	super(engine)
	_engine = engine
	Events.enemy_turn_over.connect(_clear_bonus)
	Events.combat_finished.connect(_clear_bonus)


func on_unregistered(engine: ScenarioEngine) -> void:
	for signal_to_drop: Signal in [Events.enemy_turn_over, Events.combat_finished]:
		if signal_to_drop.is_connected(_clear_bonus):
			signal_to_drop.disconnect(_clear_bonus)
	_engine = null
	super(engine)


func _clear_bonus() -> void:
	bonus = 0


func on_before_event(event: EffectEvent, _running_engine: ScenarioEngine) -> void:
	if event is not DamageEvent or event.amount <= 0 or event.actor is not Enemy:
		return
	var player: Player = Globals.player
	if not is_instance_valid(player) or player not in event.targets:
		return
	var chance: int = chance_percent()
	# No roll at 0%, so a cold drive leaves the stream where it was.
	if chance <= 0 or RNGManager.randi_range(RNGManager.Bucket.EVASION, 1, 100) > chance:
		return

	event.targets.erase(player)
	if event.targets.is_empty():
		event.canceled = true
	announce_triggered()
	Events.player_evaded.emit(event.actor as Enemy)


## The miss is called out on the health bar, where the hit was headed, and on
## the engine tile, which is what dodged it.
func announce_triggered() -> void:
	super()
	var player: Player = Globals.player
	if not is_instance_valid(player) or not player.is_inside_tree():
		return
	var text: String = get_trigger_text()
	var tint: Color = get_trigger_color()
	Juice.callout_at(player, Juice.anchor_of(player), text, tint, true)
	var engine_node: Node2D = engine_display(player)
	if engine_node:
		Juice.sparkle(engine_node, Juice.anchor_of(engine_node), tint, 10, 35.0)
		Juice.callout(engine_node, text, tint, true)
	Events.vignette_pulse.emit(tint)


func get_trigger_text() -> String:
	return tr("CALLOUT_EVADED")


func get_trigger_color() -> Color:
	return Globals.purple


## The engine charger's tile, or whatever stands in for the drive on this
## ship (the Outrigger's sail has no tile). Null outside the game scene.
static func engine_display(context: Node) -> Node2D:
	if not is_instance_valid(context) or not context.is_inside_tree():
		return null
	var charger: Node2D = context.get_tree().get_first_node_in_group(&"engine_charger") as Node2D
	if charger == null:
		return null
	var tile: Tile = charger.get_node_or_null(^"EngineChargerTile") as Tile
	return tile if tile and not tile.is_queued_for_deletion() else charger


func get_rule_info_text(tile: Tile) -> String:
	if tile == null or tile != engine_display(tile):
		return ""
	return tr("INFO_ENGINE_EVASION").format({"chance": chance_percent()})
