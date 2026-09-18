class_name KeepDieWithActorEvent
extends EffectEvent
## Returns the activator die to the actor's own queue instead of handing it back.
##
## EnemyActionEvent pulls the die out of the enemy's queue before the chain runs,
## so an action that simply omits GIVE_DIE_TO_PLAYER would orphan the die in open
## space. This puts it back — the enemy is now holding a die it will get to spend
## again next turn, which is the whole point of the verb.


func resolve(_engine: ScenarioEngine) -> void:
	if not is_instance_valid(activator_die):
		return

	# Nobody left to hold it — the player gets it back rather than losing it.
	var holder: DiceQueue = null
	if is_instance_valid(actor):
		holder = actor.get("dice_manager") as DiceQueue

	if holder == null:
		if is_instance_valid(Globals.player):
			Globals.player.dice_manager.add(activator_die)
		return

	holder.add(activator_die)
