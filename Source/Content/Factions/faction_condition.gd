class_name FactionCondition
extends Resource
## One question about what the fleet remembers of the player (FactionLedger):
## does the Caravan like them, have they ever attacked a shop. Encounters ask
## these to change with the run: a standing branch picks a ship's state by
## them (ScenarioShipStateStandingBranch), and an encounter can be dealt only
## while they hold (ScenarioResource.standing_requirements).

enum Test {
	## The faction's regard is [member regard] or warmer.
	REGARD_AT_LEAST,
	## The faction's regard is [member regard] or colder.
	REGARD_AT_MOST,
	## [member deed] has been done at least [member count] times.
	DEED_DONE,
	## [member deed] has been done fewer than [member count] times (never,
	## for the default of 1).
	DEED_NOT_DONE,
	## The player has destroyed at least [member count] of the faction's ships.
	KILLS_AT_LEAST,
}

@export var test: Test = Test.REGARD_AT_LEAST
## The faction asked about by the regard and kill tests. Null means the asking
## ship's own faction; an encounter asking for itself has no ship, so set it
## there.
@export var faction: FactionIdentity
@export var regard: FactionLedger.Regard = FactionLedger.Regard.NEUTRAL
@export var deed: StringName = &""
@export_range(1, 99) var count: int = 1


## Whether this holds in [param ledger]. [param own_faction] stands in for an
## unset [member faction]; a regard or kill test with neither never holds.
func holds(ledger: FactionLedger, own_faction: FactionIdentity = null) -> bool:
	match test:
		Test.DEED_DONE:
			return ledger.deed_count(deed) >= count
		Test.DEED_NOT_DONE:
			return ledger.deed_count(deed) < count

	var asked: FactionIdentity = faction if faction else own_faction
	if asked == null:
		push_warning("FactionCondition: a %s test needs a faction to ask about." % Test.keys()[test])
		return false
	match test:
		Test.REGARD_AT_LEAST:
			return ledger.regard(asked.id) >= regard
		Test.REGARD_AT_MOST:
			return ledger.regard(asked.id) <= regard
		Test.KILLS_AT_LEAST:
			return ledger.kills(asked.id) >= count
	return false


## Whether every one of [param conditions] holds. None at all always holds.
static func all_hold(conditions: Array[FactionCondition], ledger: FactionLedger, own_faction: FactionIdentity = null) -> bool:
	for condition: FactionCondition in conditions:
		if condition and not condition.holds(ledger, own_faction):
			return false
	return true
