class_name HeuristicPolicy
extends AutoPilotPolicy
## Plays like a player who has learned the basics: every die is worth what the
## tile does with it, less what the ship it's handed to will do with it next.
## It aims the targeting computer at whichever ship makes that trade best,
## finishes ships off, banks shields against the hits it can see coming,
## takes salvage, shops, patches the hull at repair stations (it never sells),
## and charges up and jumps toward good stops on the
## map. It reads only what a player can see: intents a "?" hides cost the
## same whatever the face (AutoPilotThreat).
##
## Greedy, one move at a time, with no lookahead. The point isn't strong play
## but a fixed, believable standard, so that the gap between it and the
## random bot says which fights and tiles reward playing well.
##
## A Persona weighs the same tally differently, for a few play styles.

## How a style values what a move does, in points of hull.
class Persona:
	var name: String
	## Per point of damage on a ship in the fight.
	var damage: float = 1.0
	## Scales the bonus for finishing a ship off.
	var kill: float = 1.0
	## Per point of hull a die handed over will cost.
	var hull: float = 1.0
	## Per shield the coming enemy turn will eat; spare shields are worth less.
	var shields: float = 0.8
	var heal: float = 0.9
	## Per status stack on an enemy.
	var status: float = 1.0
	## Per die the player gets to play again.
	var dice_back: float = 2.5
	## Per trick that pays off on another tile, and per Feed the die rides.
	var tricks: float = 1.0
	## Hull share below which it jumps away from a fight, given the charge.
	var flee_below: float = 0.25
	## Appetite for elites on the map.
	var risk: float = 1.0

	func _init(style: String) -> void:
		name = style


## The styles, by policy name. "smart" is the all-rounder.
static func persona(style: String) -> Persona:
	var made := Persona.new(style)
	match style:
		"smart":
			pass
		"aggressive":
			made.damage = 1.4
			made.kill = 1.5
			made.hull = 0.7
			made.shields = 0.5
			made.heal = 0.6
			made.flee_below = 0.0
			made.risk = 1.6
		"turtle":
			made.damage = 0.8
			made.kill = 0.8
			made.hull = 1.5
			made.shields = 1.3
			made.heal = 1.3
			made.flee_below = 0.4
			made.risk = 0.4
		"synergy":
			made.status = 2.0
			made.dice_back = 3.5
			made.tricks = 2.5
		_:
			return null
	return made


## A ship finished off stops being a threat for good: a flat bonus on top of
## the dice it was holding.
const _KILL_BONUS: float = 4.0
## Per status stack, by id: how much of a point of hull each is worth.
const _STATUS_WORTH: Dictionary[StringName, float] = {
	&"burn": 1.5,
	&"exposed": 1.0,
	&"scrambled": 1.5,
	&"jammed": 2.5,
}
const _STATUS_WORTH_DEFAULT: float = 1.0
## Spare shields, beyond what the coming enemy turn needs, still soak a later
## one. A fraction of the full value.
const _SPARE_SHIELD_SHARE: float = 0.35
## What each die still in hand is expected to add to the enemy turn.
const _EXPECTED_HIT_PER_DIE: float = 1.5
## Out of a fight, hurting a ship starts one. Worth it against pirates (a
## bounty, salvage, a civilian spared) with the hull to spare; never against
## anyone else.
const _PEACETIME_DAMAGE: float = -2.0
const _PIRATE_HUNTING: float = 0.6
const _HUNTING_HULL: float = 0.6
## Charge in a fight is worth little until it's time to leave.
const _COMBAT_CHARGE: float = 0.15
## Charging a full drive mid-fight, with nothing else to show for the die.
const _WASTED_CHARGE: float = -15.0
## A tile that destroys itself costs the tile.
const _SELF_DESTRUCT: float = -3.0
## A placement that bounced back, or one on a tile showing a lockout.
const _BOUNCED: float = -50.0
## Roughly how many more turns of the fight opening a locked tile gets back.
const _UNLOCK_TURNS: float = 1.5
## Retargeting to break a tie isn't worth a move.
const _RETARGET_MARGIN: float = 0.25

