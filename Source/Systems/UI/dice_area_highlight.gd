extends Sprite2D

func _ready() -> void:
	show()
	
	Events.player_turn_start.connect(show)
	Events.player_turn_over.connect(hide)
