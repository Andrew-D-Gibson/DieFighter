class_name BackgroundManager
extends Sprite2D

@export var starting_background: RandomBackgroundResource
@export var jump_animation_time: float = 5

@export_category("Parallax System")
@export var global_speed: float = 16
@export var parallax_levels: Array[float] = [0.1, 0.2, 0.3, 0.7, 1.0]  # Speed multipliers for each parallax level

@export_category("Managed Scenes")
@export var nebula_scene: PackedScene
@export var star_pixel_scene: PackedScene
@export var star_twinkle_scene: PackedScene
@export var debris_scene: PackedScene

var screen_size: Vector2 = Vector2(320, 180)

var stars: Array[Node2D]
var debris: Array[Node2D]
var static_objects: Array[Node2D]
var nebula: Node2D

## Current background name for modifier system
var current_background_name: String = ""

## Static RNG instance for choosing backgrounds from the random list
static var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	Globals.background_manager = self
	_clear_children()
	
	if starting_background:
		_set_background(starting_background)
	
	Events.load_scenario.connect(func(scenario: ScenarioResource) -> void:
		seed(scenario.scenario_seed)
		_set_background(scenario.background_resource)
	)
	Events.set_background.connect(_set_background)
	
	
func _process(delta: float) -> void:
	_update_objects_motion(stars, delta, 3.0, 0, 5, _wrap_star_position)
	_update_objects_motion(debris, delta, 1.0, 2, 0, _wrap_debris_position, _get_debris_base_speed)
	_update_objects_motion(static_objects, delta, 2.0, 0, 50, _wrap_static_object_position, null, true)
	_update_nebula_speed()


## Generic motion update for objects with parallax
func _update_objects_motion(
	objects: Array[Node2D], 
	delta: float, 
	speed_multiplier: float, 
	default_parallax: int,
	wrap_offset: float,
	wrap_callback: Callable,
	base_speed_callback: Variant = null,
	skip_if_zero: bool = false
) -> void:
	for obj: Node2D in objects:
		var parallax_level: int = obj.get_meta("parallax_level", default_parallax)
		
		if skip_if_zero and parallax_level == 0:
			continue
		
		var base_speed: float = base_speed_callback.call(obj) if base_speed_callback is Callable else 0.0
		var speed: float = (global_speed * get_parallax_speed(parallax_level) * speed_multiplier) + base_speed
		obj.global_position.y += delta * speed
		
		if obj.global_position.y > screen_size.y + wrap_offset:
			wrap_callback.call(obj)


func _wrap_star_position(star: Node2D) -> void:
	star.global_position.y = -5
	star.global_position.x = randf_range(0, screen_size.x)


func _wrap_debris_position(piece: Node2D) -> void:
	piece.pick_random_texture()
	piece.pick_random_velocity_delta()
	piece.global_position.y = -5 - piece.texture.get_height()
	piece.global_position.x = randf_range(0, screen_size.x)


func _wrap_static_object_position(obj: Node2D) -> void:
	obj.global_position.y = -50
	obj.global_position.x = randf_range(0, screen_size.x)


func _get_debris_base_speed(piece: Node2D) -> float:
	return 2.0 + piece.velocity_delta


func _update_nebula_speed() -> void:
	if not nebula or not nebula.material:
		return
	
	var parallax_level: int = nebula.get_meta("parallax_level", 1)
	var speed_multiplier: float = global_speed * get_parallax_speed(parallax_level)
	var base_speed: float = -0.005
	nebula.speed = base_speed * speed_multiplier


## Get the speed multiplier for a given parallax level
func get_parallax_speed(level: int) -> float:
	if level < 0 or level >= parallax_levels.size():
		return 1.0
	return parallax_levels[level]


## Set the global speed and update all objects
func set_global_speed(new_speed: float) -> void:
	global_speed = new_speed
	_update_nebula_speed()
	if nebula and nebula.material:
		var parallax_level: int = nebula.get_meta("parallax_level", 1)
		var speed_multiplier: float = global_speed * get_parallax_speed(parallax_level)
		var base_speed: Vector2 = Vector2(0, -0.01)
		nebula.material.set_shader_parameter("speed", base_speed * speed_multiplier)
	
	
func _clear_children() -> void:
	stars = []
	debris = []
	static_objects = []
	nebula = null
	
	var children: Array[Node] = get_children()
	for i: int in range(len(children)-1, -1, -1):
		if children[i] is not Control:
			children[i].queue_free()
	
	
## Seeds the rng at the start of the scenario
## (Called by the enemy manager)
static func seed(seed_value: int) -> void:
	rng.seed = seed_value
	
	
