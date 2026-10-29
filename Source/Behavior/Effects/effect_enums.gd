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
	## One random grid tile a lockout could take hold on: not already locked,
	## and not immune (Tile.accepts_lockout). Lockouts use this so they never
	## stack, and fizzle only when every tile is already locked.
	TARGET_RANDOM_LOCKABLE_TILE,
	## The tile in the source tile's mirrored cell: same row, the other side
	## of the grid (x -> grid_width - 1 - x). On a twin-pod ship that's the
	## matching cell across the hull gap. Nothing in a centre column, which
	## mirrors onto itself. The "Feed across" relays use it.
	TARGET_MIRRORED_TILE,
	## Every countdown tile on the grid (TileResource.countdown) other than
	## the source. The Fuse Cutter counts them all down at once.
	TARGET_OTHER_COUNTDOWN_TILES,
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
	## The actor takes running_amount credits from the player, or all they
	## have if that's less. The credits fly from the money counter to the actor.
	STEAL_MONEY,
	## Spend the player's shields as a cost: amount when authored, else
	## running_amount. Unlike a negative SHIELD this isn't a hit, so it plays
	## no hit feedback and doesn't count as the shields taking damage.
	SPEND_SHIELDS,
	## Ion damage (creates IonDamageEvent): strips twice running_amount from
	## the targets' shields and never touches the hull. Whatever the shields
	## can't absorb is lost.
	ION_DAMAGE,
	## The actor drains running_amount engine charge from the player, in a few
	## pulses: each drops the gauge, then motes in the effect's colour stream
	## from it to the actor. One drain however many pulses it takes, so it
	## arms engine_charge_drained once, like an enemy's CHANGE_ENGINE_CHARGE.
	SIPHON_ENGINE_CHARGE,
	## Move every status on the actor onto the first target, stacks and all,
	## merging into any it already has. The player can hand an enemy their
	## Burn; an enemy can vent the player's Burn back at them.
	TRANSFER_STATUSES,
	## Multiply every status on the targets by multiplier (x2 doubles), by
	## applying the difference: each status gets an ApplyStatusEvent of its
	## own, so it lands, shows and is heard like any other application.
	MULTIPLY_STATUSES,
	## Spend the player's hull as a cost: amount when authored, else
	## running_amount. It goes straight past the shields, and it is a hull
	## hit (whatever answers one hears it), but not damage: nothing that
	## grows, shrinks or dodges a hit touches it. Refuses rather than kill;
	## tiles gate on HULL_AT_LEAST.
	SPEND_HULL,
	## DAMAGE that pays a bounty: `amount` credits for each hostile warship
	## this very hit destroys (Bounty Scanner). See BountyDamageEvent.
	BOUNTY_DAMAGE,
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
	## Set running_amount to a roll from range_min to range_max, inclusive.
	SET_RANDOM,
	## Set running_amount to the first target's shields (0 without a target).
	SET_TO_TARGET_SHIELDS,
	## Add the face of the die the source tile is holding (KEEP_DIE_WITH_TILE)
	## to running_amount; adds nothing when it holds none. The twin-dice tiles
	## pay out on both dice with it.
	ADD_HELD_DIE_VALUE,
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
	## An enemy hands its die to the ally its slot was bound to, who spends it
	## on its own table on its turn. Ends the actor's use of the die.
	FEED_ALLY,
	## An enemy spawns a holographic die, face = its intent amount, for the
	## ally its slot was bound to, who spends it on its turn.
	SPAWN_HOLOGRAM_FOR_ALLY,
	## Re-roll every die the targets are holding. Aimed at enemies after the
	## player has handed dice over, it scrambles which intents will fire.
	REROLL_TARGETS_DICE,
	## Flip every 1 to a 6 and every 6 to a 1 among the dice the targets are
	## holding.
	FLIP_TARGETS_ONES_AND_SIXES,
	## Raise the activator die's face by running_amount, capped at 6. Unlike
	## CHANGE_ACTIVATOR_VALUE the amount is the step, not the face, so an
	## Amplifier on the tile grows the step.
	ADD_TO_ACTIVATOR_VALUE,
	## Split the activator die in two that add up to it: it keeps the bigger
	## half (rounded up) and a hologram showing the rest joins the player's
	## hand. A 1 can't split and is left as it is.
	SPLIT_ACTIVATOR,
	## The die the source tile is holding goes to the first target, the way
	## GIVE_DIE_TO_TARGET sends the activator. Twin-dice tiles pay out with
	## both dice handed over.
	GIVE_HELD_DIE_TO_TARGET,
	## The source tile keeps the activator die past the end of the turn, at
	## its face, and hands it back to the hand as the player's turn starts
	## `amount` turns from now (1 when unset). A HeldDieDelay counts it down.
	HOLD_DIE_FOR_TURNS,
	## The highest die each target is holding turns to `amount` (Cryo Lance:
	## a 1). The big die an enemy already holds is defused before it acts.
	SET_TARGETS_HIGHEST_DIE,
	## Each target's intent for the activator die's face (or `amount`, when
	## set) does nothing until its table is next rolled (Counter-Battery).
	## See Enemy.silence_face().
	SILENCE_TARGETS_FACE,
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
	CALLOUT,                  ## Float text off each target; "{amount}" shows the running amount, "{die}" the die's face
	BUMP,                     ## Squash-and-stretch each target
	ZAP,                      ## Lightning bolt from the effect source to each target
	GRID_RIPPLE,              ## A flash that ripples out across the tile grid from the source
	SCREEN_RIPPLE,            ## Screen-space shockwave distortion centred on the first target
	STREAM,                   ## Motes flowing from each target to the source (OUTWARD: the other way)
	DIE_FLARE,                ## Spin, pop and ring the activator die
	LASER,                    ## A blaster bolt from the effect source to each target; holds until it lands
	MISSILE,                  ## A missile from the effect source to each target; holds until it lands
	ION_BOLT,                 ## A crackling ion orb from the effect source to each target's shields; holds until it lands
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
	## Count down every countdown tile among the targets by running_amount.
	## Each one that reaches 0 fires its ON_COUNTDOWN_ZERO response and starts
	## again, with any extra counts carried over. See TileCountdown.
	COUNT_DOWN,
	## Arm an echo (EchoModifier): the next tile activation this turn plays
	## its whole chain twice and hands its die on once. Each echo is spent by
	## one activation; unspent ones lapse when the turn or the fight ends.
	ARM_ECHO,
	## Give every tile of the colour family named by string_param ("red",
	## "blue", ...) running_amount more damage for the rest of the fight, held
	## between 0 and range_max (FamilyBoostModifier, one per source tile). A
	## negative amount takes it back down.
	ADD_FAMILY_BOOST,
}


