class_name MoneyParticle
extends Node2D


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

var textures: Dictionary[money_amount, Texture2D] = {
	money_amount.SMALL: preload("uid://dhmcum1v58y5h"),
	money_amount.LARGE: preload("uid://b41a3gdbfjgrk")
}

var collision_radius: Dictionary[money_amount, int] = {
	money_amount.SMALL: 3,
	money_amount.LARGE: 6
}


func _ready() -> void:
	_set_up_particle()
	_set_up_float()
	
	
func _process(delta: float) -> void:
	_current_time += delta
	if _current_time > _time_to_float:
		if _floating:
			_floating = false
			
			var tween_time: float = 1
			var tween: Tween = get_tree().create_tween()
			tween.tween_property(
				self, 
				"global_position", 
				Globals.money_indicator.global_position, 
				tween_time
			).set_trans(Tween.TRANS_SPRING)\
			.set_ease(Tween.EASE_IN)
		
		return
		
	position += _current_float_velocity * delta
	
	# Get t as a fraction of time passed (clamped between 0 and 1)
	var t = clamp(_current_time / _time_to_float, 0.0, 1.0)
	
	# Decay the velocity
	_current_float_velocity = _starting_float_velocity.lerp(Vector2.ZERO, t)

	
func _set_up_particle() -> void:
	$Sprite2D.texture = textures[amount]
	$Area2D/CollisionShape2D.shape.radius = collision_radius[amount]
	

func _set_up_float() -> void:
	_time_to_float = randf_range(
		min_time_to_float,
		max_time_to_float
	)
	
	var vel_magnitude: float = randf_range(
		min_float_velocity, 
		max_float_velocity
	)
	
	_starting_float_velocity = (vel_magnitude * Vector2(1, 1)).rotated(
		randf_range(0, 2*PI)
	)


func _on_area_2d_area_entered(area: Area2D) -> void:
	if area.get_parent() == Globals.money_indicator:
		Globals.player.money += amount
		
		queue_free()
