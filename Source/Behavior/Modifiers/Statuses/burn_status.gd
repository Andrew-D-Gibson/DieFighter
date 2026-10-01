class_name BurnStatus
extends StatusModifier
## Each round, before the ship acts, it takes damage equal to its Burn, then
## the Burn drops by one. Five Burn is 5 + 4 + 3 + 2 + 1 over five rounds.


func _init() -> void:
	status_id = &"burn"
	display_name = "Burn"
	title_color = "orange"
	icon = preload("res://Assets/Textures/Statuses/burn.png")
	info_icon = preload("res://Assets/Textures/Statuses/burn_info.png")
	is_temporary = false


func on_status_tick() -> void:
	var ship: Node2D = host()
	if ship == null or _host_engine == null:
		return

	# The player lit it, so it is the player's damage: hitting a neutral ship
	# with it angers that ship like any other attack. No tile is the source,
	# so it never cashes in Exposed or a tile's Amplifier.
	var event: DamageEvent = DamageEvent.new()
	event.actor = Globals.player
	event.amount = stacks
	event.targets = [ship]
	_host_engine.queue_event(event)

	consume(1)
