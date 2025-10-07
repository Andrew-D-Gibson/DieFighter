extends Sprite2D

func _ready() -> void:
	hide()
	Events.highlight_dice_area.connect(show)
	
	Events.die_placed_on_tile.connect(func(_die: Dice, _tile: Tile) -> void:
		if len(Globals.player.dice_manager.queue) <= 0:
			hide()
	)
	
	# Just to be sure that it does hide, this is here for redundancy
	Events.player_turn_over.connect(hide)