## Map stops, by the icon the player sees.
const _STOP_ENEMY: float = 4.0
const _STOP_ELITE: float = 6.0
const _STOP_UNKNOWN: float = 3.0
const _STOP_SHOP: float = 2.0
const _STOP_EMPTY: float = 0.5
const _STOP_CORRUPT: float = -6.0
const _STOP_GATE: float = 2.0
## Credits per point a shop stop gains, up to a cap.
const _SHOP_CREDITS_PER_POINT: float = 30.0
const _SHOP_CAP: float = 5.0
## A repair station is worth this much per share of the hull missing (times
## the persona's heal), on top of an empty stop, given the credits for a repair.
const _STOP_REPAIR_PER_MISSING: float = 10.0
const _REPAIR_STOP_MIN_CREDITS: int = 10
## It buys repairs while the hull share is under this plus the persona's heal
## times the slope: smart 0.77, aggressive 0.68, turtle 0.89.
const _REPAIR_BELOW: float = 0.5
const _REPAIR_BELOW_PER_HEAL: float = 0.3
## Per tile forward: staying ahead of Fate. Small, since stops are the point.
const _PROGRESS: float = 0.3
## Per stop worth visiting that a jump flies past.
const _SKIPPED_STOP: float = -2.5
const _BACKTRACK: float = -3.0
const _THROUGH_GATE: float = 20.0
const _WORTH_VISITING: Array[String] = [
	"enemy_encounter.png", "elite_encounter.png", "unknown_encounter.png", "shop.png",
]
const _NOWHERE: float = -100.0
## On top of where a jump lands, when it's a flight from a losing fight.
const _FLIGHT: float = 20.0

## Salvage and shop stock.
const _DIE_WORTH: float = 5.0
const _CREDITS_PER_POINT: float = 8.0
const _RARITY_WORTH: float = 1.0
const _PASSIVE_TILE_WORTH: float = 3.0
## Credits per point a purchase must clear, and by how much.
const _PRICE_PER_POINT: float = 10.0
const _BUY_BAR: float = 1.0

## Takes salvage and shop stock at random instead of by worth, playing the
## rest as usual, so every tile gets taken often enough to measure, not only
## the ones this policy rates (a balance batch's "smart-randpick").
var random_picks: bool = false

var _persona: Persona
## Whether it may jump out of a fight (see set_may_flee()).
var _may_flee: bool = true
## Board states where it looked at the map and found no jump worth taking, so
## it doesn't flip tabs back and forth.
var _no_jump_from: Dictionary[String, bool] = {}
## Placements already made, by die, tile, face, uses and hand size. The same
## one again means the die bounced back (a refusal the legal move list can't
## see), so it isn't tried a third time.
var _placed: Dictionary[String, int] = {}
## Hull when it last fled each fight, by sector and map stop. Fleeing the same
## fight again with no more hull than that just comes back to it.
var _fled_at_hull: Dictionary[String, int] = {}
## Stands in for "an enemy" when valuing a tile on offer, with no fight on.
var _nominal_enemy: Enemy
## Shops a random picker has walked away from, by sector and map stop.
var _done_shopping: Dictionary[String, bool] = {}


func _init(style: Persona) -> void:
	_persona = style
	# A bounce is a refusal within one hand. Across hands the same die rolls the
	# same face often enough that a lasting tally would read every repeat as a
	# bounce and blacklist the best tile for the rest of the run.
	Events.player_turn_start.connect(_forget_placements)
	Events.first_turn_start.connect(_forget_placements)
	Events.start_scenario.connect(_forget_placements)


func _forget_placements() -> void:
	_placed.clear()


func set_may_flee(allowed: bool) -> void:
	_may_flee = allowed


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(_nominal_enemy):
		_nominal_enemy.free()


