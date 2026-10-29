class_name Player
extends Node2D

const _HEALTH_HIT_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/player_health_hit.tres")
const _SHIELDS_HIT_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/player_shields_hit.tres")
const _DICE_REROLL_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/dice_reroll_blip.tres")
const _DIE_LOST_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/die_dread_thunk.tres")

@export var _time_between_die_spawns: float = 0.2
@export var _dice_queue_spacing: int = 14

## Redline headroom as a fraction of max_engine_charge. Safe to open now that
## ChangeEngineChargeEvent clamps at max unless a change explicitly opts in,
## so only ADD_OVERCHARGE can reach the band.
const _OVERCHARGE_CAP_FRACTION: float = 0.5

## Hull paid per turn ended in the redline, as a divisor of the overcharge:
## +10 past the gate costs 5 a turn. Pushing deeper costs more, which is what
## makes the band a burst resource rather than a bank. See redline_hull_cost().
const _REDLINE_HULL_DIVISOR: int = 2

var max_engine_charge: int = 24

## Headroom above max_engine_charge that charge is allowed to occupy — the
## "redline" band. Derived from max_engine_charge whenever the dice count
## changes. Reaching it is deliberate: only an ADD_OVERCHARGE effect may push
## charge past max, so topping off to jump can never redline you by accident.
var overcharge_cap: int = 0

## The absolute ceiling the charge setter clamps to.
var charge_ceiling: int:
	get: return max_engine_charge + overcharge_cap

@export var engine_charge: int = 0:
	set(new_value):
		engine_charge = clampi(new_value, 0, charge_ceiling)
		Events.engine_charge_changed.emit()


## True once the engine will allow a jump. Deliberately >= rather than ==:
## charge can sit above max while redlined, and an equality test there would
## silently lock the player out of jumping.
func is_engine_charged() -> bool:
	return engine_charge >= max_engine_charge


func is_overcharged() -> bool:
	return engine_charge > max_engine_charge


## How far into the redline band the engine currently sits. Never negative.
func overcharge_amount() -> int:
	return maxi(0, engine_charge - max_engine_charge)


## How much charge is still needed to open the jump gate. Never negative, and
## reads 0 while overcharged.
func missing_charge() -> int:
	return maxi(0, max_engine_charge - engine_charge)


func can_afford_charge(cost: int) -> bool:
	return engine_charge >= cost


## Every die the player owns, wherever it is right now — in hand, on a tile,
## or handed to an enemy — plus the holograms they're holding. A hologram an
## enemy is holding isn't counted: it can't come back.
func dice_owned() -> int:
	if not is_inside_tree():
		return num_of_dice
	var holograms: int = 0
	for node: Node in get_tree().get_nodes_in_group('Dice'):
		var die: Dice = node as Dice
		if die and die.holographic and not die.is_queued_for_deletion() \
		and die.host_queue != null and die.host_queue is not EnemyDiceManager:
			holograms += 1
	return num_of_dice + holograms


@onready var dice_manager: DiceQueue = %DiceQueue
@onready var health: Health = %Health

var num_of_dice: int:
	set(new_num):
		var was_overcharged: bool = is_overcharged()
		num_of_dice = new_num
		
		# Floored at 1: the curve goes negative at a single die, which a jump
		# can now leave the player with, and the engine bar divides by this.
		max_engine_charge = maxi(1, (6*(num_of_dice-1)) - floor(1.7078 * sqrt(num_of_dice)))
		overcharge_cap = roundi(max_engine_charge * _OVERCHARGE_CAP_FRACTION)

		# The ceiling just moved. Re-run the charge setter so a shrinking
		# ceiling re-clamps rather than leaving charge stranded above it. A
		# drive that wasn't in the redline stops at the new gate: losing a die
		# with a full engine must not redline the player into bleeding hull.
		engine_charge = engine_charge if was_overcharged else mini(engine_charge, max_engine_charge)

		Events.die_added.emit()
		
		
@export var dice_scene: PackedScene

## True while _start_scenario() is still bringing the opening hand in. A
## fight that starts then gets its first turn once the hand is down.
var _dealing_hand: bool = false

