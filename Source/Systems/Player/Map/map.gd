class_name Map
extends Node2D

@export var map_viewport: SubViewport
@export var encounter_spacing: int = 14
@export var encounter_list: Array[EncounterResource]
@export var current_encounter_index: int

@export_category('Map Textures')
@export var current_encounter_icon: Texture2D
@export var timeline_icon: Texture2D
@export var connector_sprite: Texture2D


func _ready() -> void:
	_create_encounter_sprites()
	
	
func _create_encounter_sprites() -> void:
	for i in range(len(encounter_list)):
		# Create a timeline bar to the next location
		if i < len(encounter_list) - 1:
			var timeline_bar_sprite = Sprite2D.new()
			timeline_bar_sprite.texture = timeline_icon
			timeline_bar_sprite.position = Vector2((i * encounter_spacing) + 7, 0)
			map_viewport.add_child(timeline_bar_sprite)
			
			
		# Add the sprite for this encounter
		var encounter_sprite: Sprite2D = Sprite2D.new()
		encounter_sprite.position = Vector2(i * encounter_spacing, 0)
		map_viewport.add_child(encounter_sprite)
		
		# Mark the encounter as either our present location or 
		# a possible destination with a map icon
		if current_encounter_index == i:
			encounter_sprite.texture = current_encounter_icon
		else:
			encounter_sprite.texture = encounter_list[i].map_icon
			
			# Offset the icon up or down
			encounter_sprite.position += Vector2(0, -13 if i%2==0 else 13)
		
			# Add the connector sprite
			# Add the timeline connector sprite
			var timeline_connector_sprite: Sprite2D = Sprite2D.new()
			timeline_connector_sprite.position = Vector2(i * encounter_spacing, -4 if i%2==0 else 4)
			timeline_connector_sprite.texture = connector_sprite
			map_viewport.add_child(timeline_connector_sprite)
