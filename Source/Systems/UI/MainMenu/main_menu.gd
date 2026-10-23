extends Node2D

@export_category('Background Components')
@export var num_of_stars: int = 100
@export var num_of_twinkling_stars: int = 25
@export var background_color: Color = Globals.purple
@export var star_pixel_scene: PackedScene
@export var star_twinkle_scene: PackedScene


var _screen_size: Vector2 = Vector2(320, 180)
var _stars: Array[Node2D]

var opening_cutscene: String = "uid://b1j8blia5iw65"
var main_game_scene: String = "uid://deisauteocrjl"

var _is_loading: bool = false

const _LARGE_BUTTON: PackedScene = preload("uid://pagumreni25k")

const _MENU_TRACK: StringName = &"game_start_theme"
## Brought in by the opening cutscene on a new game.
const _RUN_TRACK: StringName = &"trailer_1"


func _ready() -> void:
	get_tree().paused = false
	# Before has_save(): a lab run points the save file somewhere else.
	ScenarioLab.end_session()
	if DevConsole.is_available():
		_add_scenario_lab_button()

	# Set up the initial state of needed components
	#%FadeIn.self_modulate = background_color
	%FadeIn.show()
	%OptionsMenu.hide()
	%ConfirmDialog.hide()
	%ConfirmDialog.confirmed.connect(_on_new_game_confirmed)

	if SaveManager.has_save():
		%ContinueButton.visible = true
		%PlayButton.set_button_text("NEW GAME")
	else:
		%ContinueButton.visible = false
		%PlayButton.set_button_text("PLAY")

	# Set up the background
	#self.self_modulate = background_color
	
	# Get rid of any pre-existing stars
	_clear_stars()

	# Create new stars
	for i in range(num_of_stars):
		_add_star(star_pixel_scene)

	for i in range(num_of_twinkling_stars):
		_add_star(star_twinkle_scene)
		
	%AnimationPlayer.play("on_application_start")
	
	SceneLoader.request(opening_cutscene)
	$VBoxContainer/QuitButton.visible = QuitManager.can_quit()

	# The menu always opens on the start theme, from the top when coming back
	# from a run.
	MusicDirector.play_track(_MENU_TRACK, 2.0, true)
	
	
func _clear_stars() -> void:
	for star: Node2D in _stars:
		star.queue_free()
	_stars = []


func _add_star(star_scene: PackedScene) -> void:
	var star: Node2D = star_scene.instantiate()
	star.z_index = -2
	add_child(star)
	star.global_position = Vector2(
		RNGManager.randf_range(RNGManager.Bucket.COSMETIC, 0, _screen_size.x),
		RNGManager.randf_range(RNGManager.Bucket.COSMETIC, 0, (_screen_size.y * 2)) - 180
	)

	# Randomize the opacity of the star to simulate brightness/distance
	star.modulate = Color(1, 1, 1, RNGManager.randf_range(RNGManager.Bucket.COSMETIC, 0.25, 0.75))
	
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
	if SaveManager.has_save():
		%ConfirmDialog.open("Starting a new game will overwrite your existing save. Continue?")
		return
	_start_new_game()


func _on_new_game_confirmed() -> void:
	SaveManager.delete_save()
	%ContinueButton.hide()
	_start_new_game()


func _start_new_game() -> void:
	SceneLoader.switch_to(get_tree(), opening_cutscene)


func _on_continue_button_pressed() -> void:
	if _is_loading:
		return
	var loaded_save: GameSaveResource = SaveManager.read_save()
	if not loaded_save:
		push_error("Failed to load save file")
		return
	Globals.pending_load_save = loaded_save
	_is_loading = true
	# Continuing skips the cutscenes that would have brought this track in.
	MusicDirector.play_track(_RUN_TRACK, 2.0)
	%LoadingPopup.show()
	# The scene change blocks the main thread while it loads, so wait until the
	# popup has actually been drawn or the player never sees it.
	await RenderingServer.frame_post_draw
	get_tree().change_scene_to_file(main_game_scene)


## Dev builds only: straight into the Scenario Lab, at the scenario tested
## last. The panel itself is on the dev console page. Built here rather than in the scene so release builds never carry it.
func _add_scenario_lab_button() -> void:
	var lab_button: Node = _LARGE_BUTTON.instantiate()
	$VBoxContainer.add_child(lab_button)
	$VBoxContainer.move_child(lab_button, $VBoxContainer/QuitButton.get_index())
	lab_button.set_button_text("LAB")
	lab_button.hover_text_color = Globals.yellow
	lab_button.pressed_within_window.connect(_on_scenario_lab_button_pressed)


func _on_scenario_lab_button_pressed() -> void:
	if _is_loading:
		return
	_is_loading = true
	MusicDirector.play_track(_RUN_TRACK, 2.0)
	%LoadingPopup.show()
	await RenderingServer.frame_post_draw
	# Asked for by name, so it's open on the console page rather than folded.
	ScenarioLabPanel.collapsed = false
	ScenarioLab.launch(ScenarioLab.index)


func _on_options_button_pressed() -> void:
	%OptionsMenu.show()
	
	
func _on_quit_button_pressed() -> void:
	QuitManager.request_quit()


func _on_wishlist_button_pressed() -> void:
	var url: String = "https://store.steampowered.com/app/3689280/Die_Fighter/"
	OS.shell_open(url)