## Whether this fight's first turn has been announced. A fight gets exactly one.
var _first_turn_announced: bool = false

## Bumped whenever the fight on screen stops being the one a waiting
## announcement was for: it ended, or the player jumped away from it (dice
## can be played while the ships are still flying in). That announcement
## mustn't go out into whatever comes next.
var _fight_generation: int = 0

## Bumped when a fight starts or the player jumps. The enemy turn that
## follows End Turn hands the turn back only if neither happened meanwhile: a
## fight can break out partway through one (a Burn tick on a civilian), and
## opens with its own first turn. A fight *ending* doesn't count: the turn
## that follows is still the one that unlocks the dice handed back.
var _turn_generation: int = 0
var _turn_generation_at_end: int = 0

## The die that fired the jump in progress. It rides the jump out on the tile
## it was dropped on, so the player can see what launched them, and comes home
## on arrival with the rest of the hand.
var _jump_activator: Dice = null

## From commit_to_jump() until arrival.
var _jump_committed: bool = false

## True while it isn't the player's turn in a fight: from End Turn until
## their next turn starts, and while a fight's ships are still flying in.
## Dice can be played then, and a tile finishing its activation would light
## End Turn; pressing it would start an enemy turn on top of the one
## running, or end a turn that hasn't been announced yet.
var _between_turns: bool = false

## True when the player's own play emptied the hand: a die went onto a tile
## and none has come back since. A fight that this play starts (the last die
## fired at a ship) opens on a turn the player has already spent, so its
## first turn deals no spare die; the next turn start still will if ships
## kept every die.
var _spent_own_hand: bool = false

## How far the dice jolt, in pixels, at the peak of a jump's run-up.
const _JUMP_RATTLE_STRENGTH: float = 1.2

var money: int:
	set(value):
		money = value
		Events.set_money.emit(money)


## Where effects aimed at the player are drawn. The ship has no sprite of its
## own on screen; its health bar is the thing the player watches.
func get_juice_anchor() -> Vector2:
	var bar: Node2D = get_node_or_null("PlayerHealthBar") as Node2D
	return bar.global_position if bar else global_position


## Where shots at the player's shields land (an ion bolt): the shield counter
## beside the health bar.
func get_shield_anchor() -> Vector2:
	var bar: PlayerHealthBar = get_node_or_null("PlayerHealthBar") as PlayerHealthBar
	return bar.get_shield_anchor() if bar else get_juice_anchor()


## Where shots at the player's hull land (an enemy's dice cannon): the hull
## readout on the health bar, wherever this ship's cockpit mounts it.
func get_hull_anchor() -> Vector2:
	var bar: PlayerHealthBar = get_node_or_null("PlayerHealthBar") as PlayerHealthBar
	return bar.get_hull_anchor() if bar else get_juice_anchor()


## Where the player's status badges go: above the health ring.
func get_status_bar() -> StatusBar:
	return get_node_or_null("%StatusBar") as StatusBar


## What a BUMP aimed at the player squashes.
func get_juice_body() -> Node2D:
	var bar: Node2D = get_node_or_null("PlayerHealthBar") as Node2D
	return bar if bar else self


