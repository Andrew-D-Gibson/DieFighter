class_name RewardResource
extends Resource

@export var min_money: int = 0
@export var max_money: int = 0
@export var num_of_rewards: int = 3
@export_range(0.0, 1.0) var dice_probability: float = 0

## The lowest rarity this offer's tiles can be. Elites and bosses raise it so
## beating them pays out in tiles a normal fight rarely shows. Rarity weighting
## still applies above the floor, and if the player already owns every tile at
## or above it, the floor is dropped rather than offering nothing.
@export var minimum_rarity: TileResource.Rarity = TileResource.Rarity.COMMON

## When max_money_pickup is above zero the offer also floats a MoneyPickup
## worth a roll in this range, sitting alongside the tile/dice choices.
##
## This is money the player has to *choose* instead of a tile, which is a
## different thing from min_money/max_money above — that pays out on its own
## the moment the reward appears, no decision attached.
@export var min_money_pickup: int = 0
@export var max_money_pickup: int = 0
## Chance the money pickup above shows up at all. Below 1.0 it becomes an
## occasional alternative, so some offers tempt the player to pass on a tile
## and others don't.
@export_range(0.0, 1.0) var money_pickup_probability: float = 1.0
