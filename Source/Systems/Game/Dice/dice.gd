class_name Dice
extends Node2D

@export var holographic: bool = false
@export var holographic_shader: ShaderMaterial

@export_category('Components')
@export var draggable: Draggable

@export_category('Graphics')
# This array must have 7 values, a blank then 1-6
@export var value_textures: Array[Texture2D]
@export var holographic_textures: Array[Texture2D]

var value: int = 0:
	set(new_value):
		value = new_value
		
		if holographic:
			$Sprite2D.texture = holographic_textures[value]
			var mat: ShaderMaterial = holographic_shader.duplicate()
			mat.set_shader_parameter("seed", randi() % 1000 / 100.0)
			$Sprite2D.material = mat
		else:
			$Sprite2D.texture = value_textures[value]
		
var host_queue: DiceQueue



func _ready() -> void:
	if value == 0:
		value = randi_range(1,6)
		
	draggable.drag_ended.connect(_check_for_acceptor)
	

func _check_for_acceptor(_draggable: Draggable, end_position: Vector2) -> void:
	var dice_acceptors = get_tree().get_nodes_in_group('CanAcceptDice')
	for acceptor in dice_acceptors:
		acceptor.check_die_drop(self, end_position)


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


func _on_tree_exiting() -> void:
	if host_queue:
		host_queue.remove(self)
