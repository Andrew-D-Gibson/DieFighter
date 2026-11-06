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
## An escort that rides to the gate (EscortResource.rides_to_gate, the
## Outrigger courier) skips the count: it stays until the sector's gate fight
## is won and says goodbye right there, while the jump waits for it. One that
## earns a ship (EscortResource.unlocks_ship) earns it the moment the gate
## falls with it alive, and shows the ship-unlock card once it has gone.
##
## Saved with the run at every checkpoint (GameSaveResource.escort_state).
## Never spawned in the Reckoning, where it already flies as one of the saved
## ships its REMEMBER_SHIP queued (ReckoningAllyWing): the same ship mustn't
## count twice.

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
## A farewell's lead-in line is held this long once it has typed out, then
## the next one starts: long enough to read, without the box's full linger.
const _LINE_HOLD_SECONDS: float = 1.5
## Longest a lead-in line may hold the goodbye, if its box never shows it.
const _LINE_TIMEOUT_SECONDS: float = 7.0
## After the gate falls, a beat for the boss's wreck and the bounty to settle
## before the escort speaks.
const _GATE_GOODBYE_DELAY_SECONDS: float = 1.6
const _SHIP_UNLOCK_POPUP: PackedScene = preload("res://Source/Systems/UI/ShipUnlockPopup/ship_unlock_popup.tscn")

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


## Whether [param ship] is the escort, and still flying, as the player jumps
## away: it goes with them (EnemyManager.start_enemy_jump_animation()).
func leaves_with_player(ship: Enemy) -> bool:
	return phase in [Phase.JOINED, Phase.RIDING] and ship == _ship \
		and is_instance_valid(ship) and ship.health.health > 0


# ── Joining and leaving ──────────────────────────────────────────────────────

func _sign_on(ship: Enemy, terms: EscortResource) -> void:
	if terms == null or terms.ship_resource == null:
		return
	# One at a time: a second ship asking to come along finds the slot taken.
	# Except one riding to the gate, which the player can't meet again this
	# run: the escort it displaces says its goodbye now, paid in full.
	if has_escort():
		if not (terms.rides_to_gate and phase == Phase.RIDING and is_instance_valid(_ship)):
			return
		_send_off_early()
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
			# One riding to the gate says goodbye there, not by its count.
			if fights_left <= 0 and not escort.rides_to_gate:
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
	# The Reckoning already has it, among the saved ships it replays.
	if Globals.fate_ledger and Globals.fate_ledger.in_reckoning:
		return
	_ship = Globals.enemy_manager.spawn_escort(escort.ship_resource, escort.escort_state, hull)
	# A farewell flies in from the left edge to the middle; every other
	# arrival jumps into its slot (_ride_in), unseen until then.
	if phase == Phase.RIDING:
		Globals.enemy_manager.hold_escort_in_slot(_ship)


func _on_start_scenario() -> void:
	if not is_instance_valid(_ship) or not _ship.is_escort:
		return
	if phase == Phase.FAREWELL:
		# Before the encounter's ships come in, so the goodbye has the stage.
		ArrivalIntro.shared().add(ArrivalIntro.Beat.ESCORT_FAREWELL, _say_goodbye)
		return
	_ride_in(_ship)


## Jumps into its slot, as the jump it left with in reverse. On its first leg
## it says so, which is the player's first sight of it riding along.
func _ride_in(ship: Enemy) -> void:
	var first_leg: bool = fights_left >= escort.fights \
		and Globals.state_manager and Globals.state_manager.get_restore().is_empty()
	await Globals.enemy_manager.jump_escort_in(ship)
	if first_leg and is_instance_valid(ship) and ship.health.health > 0 and ship.scenario_state:
		ship.dialogue_manager.show_dialogue(ship.scenario_state.display_dialogue(), ship.scenario_state.faction)


## Counted while the fight's last ship is still settling, before the
## after-combat checkpoint, which saves the count. The gate falling with an
## escort that rides to it aboard is its goodbye, saved the same way, so a
## Continue at the open gate replays it.
func _on_combat_finished() -> void:
	if phase != Phase.RIDING or not is_instance_valid(_ship) or not _ship.is_escort \
	or _ship.health.health <= 0:
		return
	fights_left -= 1
	if escort.rides_to_gate and _at_gate():
		phase = Phase.FAREWELL
		_earn_ship(escort)
		Globals.map.hold_jumps(self)
		_goodbye_at_gate()


func _at_gate() -> bool:
	var scenario: ScenarioResource = Globals.scenario_manager.current_scenario \
		if Globals.scenario_manager else null
	return scenario != null and scenario.sector_gate_scenario


