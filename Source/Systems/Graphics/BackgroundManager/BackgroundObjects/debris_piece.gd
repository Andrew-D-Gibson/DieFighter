extends Sprite2D

@export var min_velocity_delta: float = 2.0
@export var medium_piece_textures: Array[Texture2D]
@export var large_piece_textures: Array[Texture2D]

var is_medium: bool = true
var velocity_delta: float = 0
var background_color: Color:
	set(new_color):
		background_color = new_color
		material.set_shader_parameter("background_color", background_color)
		
		
func randomize() -> void:
	pick_random_texture()
	pick_random_velocity_delta()
		
		
func pick_random_texture() -> void:
	if is_medium:
		texture = medium_piece_textures.pick_random()
	else:
		texture = large_piece_textures.pick_random()
		
	rotation_degrees = Array([0, 90, 180, 270]).pick_random()


func pick_random_velocity_delta() -> void:
	var velocity_level: int 
	
	if is_medium:
		velocity_level = randi_range(1,3)
	else:
		velocity_level = randi_range(0,2)
		
	velocity_delta = velocity_level * min_velocity_delta
	
	material.set_shader_parameter("velocity_level", velocity_level)
	z_index = 3 + velocity_level
