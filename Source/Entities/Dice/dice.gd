class_name Dice
extends Node2D

@export_category('Components')
@export var draggable: Draggable

@export_category('Graphics')
# This array must have 7 values, a blank then 1-6
@export var value_textures: Array[Texture2D]

var value: int = 0:
	set(new_value):
		value = new_value
		$Sprite2D.texture = value_textures[value]
		
var host_queue: DiceQueue



func _ready() -> void:
	if value == 0:
		value = randi_range(1,6)
		
	draggable.drag_ended.connect(_check_for_acceptor)
	

func _check_for_acceptor(_draggable: Draggable, end_position: Vector2) -> void:
	var dice_acceptors = get_tree().get_nodes_in_group('CanAcceptDice')

	for acceptor in dice_acceptors:
		if not acceptor.is_currently_accepting:
			continue

		var bounding_rect: Rect2 = Rect2(acceptor.global_position, Vector2(acceptor.width, acceptor.height))
		if bounding_rect.has_point(end_position):
			var acceptor_node = acceptor.get_parent()
			
			if acceptor_node is Tile:
				acceptor_node.try_to_activate(self)
				
			elif acceptor_node is DiceReceptacle:
				acceptor_node.dice_queue.add(self, true)


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