## Where it is, once the boss's wreck has settled. The jump is held from the
## moment the gate falls until the goodbye (and any ship-unlock card) is done.
func _goodbye_at_gate() -> void:
	await get_tree().create_timer(_GATE_GOODBYE_DELAY_SECONDS).timeout
	if phase == Phase.FAREWELL and is_instance_valid(_ship):
		await _say_goodbye()
	Globals.map.release_jumps(self)


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
## ships wait for it. One riding to the gate says it from its slot instead,
## clear of the boss's bounty, and holds the jump throughout; if it earned a
## ship, the ship-unlock card follows once it has gone.
func _say_goodbye() -> void:
	var ship: Enemy = _ship
	if not is_instance_valid(ship):
		return
	var terms: EscortResource = escort
	var remembered_as: String = ally_id
	var spot: Vector2 = EnemyManager.ESCORT_SLOT if terms.rides_to_gate \
		else Globals.enemy_manager.escort_farewell_spot(ship)
	if terms.rides_to_gate:
		Globals.map.hold_jumps(self)
	_drop()
	await _send_off(ship, terms, remembered_as, spot)
	# Shot down mid-goodbye: it never got the plans out.
	var got_away: bool = not is_instance_valid(ship) or not ship.health.is_dead
	if got_away and not terms.unlocks_ship.is_empty():
		_earn_ship(terms)
		await _show_ship_unlock(terms.unlocks_ship)
	if terms.rides_to_gate:
		Globals.map.release_jumps(self)


## The escort's goodbye, once the keeper has let go of it (so its own
## departure reads as nothing more): to [param spot], each lead-in line in
## turn, the farewell state, and gone.
func _send_off(ship: Enemy, terms: EscortResource, remembered_as: String, spot: Vector2) -> void:
	if is_instance_valid(ship) and ship.position.distance_to(spot) > 0.5:
		await Globals.enemy_manager.move_escort(ship, spot)
	if not is_instance_valid(ship) or ship.health.is_dead:
		return

	if Globals.fate_ledger:
		Globals.fate_ledger.record_escort_outcome(remembered_as, FateLedger.ESCORT_DELIVERED)
	Events.escort_delivered.emit(ship)
	for line: ScenarioShipState in terms.farewell_lead_in:
		if not is_instance_valid(ship) or ship.health.is_dead:
			return
		await _say_line(ship, line)
	if not is_instance_valid(ship):
		return
	# With the farewell line ("Take this."), after any lead-in.
	if terms.payout:
		var at: Vector2 = terms.payout_position if terms.payout_position != Vector2.ZERO \
			else ship.global_position
		Events.spawn_reward.emit(at, terms.payout)
	ship.force_scenario_state(terms.farewell_state)

	# Bounded: a goodbye that goes wrong mustn't hold the arrival forever.
	var waited: float = 0.0
	while is_instance_valid(ship) and waited < _FAREWELL_TIMEOUT_SECONDS:
		await get_tree().process_frame
		waited += get_process_delta_time()


## Puts [param ship] into [param line]'s state and returns once its line has
## typed out and been held a moment (bounded).
func _say_line(ship: Enemy, line: ScenarioShipState) -> void:
	var dialogue: EnemyDialogueManager = ship.dialogue_manager
	# Connected first: the line can show the moment the state is entered.
	var shown: Array[bool] = [false]
	var on_shown: Callable = func() -> void: shown[0] = true
	dialogue.line_shown.connect(on_shown)
	ship.force_scenario_state(line)
	var read_time: float = dialogue.character_reveal_time * line.display_dialogue().length() \
		+ _LINE_HOLD_SECONDS
	var waited: float = 0.0
	var since_shown: float = 0.0
	while is_instance_valid(ship) and waited < _LINE_TIMEOUT_SECONDS and since_shown < read_time:
		await get_tree().process_frame
		waited += get_process_delta_time()
		if shown[0]:
			since_shown += get_process_delta_time()
	if is_instance_valid(ship) and dialogue.line_shown.is_connected(on_shown):
		dialogue.line_shown.disconnect(on_shown)


## A gate escort is signing on while this one still rides: it says its
## goodbye where it is, paid in full, and the slot is the newcomer's.
func _send_off_early() -> void:
	var ship: Enemy = _ship
	var terms: EscortResource = escort
	var remembered_as: String = ally_id
	_drop()
	_send_off(ship, terms, remembered_as, ship.position)


## The ship [param terms] earns, for good. Only once it's earned in the
## player's own runs (ShipUnlocks); a replay changes nothing.
func _earn_ship(terms: EscortResource) -> void:
	if terms and not terms.unlocks_ship.is_empty():
		ShipUnlocks.unlock(terms.unlocks_ship)


## The ship-unlock card, until the player closes it. Never while the
## AutoPilot flies: nobody would close it.
func _show_ship_unlock(id: StringName) -> void:
	var ship: ShipResource = ShipCatalog.find(id)
	if ship == null or ship.id != id:
		return
	if is_instance_valid(AutoPilot) and AutoPilot.is_playing():
		return
	var popup: ShipUnlockPopup = _SHIP_UNLOCK_POPUP.instantiate()
	get_tree().current_scene.add_child(popup)
	popup.global_position = Vector2.ZERO
	popup.open(ship)
	await popup.closed
	popup.queue_free()


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
