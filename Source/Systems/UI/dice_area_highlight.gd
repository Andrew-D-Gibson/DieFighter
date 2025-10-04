extends Sprite2D

func _ready() -> void:
	hide()
	Events.player_turn_start.connect(show)
	
	Events.die_placed_on_tile.connect(func() -> void:
		if len(Globals.player.dice_manager.queue) <= 0:
			hide()
	)
	
	# Just to be sure that it does hide, this is here for redundancy
	Events.player_turn_over.connect(hide)
