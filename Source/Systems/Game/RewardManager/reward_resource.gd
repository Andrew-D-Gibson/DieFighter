class_name RewardResource
extends Resource

@export var min_money: int = 0
@export var max_money: int = 0
@export var num_of_rewards: int = 3
@export_range(0.0, 1.0) var dice_probability: float = 0

## When max_money_pickup is above zero the offer also floats a MoneyPickup
## worth a roll in this range, sitting alongside the tile/dice choices.
##
## This is money the player has to *choose* instead of a tile, which is a
## different thing from min_money/max_money above — that pays out on its own
## the moment the reward appears, no decision attached.
@export var min_money_pickup: int = 0
@export var max_money_pickup: int = 0
