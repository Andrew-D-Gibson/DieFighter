class_name ReckoningRules
extends RefCounted
## The Reckoning's rules that decide how a run ends (RECKONING_ENDINGS.md
## §1, §5), kept pure so they can be read and tested without a fight.
## ReckoningDirector notices what happened and asks here what it means.

## What just happened in the fight that may end it.
enum Trigger {
	## The bank was full and the player jumped.
	JUMPED,
	## The player's last die left with an ally ("Run for it").
	LAST_DIE_TO_ALLY,
	## A hostile ship left the fight with the player's last die.
	LAST_DIE_TO_ECHO,
	## The player's hull hit 0.
	HULL_ZERO,
	## A die spent while targeting "You" destroyed it.
	SELF_DESTROYED,
}


## The engine charge the escape needs: [param multiplier] full drives at the
## size the drive was when the player turned Back. Fixed from then on, so
## handing dice away never lowers it.
static func escape_goal(max_engine_charge: int, multiplier: float) -> int:
	return maxi(1, roundi(max_engine_charge * multiplier))


## Whether [param trigger] ends the fight: everything does, except the last
## die leaving with an ally while [param bank_full]. The player isn't consumed
## then; the arrow is lit, and they can still jump with no dice at all.
static func ends_fight(trigger: Trigger, bank_full: bool) -> bool:
	return not (trigger == Trigger.LAST_DIE_TO_ALLY and bank_full)


## The ending [param trigger] brings, or null when it brings none: the last
## die leaving with an ally while [param bank_full] leaves the player
## unconsumed, still able to jump with no dice at all.
##
## [param saved_out] are the allies that jumped out with a die, in the order
## they left; [param left_behind] those still on the board or still queued;
## [param lost] those destroyed in the fight; [param missed] the run's missed
## chances (FateLedger.missed). The Convoy is perfect only when nobody was
## left behind anywhere: every saved ship out, none lost, none left, and
## nothing missed during the run.
static func resolve(trigger: Trigger, bank_full: bool, saved_out: Array[String],
		left_behind: Array[String], lost: Array[String], missed: Array[Dictionary]) -> ReckoningEnding:
	var ending: ReckoningEnding = ReckoningEnding.new()
	match trigger:
		Trigger.JUMPED:
			ending.kind = ReckoningEnding.Kind.ALONE if saved_out.is_empty() else ReckoningEnding.Kind.CONVOY
		Trigger.LAST_DIE_TO_ALLY:
			if not ends_fight(trigger, bank_full):
				return null
			ending.kind = ReckoningEnding.Kind.LAST_DIE
		Trigger.SELF_DESTROYED:
			ending.kind = ReckoningEnding.Kind.BECOME_FATE
		_:
			ending.kind = ReckoningEnding.Kind.FELL_IN
	ending.saved_out = saved_out.duplicate()
	ending.left_behind = left_behind.duplicate()
	ending.lost = lost.duplicate()
	ending.missed = missed.duplicate(true)
	ending.perfect = ending.kind == ReckoningEnding.Kind.CONVOY and left_behind.is_empty() \
		and lost.is_empty() and missed.is_empty()
	return ending
