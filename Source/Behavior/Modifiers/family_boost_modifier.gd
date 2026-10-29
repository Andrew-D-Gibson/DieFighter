class_name FamilyBoostModifier
extends Modifier
## Every tile of one colour family deals [member bonus] more damage per hit,
## for the rest of the fight (War Footing on red tiles).
##
## A tile's family is its art's folder (ColorSymbolBadge), the same colour the
## player reads off the grid, so a new red tile is boosted with nothing to
## register. Only damage grows, once per hit: a tile that hits three times
## gains the bonus three times, like an Amplifier would give it.
##
## One per source tile, so two War Footings build and cap separately. Lasts
## until the fight ends (or the scenario's engine shuts down on a jump).

var family: ColorSymbolBadge.Family
var bonus: int = 0


func _init(owner_tile: Node2D, boosted_family: ColorSymbolBadge.Family) -> void:
	modifier_name = "Family Boost"
	source = owner_tile
	affected_node = owner_tile
	family = boosted_family
	priority = 20   # flat additive, alongside the Amplifier


## The family a string_param names ("red", "Blue"), or NONE.
static func family_named(family_name: String) -> ColorSymbolBadge.Family:
	return ColorSymbolBadge.Family.get(family_name.strip_edges().to_upper(), ColorSymbolBadge.Family.NONE)


## The boost [param owner_tile] keeps for [param boosted_family], or null.
static func find(engine: ScenarioEngine, owner_tile: Node, boosted_family: ColorSymbolBadge.Family) -> FamilyBoostModifier:
	if engine == null:
		return null
	for mod: Modifier in engine.modifiers:
		if mod is FamilyBoostModifier and mod.source == owner_tile \
				and (mod as FamilyBoostModifier).family == boosted_family:
			return mod
	return null


## The total bonus every boost in play gives [param tile]'s damage.
static func total_for(engine: ScenarioEngine, tile: Tile) -> int:
	if engine == null or not is_instance_valid(tile):
		return 0
	var total: int = 0
	for mod: Modifier in engine.modifiers:
		if mod is FamilyBoostModifier and (mod as FamilyBoostModifier).boosts(tile):
			total += (mod as FamilyBoostModifier).bonus
	return total


var _engine: ScenarioEngine = null


func on_registered(engine: ScenarioEngine) -> void:
	super(engine)
	_engine = engine
	Events.combat_finished.connect(_lapse)


func on_unregistered(engine: ScenarioEngine) -> void:
	if Events.combat_finished.is_connected(_lapse):
		Events.combat_finished.disconnect(_lapse)
	_engine = null
	super(engine)


func _lapse() -> void:
	if _engine and self in _engine.modifiers:
		_engine.remove_modifier(self)


## Whether [param tile] is one of the family this boosts.
func boosts(tile: Node) -> bool:
	return tile is Tile and is_instance_valid(tile) and (tile as Tile).tile_resource != null \
		and ColorSymbolBadge.family_of_tile((tile as Tile).tile_resource) == family


func on_before_event(event: EffectEvent, _running_engine: ScenarioEngine) -> void:
	if bonus <= 0 or event is not DamageEvent or event.actor is not Player:
		return
	if not event.is_amplifiable() or event.amount <= 0 or not boosts(event.effect_source):
		return
	event.amount += bonus
	announce_triggered()


func get_trigger_text() -> String:
	return "%+d" % bonus


func get_info_text() -> String:
	return "[color=yellow]%s %+d[/color]: %s tiles deal %+d damage this fight." % [
		_source_name(), bonus, _family_word(), bonus]


func get_rule_info_text(tile: Tile) -> String:
	if bonus <= 0 or not boosts(tile):
		return ""
	return "[color=yellow]%s %+d[/color]: this tile deals %+d damage this fight." % [
		_source_name(), bonus, bonus]


func _source_name() -> String:
	var tile: Tile = source as Tile
	if tile == null or not is_instance_valid(tile) or tile.tile_resource == null:
		return modifier_name
	# The tile's name without its own colour tag, which would fight the line's.
	var regex: RegEx = RegEx.create_from_string(r"\[/?color[^\]]*\]")
	return regex.sub(tile.tile_resource.tile_name, "", true)


func _family_word() -> String:
	return String(ColorSymbolBadge.Family.find_key(family)).capitalize()
