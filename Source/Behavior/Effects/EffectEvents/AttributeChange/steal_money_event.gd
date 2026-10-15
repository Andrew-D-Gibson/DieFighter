class_name StealMoneyEvent
extends EffectEvent
## The actor takes [member amount] credits from the player, or everything they
## have if that's less. The balance drops at once (so a checkpoint never sees
## credits still in flight) and the coins stream from the money counter to the
## thief, the payout a destroyed ship makes run backwards.

const _MONEY_PARTICLE_SCENE: PackedScene = preload("res://Source/Systems/Game/MoneyParticles/money_particle.tscn")

## What was actually taken, once resolved.
var taken: int = 0


## A toll is a price; an Amplifier shouldn't make it steeper.
func is_amplifiable() -> bool:
	return false


func resolve(_engine: ScenarioEngine) -> void:
	if not is_instance_valid(Globals.player) or amount <= 0:
		return

	taken = mini(amount, Globals.player.money)
	if taken <= 0:
		return
	Globals.player.money -= taken

	var thief: Node2D = actor as Node2D if is_instance_valid(actor) else null
	if thief == null:
		return
	# Parented to the RewardManager like a payout's coins, so they outlive the
	# chain and the ship that triggered them.
	var parent: Node = Globals.reward_manager if is_instance_valid(Globals.reward_manager) \
		else thief.get_parent()
	MoneyParticle.spawn_loss(parent, thief, taken, _MONEY_PARTICLE_SCENE)