func _set_background(background_resource: Resource) -> void:
	_clear_children()
	
	if background_resource.has_method("get_random_background"):
		var selected_bg: Resource = background_resource.get_random_background(rng)
		if selected_bg:
			_set_background(selected_bg)
		return
	
	if not background_resource is BackgroundResource:
		push_error("BackgroundManager: Invalid background resource type!")
		return
	
	var bg_resource: BackgroundResource = background_resource as BackgroundResource
	current_background_name = _determine_background_name(bg_resource)
	self.self_modulate = bg_resource.background_color
	
	if bg_resource.nebula:
		_set_nebula(bg_resource.nebula_color)
	if bg_resource.stars:
		_set_stars(bg_resource.num_of_stars, bg_resource.num_of_twinkling_stars)
	if bg_resource.debris:
		_set_debris(bg_resource.num_of_med_pieces, bg_resource.num_of_large_pieces, bg_resource.background_color)
	if bg_resource.static_objects.size() > 0:
		_set_static_objects(bg_resource.static_objects)


func _set_nebula(nebula_color: Color) -> void:
	nebula = nebula_scene.instantiate()
	nebula.material.set_shader_parameter('nebula_color', Vector4(nebula_color.r, nebula_color.g, nebula_color.b, nebula_color.a))
	nebula.set_meta("parallax_level", 1)
	add_child(nebula)


func _set_stars(num_of_stars: int, num_of_twinkling_stars: int) -> void:
	_create_stars(star_pixel_scene, num_of_stars)
	_create_stars(star_twinkle_scene, num_of_twinkling_stars)


func _create_stars(star_scene: PackedScene, count: int) -> void:
	for i: int in range(count):
		var star: Node2D = star_scene.instantiate()
		add_child(star)
		star.global_position = _random_screen_position()
		star.modulate = Color(1, 1, 1, randf_range(0.25, 0.75))
		star.set_meta("parallax_level", 0)
		stars.append(star)


func _random_screen_position() -> Vector2:
	return Vector2(randf_range(0, screen_size.x), randf_range(0, screen_size.y))
		

func _set_debris(num_of_med_pieces: int, num_of_large_pieces: int, background_color: Color) -> void:
	for i: int in range(num_of_med_pieces + num_of_large_pieces):
		var piece: Node2D = debris_scene.instantiate()
		piece.is_medium = (i < num_of_med_pieces)
		piece.randomize()
		piece.background_color = background_color
		piece.set_meta("parallax_level", 2 if piece.is_medium else 1)
		piece.global_position = Vector2(randf_range(0, screen_size.x), randf_range(-50, screen_size.y))
		add_child(piece)
		debris.append(piece)


func _set_static_objects(static_object_data: Array[StaticBackgroundObjectResource]) -> void:
	for object_data: StaticBackgroundObjectResource in static_object_data:
		if not object_data.scene:
			continue
		
		var static_object: Node2D = object_data.scene.instantiate()
		static_object.global_position = object_data.position
		static_object.scale = object_data.scale
		static_object.rotation = object_data.rotation
		static_object.modulate = object_data.modulate
		static_object.set_meta("parallax_level", object_data.get_parallax_level() if object_data.has_method("get_parallax_level") else 0)
		add_child(static_object)
		static_objects.append(static_object)
			
			
func make_static_objects_movable() -> void:
	for static_object: Node2D in static_objects:
		if static_object.get_meta("parallax_level") == 0:
			static_object.set_meta("parallax_level", 1)
	

func play_jump_intro() -> void:
	# Set up timings
	var speed_ramp_up_time: float = 4

	# Speed up the background object speed by half
	await tween_speed(320, speed_ramp_up_time/2)
	
	# Start fading in particles
	%JumpTransition.set_background_transparency(0)
	%JumpTransition.set_particles_transparency(0)
	%JumpTransition.show()
	%JumpTransition.tween_particles(1.0, speed_ramp_up_time/2)
	
	# Finish speeding up background objects
	await tween_speed(480, speed_ramp_up_time/2)
	
	# Punch in the jump background
	%JumpTransition.tween_background(1.0, 0.5)
	
	# Shake the camera
	Events.camera_shake_large.emit(false)
	
	
func play_jump_outro() -> void:
	var speed_ramp_down_time: float = 1
	
	# Drop the jump background
	%JumpTransition.set_background_transparency(0)
	
	# Quickly slow down and fade the particles
	%JumpTransition.tween_particles(0, speed_ramp_down_time)
	await tween_speed(16, speed_ramp_down_time)
	%JumpTransition.hide()


## Determine background name based on background resource properties
func _determine_background_name(bg_resource: BackgroundResource) -> String:
	# Simple heuristic to determine background type
	if bg_resource.nebula:
		return "nebula"
	elif bg_resource.stars and bg_resource.num_of_stars > 10:
		return "starfield"
	elif bg_resource.debris and bg_resource.num_of_large_pieces > 5:
		return "debris_field"
	elif bg_resource.static_objects.size() > 0:
		return "complex"
	else:
		return "empty_space"
	
	
func tween_speed(final_speed: int, time: float) -> void:
	var speed_tween: Tween = get_tree().create_tween()
	speed_tween.tween_property(
		self,
		"global_speed",
		final_speed,
		time
	)
	await speed_tween.finished
