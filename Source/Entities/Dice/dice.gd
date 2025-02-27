class_name Dice
extends Node2D

@export_category('Components')
@export var draggable: Draggable

@export_category('Graphics')
# This array must have 7 values, a blank then 1-6
@export var value_textures: Array[Texture2D]

var value: int = 0:
	set(new_value):
		value = 3 #new_value
		$Sprite2D.texture = value_textures[value]
		

func _ready() -> void:
	if value == 0:
		value = randi_range(1,6)
		
	draggable.drag_ended.connect(_check_for_tile_activation)
	

func _check_for_tile_activation(_draggable: Draggable, end_position: Vector2) -> void:
	var tile = _get_overlapping_tile(end_position)
	if tile:
		tile.try_to_activate(self)
	
	
func _get_overlapping_tile(drag_end_pos: Vector2) -> Tile:
	var tiles = get_tree().get_nodes_in_group('Tiles')
	for tile in tiles:
		var tile_top_left_corner = tile.global_position - Vector2(16,16)
		var bounding_rect: Rect2 = Rect2(tile_top_left_corner, Vector2(32, 32))
		if bounding_rect.has_point(drag_end_pos):
			return tile
			
	return null


func reroll_with_tween() -> void:
	var tween_time = 0.2
		
	var tween = get_tree().create_tween().set_parallel()
	tween.tween_property(self, 'rotation_degrees', 180, tween_time).from(0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, 'global_position', global_position + Vector2(0,-8), tween_time).set_trans(Tween.TRANS_SINE)
	
	tween.chain().tween_callback(func():
		value = randi_range(1,6)
	)
	tween.tween_property(self, 'rotation_degrees', 180, tween_time).from(0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, 'global_position', global_position, tween_time).set_trans(Tween.TRANS_SINE)
	
	
	await tween.finished