func _ready() -> void:
	Globals.player = self
	# The redline's cost lives here rather than in a manager because Player
	# owns engine_charge; the consequence of holding it past the gate belongs
	# with the field, not with the bar that draws it.
	Events.enemy_turn_over.connect(_bleed_for_redline)
	# game_over waits for the cockpit to come apart (CockpitDestruction).
	health.death.connect(Events.player_destroyed.emit)
	Events.player_destroyed.connect(_stand_down)
	health.health_damaged.connect(Events.player_health_hit.emit)
	health.shields_damaged.connect(Events.player_shields_hit.emit)
	health.shields_broken.connect(Events.player_shields_broken.emit)
	health.shields_reinforced.connect(Events.player_shields_gained.emit)
	health.fatal_damage.connect(Events.player_fatal_damage.emit)
	
	health.health_damaged.connect(func() -> void:
		Events.play_sound.emit(_HEALTH_HIT_SFX)
		Events.camera_shake_large.emit(true)
	)
	health.shields_damaged.connect(func() -> void:
		Events.play_sound.emit(_SHIELDS_HIT_SFX)
		Events.camera_shake_small.emit()
	)
	# The moment the last shield goes, the next hit is on the hull. Escalate to
	# the big shake so the player feels the floor drop out rather than reading
	# a number change.
	health.shields_broken.connect(func() -> void:
		Events.camera_shake_large.emit(false)
	)
	
	
	# Every die coming back to the hand passes through here, from whatever
	# was last moving it: a ship's queue, a dying ship's hold, a tile, a reroll.
	dice_manager.die_received.connect(func(die: Dice) -> void: die.reset_visual_state())
	dice_manager.die_added.connect(func() -> void:
		_spent_own_hand = false
		_update_dice_queue_locations()
		_make_newest_die_draggable()
	)
	dice_manager.die_removed.connect(_update_dice_queue_locations)
	
	Events.tile_activation_complete.connect(_check_for_end_of_turn)
	Events.die_placed_on_tile.connect(func(_die: Dice, _tile: Tile) -> void:
		_spent_own_hand = dice_manager.queue.is_empty()
	)
	
	Events.jump.connect(_carry_dice_through_jump)
	
	%EndTurnButton.disabled = true
	%EndTurnButton.update_ui()
	
	Events.start_scenario.connect(_start_scenario)
	Events.start_combat.connect(func() -> void:
		# A fight breaking out during an enemy turn run out of combat starts
		# with its own first turn, not the one that enemy turn would start.
		_fight_generation += 1
		_turn_generation += 1
		_between_turns = true
		if not _dealing_hand:
			_announce_first_turn()
	)
	Events.combat_finished.connect(func() -> void:
		_first_turn_announced = false
		_fight_generation += 1
		_between_turns = false
	)
	Events.combat_finished.connect(_ensure_a_die_after_combat)
	Events.enemy_turn_over.connect(_start_player_turn)
	Events.load_game_save.connect(_load_game_save)
	
	money = 0
			
			
## Charges the player hull for every turn ended above the jump gate.
##
## Goes through the scenario engine rather than touching Health directly, so
## the bleed passes the same modifier pipeline as any other damage and a region
## that caps or blunts damage blunts this too.
func _bleed_for_redline() -> void:
	var over: int = overcharge_amount()
	if over <= 0:
		return

	if not Globals.scenario_manager:
		return

	var engine: ScenarioEngine = ScenarioEngine.current()
	if engine == null:
		return

	var event: DamageEvent = DamageEvent.new()
	event.amount = redline_hull_cost(over)
	event.actor = self
	event.effect_source = self
	event.targets = [self]
	engine.queue_event(event)

	Events.camera_shake_small.emit()


## Hull lost for ending a turn [param over] charge past the gate: half of it,
## rounded up like every "half of" in the game (+3 costs 2), and never less
## than 1 while redlined at all.
static func redline_hull_cost(over: int) -> int:
	if over <= 0:
		return 0
	return maxi(1, ceili(over / float(_REDLINE_HULL_DIVISOR)))


func _load_game_save(game_save: GameSaveResource) -> void:
	health.max_health = game_save.player_max_health
	health.starting_health = game_save.player_health
	health.health = game_save.player_health
	health.shields = game_save.player_defense
	num_of_dice = game_save.num_of_dice
	engine_charge = game_save.player_engine_charge
	money = game_save.money


# Update the dice desired locations in the world
func _update_dice_queue_locations() -> void:
	for i: int in range(len(dice_manager.queue)):
		dice_manager.queue[i].draggable.home_position = global_position + dice_manager.position + Vector2(i * _dice_queue_spacing, 0)


func _make_newest_die_draggable() -> void:
	if dice_manager.queue[-1].draggable.state != Draggable.DragState.DRAGGING:
		dice_manager.queue[-1].draggable.state = Draggable.DragState.DEFAULT


