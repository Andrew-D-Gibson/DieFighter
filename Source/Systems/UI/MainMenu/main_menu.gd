extends Sprite2D

@export_category('Background Components')
@export var num_of_stars: int = 100
@export var num_of_twinkling_stars: int = 25
@export var background_color: Color = Globals.purple
@export var star_pixel_scene: PackedScene
@export var star_twinkle_scene: PackedScene


var _screen_size: Vector2 = Vector2(320, 180)
var _stars: Array[Node2D]

var opening_cutscene: String = "uid://b1j8blia5iw65"


func _ready() -> void:
	get_tree().paused = false
	
	# Set up the initial state of needed components
	%FadeIn.self_modulate = background_color
	%FadeIn.show()
	%OptionsMenu.hide()
	
	# Set up the background
	self.self_modulate = background_color
	
	# Get rid of any pre-existing stars
	_clear_stars()

	# Create new stars 
	seed('Die Fighter'.hash())
	for i in range(num_of_stars):
		_add_star(star_pixel_scene)

	for i in range(num_of_twinkling_stars):
		_add_star(star_twinkle_scene)
		
		
	%AnimationPlayer.play("on_application_start")
	
	ResourceLoader.load_threaded_request(opening_cutscene)
	
	
func _clear_stars() -> void:
	for star in _stars:
		star.queue_free()
	_stars = []


func _add_star(star_scene: PackedScene) -> void:
	var star = star_scene.instantiate()
	add_child(star)
	star.global_position = Vector2(
		randf_range(0, _screen_size.x),
		randf_range(0, (_screen_size.y * 2)) - 180
	)

	# Randomize the opacity of the star to simulate brightness/distance
	star.modulate = Color(1, 1, 1, randf_range(0.25, 0.75))
	
	_stars.append(star)


func _input(event: InputEvent) -> void:
	# Handle skipping the intro animation
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed \
		and %AnimationPlayer.get_current_animation() == "on_application_start":
			%AnimationPlayer.stop()
			%FadeIn.visible = false
			%Camera2D.offset.y = 90


func _on_play_button_pressed() -> void:
	#get_tree().change_scene_to_file(main_game_file)
	var status := ResourceLoader.load_threaded_get_status(opening_cutscene)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		var resource := ResourceLoader.load_threaded_get(opening_cutscene)
		if resource is PackedScene:
			get_tree().change_scene_to_packed(resource)

	elif status == ResourceLoader.THREAD_LOAD_FAILED:
		push_error("Failed to load opening cutscene")

	

func _on_options_button_pressed() -> void:
	%OptionsMenu.show()
	
	
func _on_quit_button_pressed() -> void:
	get_tree().quit()


func _on_wishlist_button_pressed() -> void:
	var url: String = "https://store.steampowered.com/app/3689280/Die_Fighter/"
	OS.shell_open(url)
