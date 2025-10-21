class_name BackgroundManager
extends Sprite2D

@export var starting_background: Resource

@export_category("Managed Scenes")
@export var nebula_scene: PackedScene
@export var star_pixel_scene: PackedScene
@export var star_twinkle_scene: PackedScene
@export var debris_scene: PackedScene

var screen_size: Vector2 = Vector2(320, 180)

var stars: Array[Node2D]
var debris: Array[Node2D]
var static_objects: Array[Node2D]

## Static RNG instance for choosing backgrounds from the random list
static var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	Globals.background_manager = self
	_clear_children()
	
	if starting_background:
		_set_background(starting_background)
	
	Events.load_scenario.connect(func(scenario: ScenarioResource) -> void:
		seed(scenario.seed)
		_set_background(scenario.background_resource)
	)
	Events.set_background.connect(_set_background)
	
	
func _process(delta: float) -> void:
	for star in stars:
		star.global_position.y += delta * 3
		
		if star.global_position.y > screen_size.y + 5:
			star.global_position.y = -5
			star.global_position.x = randf_range(0, screen_size.x)
			
	for piece in debris:
		piece.global_position.y += delta * (5 + piece.velocity_delta)
		
		if piece.global_position.y > screen_size.y + piece.texture.get_height():
			piece.pick_random_texture()
			piece.pick_random_velocity_delta()
			piece.global_position.y = -5 - piece.texture.get_height()
			piece.global_position.x = randf_range(0, screen_size.x)
	
	
func _clear_children() -> void:
	stars = []
	debris = []
	static_objects = []
	
	var children = get_children()
	for i in range(len(children)-1, -1, -1):
		children[i].queue_free()
	
	
## Seeds the rng at the start of the scenario
## (Called by the enemy manager)
static func seed(seed_value: int) -> void:
	rng.seed = seed_value
	
	
func _set_background(background_resource: Resource) -> void:
	_clear_children()
	
	# Handle RandomBackgroundResource
	if background_resource.has_method("get_random_background"):
		var selected_bg = background_resource.get_random_background(rng)
		if selected_bg:
			_set_background(selected_bg)
		return
	
	# Handle regular BackgroundResource
	if not background_resource is BackgroundResource:
		push_error("BackgroundManager: Invalid background resource type!")
		return
	
	var bg_resource = background_resource as BackgroundResource
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
	var nebula = nebula_scene.instantiate()
	var nebula_color_vec4 = Vector4(
		nebula_color.r,
		nebula_color.g,
		nebula_color.b,
		nebula_color.a
	)
	nebula.material.set_shader_parameter('nebula_color',nebula_color_vec4)
	add_child(nebula)


func _set_stars(num_of_stars: int, num_of_twinkling_stars: int) -> void:
	for i in range(num_of_stars):
		var star = star_pixel_scene.instantiate()
		add_child(star)
		star.global_position = Vector2(
			randf_range(0, screen_size.x),
			randf_range(0, screen_size.y)
		)
		
		# Randomize the opacity of the star to simulate distance
		star.modulate = Color(1, 1, 1, randf_range(0.25, 0.75))
		
		stars.append(star)
		
		
	for i in range(num_of_twinkling_stars):
		var star = star_twinkle_scene.instantiate()
		add_child(star)
		star.global_position = Vector2(
			randf_range(0, screen_size.x),
			randf_range(0, screen_size.y)
		)
		
		# Randomize the opacity of the star to simulate distance
		star.modulate = Color(1, 1, 1, randf_range(0.25, 0.75))
		
		stars.append(star)
		

func _set_debris(num_of_med_pieces: int, num_of_large_pieces: int, background_color: Color) -> void:
	for i in range(num_of_med_pieces + num_of_large_pieces):
		var piece = debris_scene.instantiate()
		piece.is_medium = (i < num_of_med_pieces)
		piece.randomize()
		piece.background_color = background_color
		add_child(piece)
		piece.global_position = Vector2(
			randf_range(0, screen_size.x),
			randf_range(-50, screen_size.y)
		)
		
		debris.append(piece)


func _set_static_objects(static_object_data: Array[StaticBackgroundObjectResource]) -> void:
	for object_data in static_object_data:
		if object_data.scene:
			var static_object = object_data.scene.instantiate()
			add_child(static_object)
			
			# Set position, scale, rotation, and modulate
			static_object.global_position = object_data.position
			static_object.scale = object_data.scale
			static_object.rotation = object_data.rotation
			static_object.modulate = object_data.modulate
			
			static_objects.append(static_object)
	