func _process(_delta: float) -> void:
	# Handle rearranging dice in the queue
	for die: Node in get_children():
		if die is not Dice:
			continue
			
		if die.draggable.state == Draggable.DragState.DRAGGING:
			var current_queue_position: int = dice_manager.queue.find(die)
			
			if current_queue_position == -1:
				dice_manager.add(die, true, false)
			
			var dice_queue_mouse_pos: Vector2 = \
				get_global_mouse_position() \
				- dice_manager.global_position \
				+ Vector2(6, 0)
			

			# Create a rectangle that encompasses the current displayed dice queue
			var dice_queue_bounding_rect: Rect2 = Rect2(
				-_dice_queue_spacing/2.0, # x
				-_dice_queue_spacing/2.0, # y
				(len(dice_manager.queue) - 1) * _dice_queue_spacing, # width
				_dice_queue_spacing, # height
			)

			if dice_queue_bounding_rect.has_point(dice_queue_mouse_pos):
				# Determine which queue position the mouse is hovering over
				var hovered_queue_position: int = int(dice_queue_mouse_pos.x / _dice_queue_spacing)
				# Make sure we limit the hovered location to the end of the queue
				hovered_queue_position = min(hovered_queue_position, len(dice_manager.queue)-1)
				
				# Switch the positions of the two dice, then update their locations
				if current_queue_position != hovered_queue_position:
					dice_manager.remove(die)
					dice_manager.queue.insert(hovered_queue_position, die)
					_update_dice_queue_locations()
			
			elif current_queue_position != len(dice_manager.queue)-1:
				dice_manager.remove(die)
				dice_manager.add(die, true, false)


## Lights End Turn once nothing is left to play. Checked as each tile finishes
## activating, and as each turn starts: a turn can open with the hand already
## spent (the last die is on a tile that holds it, like a Welder), and with
## no activation to come, nothing else would light it.
func _check_for_end_of_turn() -> void:
	# An empty hand isn't enough: dice already dropped on tiles queued behind
	# this activation (a Bump waiting on a Dice Cannon) still have to fire.
	var engine: ScenarioEngine = ScenarioEngine.current()
	var activations_pending: bool = engine != null and engine.has_pending_tile_activation()
	# The die that fired a jump finishes its activation while the map is still
	# panning, with the hand empty; the turn still mustn't end.
	var hand_spent: bool = len(dice_manager.queue) == 0
	if (hand_spent or _hand_may_be_kept()) and not activations_pending and not _jump_committed \
	and not _between_turns:
		%EndTurnButton.disabled = false
		%EndTurnButton.update_ui()
		# The nudge says "you're done". With dice still in hand that's the
		# player's call, not a prompt.
		if hand_spent:
			%EndTurnButton.soft_highlight()
	else:
		%EndTurnButton.disabled = true
		%EndTurnButton.update_ui()


## Whether this ship lets the turn end with dice still in hand
## (ShipResource.hand_may_be_kept). Every other ship plays its whole hand.
## Only in a fight: out of one, ending turns at will would refill every tile's
## uses and reroll the hand for free.
func _hand_may_be_kept() -> bool:
	var ship: ShipResource = Globals.current_ship()
	return ship != null and ship.hand_may_be_kept and Globals.state_manager != null \
		and Globals.state_manager.state == GameStateManager.GameState.IN_COMBAT


func reroll_dice() -> void:
	for die: Dice in dice_manager.queue:
		if die:
			die.reroll_with_tween()
			Events.play_sound.emit(_DICE_REROLL_SFX)		
			await get_tree().create_timer(0.2).timeout
	
	Events.highlight_dice_area.emit()
	

func _start_player_turn() -> void:
	# An enemy turn can finish after the player has committed to a jump, or
	# as they leave (one run out of combat goes on while they play). Its
	# fight is gone, and the turn with it.
	if _jump_committed or _turn_generation_at_end != _turn_generation:
		return
	# Wait for any dice to get back to the dice queue before rerolling them
	await get_tree().create_timer(0.5).timeout
	if _turn_generation_at_end != _turn_generation:
		return
	await reroll_dice()
	await _ensure_a_die_to_play()
	if _turn_generation_at_end != _turn_generation:
		return

	_between_turns = false
	Events.player_turn_refresh.emit()
	Events.player_turn_start.emit()
	_check_for_end_of_turn()
	
	for die: Dice in dice_manager.queue:
		die.draggable.state = Draggable.DragState.DEFAULT


