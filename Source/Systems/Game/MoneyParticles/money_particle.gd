class_name MoneyParticle
extends Node2D

const _MONEY_TICK_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/money_tick.tres")


enum money_amount {
	SMALL = 1,
	LARGE = 5
}
@export var amount: money_amount = money_amount.SMALL:
	set(new_amount):
		amount = new_amount
		_set_up_particle()

var _time_to_float: float
@export var min_time_to_float: float = 0.75
@export var max_time_to_float: float = 2
var _current_time: float = 0

var _starting_float_velocity: Vector2
var _current_float_velocity: Vector2
@export var min_float_velocity: float
@export var max_float_velocity: float

var _floating: bool = true

## A credit that's leaving the player flies to _destination and is gone,
## rather than flying to the money counter and paying out.
var _leaving: bool = false
var _destination: Node2D = null

var textures: Dictionary[money_amount, Texture2D] = {
	money_amount.SMALL: preload("uid://dhmcum1v58y5h"),
	money_amount.LARGE: preload("uid://b41a3gdbfjgrk")
}

var collision_radius: Dictionary[money_amount, int] = {
	money_amount.SMALL: 3,
	money_amount.LARGE: 6
}

var _money_added_particle_scene: PackedScene = preload("uid://cf7c6vnmskqff")


## Pays out [param credits] as floating particles at [param global_pos],
## parented to [param parent]. Large denominations first, then small change.
##
## Every payout in the game routes through here so credits look the same
## wherever they came from — a destroyed ship's drop, a salvage pickup — and
## so the "how many coins is this worth" arithmetic lives in exactly one place.
##
## The scene is passed in rather than preloaded: this script is attached to
## that scene, and preloading it here would be a cyclic dependency.
static func spawn_payout(
	parent: Node, global_pos: Vector2, credits: int, particle_scene: PackedScene
) -> void:
	if credits <= 0 or particle_scene == null or not is_instance_valid(parent):
		return

	for particle_amount: money_amount in _denominations(credits):
		var particle: MoneyParticle = particle_scene.instantiate()
		particle.amount = particle_amount

		parent.add_child(particle)
		particle.global_position = global_pos
		if is_instance_valid(Globals.money_indicator):
			Globals.money_indicator.track_coin(particle)


## The reverse of [method spawn_payout]: [param total] credits burst off the
## money counter and fly to [param destination]. Purely a picture of the loss,
## so the caller takes the credits off the balance itself; a coin that never
## lands (the scenario ends mid-flight) has already been paid.
static func spawn_loss(
	parent: Node, destination: Node2D, total: int, particle_scene: PackedScene
) -> void:
	if total <= 0 or particle_scene == null or not is_instance_valid(parent) \
	or not is_instance_valid(Globals.money_indicator):
		return

	for particle_amount: money_amount in _denominations(total):
		var particle: MoneyParticle = particle_scene.instantiate()
		particle.amount = particle_amount
		particle._leaving = true
		particle._destination = destination
		parent.add_child(particle)
		particle.global_position = Globals.money_indicator.coin_target()
		Globals.money_indicator.track_coin(particle)


## Whether this coin is on its way to the player's balance, rather than
## flying off with credits already taken from it.
func is_payout() -> bool:
	return not _leaving


## Large coins first, then small change.
static func _denominations(total: int) -> Array[money_amount]:
	var coins: Array[money_amount] = []
	for i: int in range(floori(float(total) / money_amount.LARGE)):
		coins.append(money_amount.LARGE)
	for i: int in range(total % money_amount.LARGE):
		coins.append(money_amount.SMALL)
	return coins


func _ready() -> void:
	_set_up_particle()
	_set_up_float()
	
	
func _process(delta: float) -> void:
	_current_time += delta
	if _current_time > _time_to_float:
		if _floating:
			_floating = false
			if _leaving:
				_fly_away()
				return
			
			var tween_time: float = 0.75
			var tween: Tween = get_tree().create_tween()
			# The readout's resting place: the console may still be dropping
			# in, and its catch area arrives there to meet the coin.
			tween.tween_property(
				self, 
				"global_position", 
				Globals.money_indicator.coin_target(), 
				tween_time
			).set_trans(Tween.TRANS_QUART)\
			.set_ease(Tween.EASE_IN)
		
		return
		
	position += _current_float_velocity * delta
	
	# Get t as a fraction of time passed (clamped between 0 and 1)
	var t: float = clampf(_current_time / _time_to_float, 0.0, 1.0)
	
	# Decay the velocity
	_current_float_velocity = _starting_float_velocity.lerp(Vector2.ZERO, t)

	
## A lost credit heads for whoever took it and winks out on arrival. If they're
## already gone it just fades where it is.
func _fly_away() -> void:
	var tween: Tween = get_tree().create_tween()
	if is_instance_valid(_destination):
		tween.tween_property(
			self, "global_position", _destination.global_position, 0.75
		).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
		tween.tween_callback(func() -> void: Events.play_sound.emit(_MONEY_TICK_SFX))
	else:
		tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)


func _set_up_particle() -> void:
	$Sprite2D.texture = textures[amount]
	$Area2D/CollisionShape2D.shape.radius = collision_radius[amount]
	

func _set_up_float() -> void:
	_time_to_float = RNGManager.randf_range(
		RNGManager.Bucket.COSMETIC, min_time_to_float, max_time_to_float
	)

	var vel_magnitude: float = RNGManager.randf_range(
		RNGManager.Bucket.COSMETIC, min_float_velocity, max_float_velocity
	)

	_starting_float_velocity = (vel_magnitude * Vector2(1, 1)).rotated(
		RNGManager.randf_range(RNGManager.Bucket.COSMETIC, 0, 2*PI)
	)


func _on_area_2d_area_entered(area: Area2D) -> void:
	# A lost credit starts on top of the counter; it mustn't pay itself back.
	if _leaving:
		return
	if area.get_parent() == Globals.money_indicator:
		Globals.player.money += amount
		
		var particles: CPUParticles2D = _money_added_particle_scene.instantiate()
		particles.global_position = global_position
		add_sibling(particles)
		
		Events.play_sound.emit(_MONEY_TICK_SFX)
		
		queue_free()
