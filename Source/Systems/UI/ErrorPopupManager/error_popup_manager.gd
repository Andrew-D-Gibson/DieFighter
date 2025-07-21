class_name ErrorPopupManager
extends Node

@export var error_text_popup_scene: PackedScene

var _current_popups: Array[ErrorTextPopup]

func _ready() -> void:
	Events.error_text_popup.connect(_create_error_popup)
	
	
func _create_error_popup(text: String, global_pos: Vector2) -> void:
	_clear_current_popups()
	
	var error_text: ErrorTextPopup = error_text_popup_scene.instantiate()
	add_child(error_text)
	error_text.text = text
	error_text.global_position = global_pos + Vector2(-error_text.size.x / 2, -error_text.size.y)
			
	_current_popups.append(error_text)


func _clear_current_popups() -> void:
	for i in range(len(_current_popups)-1, -1, -1):
		if _current_popups[i]:
			_current_popups[i].queue_free()
	
	_current_popups = []
