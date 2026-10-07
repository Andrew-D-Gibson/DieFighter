## EffectEnums
## Centralised enum definitions for the data-driven effect system.
##
## Every EffectData resource has a 'category' (which class of thing it does)
## and a 'subtype' (the specific variant within that category).
##
## HOW TO ADD A NEW EFFECT TYPE:
##   1. Decide which Category it belongs to (or add a new one).
##   2. APPEND a value to the END of that category's subtype enum. Never insert
##      one in the middle: .tres files store 'subtype' as a raw int, so every
##      authored effect below the insertion point silently becomes a different
##      effect. Same goes for Category itself.
##   3. Implement a corresponding EffectHandler subclass.
##   4. Add a row to EffectCatalog, in the same position as the enum value.
##      That one row is what the registry, the inspector dropdown and the
##      field-visibility rules all read — there is nothing else to update.
##
## This file owns the ordinals and nothing else. What each effect is called,
## which handler runs it, and which parameters it takes all live in
## EffectCatalog, which validate()s itself against these enums at startup.

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
	TARGET_RANDOM_OTHER_ENEMY,     	## One random living enemy that isn't the actor
	TARGET_RANDOM_ADJACENT_TILE,   	## One random tile directly above, below, left or right of the source tile
	## The ally an enemy action was bound to when its slot was rolled. The
	## slot needs an ally to be rolled at all, and its intent names the ship.
	TARGET_BOUND_ALLY,
	## The hostile non-player ship an enemy action was bound to when its slot
	## was rolled (a pirate's raid on a civilian).
	TARGET_BOUND_HOSTILE_SHIP,
}


# ── Attribute Change Subtypes ──────────────────────────────────────────────────
enum AttributeChangeSubtype {
	DAMAGE,               ## Deal damage to targets (creates DamageEvent)
	HEAL,                 ## Restore HP to targets (creates HealEvent)
	SHIELD,               ## Grant shields to targets (creates ShieldEvent)
	CHANGE_ENGINE_CHARGE, ## Change the player's engine charge by an amount
	## Spend engine charge as a cost. Unlike CHANGE_ENGINE_CHARGE, which
	## clamps a negative amount silently at zero, this refuses to underflow —
	## so a tile can't fire its payoff for free when the player can't afford
	## it. Affordability is normally guaranteed upstream by the
	## CHARGE_AT_LEAST activation check; this is the guard rail for when a
	## tile's authored cost and its threshold disagree.
	SPEND_ENGINE_CHARGE,
	## Add charge, permitted to push PAST max_engine_charge into the redline
	## band. The only door into overcharge: ordinary CHANGE_ENGINE_CHARGE
	## clamps at max, so topping off to jump can never redline you by accident.
	ADD_OVERCHARGE,
	## Put the status named by string_param on the targets, with running_amount
	## stacks (added to any they already have). See StatusCatalog.
	APPLY_STATUS,
	## Remove the status named by string_param from the targets entirely.
	CLEAR_STATUS,
}