func choose(moves: Array[AutoPilotMove], rng: RandomNumberGenerator) -> AutoPilotMove:
	var by_kind: Dictionary[AutoPilotMove.Kind, Array] = {}
	for move: AutoPilotMove in moves:
		if not by_kind.has(move.kind):
			by_kind[move.kind] = []
		by_kind[move.kind].append(move)

	if by_kind.has(AutoPilotMove.Kind.CLAIM):
		var claim: AutoPilotMove = _random_claim(by_kind[AutoPilotMove.Kind.CLAIM], rng) \
			if random_picks else _best_item(by_kind[AutoPilotMove.Kind.CLAIM], false)
		if claim:
			return claim
	if by_kind.has(AutoPilotMove.Kind.BUY):
		var purchase: AutoPilotMove = _random_purchase(by_kind[AutoPilotMove.Kind.BUY], rng) \
			if random_picks else _best_item(by_kind[AutoPilotMove.Kind.BUY], true)
		if purchase:
			return purchase
	if by_kind.has(AutoPilotMove.Kind.REPAIR) and _wants_repair():
		return by_kind[AutoPilotMove.Kind.REPAIR][0]
	# On most ships End Turn only lights once the hand is spent. A ship that
	# may keep its hand (the Outrigger's sail) lights it early: ending then
	# banks the rest, so it's weighed against the best play below instead.
	var end_turn: AutoPilotMove = null
	if by_kind.has(AutoPilotMove.Kind.END_TURN):
		end_turn = by_kind[AutoPilotMove.Kind.END_TURN][0]
		if AutoPilotMove.dice_in_hand().is_empty():
			return end_turn

	if _gate_still_opening():
		# The ring comes up a moment after the boss goes down; jumping before
		# then could only go backwards.
		return null

	var on_map: bool = is_instance_valid(Globals.map) and Globals.map.visible
	var want_map: bool = _wants_to_jump() and not _no_jump_from.has(_board_key())
	if want_map and not on_map and by_kind.has(AutoPilotMove.Kind.VIEW_MAP):
		return by_kind[AutoPilotMove.Kind.VIEW_MAP][0]
	if not want_map and on_map and by_kind.has(AutoPilotMove.Kind.VIEW_SYSTEMS):
		return by_kind[AutoPilotMove.Kind.VIEW_SYSTEMS][0]

	var placements: Array = by_kind.get(AutoPilotMove.Kind.PLACE_DIE, [])
	if on_map:
		# It came here to leave. Out of a fight a jump is the only way on, so
		# the least bad one is taken.
		placements = placements.filter(_is_jump)
	var best: Dictionary = _best_placement(placements)
	if end_turn and not on_map and (best.is_empty() or best["score"] <= _bank_value(best["move"].die)):
		return end_turn
	# No jump at all: there's something to do on the systems tab first.
	if on_map and (best.is_empty() or best["score"] <= _NOWHERE / 2.0) \
	and by_kind.has(AutoPilotMove.Kind.VIEW_SYSTEMS):
		_no_jump_from[_board_key()] = true
		return by_kind[AutoPilotMove.Kind.VIEW_SYSTEMS][0]
	if best.is_empty():
		# Nothing worth doing: wait for the hand, or the salvage, to change.
		return null
	var aim: Enemy = best["target"]
	if aim != _targeted():
		for retarget: AutoPilotMove in by_kind.get(AutoPilotMove.Kind.TARGET, []):
			if retarget.enemy == aim:
				return retarget
	var chosen: AutoPilotMove = best["move"]
	var key: String = _placement_key(chosen.die, chosen.tile)
	_placed[key] = _placed.get(key, 0) + 1
	if _in_combat() and _is_jump(chosen):
		_fled_at_hull[_fight_key()] = Globals.player.health.health
	return chosen


# ── Placing dice ───────────────────────────────────────────────────────────────

static func _is_jump(move: AutoPilotMove) -> bool:
	return move.tile == Globals.map.left_arrow_tile or move.tile == Globals.map.right_arrow_tile


