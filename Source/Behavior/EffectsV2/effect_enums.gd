## EffectEnums
## Centralised enum definitions for the data-driven effect system.
##
## Every EffectData resource has a 'category' (which class of thing it does)
## and a 'subtype' (the specific variant within that category).
##
## HOW TO ADD A NEW EFFECT TYPE:
##   1. Decide which Category it belongs to (or add a new one).
##   2. Add a value to that category's subtype enum.
##   3. Implement a corresponding EffectHandler subclass.
##   4. Register it in EffectRegistry._ready().

class_name EffectEnums
extends RefCounted


# ── Top-Level Categories ───────────────────────────────────────────────────────
## Which broad class of operation does this EffectData represent?

enum Category {
	TARGETING,        ## Set or clear context.targets
	ATTRIBUTE_CHANGE, ## Damage, heal, shield, engine charge
	AMOUNT_MODIFIER,  ## Modify the amount before an attribute change
	DICE_CONTROL,     ## Change die values, reroll, ownership, holographic
	AUDIO_VISUAL,     ## Particles, tweens, sounds, wait
	TILE_CONTROL,     ## Activate, move, lock, status, data, uses
	SCENARIO_CONTROL, ## Open shop, close shop, jump, flee
	CONDITIONAL,      ## Branch execution based on a condition
	REPETITION,       ## Modify how many times the chain repeats
	UTILITY,          ## Debug print, destroy source, misc
}


# ── Targeting Subtypes ─────────────────────────────────────────────────────────
enum TargetingSubtype {
	TARGET_ENEMIES,                	## All living enemies
	TARGET_PLAYER,                 	## The player ship
	TARGET_RANDOM_ENEMY,           	## One random living enemy
	TARGET_ALL_SHIPS,              	## Player + all living enemies
	TARGET_ALL_OTHER_SHIPS,        	## All ships except the actor
	TARGET_RANDOM_SHIP,            	## One random ship (player or enemy)
	TARGET_RANDOM_TILE,            	## One random tile on the grid
	TARGET_SURROUNDING_TILES,      	## Tiles adjacent to the effect source tile
	TARGET_WITH_TARGETING_COMPUTER,	## Uses the player's targeting computer selection
	TARGET_TILE_WITH_OFFSET,		## Targets a tile that is offset from the source tile
	TARGET_EFFECT_SOURCE,          	## The tile or entity that owns this chain
	TARGET_SELF,                   	## The actor itself (e.g. enemy targets itself)
}


# ── Attribute Change Subtypes ──────────────────────────────────────────────────
enum AttributeChangeSubtype {
	DAMAGE,               ## Deal damage to targets (creates DamageEvent)
	HEAL,                 ## Restore HP to targets (creates HealEvent)
	SHIELD,               ## Grant shields to targets (creates ShieldEvent)
	CHANGE_ENGINE_CHARGE, ## Change the player's engine charge by an amount
}


# ── Amount Modifier Subtypes ───────────────────────────────────────────────────
## These push an AmountModifierEvent that modifies the next ATTRIBUTE_CHANGE
## amount in the same chain. Alternatively, represent these as Modifier objects
## if they are persistent upgrades rather than one-shot chain effects.
enum AmountModifierSubtype {
	MULTIPLY,             ## Multiply amount by a float multiplier
	ADD_ADJACENT_TILES,   ## Add count of adjacent tiles of a type to amount
	ADD_TILE_DATA,        ## Add a tile's stored data value to amount
	NEGATE,               ## Negate the amount (multiply by -1)
	SET_TO_ENGINE_CHARGE, ## Replace amount with current engine charge value
}


# ── Dice Control Subtypes ──────────────────────────────────────────────────────
enum DiceControlSubtype {
	CHANGE_ACTIVATOR_VALUE,  ## Set the activator die's value to a specific number
	REROLL_ACTIVATOR,        ## Reroll the activator die
	REROLL_ALL,              ## Reroll all dice currently on the grid
	FLIP_ONES_AND_SIXES,     ## Replace all 1s with 6s and vice versa
	GIVE_DIE_TO_PLAYER,      ## Transfer a die to the player
	GIVE_DIE_TO_TARGET,      ## Transfer a die to a targeted entity
	GIVE_DIE_AWAY,           ## Give the activator die away from the actor
	KEEP_DIE_WITH_TILE,      ## Retain the activator die on this tile after use
	SPAWN_HOLOGRAPHIC_DIE,   ## Spawn a holographic (one-use) die
	RECEIVE_DIE_FROM_TARGET, ## Enemy action: take a die from a target
}


# ── Visual Subtypes ────────────────────────────────────────────────────────────
enum AudioVisualSubtype {
	SPAWN_HIT_PARTICLES,      ## Directional burst particles at target
	SPAWN_EXPLOSION_PARTICLES,## Explosion burst at target
	ANIMATE_DIE_TO_TILE,      ## Tween the activator die to a target tile position
	ATTACK_TWEEN,             ## Tween the effect source toward a target (attack animation)
	SHAKE_DICE,               ## Shake all dice visually
	PLAY_SOUND,               ## Play a SFX resource
	WAIT,                     ## Wait for N milliseconds (for timing)
}


# ── Tile Control Subtypes ──────────────────────────────────────────────────────
enum TileControlSubtype {
	ACTIVATE_SELF,              ## Activate this tile again (looping)
	ACTIVATE_TARGETED_TILES,    ## Activate all tiles in context.targets
	MOVE_TILE_WITH_OFFSET,      ## Move a tile by a grid offset (x, y)
	PUSH_TILE_IN_DIRECTION,     ## Push a tile one step in a cardinal direction
	PULL_ROW_TILES_TO_COLUMN,   ## Shift all tiles in a row toward a column
	ADD_AMPLIFIER_MODIFIER,       ## Add an amplifier status to a grid position
	LOCKOUT_TILE,               ## Lock a tile so it can't be activated this turn
	ADD_USES_REMAINING,         ## Add N uses to targeted tiles
	INCREMENT_TILE_DATA,        ## Increment a named int stored on a tile
	SET_TILE_DATA,              ## Set a named value stored on a tile
}


# ── Scenario Control Subtypes ──────────────────────────────────────────────────
enum ScenarioControlSubtype {
	OPEN_SHOP,  ## Open the shop UI
	CLOSE_SHOP, ## Close the shop UI
	JUMP,       ## Trigger a hyperspace jump
	FLEE,       ## Enemy flees (removes itself from combat)
	MOVE_SHIP,  ## Move an enemy ship's position on screen
}


# ── Conditional Subtypes ───────────────────────────────────────────────────────
## ConditionalEffectData (a subclass of EffectData) holds if_true / if_false
## sub-chains that the ConditionalHandler executes.
enum ConditionalSubtype {
	IF_ACTIVATOR_ODD,    ## True if the activator die's face value is odd
	IF_ENEMY_TARGETED,   ## True if context.targets[0] is an Enemy
	IF_ENGINE_CHARGED,   ## True if the player's engine is charged
	IF_DIE_VALUE_IN_RANGE, ## True if die value is between min and max (inclusive)
}


# ── Repetition Subtypes ────────────────────────────────────────────────────────
enum RepetitionSubtype {
	ADD_REPETITIONS, ## Add N additional repetitions to context.repetitions
}


# ── Utility Subtypes ───────────────────────────────────────────────────────────
enum UtilitySubtype {
	DESTROY_SOURCE, ## Queue-free the effect source node (e.g. a one-time tile)
	PRINT_DEBUG,    ## Print a debug string to the console (for testing)
}