# ── Amount Modifier Subtypes ───────────────────────────────────────────────────
## These mutate context.running_amount directly, synchronously. Each step in the chain
## can add/multiply/set the running amount, and any ATTRIBUTE_CHANGE handler (or other
## consumer) later in the same repetition reads the final value.
enum AmountModifierSubtype {
	SET,                  ## Set running_amount to a fixed value
	ADD,                  ## Add a fixed value to running_amount
	MULTIPLY,             ## Multiply running_amount by a float multiplier
	ADD_ADJACENT_TILES,   ## Add count of adjacent tiles to running_amount
	ADD_TILE_DATA,        ## Add a tile's stored data value to running_amount
	SET_TO_ENGINE_CHARGE, ## Set running_amount to current engine charge value
	SET_TO_DIE_VALUE,     ## Set running_amount to the activator die's face value
	SET_TO_ENEMY_INTENT,  ## Set running_amount to the enemy action's rolled intent amount
	ADD_EMPTY_ADJACENT_CELLS, ## Add count of empty cells around the source tile
	## Set running_amount to how much charge is still MISSING (max - current).
	## Reads 0 once the jump gate is open, so effects built on it are strongest
	## on a cold drive and go quiet as the player secures their escape.
	SET_TO_MISSING_CHARGE,
	## Set running_amount to how far past max the drive is sitting (0 when not
	## overcharged). Lets a tile cash out surplus without touching the charge
	## the player needs to leave.
	SET_TO_OVERCHARGE,
	## Set running_amount to how many Feeds carried the die here (0 when it
	## came from the player's hand). The payoff for the end of a long machine.
	SET_TO_FEED_DEPTH,
	## Set running_amount to how many tiles have activated this player turn,
	## counting the one reading it.
	SET_TO_ACTIVATIONS_THIS_TURN,
	## Set running_amount to the first target's stacks of the status named by
	## string_param (0 when it has none).
	SET_TO_TARGET_STATUS,
	## Set running_amount to how many dice the player owns, holograms included
	## (see Player.dice_owned()). Where a die is right now doesn't matter.
	SET_TO_DICE_OWNED,
	## Set running_amount to how many dice are still in the player's hand,
	## not counting the one being spent.
	SET_TO_DICE_IN_HAND,
	## Set running_amount to how many dice the first target is holding.
	SET_TO_TARGET_DICE_HELD,
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
	RECEIVE_DIE_FROM_TARGET, ## The actor takes back a die its first target is holding
	KEEP_DIE_WITH_ACTOR,     ## The actor holds onto the activator die instead of returning it
	## The activator die gains the value of the die the source tile is holding
	## (capped at 6), and the held die goes back to the player's hand.
	MERGE_HELD_DIE,
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
	HITSTOP,                  ## Freeze the game for N ms on the impact frame
	SLOW_MO,                  ## Slow the game to a time scale for N ms
	ZOOM_PUNCH,               ## Kick the camera zoom in toward the target, ease back
	FLASH_TARGET,             ## Flash the targets a solid color for a moment
	SCREEN_SHAKE,             ## Shake the camera (1 small, 2 large, 3 large + glitch)
	VIGNETTE_PULSE,           ## Flash the screen-edge vignette in a color
	GLITCH_BURST,             ## Turn the glitch overlay on for N ms
	SHOCKWAVE,                ## Ring out from each target (negative amount: ring closes in, a lock-on)
	SPARK_BURST,              ## Burst of sparks at each target
	CALLOUT,                  ## Float text off each target; "{amount}" shows the running amount
	BUMP,                     ## Squash-and-stretch each target
	ZAP,                      ## Lightning bolt from the effect source to each target
	GRID_RIPPLE,              ## A flash that ripples out across the tile grid from the source
	SCREEN_RIPPLE,            ## Screen-space shockwave distortion centred on the first target
	STREAM,                   ## Motes flowing from each target to the source ("out": the other way)
	DIE_FLARE,                ## Spin, pop and ring the activator die
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
	PUSH_TARGETED_TILES,        ## Push each targeted tile one cell (zero offset = random)
	PASS_DIE_TO_TILE,           ## Hand the activator die to a targeted tile and activate it
	## Arm the engine death save: a full drive cancels a killing blow and is
	## spent doing it. A modifier rather than an event response because the
	## save has to be decided before the damage lands.
	ADD_DEATH_SAVE_MODIFIER,
	## Spawn a holographic die showing running_amount at the source tile and
	## Feed it to the first target, exactly as PASS_DIE_TO_TILE would pass a
	## real one.
	FEED_HOLOGRAM,
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
	IF_TARGET_HOLDS_MATCHING_DIE, ## True if the first target already holds a die of the activator's value
	IF_OVERCHARGED,      ## True if the drive is sitting above max_engine_charge
	IF_FED,              ## True if another tile's Feed passed the die here
	IF_SOURCE_HOLDS_DIE, ## True if the source tile is holding a die other than the activator
	IF_TARGET_HAS_STATUS, ## True if the first target has the status named by string_param
	IF_DICE_OWNED_IN_RANGE, ## True if the player owns between min and max dice (inclusive), holograms included
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


## The subtype enum belonging to a Category, or an empty Dictionary for a
## category that has none. Lets callers walk the enums generically instead of
## hardcoding yet another category -> subtype mapping; EffectCatalog.validate()
## uses it to prove every enum value has a catalog row.
static func subtype_enum(category: Category) -> Dictionary:
	match category:
		Category.TARGETING:        return TargetingSubtype
		Category.ATTRIBUTE_CHANGE: return AttributeChangeSubtype
		Category.AMOUNT_MODIFIER:  return AmountModifierSubtype
		Category.DICE_CONTROL:     return DiceControlSubtype
		Category.AUDIO_VISUAL:     return AudioVisualSubtype
		Category.TILE_CONTROL:     return TileControlSubtype
		Category.SCENARIO_CONTROL: return ScenarioControlSubtype
		Category.CONDITIONAL:      return ConditionalSubtype
		Category.REPETITION:       return RepetitionSubtype
		Category.UTILITY:          return UtilitySubtype
		_:                         return {}
