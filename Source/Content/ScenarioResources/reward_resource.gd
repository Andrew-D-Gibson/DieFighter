class_name RewardResource
extends Resource

@export var min_money: int = 0
@export var max_money: int = 0
## How much of min_money/max_money is credits owed back rather than loot: what
## the player paid a trader they then destroyed (Enemy.wreck_reward()). The
## payout calls it out on its own line so the player learns the rule. Set at
## runtime on a copy, never authored.
var refund: int = 0
@export var num_of_rewards: int = 3
@export_range(0.0, 1.0) var dice_probability: float = 0
## Chance the offer's last choice is a Grid Slot instead, while the grid has a
## sealed cell to open. Always offered when the grid is full, since a tile
## would have nowhere to go. Raised from 0.25: a combat usually makes one
## offer, so at a quarter players went most of a sector without seeing a slot.
@export_range(0.0, 1.0) var grid_slot_probability: float = 0.4

## The lowest rarity this offer's tiles can be. Elites and bosses raise it so
## beating them pays out in tiles a normal fight rarely shows. Rarity weighting
## still applies above the floor, and if the player already owns every tile at
## or above it, the floor is dropped rather than offering nothing.
@export var minimum_rarity: TileResource.Rarity = TileResource.Rarity.COMMON
## Offers only the flown ship's own tiles (ShipResource.signature_tiles): the
## Outrigger courier's spare parts for a pilot flying its sister ship. A ship
## with none falls back to the usual pool.
@export var ship_signature_only: bool = false

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
