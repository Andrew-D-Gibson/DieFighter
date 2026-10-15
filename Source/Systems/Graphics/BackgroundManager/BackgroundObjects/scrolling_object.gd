class_name ScrollingObject
extends Sprite2D
## One piece of a ScrollingObjectsResource drifting past the cockpit. Each time
## it wraps back to the top it rerolls its look and depth.

@export var min_velocity_delta: float = 2.0

var objects: ScrollingObjectsResource
var is_medium: bool = true
var velocity_delta: float = 0


func setup(new_objects: ScrollingObjectsResource, medium: bool, background_color: Color) -> void:
	objects = new_objects
	is_medium = medium
	material.set_shader_parameter("background_color", background_color)
	material.set_shader_parameter("color", objects.silhouette_color)
	material.set_shader_parameter("keep_texture_colors", objects.keep_texture_colors)
	material.set_shader_parameter("base_visibility", objects.base_visibility)
	material.set_shader_parameter("visibility_per_depth", objects.visibility_per_depth)
	reroll()


func reroll() -> void:
	pick_random_texture()
	pick_random_velocity_delta()


func pick_random_texture() -> void:
	var textures: Array[Texture2D] = objects.medium_textures if is_medium else objects.large_textures
	texture = RNGManager.pick_random(RNGManager.Bucket.BACKGROUND, textures)

	if objects.random_quarter_turns:
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
