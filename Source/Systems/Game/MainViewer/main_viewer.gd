class_name MainViewer
extends Node2D

enum ScreenShowing {COMMS, SYSTEMS, MAP}
var screen_showing: ScreenShowing = ScreenShowing.SYSTEMS

@export_category('Components')
@export var background: AnimatedSprite2D
@export var comms: CommsManager
@export var tile_grid: TileGrid
@export var map: Map
@export var engine_charger: Node2D


@export_category('Tab Buttons')
@export var comms_button_background: AnimatedSprite2D
@export var comms_button_label: RichTextLabel

@export var systems_button_background: AnimatedSprite2D
@export var systems_button_label: RichTextLabel

@export var map_button_background: AnimatedSprite2D
@export var map_button_label: RichTextLabel


func _ready() -> void:
	Events.load_scenario.connect(_show_starting_screen)
	Events.show_comms.connect(_show_comms)
	Events.show_map.connect(_show_map)
	Events.show_systems.connect(_show_systems)
	Events.hide_comms.connect(_hide_comms)
	

func _show_starting_screen(scenario: ScenarioResource) -> void:
	match scenario.starting_screen:
		ScreenShowing.COMMS:
			_show_comms()
		ScreenShowing.SYSTEMS:
			_show_systems()
		ScreenShowing.MAP:
			_show_map()
	
	
func _show_comms() -> void:
	background.frame = 0
	screen_showing = ScreenShowing.COMMS
	
	comms_button_label.add_theme_color_override('default_color', Globals.white)
	comms_button_label.text = 'COMMS'
	
	comms.visible = true
	comms.update_speaker()
	engine_charger.visible = false
	tile_grid.visible = false
	map.visible = false
	
	
	
func _comms_hovered(is_hovered: bool) -> void:
	if is_hovered and screen_showing != ScreenShowing.COMMS:
		comms_button_label.add_theme_color_override('default_color', Globals.orange)
		comms_button_label.text = '[wave amp=8.0 freq=5.0 connected=1]COMMS[/wave]'
		#comms_button_background.frame = 1
	else:
		comms_button_label.add_theme_color_override('default_color', Globals.white)
		comms_button_label.text = 'COMMS'
		#comms_button_background.frame = 0


func _show_systems() -> void:
	background.frame = 1
	screen_showing = ScreenShowing.SYSTEMS
	
	systems_button_label.add_theme_color_override('default_color', Globals.white)
	systems_button_label.text = 'SYSTEMS'
	
	comms.visible = false
	engine_charger.visible = true
	tile_grid.visible = true
	map.visible = false
	
	
func _systems_hovered(is_hovered: bool) -> void:
	if is_hovered and screen_showing != ScreenShowing.SYSTEMS:
		systems_button_label.add_theme_color_override('default_color', Globals.green)
		systems_button_label.text = '[wave amp=8.0 freq=5.0 connected=1]SYSTEMS[/wave]'
		#systems_button_background.frame = 1
	else:
		systems_button_label.add_theme_color_override('default_color', Globals.white)
		systems_button_label.text = 'SYSTEMS'
		#systems_button_background.frame = 0
	
	
func _show_map() -> void:
	background.frame = 2
	screen_showing = ScreenShowing.MAP
	
	map_button_label.add_theme_color_override('default_color', Globals.white)
	map_button_label.text = 'MAP'
	
	comms.visible = false
	engine_charger.visible = true
	tile_grid.visible = false
	map.visible = true
	

func _map_hovered(is_hovered: bool) -> void:
	if is_hovered and screen_showing != ScreenShowing.MAP:
		map_button_label.add_theme_color_override('default_color', Globals.purple)
		map_button_label.text = '[wave amp=8.0 freq=5.0 connected=1]MAP[/wave]'
		#map_button_background.frame = 1
	else:
		map_button_label.add_theme_color_override('default_color', Globals.white)
		map_button_label.text = 'MAP'
		#map_button_background.frame = 0
		
		
func _hide_comms() -> void:
	if screen_showing == ScreenShowing.COMMS:
		_show_systems()