## The best die-on-tile and the ship to aim at while playing it:
## {move, target, score}, or empty with nothing to place.
func _best_placement(placements: Array) -> Dictionary:
	var best: Dictionary = {}
	var current: Enemy = _targeted()
	var aims: Array[Enemy] = []
	if _in_combat():
		aims.assign(Globals.enemy_manager.get_alive_enemies())
	if aims.is_empty():
		aims.append(current)
	for placement: AutoPilotMove in placements:
		var penalty: float = _BOUNCED * _placed.get(_placement_key(placement.die, placement.tile), 0)
		var locked: bool = _locked_out(placement.tile)
		var opens: bool = locked and LockoutModifier.unlocks(placement.die.value)
		if locked and not opens:
			penalty += _BOUNCED
		for aim: Enemy in aims:
			var score: float = penalty
			if locked:
				# The tile does nothing this time; a low die only opens it.
				if opens:
					score += _unlock_value(placement.tile, placement.die.value)
			else:
				score += score_placement(placement.die, placement.tile, aim)
			# Ties stay on the ship already targeted.
			if aim != current:
				score -= _RETARGET_MARGIN
			if best.is_empty() or score > best["score"]:
				best = {"move": placement, "target": aim, "score": score}
	return best


func _placement_key(die: Dice, tile: Tile) -> String:
	return "%d/%d/%d/%d/%d" % [die.get_instance_id(), tile.get_instance_id(), die.value,
		tile.uses_remaining, AutoPilotMove.dice_in_hand().size()]


## Opening [param tile] with a [param face]: what it's worth for the rest of
## the fight, less the die, which goes to a ship picked at random.
func _unlock_value(tile: Tile, face: int) -> float:
	var ships: Array[Enemy] = Globals.enemy_manager.get_alive_enemies()
	var handoff: float = 0.0
	for ship: Enemy in ships:
		handoff += AutoPilotThreat.of_face(ship, face)
	if not ships.is_empty():
		handoff /= ships.size()
	return _tile_worth(tile) * _UNLOCK_TURNS - handoff * _persona.hull


## A lockout cancels whatever the tile is given until a low die opens it, and shows
## on it.
static func _locked_out(tile: Tile) -> bool:
	var engine: ScenarioEngine = ScenarioEngine.current()
	if not engine:
		return false
	for modifier: Modifier in engine.modifiers:
		if modifier is LockoutModifier and modifier.affected_node == tile:
			return true
	return false


## What dropping [param die] on [param tile] is worth with [param aim]
## targeted, in points of hull.
func score_placement(die: Dice, tile: Tile, aim: Enemy) -> float:
	var forecast: AutoPilotForecast = AutoPilotForecast.of(tile, die, aim)
	var in_combat: bool = _in_combat()
	var player: Player = Globals.player
	var score: float = 0.0

	var finished: Array[Enemy] = []
	for hit: Node in forecast.damage:
		var amount: float = forecast.damage[hit]
		if hit == player:
			score -= amount * _persona.hull
		elif hit is Enemy:
			if not in_combat:
				score += amount * _peacetime_damage(hit as Enemy)
				continue
			var ship: Enemy = hit as Enemy
			var toughness: float = float(ship.health.health + ship.health.shields)
			score += minf(amount, toughness) * _persona.damage
			if amount >= toughness and toughness > 0.0:
				finished.append(ship)
				score += _persona.kill * (_KILL_BONUS + AutoPilotThreat.held(ship))

	if in_combat:
		score += _shield_value(forecast.shields)
	score += minf(forecast.heal, float(player.health.max_health - player.health.health)) * _persona.heal
	score += _charge_value(forecast.charge, in_combat)
	if _only_wastes_charge(forecast, in_combat):
		score += _WASTED_CHARGE
	if in_combat:
		for status: StringName in forecast.statuses:
			score += forecast.statuses[status] * _STATUS_WORTH.get(status, _STATUS_WORTH_DEFAULT) * _persona.status
		for ship: Enemy in forecast.rerolled:
			score += (AutoPilotThreat.held(ship) - AutoPilotThreat.held_if_rerolled(ship)) * _persona.hull
		for ship: Enemy in forecast.flipped:
			score += (AutoPilotThreat.held(ship) - AutoPilotThreat.held_if_flipped(ship)) * _persona.hull
		for ship: Enemy in forecast.reclaimed:
			score += AutoPilotThreat.worst_held(ship) * _persona.hull + _persona.dice_back
	score += forecast.dice_back * _persona.dice_back
	score += (forecast.tile_tricks + forecast.deepest_feed * 0.5) * _persona.tricks
	if forecast.destroys_itself:
		score += _SELF_DESTRUCT
	if forecast.jump != 0:
		score += _jump_value(forecast.jump)

	for handoff: AutoPilotForecast.Handoff in forecast.handoffs:
		score -= _handoff_cost(handoff, finished) * handoff.share * _persona.hull
	return score


