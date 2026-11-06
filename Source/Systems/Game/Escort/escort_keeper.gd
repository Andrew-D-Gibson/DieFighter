class_name EscortKeeper
extends Node
## The ship riding along with the player: one the player helped, that leaves
## with them instead of staying behind (EscortResource, signed on by the state
## it enters: the Mayday's "Bless you, pilot. Stay close.").
##
## It flies in to its own slot at every arrival after the one it joined at
## (EnemyManager.ESCORT_SLOT) and fights on the player's side. Each fight won
## with it still flying counts down its EscortResource.fights. At the arrival
## after the last one it flies to the middle, says goodbye, pays and jumps
## away. If it dies on the way, the payout is lost, nothing more: no standing
## lost, and the Reckoning still counts it among the ships the player saved
## (it was remembered as it signed on), though it says something different.
## A player who turns on it loses it too, and its state's deeds say the rest.
##
## Saved with the run at every checkpoint (GameSaveResource.escort_state).
## Never spawned in the Reckoning, where it is already one of the Saved Ship
## tiles: the same ship mustn't count twice.

enum Phase {
	## No escort.
	NONE,
	## Signed on in the encounter the player is still in: the ship is that
	## encounter's own, and leaves with them at the jump.
	JOINED,
	## Flying along, in its slot at every arrival.
	RIDING,
	## Its fights are done: it says goodbye at this arrival.
	FAREWELL,
}

## The phases as the save names them.
const _PHASE_IDS: Dictionary[Phase, String] = {
	Phase.JOINED: "joined",
	Phase.RIDING: "riding",
	Phase.FAREWELL: "farewell",
}

## How long the goodbye may take before the arrival gives up waiting on it.
const _FAREWELL_TIMEOUT_SECONDS: float = 6.0

var escort: EscortResource = null
var phase: Phase = Phase.NONE
## Won fights left before it says goodbye.
var fights_left: int = 0
## The hull it carried out of its last encounter; 0 for a whole one.
var hull: int = 0
## The enemy id the Reckoning remembers it by (FateLedger.allies), to tell it
## how the escort went.
var ally_id: String = ""

## The ship on the board now: the escort, or while JOINED the encounter's own
## ship that signed on. Null between encounters.
var _ship: Enemy = null


func _ready() -> void:
	Globals.escort_keeper = self
	Events.load_game_save.connect(_load_game_save)
	Events.escort_signed_on.connect(_sign_on)
	Events.jump.connect(_on_jump)
	# After EnemyManager's own listener (this node comes later in the
	# scene), so a jump's leftovers are cleared and the encounter's ships are
	# in before the escort joins them.
	Events.load_scenario.connect(_on_load_scenario)
	Events.start_scenario.connect(_on_start_scenario)
	# Before GameStateManager's after-combat checkpoint, which is connected
	# last, so the fight just won is counted in the save it writes.
	Events.combat_finished.connect(_on_combat_finished)
	Events.enemy_left.connect(_on_enemy_left)
	Events.ship_scenario_state_changed.connect(_on_state_changed)


func has_escort() -> bool:
	return phase != Phase.NONE


## The escort on the board, if it's flying in this encounter.
func escort_ship() -> Enemy:
	if phase in [Phase.RIDING, Phase.FAREWELL] and is_instance_valid(_ship):
		return _ship
	return null


# ── Joining and leaving ──────────────────────────────────────────────────────

func _sign_on(ship: Enemy, terms: EscortResource) -> void:
	# One at a time: a second ship asking to come along finds the slot taken.
	if has_escort() or terms == null or terms.ship_resource == null:
		return
	escort = terms
	phase = Phase.JOINED
	fights_left = maxi(1, terms.fights)
	hull = 0
	ally_id = ContentRegistry.get_enemy_id(ship.enemy_resource.resource_path) if ship.enemy_resource else ""
	_ship = ship


## Leaving with the player. The ship that signed on leaves the encounter
## patched up (the player's help is what got its drive going): it rides
## along on a whole hull.
func _on_jump() -> void:
	match phase:
		Phase.JOINED:
			phase = Phase.RIDING
			hull = 0
		Phase.RIDING:
			if is_instance_valid(_ship) and _ship.health.health > 0:
				hull = _ship.health.health
			if fights_left <= 0:
				phase = Phase.FAREWELL
	_ship = null


func _on_load_scenario(_scenario: ScenarioResource) -> void:
	_ship = null
	# A Continue partway through the encounter it signed on in: that
	# encounter's ship is back in the state that signed it on.
	if phase == Phase.JOINED:
		for ship: Enemy in Globals.enemy_manager.get_alive_enemies():
			if ship.scenario_state and ship.scenario_state.escort == escort:
				_ship = ship
		return
	if phase not in [Phase.RIDING, Phase.FAREWELL]:
		return
	# The Reckoning already has it, as a Saved Ship tile.
	if Globals.fate_ledger and Globals.fate_ledger.in_reckoning:
		return
	_ship = Globals.enemy_manager.spawn_escort(escort.ship_resource, escort.escort_state, hull)


