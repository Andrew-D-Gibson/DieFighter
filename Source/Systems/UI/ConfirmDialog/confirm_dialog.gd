class_name ConfirmDialog
extends Node2D

signal confirmed()
signal cancelled()


func open(message: String) -> void:
	%MessageLabel.text = message
	show()


func _on_confirm_button_pressed() -> void:
	hide()
	confirmed.emit()


func _on_cancel_button_pressed() -> void:
	hide()
	cancelled.emit()