# ── Scenario Control Subtypes ──────────────────────────────────────────────────
enum ScenarioControlSubtype {
	OPEN_SHOP,  ## Open the shop UI
	CLOSE_SHOP, ## Close the shop UI
	JUMP,       ## Trigger a hyperspace jump
	FLEE,       ## Enemy flees (removes itself from combat)
	MOVE_SHIP,  ## Move an enemy ship's position on screen
	## The enemy leaves combat taking every die it holds, the one it is
	## spending included. The player loses those dice for good, as if they had
	## jumped away from them.
	ESCAPE_WITH_DICE,
	## The enemy launches a new ship of ship_resource beside itself, on its
	## own side, to fight from the next turn.
	LAUNCH_SHIP,
	OPEN_REPAIR_STATION,  ## Open the repair station UI (repair hull, sell tiles)
	CLOSE_REPAIR_STATION, ## Close the repair station UI
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
	## True while a fight is on. Event responses skip activation checks, so a
	## passive that lashes out at a random enemy guards with this; outside
	## combat that "enemy" could be a merchant.
	IF_IN_COMBAT,
	## True if the player has at least `amount` engine charge. The "Boost"
	## tiles branch on it: pay that much for the bigger effect, or fire plain.
	IF_CHARGE_AT_LEAST,
	## True if the source tile sits in a grid row from range_min to range_max
	## (0 is the top row). For tiles that do more in one part of the grid,
	## which on the Carousel means part of each lap.
	IF_SOURCE_IN_ROW,
}


# ── Repetition Subtypes ────────────────────────────────────────────────────────
enum RepetitionSubtype {
	ADD_REPETITIONS, ## Add N additional repetitions to context.repetitions
}


# ── Utility Subtypes ───────────────────────────────────────────────────────────
enum UtilitySubtype {
	DESTROY_SOURCE, ## Queue-free the effect source node (e.g. a one-time tile)
	PRINT_DEBUG,    ## Print a debug string to the console (for testing)
	## A DelayedEffectData: its delayed_effects play against the first target
	## as the player's turn starts `amount` turns from now, with the running
	## amount as it stands now (see DelayedPayload).
	DELAY_EFFECTS,
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
