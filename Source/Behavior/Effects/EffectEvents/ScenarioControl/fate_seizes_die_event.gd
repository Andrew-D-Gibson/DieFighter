class_name FateSeizesDieEvent
extends EffectEvent
## An Undertow echo grabs the best die in the player's hand before they can
## place it (Plunder, LORE.md §7). It's the ship's to spend on its turn, like
## any die the player hands over.


func is_amplifiable() -> bool:
	return false


func resolve(_engine: ScenarioEngine) -> void:
	if not is_instance_valid(Globals.player) or not Globals.enemy_manager:
		return
	var thieves: Array[Enemy] = []
	# No Fate throw touches "You" (FateSelf).
	for ship: Enemy in FateSelf.by_chance(Globals.enemy_manager.get_alive_enemies()):
		if is_instance_valid(ship) and ship.is_hostile():
			thieves.append(ship)
	if thieves.is_empty():
		return

	var best: Dice = null
	for die: Dice in Globals.player.dice_manager.queue:
		if is_instance_valid(die) and not die.holographic and (best == null or die.value > best.value):
			best = die
	if best == null:
		return

	var thief: Enemy = RNGManager.pick_random(RNGManager.Bucket.ENEMY_AI, thieves)
	best.draggable.state = Draggable.DragState.ENEMY_HOLDING
	thief.dice_manager.add(best)
	TractorBeam.pull(best, thief)
	Juice.callout(thief, TranslationServer.translate("FATE_CALLOUT_SEIZED"), Globals.red)
