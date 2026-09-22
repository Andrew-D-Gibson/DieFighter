class_name Player
extends Node2D

const _HEALTH_HIT_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/player_health_hit.tres")
const _SHIELDS_HIT_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/player_shields_hit.tres")
const _DICE_REROLL_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/dice_reroll_blip.tres")

@export var _time_between_die_spawns: float = 0.2
@export var _dice_queue_spacing: int = 14

## Redline headroom as a fraction of max_engine_charge. Held at 0 until the
## overcharge effects exist: without the ADD_OVERCHARGE clamp in
## ChangeEngineChargeEvent, any headroom here would let the ordinary Engine
## Charger tile spill past max and redline the player by accident.
const _OVERCHARGE_CAP_FRACTION: float = 0.0

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
		num_of_dice = new_num
		
		max_engine_charge = (6*(num_of_dice-1)) - floor(1.7078 * sqrt(num_of_dice))
		overcharge_cap = roundi(max_engine_charge * _OVERCHARGE_CAP_FRACTION)

		# The ceiling just moved. Re-run the charge setter so a shrinking
		# ceiling re-clamps rather than leaving charge stranded above it.
		engine_charge = engine_charge

		Events.die_added.emit()
		
		
@export var dice_scene: PackedScene

@onready var tile_activation_queue: Array[Tile] = []
@onready var tile_currently_activating: bool = false


var money: int:
	set(value):
		money = value
		Events.set_money.emit(money)


func _ready() -> void:
	Globals.player = self
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
	
	Events.jump.connect(_delete_existing_dice)
	
	%EndTurnButton.disabled = true
	%EndTurnButton.update_ui()
	
	Events.start_scenario.connect(_start_scenario)
	Events.enemy_turn_over.connect(_start_player_turn)
	Events.load_game_save.connect(_load_game_save)
	
	money = 0
			
			
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
	health.shields = 0
	_delete_existing_dice()
	await get_tree().create_timer(_time_between_die_spawns).timeout
	spawn_dice()


func end_turn() -> void:
	%EndTurnButton.disabled = true
	%EndTurnButton.update_ui()
	Events.player_turn_over.emit()