func _on_start_scenario() -> void:
	if not is_instance_valid(_ship) or not _ship.is_escort:
		return
	if phase == Phase.FAREWELL:
		# Before the encounter's ships come in, so the goodbye has the stage.
		ArrivalIntro.shared().add(ArrivalIntro.Beat.ESCORT_FAREWELL, _say_goodbye)
		return
	_ride_in(_ship)


## Into its slot. On its first leg it says so, which is the player's first
## sight of it riding along.
func _ride_in(ship: Enemy) -> void:
	var first_leg: bool = fights_left >= escort.fights \
		and Globals.state_manager and Globals.state_manager.get_restore().is_empty()
	await Globals.enemy_manager.move_escort(ship, EnemyManager.ESCORT_SLOT)
	if first_leg and is_instance_valid(ship) and ship.health.health > 0 and ship.scenario_state:
		ship.dialogue_manager.show_dialogue(ship.scenario_state.display_dialogue(), ship.scenario_state.faction)


## Counted while the fight's last ship is still settling, before the
## after-combat checkpoint, which saves the count.
func _on_combat_finished() -> void:
	if phase == Phase.RIDING and is_instance_valid(_ship) and _ship.is_escort and _ship.health.health > 0:
		fights_left -= 1


func _on_enemy_left(ship: Enemy, _faction: ScenarioManager.Faction) -> void:
	if ship != _ship or phase == Phase.NONE:
		return
	if phase in [Phase.RIDING, Phase.FAREWELL] and ship.health.is_dead:
		if Globals.fate_ledger:
			Globals.fate_ledger.record_escort_outcome(ally_id, FateLedger.ESCORT_LOST)
		Events.escort_lost.emit(ship)
	_drop()


## Turned on by the player (or by the encounter it joined at, before it
## could leave): no escort, no payout. Its new state's deeds tell the fleet.
func _on_state_changed(ship: Enemy) -> void:
	if ship == _ship and phase != Phase.NONE and ship.is_hostile():
		_drop()


## Flies to the middle, says its goodbye, pays, and jumps away (the farewell
## state's chain ends in a FLEE). A beat of the arrival, so the encounter's
## ships wait for it.
func _say_goodbye() -> void:
	var ship: Enemy = _ship
	if not is_instance_valid(ship):
		return
	var terms: EscortResource = escort
	var remembered_as: String = ally_id
	await Globals.enemy_manager.move_escort(ship, Globals.enemy_manager.escort_farewell_spot(ship))
	if not is_instance_valid(ship) or ship.health.is_dead:
		return

	# Done with before it leaves, so its own departure reads as nothing more.
	_drop()
	if Globals.fate_ledger:
		Globals.fate_ledger.record_escort_outcome(remembered_as, FateLedger.ESCORT_DELIVERED)
	if terms.payout:
		Events.spawn_reward.emit(ship.global_position, terms.payout)
	Events.escort_delivered.emit(ship)
	ship.force_scenario_state(terms.farewell_state)

	# Bounded: a goodbye that goes wrong mustn't hold the arrival forever.
	var waited: float = 0.0
	while is_instance_valid(ship) and waited < _FAREWELL_TIMEOUT_SECONDS:
		await get_tree().process_frame
		waited += get_process_delta_time()


func _drop() -> void:
	escort = null
	phase = Phase.NONE
	fights_left = 0
	hull = 0
	ally_id = ""
	_ship = null


# ── Save ─────────────────────────────────────────────────────────────────────

## Empty when there's no escort. The hull is read off the ship while it's on
## the board, so a checkpoint after a fight keeps the damage it took.
func get_state() -> Dictionary:
	if phase == Phase.NONE or escort == null:
		return {}
	var hull_now: int = hull
	if phase == Phase.RIDING and is_instance_valid(_ship) and _ship.is_escort and _ship.health.health > 0:
		hull_now = _ship.health.health
	return {
		"escort": escort.resource_path,
		"phase": _PHASE_IDS[phase],
		"fights_left": fights_left,
		"hull": hull_now,
		"ally": ally_id,
	}


## Restores from get_state() as it comes back from JSON. Anything it can't
## read back is no escort at all.
func load_state(state: Dictionary) -> void:
	_drop()
	var path: String = str(state.get("escort", ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var terms: EscortResource = load(path) as EscortResource
	var phase_id: String = str(state.get("phase", ""))
	var saved_phase: Phase = Phase.NONE
	for each: Phase in _PHASE_IDS:
		if _PHASE_IDS[each] == phase_id:
			saved_phase = each
	if terms == null or saved_phase == Phase.NONE:
		return
	escort = terms
	phase = saved_phase
	fights_left = int(state.get("fights_left", terms.fights))
	hull = int(state.get("hull", 0))
	ally_id = str(state.get("ally", ""))


func _load_game_save(game_save: GameSaveResource) -> void:
	load_state(game_save.escort_state)
