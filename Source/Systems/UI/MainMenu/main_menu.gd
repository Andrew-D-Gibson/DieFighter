extends Sprite2D

@export var num_of_stars: int = 100
@export var num_of_twinkling_stars: int = 25
@export var background_color: Color = Globals.purple

@export_category('Managed Scenes')
@export var star_pixel_scene: PackedScene
@export var star_twinkle_scene: PackedScene

@export_category('Components')
@export var fade_in_sprite: Sprite2D
@export var camera: Camera2D
@export var animation_player: AnimationPlayer

var screen_size: Vector2 = Vector2(320, 180)

var stars: Array[Node2D]


func _ready() -> void:
	self.self_modulate = background_color
	fade_in_sprite.self_modulate = background_color
	fade_in_sprite.visible = true
	
	# Create the stars by randomly populating the set number
	seed('Die Fighter'.hash())
	for i in range(num_of_stars):
		_add_star(star_pixel_scene)

	for i in range(num_of_twinkling_stars):
		_add_star(star_twinkle_scene)
	

func _add_star(star_scene: PackedScene) -> void:
	var star = star_scene.instantiate()
	add_child(star)
	star.global_position = Vector2(
		randf_range(0, screen_size.x),
		randf_range(0, screen_size.y * 2)
	)

	# Randomize the opacity of the star to simulate brightness/distance
	star.modulate = Color(1, 1, 1, randf_range(0.25, 0.75))

	stars.append(star)


func _input(event: InputEvent) -> void:
	# Handle skipping the intro animation
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed \
		and animation_player.get_current_animation() == animation_player.get_autoplay():
			animation_player.stop()
			fade_in_sprite.visible = false
			camera.offset.y = 270