func _peacetime_damage(ship: Enemy) -> float:
	var pirate: bool = ship.scenario_state != null \
		and ship.scenario_state.faction == ScenarioManager.Faction.PIRATE
	var health: Health = Globals.player.health
	if pirate and float(health.health) >= float(health.max_health) * _HUNTING_HULL:
		return _PIRATE_HUNTING * _persona.risk
	return _PEACETIME_DAMAGE


## Expected hull the die costs where it lands. A ship this move finishes off
## can't take it: it goes to another at random, or home if none are left.
func _handoff_cost(handoff: AutoPilotForecast.Handoff, finished: Array[Enemy]) -> float:
	if handoff.hologram:
		return 0.0
	if is_instance_valid(handoff.ship) and not handoff.ship in finished:
		return AutoPilotThreat.of_face(handoff.ship, handoff.face)
	var others: Array[Enemy] = []
	if is_instance_valid(Globals.enemy_manager):
		for ship: Enemy in Globals.enemy_manager.get_alive_enemies():
			if not ship in finished:
				others.append(ship)
	if others.is_empty():
		return -_persona.dice_back / _persona.hull
	var total: float = 0.0
	for ship: Enemy in others:
		total += AutoPilotThreat.of_face(ship, handoff.face)
	return total / others.size()


## Shields count in full up to what the coming enemy turn should take, and
## for a fraction beyond.
func _shield_value(amount: float) -> float:
	if amount <= 0.0:
		return amount * _persona.shields
	var coming: float = float(AutoPilotMove.dice_in_hand().size() - 1) * _EXPECTED_HIT_PER_DIE
	for ship: Enemy in Globals.enemy_manager.get_alive_enemies():
		coming += AutoPilotThreat.held(ship)
	var needed: float = maxf(0.0, coming - Globals.player.health.shields)
	var useful: float = minf(amount, needed)
	return (useful + (amount - useful) * _SPARE_SHIELD_SHARE) * _persona.shields


## Out of a fight charge is the way to the next stop, worth it up to a full
## drive. In one, a little, unless it's time to leave.
func _charge_value(amount: float, in_combat: bool) -> float:
	var player: Player = Globals.player
	var missing: float = maxf(0.0, float(player.max_engine_charge - player.engine_charge))
	if amount < 0.0:
		return amount * (_COMBAT_CHARGE if in_combat else 1.0)
	if in_combat and not _wants_to_flee():
		return minf(amount, missing) * _COMBAT_CHARGE
	return minf(amount, missing)


## A die that only tops up a full drive mid-fight does nothing for the fight,
## yet still goes to the target (the Engine Charger hands it on), so almost
## any tile that does something is the better play.
func _only_wastes_charge(forecast: AutoPilotForecast, in_combat: bool) -> bool:
	if not in_combat or forecast.charge <= 0.0 or _wants_to_flee():
		return false
	var player: Player = Globals.player
	if player.engine_charge < player.max_engine_charge:
		return false
	for hit: Node in forecast.damage:
		if hit is Enemy:
			return false
	return forecast.shields <= 0.0 and forecast.heal <= 0.0 and forecast.statuses.is_empty() \
		and forecast.dice_back <= 0.0 and forecast.jump == 0


