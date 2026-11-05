extends Node2D

@export_category('Background Components')
@export var num_of_stars: int = 100
@export var num_of_twinkling_stars: int = 25
@export var star_pixel_scene: PackedScene
@export var star_twinkle_scene: PackedScene

## Where the stars go: one screen wide and two tall, so the camera's pan on
## application start has sky the whole way.
const _STAR_AREA: Rect2 = Rect2(0, -180, 320, 360)

var opening_cutscene: String = "uid://b1j8blia5iw65"
var main_game_scene: String = "uid://deisauteocrjl"

var _is_loading: bool = false
## Whether the new game being launched is the tutorial run. Only handed to
## Globals once the game actually starts, so backing out of the overwrite
## check leaves nothing queued.
var _launching_tutorial: bool = false

const _MENU_TRACK: StringName = &"game_start_theme"
## Brought in by the opening cutscene on a new game.
const _RUN_TRACK: StringName = &"trailer_1"


func _ready() -> void:
	get_tree().paused = false
	# Before has_save(): a lab run (started from the dev console) points the
	# save file somewhere else.
	ScenarioLab.end_session()

	%FadeIn.show()
	%OptionsMenu.hide()
	%ConfirmDialog.hide()
	%ConfirmDialog.confirmed.connect(_on_new_game_confirmed)
	%ShipSelectPopup.launched.connect(_on_ship_launched)
	%ShipSelectPopup.tutorial_launched.connect(_on_tutorial_launched)
	# Erase Progress can take the save away while the menu is up.
	%OptionsMenu.progress_changed.connect(_refresh_play_buttons)
	_refresh_play_buttons()

	StarScatter.scatter(self, star_pixel_scene, num_of_stars, _STAR_AREA)
	StarScatter.scatter(self, star_twinkle_scene, num_of_twinkling_stars, _STAR_AREA)

	%AnimationPlayer.play("on_application_start")
	# A new scene is drawn once before its AnimationPlayer first processes,
	# which flashed the finished menu ahead of the fade. Pose the first frame
	# now instead.
	%AnimationPlayer.advance(0.0)
	
	SceneLoader.request(opening_cutscene)
	$VBoxContainer/QuitButton.visible = QuitManager.can_quit()

	# Whatever is playing carries on into the menu. Only silence (a run's
	# playlist ran out, say) is filled with the start theme.
	if MusicDirector.current_track_id() == &"":
		MusicDirector.play_track(_MENU_TRACK, 2.0)
	
	
func _refresh_play_buttons() -> void:
	if SaveManager.has_save():
		%ContinueButton.visible = true
		%PlayButton.set_button_text("MENU_NEW_GAME")
	else:
		%ContinueButton.visible = false
		%PlayButton.set_button_text("MENU_PLAY")


func _input(event: InputEvent) -> void:
	# Handle skipping the intro animation
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed \
		and %AnimationPlayer.get_current_animation() == "on_application_start":
			%AnimationPlayer.stop()
			%FadeIn.visible = false
			%Camera2D.offset.y = 90


## A new run starts by picking its ship. The save is only put at risk once
## one is picked, so backing out of the picker loses nothing. A player who
## hasn't played the tutorial yet goes straight into it instead: a ship
## picker means nothing before they know what a ship does.
func _on_play_button_pressed() -> void:
	if not Globals.tutorial_completed:
		_on_tutorial_launched(ShipCatalog.find(ShipCatalog.DEFAULT_ID))
		return
	%ShipSelectPopup.open()


func _on_tutorial_launched(ship: ShipResource) -> void:
	_launch(ship, true)


func _on_ship_launched(ship: ShipResource) -> void:
	_launch(ship, false)


func _launch(ship: ShipResource, as_tutorial: bool) -> void:
	Globals.selected_ship = ship
	_launching_tutorial = as_tutorial
	if SaveManager.has_save():
		%ConfirmDialog.open(tr("MENU_OVERWRITE_SAVE"), true)
		return
	_start_new_game()


func _on_new_game_confirmed() -> void:
	SaveManager.delete_save()
	%ContinueButton.hide()
	_start_new_game()


func _start_new_game() -> void:
	Globals.tutorial_requested = _launching_tutorial
	SceneLoader.switch_to(get_tree(), opening_cutscene)


func _on_continue_button_pressed() -> void:
	if _is_loading:
		return
	var loaded_save: GameSaveResource = SaveManager.read_save()
	if not loaded_save:
		push_error("Failed to load save file")
		return
	Globals.pending_load_save = loaded_save
	# The game scene shapes its grid from the ship before it reads the save.
	Globals.selected_ship = ShipCatalog.find(loaded_save.ship_id)
	_is_loading = true
	# Continuing skips the cutscenes that would have brought this track in.
	MusicDirector.play_track(_RUN_TRACK, 2.0)
	%LoadingPopup.show()
	# The scene change blocks the main thread while it loads, so wait until the
	# popup has actually been drawn or the player never sees it.
	await RenderingServer.frame_post_draw
	get_tree().change_scene_to_file(main_game_scene)


func _on_codex_button_pressed() -> void:
	%CodexPopup.open()


func _on_options_button_pressed() -> void:
	%OptionsMenu.show()
	
	
func _on_quit_button_pressed() -> void:
	QuitManager.request_quit()


func _on_wishlist_button_pressed() -> void:
	Utils.open_wishlist()