func _delete_existing_dice() -> void:
	for die: Dice in get_tree().get_nodes_in_group('Dice'):
		die.queue_free()
	dice_manager.queue = []
	

func spawn_dice(num_to_spawn: int = num_of_dice, value: int = 0, holographic: bool = false) -> void:
	for i: int in range(num_to_spawn):
		var new_die: Dice = dice_scene.instantiate()
		new_die.global_position = global_position + Vector2(600, 0)
		new_die.holographic = holographic
		if value != 0:
			new_die.value = value
		
		add_child(new_die)		
		dice_manager.add(new_die, true, false)
		
		await get_tree().create_timer(_time_between_die_spawns).timeout
		Events.play_sound.emit(_DICE_REROLL_SFX)
		
	_update_dice_queue_locations()
	Events.highlight_dice_area.emit()
	
	
func _start_scenario() -> void:
	# Continuing a save taken partway through a scenario: the hand and the
	# shields are whatever they were then, not a fresh arrival's.
	var restoring: bool = Globals.state_manager and not Globals.state_manager.get_restore().is_empty()
	_dealing_hand = true
	_first_turn_announced = false
	_jump_committed = false
	_between_turns = Globals.state_manager != null \
			and Globals.state_manager.state == GameStateManager.GameState.IN_COMBAT
	_bring_jump_activator_home()

	if not restoring:
		health.shields = 0
	await get_tree().create_timer(_time_between_die_spawns).timeout

	if restoring:
		await _restore_saved_hand()
	else:
		await _arrive_with_hand()
	_unlock_dice_after_jump()
	_dealing_hand = false
	if Globals.state_manager and Globals.state_manager.state == GameStateManager.GameState.IN_COMBAT:
		_announce_first_turn()


## A fight's first turn has no player_turn_start (that follows an enemy turn),
## so it's announced here, once every ship has landed (Events.enemies_arrived).
## A fight breaking out mid-scenario starts it on start_combat. One opening
## with the scenario is started by _start_scenario() once the hand is dealt:
## state can stay IN_COMBAT through a flee into the next fight, so no
## start_combat comes for it.
func _announce_first_turn() -> void:
	if _first_turn_announced:
		return
	_first_turn_announced = true
	var fight: int = _fight_generation

	# Combat-start effects must not fire at ships that are still flying in or
	# haven't been targeted yet.
	var enemy_manager: EnemyManager = Globals.enemy_manager
	if enemy_manager and enemy_manager.arrival_in_progress:
		await Events.enemies_arrived
	# A new run's ambusher opens fire before the player's first move.
	if Globals.state_manager and fight == _fight_generation:
		await Globals.state_manager.play_opening_strike()
	await _ensure_a_die_for_first_turn()

	# The fight may have ended (or the player jumped) while we waited.
	if fight != _fight_generation or not Globals.state_manager \
			or Globals.state_manager.state != GameStateManager.GameState.IN_COMBAT:
		return
	_between_turns = false
	Events.first_turn_start.emit()
	_check_for_end_of_turn()


## A Continue builds the scene from nothing, so no die has survived to here:
## the hand is rebuilt from the save. The save only records the dice in hand,
## so any owned die that was elsewhere when it was taken (on a tile, mid-
## flight) is topped back up, since a die the player owns is never lost to a
## save.
func _restore_saved_hand() -> void:
	_delete_existing_dice()
	var saved_hand: Array = Globals.state_manager.get_restore().get("dice", [])
	var real_dice: int = 0
	for entry: Variant in saved_hand:
		var holo: bool = bool(entry.get("holo", false))
		if not holo:
			real_dice += 1
		await spawn_dice(1, int(entry["value"]), holo)
	if real_dice < num_of_dice:
		await spawn_dice(num_of_dice - real_dice)


