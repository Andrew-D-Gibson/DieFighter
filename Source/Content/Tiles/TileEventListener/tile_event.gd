class_name TileEvent
extends Resource

## Values are stored as raw ints in .tres files — append new ones, never insert.
enum EventType {
	ON_TURN_START,
	ON_TILE_PUSHED,
	ON_TILE_MANUALLY_MOVED,
	## Every enemy has finished acting. The hook for tiles that brace rather
	## than attack — they pay out after you've seen what the turn did to you.
	ON_ENEMY_TURN_OVER,
	## The player's hull (not shields) just took damage. The hook for
	## retaliation: getting hit stops being purely something that happens to you.
	ON_PLAYER_HEALTH_HIT,
	## An enemy siphoned engine charge. The hook for punishing the one verb
	## that attacks the player's ability to leave rather than their hull.
	ON_ENGINE_CHARGE_DRAINED,
	## A tile directly above, below, left or right of this one activated. The
	## hook for tiles that profit from sitting beside a busy machine.
	ON_ADJACENT_TILE_ACTIVATED,
	## A tile in any of the eight cells around this one activated, diagonals
	## included. The wider net, for tiles that should catch every hop of a
	## chain winding past them.
	ON_SURROUNDING_TILE_ACTIVATED,
	## The player gained shields, from any source. The hook for tiles that
	## turn bracing into pressure.
	ON_PLAYER_SHIELDS_GAINED,
	## This tile's countdown (TileResource.countdown) just reached 0. The
	## countdown tile's payout. Fired once per time it runs out, straight after
	## the count that did it (TileCountdown).
	ON_COUNTDOWN_ZERO,
	ON_COMBAT_START,              # placeholder, owned by tiles/ramp-status
	ON_STATUS_APPLIED_TO_ENEMY,   # placeholder, owned by tiles/ramp-status
	## An enemy's damage was aimed at the player: once per hit, whether the
	## shields or the hull take it (ion damage included). A hit that misses
	## (Phased) never reached the player and doesn't count. The response's
	## context carries the attacker as trigger_ship (TARGET_TRIGGERING_SHIP).
	ON_PLAYER_ATTACKED,
	## The player just took a killing blow. Answering it is a death save: the
	## tile holds the hull at 1 on the spot, then its chain plays and should
	## spend the tile (Tile._on_player_fatal_damage).
	ON_PLAYER_FATAL_DAMAGE = 100,
}

@export var event: EventType
@export var listen_only_for_self: bool = true
