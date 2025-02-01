class_name IntentIndicator
extends Node2D

@export var intent_sprites: Array[Sprite2D]

func update_intent_indicators(turn_actions: Array[EnemyActionResource]) -> void:
	for i in range(6):
		intent_sprites[i].texture = turn_actions[i].intent_indicator