## What keeping [param die] in hand through End Turn is worth on a ship with
## a sail (OutriggerSail): the charge it adds while the sail has room, less
## what the enemy will do with it, since it goes to the target afterwards.
func _bank_value(die: Dice) -> float:
	if not OutriggerSail.is_sail_up():
		return 0.0
	var hand: Array[Dice] = OutriggerSail.banked_dice()
	var faces: Array[int] = []
	for held: Dice in hand:
		faces.append(held.value)
	var plan: Array[int] = OutriggerSail.charge_plan(faces,
			Globals.player.engine_charge, Globals.player.max_engine_charge)
	var index: int = hand.find(die)
	var charge: float = _charge_value(plan[index], true) if index >= 0 else 0.0
	var target: Enemy = _targeted()
	var handoff: float = AutoPilotThreat.of_face(target, die.value) * _persona.hull \
			if is_instance_valid(target) and not die.holographic else 0.0
	return charge - handoff


# ── The map ────────────────────────────────────────────────────────────────────

func _wants_to_jump() -> bool:
	if not is_instance_valid(Globals.player) or not Globals.player.is_engine_charged():
		return false
	return _wants_to_flee() if _in_combat() else true


func _wants_to_flee() -> bool:
	if not _may_flee or not _in_combat():
		return false
	var health: Health = Globals.player.health
	if float(health.health) >= float(health.max_health) * _persona.flee_below:
		return false
	if _fled_at_hull.has(_fight_key()) and health.health <= _fled_at_hull[_fight_key()]:
		return false
	return _has_refuge()


## Whether some stop a jump could reach will still be an ordinary stop when it
## lands: not Fate's, and not the gate. Fleeing anywhere else only trades this
## fight for one as bad, or for a trip straight back to it.
static func _has_refuge() -> bool:
	var map: Map = Globals.map
	var here: int = map.current_scenario_index
	for distance: int in range(1, 7):
		for there: int in [here - distance, here + distance]:
			if there < 0 or there >= map.scenario_list.size():
				continue
			var stop: ScenarioResource = map.scenario_list[there]
			if map.is_fate_scenario(stop) or stop.sector_gate_scenario or _corrupted_by_next_jump(there):
				continue
			return true
	return false


## Out of a fight at a sector gate whose ring isn't up yet: the boss was just
## beaten.
static func _gate_still_opening() -> bool:
	if _in_combat() or not is_instance_valid(Globals.jump_gate) or Globals.jump_gate.is_open():
		return false
	var scenario: ScenarioResource = Globals.scenario_manager.current_scenario
	return scenario != null and scenario.sector_gate_scenario


static func _fight_key() -> String:
	return "%d/%d" % [Globals.state_manager.current_game_save.sector_index,
		Globals.map.current_scenario_index]


## A jump of [param delta] tiles: where it lands, as the map shows it.
func _jump_value(delta: int) -> float:
	var map: Map = Globals.map
	var last: int = map.scenario_list.size() - 1
	var here: int = map.current_scenario_index
	if delta > 0 and here == last:
		return _THROUGH_GATE if is_instance_valid(Globals.jump_gate) and Globals.jump_gate.is_open() else _NOWHERE
	var there: int = clampi(here + delta, 0, last)
	if there == here:
		return _NOWHERE
	var score: float = _stop_value(there)
	if delta > 0:
		score += _PROGRESS * delta + _SKIPPED_STOP * _stops_between(here, there)
	else:
		score += _BACKTRACK + delta
	if _in_combat():
		# Anywhere is better than here, but some places are better than others.
		score += _FLIGHT
	return score


