extends Node2D

@export var time_to_revert: float = 10
var countdown_tween: Tween

func popup(old_fullscreen: bool, old_resolution: Vector2, old_position: Vector2) -> void:
	show()
	
	countdown_tween = get_tree().create_tween()
	countdown_tween.tween_method(
		_update_revert_text, 
		time_to_revert, 
		0, 
		time_to_revert
	).set_trans(Tween.TRANS_LINEAR)
	
	await countdown_tween.finished
	revert()
	

func _update_revert_text(time: float) -> void:
	var time_to_show: String = str(ceil(time))
	%RevertText.text = "Reverting in [color=#d03656]" + \
					time_to_show + \
					"[/color] seconds"
	

func accept() -> void:
	if countdown_tween:
		countdown_tween.kill()
		
	hide()
	
	
func revert() -> void:
	if countdown_tween:
		countdown_tween.kill()
