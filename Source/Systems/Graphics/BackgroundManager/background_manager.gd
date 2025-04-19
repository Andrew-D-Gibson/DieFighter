class_name BackgroundManager
extends Sprite2D

@export var starting_background: BackgroundResource

@export_category("Managed Scenes")
@export var nebula_scene: PackedScene
@export var star_pixel_scene: PackedScene
@export var star_twinkle_scene: PackedScene
var screen_size: Vector2 = Vector2(320, 180)

var stars: Array[Node2D]


func _ready() -> void:
	Globals.background_manager = self
	_clear_children()
	
	if starting_background:
		_set_background(starting_background)
	
	Events.set_background.connect(_set_background)
	
	
func _process(delta: float) -> void:
	for star in stars:
		star.global_position.y += delta * 3
		
		if star.global_position.y > screen_size.y + 5:
			star.global_position.y = -5
			star.global_position.x = randf_range(0, screen_size.x)
	
	
func _clear_children() -> void:
	stars = []
	
	var children = get_children()
	for i in range(len(children)-1, -1, -1):
		children[i].queue_free()
	
	
	
func _set_background(background_resource: BackgroundResource) -> void:
	_clear_children()

	self.self_modulate = background_resource.background_color
	
	if background_resource.nebula:
		_set_nebula(background_resource.nebula_color)
		
	if background_resource.stars:
		_set_stars(background_resource.num_of_stars, background_resource.num_of_twinkling_stars)


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
		