func _stop_value(index: int) -> float:
	var map: Map = Globals.map
	var stop: ScenarioResource = map.scenario_list[index]
	if _corrupted_by_next_jump(index):
		return _STOP_CORRUPT
	var health: Health = Globals.player.health
	var hull_share: float = float(health.health) / maxf(1.0, float(health.max_health))
	var icon: String = stop.map_icon.resource_path.get_file() if stop.map_icon else ""
	match icon:
		"enemy_encounter.png":
			return _STOP_ENEMY if hull_share > 0.5 else 1.0
		"elite_encounter.png":
			return _STOP_ELITE * _persona.risk if hull_share > 0.7 else -3.0
		"unknown_encounter.png":
			return _STOP_UNKNOWN
		"shop.png":
			return _STOP_SHOP + minf(AutoPilotSnapshot.credits() / _SHOP_CREDITS_PER_POINT, _SHOP_CAP)
		"healing_encounter.png":
			if AutoPilotSnapshot.credits() < _REPAIR_STOP_MIN_CREDITS:
				return _STOP_EMPTY
			return _STOP_EMPTY + (1.0 - hull_share) * _STOP_REPAIR_PER_MISSING * _persona.heal
		"fate_encounter.png":
			return _STOP_CORRUPT
		"jump_gate.png":
			# The boss waits; the stops before it are where the build grows.
			var left: int = _stops_between(map.current_scenario_index, index)
			return _STOP_GATE + _SKIPPED_STOP * 1.6 * left
	return _STOP_EMPTY


## Stops worth visiting strictly between [param from] and [param to] that will
## still be there after the next jump.
static func _stops_between(from: int, to: int) -> int:
	var count: int = 0
	for index: int in range(from + 1, to):
		if _corrupted_by_next_jump(index):
			continue
		var icon: Texture2D = Globals.map.scenario_list[index].map_icon
		if icon and icon.resource_path.get_file() in _WORTH_VISITING:
			count += 1
	return count


## Fate takes the tiles in danger as the player jumps, before they land.
static func _corrupted_by_next_jump(index: int) -> bool:
	var map: Map = Globals.map
	if map.scenario_list[index].sector_gate_scenario:
		return false
	return index in map.stray_danger_indices \
		or (index > map.fate_index and index <= map.fate_index + map.scenarios_in_danger)


## What the board looks like for deciding whether to jump; a new hand or more
## charge is worth another look at the map.
func _board_key() -> String:
	return "%d/%d/%d/%d" % [Globals.map.current_scenario_index, Globals.player.engine_charge,
		AutoPilotMove.dice_in_hand().size(), Globals.player.health.health]


# ── Salvage and the shop ───────────────────────────────────────────────────────

## Whether to buy another repair: while the hull is low enough for this style
## to care. The station only offers one it can pay for and has room for.
func _wants_repair() -> bool:
	var health: Health = Globals.player.health
	var hull_share: float = float(health.health) / maxf(1.0, float(health.max_health))
	return hull_share < _REPAIR_BELOW + _REPAIR_BELOW_PER_HEAL * _persona.heal


## The best of [param offers] worth having; for purchases, only one that
## clears its price. Null if none is.
func _best_item(offers: Array, buying: bool) -> AutoPilotMove:
	var best: AutoPilotMove = null
	var best_score: float = -INF
	for offer: AutoPilotMove in offers:
		var score: float = item_value(offer.item)
		if score < 0.0:
			continue
		if buying:
			score -= offer.price / _PRICE_PER_POINT
			if score < _BUY_BAR:
				continue
		if score > best_score:
			best_score = score
			best = offer
	return best


## Any one of [param offers]: a random picker always takes something.
static func _random_claim(offers: Array, rng: RandomNumberGenerator) -> AutoPilotMove:
	return offers[rng.randi_range(0, offers.size() - 1)]


## Any one of [param stock] it can afford, or null once it has walked away.
## Before each purchase walking away is one more equal choice, so a shop
## visit buys nothing about as often as it buys any one item.
func _random_purchase(stock: Array, rng: RandomNumberGenerator) -> AutoPilotMove:
	var shop_key: String = _fight_key()
	if _done_shopping.has(shop_key):
		return null
	var pick: int = rng.randi_range(0, stock.size())
	if pick == stock.size():
		_done_shopping[shop_key] = true
		return null
	return stock[pick]


