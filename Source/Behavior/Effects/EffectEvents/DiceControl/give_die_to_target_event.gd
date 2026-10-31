class_name GiveDieToTargetEvent
extends EffectEvent


func resolve(_engine: ScenarioEngine) -> void:
	if not is_instance_valid(activator_die):
		return

	activator_die.draggable.state = Draggable.DragState.ENEMY_HOLDING

	# No valid target — return to the player with the face unchanged.
	if targets.is_empty() or not is_instance_valid(targets[0]):
		if is_instance_valid(Globals.player):
			Globals.player.dice_manager.add(activator_die)
		return

	var target: Node = targets[0]

	# The target was destroyed before the die reached it (usually by this
	# very shot): the die goes wherever the wreck's own dice went, leaving
	# with them. Deciding that here, by any rule of its own, sent the killing
	# shot somewhere the rest of the hold didn't go (a civilian about to hand
	# it straight back).
	if target.health.health <= 0:
		if target is Enemy and activator_die is Dice:
			(target as Enemy).dice_manager.pass_on_after_death(activator_die as Dice)
		elif is_instance_valid(Globals.player):
			Globals.player.dice_manager.add(activator_die)
		return

	_hand_to(target)


## Queues the die with the target straight away, so game state is settled before
## the next event. When an enemy is the one receiving it, the tractor beam then
## plays the trip there without holding up the chain; an enemy action can also
## target the player, who just takes the die back normally.
func _hand_to(target: Node) -> void:
	target.dice_manager.add(activator_die)
	if target is Enemy:
		TractorBeam.pull(activator_die, target)
