class_name MainViewer
extends Node2D

enum ScreenShowing {SYSTEMS, MAP}
var screen_showing: ScreenShowing = ScreenShowing.SYSTEMS

@export_category('Components')
@export var background: AnimatedSprite2D
@export var tile_grid: TileGrid
@export var map: Map

@export_category('Tab Buttons')
@export var systems_button_label: RichTextLabel
@export var map_button_label: RichTextLabel


func _ready() -> void:
	%SystemsRevealOverlay.show()
	%SystemsRevealOverlay.material.set_shader_parameter("progress", 0.0)
	%MapRevealOverlay.show()
	%MapRevealOverlay.material.set_shader_parameter("progress", 0.0)
	
	Events.start_scenario.connect(func() -> void:
		_check_for_engine_charge()
		_show_systems()
	)
	Events.engine_charge_changed.connect(_check_for_engine_charge)
	Events.start_combat.connect(func() -> void:
		map_button_label.add_theme_color_override('default_color', Globals.white)
		map_button_label.text = 'MAP'	
	)
	Events.combat_finished.connect(func() -> void:
		map_button_label.add_theme_color_override('default_color', Globals.medium_purple)
		map_button_label.text = '[wave amp=6.0 freq=5.0 connected=1]MAP[/wave]'
	)
	Events.show_map.connect(_show_map)
	Events.show_systems.connect(_show_systems)
	
	Events.systems_startup.connect(_systems_startup)
	Events.map_startup.connect(_map_startup)


func _show_systems() -> void:
	background.frame = 0
	screen_showing = ScreenShowing.SYSTEMS
	
	systems_button_label.add_theme_color_override('default_color', Globals.white)
	systems_button_label.text = 'SYSTEMS'

	tile_grid.visible = true
	map.visible = false
	
	Events.systems_shown.emit()
	
	
func _systems_hovered(is_hovered: bool) -> void:
	if is_hovered and screen_showing != ScreenShowing.SYSTEMS:
		systems_button_label.add_theme_color_override('default_color', Globals.green)
		systems_button_label.text = '[wave amp=8.0 freq=5.0 connected=1]SYSTEMS[/wave]'

	else:
		systems_button_label.add_theme_color_override('default_color', Globals.white)
		systems_button_label.text = 'SYSTEMS'

	
	
func _show_map() -> void:
	background.frame = 2
	screen_showing = ScreenShowing.MAP
	
	map_button_label.add_theme_color_override('default_color', Globals.white)
	map_button_label.text = 'MAP'

	tile_grid.visible = false
	map.visible = true
	
	Events.map_shown.emit()
	

func _map_hovered(is_hovered: bool) -> void:
	if is_hovered and screen_showing != ScreenShowing.MAP:
		map_button_label.add_theme_color_override('default_color', Globals.purple)
		map_button_label.text = '[wave amp=8.0 freq=5.0 connected=1]MAP[/wave]'

	else:
		map_button_label.add_theme_color_override('default_color', Globals.white)
		map_button_label.text = 'MAP'


func _check_for_engine_charge() -> void:
	if Globals.player.engine_charge >= Globals.player.max_engine_charge:
		map_button_label.add_theme_color_override('default_color', Globals.medium_purple)
		map_button_label.text = '[wave amp=6.0 freq=5.0 connected=1]MAP[/wave]'
		
		
func _systems_startup() -> void:
	_show_systems()
	_systems_reveal_tween()
	
		
func _map_startup() -> void:
	_check_for_engine_charge()
	_map_reveal_tween()
	
	
func _systems_reveal_tween() -> void:
	var reveal_tween: Tween = get_tree().create_tween()
	var reveal_time: float = 3
	var max_progress: int = 54
	
	reveal_tween.tween_property(
		%SystemsRevealOverlay, 
		"material:shader_parameter/progress", 
		max_progress, 
		reveal_time
	).from(0)

	await reveal_tween.finished
	%SystemsRevealOverlay.hide()
	
	
func _map_reveal_tween() -> void:
	var reveal_tween: Tween = get_tree().create_tween()
	var reveal_time: float = 3
	var max_progress: int = 60
	
	reveal_tween.tween_property(
		%MapRevealOverlay, 
		"material:shader_parameter/progress", 
		max_progress, 
		reveal_time
	).from(25)

	await reveal_tween.finished
	%MapRevealOverlay.hide()
