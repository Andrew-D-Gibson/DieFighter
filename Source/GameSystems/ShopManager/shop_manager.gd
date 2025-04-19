class_name ShopManager
extends Node2D

func _ready() -> void:
	Events.open_shop.connect(_open_shop)
	Events.close_shop.connect(_close_shop)
	
	
func _open_shop() -> void:
	pass
	
	
func _close_shop() -> void:
	pass
