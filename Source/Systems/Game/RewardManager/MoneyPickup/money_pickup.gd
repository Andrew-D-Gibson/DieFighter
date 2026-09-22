class_name MoneyPickup
extends Node2D

## A claimable pile of credits floating in a reward offer, alongside the tile
## and dice choices. Dragging it out of the offer banks its value, the same
## way dragging a tile out installs that tile on the grid.
##
## Authored through RewardResource.min_money_pickup / max_money_pickup — a
## reward with a pickup gives the player something to weigh a tile against,
## which is what makes a "take the money and we stay friendly" encounter work.

@export_category('Components')
@export var draggable: Draggable
@export var amount_label: RichTextLabel

## The floating credit particles claiming this pickup pays out as.
@export var money_particle_scene: PackedScene

## How many credits claiming this pickup is worth.
@export var amount: int = 0:
	set(new_amount):
		amount = new_amount
		_update_label()


func _ready() -> void:
	_update_label()


## Banks this pickup's value. The credits are paid out as the same floating
## particles a destroyed ship drops, so they fly to the money indicator and
## tick up there rather than silently appearing on the counter.
##
## The particles are parented to the RewardManager, not to this node: Reward
## frees the whole offer the moment something is taken, which would take
## freshly spawned children down with it before they ever reached the counter.
func claim() -> void:
	var particle_parent: Node = Globals.reward_manager
	if not is_instance_valid(particle_parent):
		particle_parent = get_parent()

	MoneyParticle.spawn_payout(
		particle_parent, global_position, amount, money_particle_scene
	)


func _update_label() -> void:
	if not is_instance_valid(amount_label):
		return

	amount_label.text = "[center]%d[/center]" % amount
