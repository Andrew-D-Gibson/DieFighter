class_name Player
extends Node2D

const _HEALTH_HIT_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/player_health_hit.tres")
const _SHIELDS_HIT_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/player_shields_hit.tres")
const _DICE_REROLL_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/dice_reroll_blip.tres")
const _DIE_LOST_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/die_dread_thunk.tres")

## Marks a die this script locked for the length of a jump, so arrival only
## unlocks what the jump locked and leaves a tutorial's own locks alone.
const _TRANSIT_LOCK_META: StringName = &"_transit_locked"

@export var _time_between_die_spawns: float = 0.2
@export var _dice_queue_spacing: int = 14

## Redline headroom as a fraction of max_engine_charge. Safe to open now that
## ChangeEngineChargeEvent clamps at max unless a change explicitly opts in,
## so only ADD_OVERCHARGE can reach the band.
const _OVERCHARGE_CAP_FRACTION: float = 0.5

## Hull paid per turn ended in the redline, as a divisor of the overcharge:
## +10 past the gate costs 5 a turn. Pushing deeper costs more, which is what
## makes the band a burst resource rather than a bank.
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

var money: int:
	set(value):
		money = value
		Events.set_money.emit(money)


## Where effects aimed at the player are drawn. The ship has no sprite of its
## own on screen; its health bar is the thing the player watches.
func get_juice_anchor() -> Vector2:
	var bar: Node2D = get_node_or_null("PlayerHealthBar") as Node2D
	return bar.global_position if bar else global_position


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
	health.death.connect(Events.game_over.emit)
	health.health_damaged.connect(Events.player_health_hit.emit)
	health.shields_damaged.connect(Events.player_shields_hit.emit)
	health.shields_broken.connect(Events.player_shields_broken.emit)
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
	
	
	dice_manager.die_added.connect(func() -> void:
		_update_dice_queue_locations()
		_make_newest_die_draggable()
		_reset_newest_die_transform()
	)
	dice_manager.die_removed.connect(_update_dice_queue_locations)
	
	Events.tile_activation_complete.connect(_check_for_end_of_turn)
	
	Events.jump.connect(_carry_dice_through_jump)
	
	%EndTurnButton.disabled = true
	%EndTurnButton.update_ui()
	
	Events.start_scenario.connect(_start_scenario)
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
	event.amount = maxi(1, over / _REDLINE_HULL_DIVISOR)
	event.actor = self
	event.effect_source = self
	event.targets = [self]
	engine.queue_event(event)

	Events.camera_shake_small.emit()


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
		
		
func _reset_newest_die_transform() -> void:
	if dice_manager.queue[-1].draggable.state != Draggable.DragState.DRAGGING:
		dice_manager.queue[-1].scale = Vector2(1,1)
		dice_manager.queue[-1].rotation_degrees = 0
	

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


func _check_for_end_of_turn() -> void:
	if len(dice_manager.queue) == 0:
		%EndTurnButton.disabled = false
		%EndTurnButton.update_ui()
		%EndTurnButton.soft_highlight()
	else:
		%EndTurnButton.disabled = true
		%EndTurnButton.update_ui()


func reroll_dice() -> void:
	for die: Dice in dice_manager.queue:
		if die:
			die.reroll_with_tween()
			Events.play_sound.emit(_DICE_REROLL_SFX)		
			await get_tree().create_timer(0.2).timeout
	
	Events.highlight_dice_area.emit()
	

func _start_player_turn() -> void:
	# Wait for any dice to get back to the dice queue before rerolling them
	await get_tree().create_timer(0.5).timeout
	await reroll_dice()

	Events.player_turn_refresh.emit()
	Events.player_turn_start.emit()
	
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

	if not restoring:
		health.shields = 0
	await get_tree().create_timer(_time_between_die_spawns).timeout

	if restoring:
		await _restore_saved_hand()
	else:
		await _arrive_with_hand()
	_unlock_dice_after_jump()


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
		else:
			_stow_die_for_jump(die)

	if stranded > 0:
		_announce_lost_dice(stranded)
		num_of_dice = maxi(1, num_of_dice - stranded)


## Brings a die home to the hand and holds it there until arrival. Nothing
## may be played mid-jump: the scenario engine a tile would fire through has
## already been shut down.
func _stow_die_for_jump(die: Dice) -> void:
	if die.host_queue != dice_manager:
		dice_manager.add(die, true, false)
	die.draggable.state = Draggable.DragState.DEFAULT
	die.scale = Vector2.ONE
	die.rotation = 0.0
	if die.draggable.dragging_allowed:
		die.draggable.dragging_allowed = false
		die.set_meta(_TRANSIT_LOCK_META, true)


## The die stays with the ship that's holding it, and is seen to: it rides
## that ship off the bottom of the screen as the player jumps away, and is
## freed with it. Pulled out of every queue and the Dice group first, so
## nothing can hand it back — a ship freed mid-jump never gives its dice away,
## but a combat_finished arriving late would.
func _strand_die(die: Dice, holder: Enemy) -> void:
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
		if is_instance_valid(die) and die.has_meta(_TRANSIT_LOCK_META):
			die.remove_meta(_TRANSIT_LOCK_META)
			die.draggable.dragging_allowed = true


## The dice in hand, for the save: value and whether each is holographic.
func capture_hand() -> Array:
	var hand: Array = []
	for die: Dice in dice_manager.queue:
		if is_instance_valid(die):
			hand.append({"value": die.value, "holo": die.holographic})
	return hand


func end_turn() -> void:
	%EndTurnButton.disabled = true
	%EndTurnButton.update_ui()
	Events.player_turn_over.emit()