## Arriving keeps whatever dice made the jump and rolls them fresh, rather
## than swapping in a new set. The hand only grows here when it has to: the
## first scenario of a run, a Continue from an arrival checkpoint, or a die
## bought since the last arrival that never reached the hand.
func _arrive_with_hand() -> void:
	var carried: Array[Dice] = _real_dice_in_hand()
	var shortfall: int = num_of_dice - carried.size()

	# More dice in hand than owned would mean a die was double-counted
	# somewhere. Trust the count, which is what the save records.
	while shortfall < 0:
		var extra: Dice = carried.pop_back()
		dice_manager.remove(extra)
		extra.queue_free()
		shortfall += 1

	if not carried.is_empty():
		await reroll_dice()
	if shortfall > 0:
		await spawn_dice(shortfall)


func _real_dice_in_hand() -> Array[Dice]:
	var real: Array[Dice] = []
	for die: Dice in dice_manager.queue:
		if is_instance_valid(die) and not die.holographic:
			real.append(die)
	return real


## A jump keeps every die the player still has — in hand, held by a tile, or
## sitting on the tile that fired the jump — and leaves behind every die an
## enemy is holding. The die that fired the jump is never on an enemy, so a
## jump can't empty the hand.
##
## A die with no host_queue was never the player's: shop stock or salvage on
## offer. Those go with the scenario, as they always have.
func _carry_dice_through_jump() -> void:
	var stranded: int = 0
	for node: Node in get_tree().get_nodes_in_group('Dice'):
		var die: Dice = node as Dice
		if die == null or die.is_queued_for_deletion():
			continue

		if die.host_queue == null:
			die.queue_free()
		elif die.host_queue is EnemyDiceManager:
			_strand_die(die, die.host_queue.get_parent() as Enemy)
			if not die.holographic:
				stranded += 1
		elif die.holographic:
			_dissolve_hologram(die)
		elif die == _jump_activator:
			_lock_die_for_jump(die)
		else:
			_stow_die_for_jump(die)

	_lose_dice(stranded)


## A ship is leaving the fight with [param dice]: they go with it, and every
## real one among them is gone from the Fleet for good, exactly as if the
## player had jumped away from it. Holograms fizzle with the ship.
func lose_dice_to(holder: Enemy, dice: Array[Dice]) -> void:
	var lost: int = 0
	for die: Dice in dice:
		if not is_instance_valid(die) or die.is_queued_for_deletion():
			continue
		TractorBeam.release(die)
		_strand_die(die, holder)
		if not die.holographic:
			lost += 1

	_lose_dice(lost)


## Brings a die home to the hand and holds it there until arrival. Nothing
## may be played mid-jump: the scenario engine a tile would fire through has
## already been shut down.
func _stow_die_for_jump(die: Dice) -> void:
	if die.host_queue != dice_manager:
		dice_manager.add(die, true, false)
	die.draggable.state = Draggable.DragState.DEFAULT
	# A die already in hand skips the add, so square it up here too.
	die.reset_visual_state()
	_lock_die_for_jump(die)


func _lock_die_for_jump(die: Dice) -> void:
	if die.draggable.dragging_allowed:
		die.draggable.dragging_allowed = false
		die.transit_locked = true


## The player is leaving: JumpEvent calls this the moment a jump is decided,
## before the map pans to the destination. From here until arrival nothing
## more is played and the turn can't be ended, since an enemy turn or a tile
## started now would play out in a scenario that's about to be torn down.
##
## [param die], the one that fired the jump, stays on its tile for the trip
## instead of flying home with the rest, so the player can see what launched
## them. A hologram can't make the trip at all.
func commit_to_jump(die: Dice) -> void:
	_jump_committed = true
	_fight_generation += 1
	_turn_generation += 1
	%EndTurnButton.disabled = true
	%EndTurnButton.update_ui()
	for held: Dice in dice_manager.queue:
		if is_instance_valid(held):
			_lock_die_for_jump(held)
	if is_instance_valid(die) and not die.holographic:
		_jump_activator = die