## What having [param item] is worth: a tile by what it does with an average
## die, a die, or credits.
func item_value(item: Node) -> float:
	if item is MoneyPickup:
		return (item as MoneyPickup).amount / _CREDITS_PER_POINT
	if item is Tile:
		return _tile_worth(item as Tile)
	return _DIE_WORTH


func _tile_worth(tile: Tile) -> float:
	var resource: TileResource = tile.tile_resource
	var worth: float = float(resource.rarity) * _RARITY_WORTH
	if resource.effect_chain == null or _refuses_dice(resource):
		return worth + _PASSIVE_TILE_WORTH
	if not is_instance_valid(_nominal_enemy):
		_nominal_enemy = _make_nominal_enemy()
	var nominal: Array[Enemy] = [_nominal_enemy]
	var total: float = 0.0
	for face: int in range(1, 7):
		if _accepts_face(resource, face):
			total += _nominal_score(tile, face, nominal)
	worth += total / 6.0
	# A tile that fires all turn is worth more than one with a use or two.
	if resource.uses_per_turn < 0:
		worth *= 1.2
	else:
		worth *= 0.7 + 0.15 * resource.uses_per_turn
	return worth


## A tile's output with [param face], at face value: no fight to read, so no
## kills, no threats, every shield and charge counted.
func _nominal_score(tile: Tile, face: int, nominal: Array[Enemy]) -> float:
	var die: _NominalDie = _NominalDie.new()
	die.value = face
	var forecast: AutoPilotForecast = AutoPilotForecast.of(tile, die, _nominal_enemy, nominal)
	die.free()
	var score: float = 0.0
	for hit: Node in forecast.damage:
		score += forecast.damage[hit] * (_persona.damage if hit is Enemy else -_persona.hull)
	score += forecast.shields * _persona.shields + forecast.heal * _persona.heal
	score += forecast.charge * _COMBAT_CHARGE
	for status: StringName in forecast.statuses:
		score += forecast.statuses[status] * _STATUS_WORTH.get(status, _STATUS_WORTH_DEFAULT) * _persona.status
	score += forecast.dice_back * _persona.dice_back
	score += (forecast.tile_tricks + forecast.deepest_feed * 0.5) * _persona.tricks
	if forecast.destroys_itself:
		score += _SELF_DESTRUCT
	return score


## An enemy with nothing but a hull and an empty hand, so the steps that read
## a target's shields or dice find something to read.
static func _make_nominal_enemy() -> Enemy:
	var ship: Enemy = Enemy.new()
	ship.health = Health.new()
	ship.add_child(ship.health)
	ship.dice_manager = EnemyDiceManager.new()
	ship.add_child(ship.dice_manager)
	return ship


## A die that's only a face, for valuing a tile with each face in turn.
class _NominalDie extends Node:
	var value: int = 1
	var holographic: bool = false


static func _accepts_face(resource: TileResource, face: int) -> bool:
	for check: ActivationResource in resource.activation_checks:
		if check.type == ActivationResource.ActivationType.VALUE and not face in check.acceptable_values:
			return false
	return true


static func _refuses_dice(resource: TileResource) -> bool:
	for check: ActivationResource in resource.activation_checks:
		if check.type == ActivationResource.ActivationType.CANT_BE_ACTIVATED_WITH_DIE:
			return true
	return false


# ── The board ──────────────────────────────────────────────────────────────────

static func _in_combat() -> bool:
	return Globals.state_manager.state == GameStateManager.GameState.IN_COMBAT


static func _targeted() -> Enemy:
	if not is_instance_valid(Globals.targeting_computer):
		return null
	var ship: Enemy = Globals.targeting_computer.targeted_enemy
	return ship if is_instance_valid(ship) else null
