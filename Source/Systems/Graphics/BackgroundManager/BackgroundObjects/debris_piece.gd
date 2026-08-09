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
		texture = RNGManager.pick_random(RNGManager.Bucket.BACKGROUND, medium_piece_textures)
	else:
		texture = RNGManager.pick_random(RNGManager.Bucket.BACKGROUND, large_piece_textures)

	rotation_degrees = RNGManager.pick_random(RNGManager.Bucket.BACKGROUND, [0, 90, 180, 270])


func pick_random_velocity_delta() -> void:
	var velocity_level: int

	if is_medium:
		velocity_level = RNGManager.randi_range(RNGManager.Bucket.BACKGROUND, 2, 4)
	else:
		velocity_level = RNGManager.randi_range(RNGManager.Bucket.BACKGROUND, 1, 2)
		
	velocity_delta = velocity_level * min_velocity_delta
	
	material.set_shader_parameter("velocity_level", velocity_level)
	z_index = 3 + velocity_level