func _bring_jump_activator_home() -> void:
	if is_instance_valid(_jump_activator) and not _jump_activator.is_queued_for_deletion():
		_stow_die_for_jump(_jump_activator)
	_jump_activator = null


## Every die making the jump shakes harder as the drive spools up, building
## over [param ramp_time] until settle_dice_after_jump().
func rattle_dice_for_jump(ramp_time: float) -> void:
	for die: Dice in _dice_making_the_jump():
		die.rattle(_JUMP_RATTLE_STRENGTH, ramp_time)


## The drive has kicked in: the dice drop still all at once.
func settle_dice_after_jump() -> void:
	for die: Dice in _dice_making_the_jump():
		die.settle()


func _dice_making_the_jump() -> Array[Dice]:
	var dice: Array[Dice] = []
	for die: Dice in dice_manager.queue:
		if is_instance_valid(die):
			dice.append(die)
	if is_instance_valid(_jump_activator):
		dice.append(_jump_activator)
	return dice


## The die stays with the ship that's holding it, and is seen to: it rides
## that ship off the bottom of the screen as the player jumps away, and is
## freed with it. Pulled out of every queue and the Dice group first, so
## nothing can hand it back — a ship freed mid-jump never gives its dice away,
## but a combat_finished arriving late would.
func _strand_die(die: Dice, holder: Enemy) -> void:
	# A die mid-action has already left its holder's queue.
	if die.host_queue:
		die.host_queue.remove(die)
	die.host_queue = null
	die.remove_from_group('Dice')
	die.draggable.state = Draggable.DragState.MOVING_WITH_CODE
	if is_instance_valid(holder):
		die.reparent(holder, true)
		# A die's own z lifts it over the cockpit, which is right in hand and
		# wrong here: the ship drops behind the cockpit as the player jumps
		# away, and the die has to go behind it with the ship.
		die.z_index = 0

	if die.holographic:
		return
	Juice.die_flare(die, Globals.red)
	Juice.callout(die, "LOST", Globals.red)


## A hologram is borrowed light, not a die the player owns: it can't make the
## trip, and fizzles out where it sits.
func _dissolve_hologram(die: Dice) -> void:
	if die.host_queue:
		die.host_queue.remove(die)
	Juice.sparkle(self, die.global_position, Globals.white, 10, 30.0, true)
	die.queue_free()


## Takes [param count] dice off the Fleet for good, never leaving fewer than
## one.
func _lose_dice(count: int) -> void:
	if count <= 0:
		return
	_announce_lost_dice(count)
	num_of_dice = maxi(1, num_of_dice - count)


## The player always has a die to play. Ships can take every die there is
## (a Cutpurse pockets them, a Charge Bore holds the last one), and with
## nothing in hand or on a tile the player can't fight back in a fight, or
## jump out of a scenario at all. So they're given a spare: a die the Fleet
## still owns that nobody is holding (the count never drops below one) turns
## up for real; if every die is in a ship's hands, a hologram stands in. A
## hologram doesn't count as owned and fizzles at the jump, so it can't be
## banked, and it's enough to shoot the holder down and get the dice back.
##
## Checked at the start of each turn, and once a fight is over.
func _ensure_a_die_to_play() -> void:
	if _has_a_die_to_play():
		return
	# A die still on its way somewhere (fired off a tile, being spent by a
	# ship, caught in a beam) may yet come home, so judge once it's landed.
	await _until_board_settles()
	if _jump_committed or _has_a_die_to_play():
		return
	var real: bool = num_of_dice > _real_dice_still_held()
	await spawn_dice(1, 0, not real)
	Juice.callout_at(self, global_position + dice_manager.position + Vector2(0, -14),
			tr("CALLOUT_SPARE_DIE"), Globals.white, true)


## As _ensure_a_die_to_play(), unless the player emptied the hand
## themselves: a fight they started with their last die isn't one ships left
## them nothing to fight with.
func _ensure_a_die_for_first_turn() -> void:
	if _spent_own_hand:
		return
	await _ensure_a_die_to_play()


## A fight can end with the hand empty: a ship flew off with every die. The
## survivors hand their dice home a frame after combat_finished; this was
## connected first, so it waits a frame longer to see them land.
func _ensure_a_die_after_combat() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await _until_board_settles()
	if Globals.state_manager and Globals.state_manager.state == GameStateManager.GameState.OUT_OF_COMBAT:
		await _ensure_a_die_to_play()


## A die in hand, or on a tile that will hand it back. Judged by where each
## die actually sits: a die in flight still points at the last queue it left.
func _has_a_die_to_play() -> bool:
	for node: Node in get_tree().get_nodes_in_group('Dice'):
		var die: Dice = node as Dice
		if die and not die.is_queued_for_deletion() and die.host_queue != null \
		and die.host_queue is not EnemyDiceManager and die in die.host_queue.queue:
			return true
	return false


## Returns once no die is being pulled and no chain is resolving.
func _until_board_settles() -> void:
	await TractorBeam.wait_for_landings(get_tree())
	var engine: ScenarioEngine = ScenarioEngine.current()
	if engine and engine.currently_processing_queue:
		await engine.finished_processing_queue


## Real dice the player still has somewhere, a ship's hands included. Shop
## stock and salvage on offer have no host_queue and were never theirs.
func _real_dice_still_held() -> int:
	var held: int = 0
	for node: Node in get_tree().get_nodes_in_group('Dice'):
		var die: Dice = node as Dice
		if die and not die.holographic and not die.is_queued_for_deletion() \
		and die.host_queue != null:
			held += 1
	return held


## The count drop is the part that lasts — fewer dice is a smaller hand and a
## lower jump gate for the rest of the run — so it's said out loud over the
## hand, not just shown on the dice being left behind.
func _announce_lost_dice(count: int) -> void:
	Events.play_sound.emit(_DIE_LOST_SFX)
	Events.camera_shake_small.emit()
	var text: String = "-%d DIE" % count if count == 1 else "-%d DICE" % count
	Juice.callout_at(self, global_position + dice_manager.position + Vector2(0, -14),
			text, Globals.red, true)


func _unlock_dice_after_jump() -> void:
	for die: Dice in dice_manager.queue:
		if is_instance_valid(die) and die.transit_locked:
			die.transit_locked = false
			die.draggable.dragging_allowed = true


## The dice in hand, for the save: value and whether each is holographic.
func capture_hand() -> Array:
	var hand: Array = []
	for die: Dice in dice_manager.queue:
		if is_instance_valid(die):
			hand.append({"value": die.value, "holo": die.holographic})
	return hand


## The ship is lost: nothing in hand can be played, and the turn can't be
## ended. A die mid-drag is dropped where it is rather than played, since the
## engine it would fire through has shut down.
func _stand_down() -> void:
	%EndTurnButton.disabled = true
	%EndTurnButton.update_ui()
	for die: Dice in _dice_making_the_jump():
		die.draggable.dragging_allowed = false
		if die.draggable.state == Draggable.DragState.DRAGGING:
			die.draggable.state = Draggable.DragState.MOVING_WITH_CODE


## Whether the opening hand is still coming in after an arrival.
func is_dealing_hand() -> bool:
	return _dealing_hand


## Whether a jump has been decided (commit_to_jump()) and the ship hasn't
## arrived yet.
func is_jump_committed() -> bool:
	return _jump_committed


## Whether the End Turn button would take a press right now.
func can_end_turn() -> bool:
	return not %EndTurnButton.disabled


## The player's own End Turn press, from the button or its key. With dice
## left that a tile would take, it asks first (the Game/confirm_end_turn
## option). Code ending the turn for its own reasons (the AutoPilot, the
## tutorial) calls end_turn() and is never asked.
func request_end_turn() -> void:
	if not can_end_turn():
		return
	# Checked again on confirming: the turn may have moved on while asking.
	%EndTurnConfirm.request(self, func() -> void:
		if can_end_turn():
			end_turn())


func end_turn() -> void:
	_between_turns = true
	_turn_generation_at_end = _turn_generation
	%EndTurnButton.disabled = true
	%EndTurnButton.update_ui()
	Events.player_turn_over.emit()
