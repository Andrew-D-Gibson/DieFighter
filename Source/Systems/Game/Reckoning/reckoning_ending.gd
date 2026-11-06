class_name ReckoningEnding
extends RefCounted
## How a Reckoning ended, and everything its cutscenes need to show it
## (RECKONING_ENDINGS.md §5.2). ReckoningDirector builds one when the fight
## ends; ReckoningEndingPlayer hands it to each cutscene in turn. Cutscenes
## draw from this and never read the ledger themselves, so the dev console can
## preview any ending with made-up data (preview()).

enum Kind {
	## Jumped out with no ally out before them.
	ALONE,
	## Jumped out with at least one ally out. perfect: nobody left behind anywhere.
	CONVOY,
	## The last die left with an ally before the bank was full: Save Others.
	LAST_DIE,
	## Destroyed "You".
	BECOME_FATE,
	## Hull gone, or an echo took the last die.
	FELL_IN,
}

## Why a formation slot is empty (RECKONING_ENDINGS.md §6, The formation).
const MISSED_KILLED: String = "killed"
const MISSED_BETRAYED: String = "betrayed"
const MISSED_ESCORT_LOST: String = "escort_lost"

var kind: Kind = Kind.ALONE
## CONVOY only: the run left nobody behind, in the fight or before it.
var perfect: bool = false
## The ship the player flew (ShipResource id), for their hull's art.
var ship_id: StringName = &""
## Enemy ids of the saved ships that jumped out with a die, in the order they left.
var saved_out: Array[String] = []
## Enemy ids of saved ships still on the board or still queued when the fight ended.
var left_behind: Array[String] = []
## Enemy ids of saved ships destroyed during the fight.
var lost: Array[String] = []
## The run's missed opportunities, oldest first: {"enemy": id or "", "reason": MISSED_*}.
var missed: Array[Dictionary] = []
## The first ship the run ever saved (enemy id), or "" if it saved none.
var first_saved: String = ""
## The ship that took the player's last die (enemy id), LAST_DIE only.
var last_die_holder: String = ""
## Dice the player still held when it ended.
var dice_left: int = 0
## The faces of the player's Fate's Die (FateDie.Face values), slot by slot,
## for a film that shows their own die.
var die_faces: Array[int] = []


## The id Events.fate_ending, GameOver and CollectionManager know this by.
func ending_id() -> StringName:
	match kind:
		Kind.ALONE:
			return &"alone"
		Kind.CONVOY:
			return &"convoy"
		Kind.LAST_DIE:
			return &"last_die"
		Kind.BECOME_FATE:
			return &"become_fate"
		_:
			return &"fell_in"


## Every formation slot the run could have filled: ships that got out, then
## ships left behind or lost in the fight, then the run's missed
## opportunities. Capped at [param cap]; the ships that got out always fit.
func formation_size(cap: int = 12) -> int:
	return mini(cap, maxi(saved_out.size(), saved_out.size() + left_behind.size() + lost.size() + missed.size()))


## An ending made up for the dev console (`fate end <kind>`): real ship ids,
## so cutscenes can be previewed without fighting the Reckoning.
static func preview(preview_kind: Kind, preview_perfect: bool = false) -> ReckoningEnding:
	var ending: ReckoningEnding = ReckoningEnding.new()
	ending.kind = preview_kind
	ending.perfect = preview_perfect and preview_kind == Kind.CONVOY
	if is_instance_valid(Globals.state_manager) and Globals.state_manager.current_game_save:
		ending.ship_id = StringName(Globals.state_manager.current_game_save.ship_id)
	ending.first_saved = "mayday_runner"
	for face: FateDie.Face in FateDie.carvable_faces():
		ending.die_faces.append(face)
	if is_instance_valid(Globals.fate_ledger) and Globals.fate_ledger.has_die:
		ending.die_faces.assign(Globals.fate_ledger.die.faces)
	match preview_kind:
		Kind.ALONE:
			ending.left_behind = ["hauler"]
			ending.missed = [{"enemy": "civilian_transport", "reason": MISSED_KILLED}]
			ending.dice_left = 3
		Kind.CONVOY:
			ending.saved_out = ["mayday_runner", "picket_holdout", "hauler"]
			if not ending.perfect:
				ending.left_behind = ["outrigger_courier"]
				ending.missed = [
					{"enemy": "civilian_transport", "reason": MISSED_KILLED},
					{"enemy": "", "reason": MISSED_BETRAYED},
				]
			ending.dice_left = 0 if ending.perfect else 1
		Kind.LAST_DIE:
			ending.saved_out = ["mayday_runner", "picket_holdout", "hauler"]
			ending.left_behind = ["outrigger_courier"]
			ending.missed = [{"enemy": "civilian_transport", "reason": MISSED_KILLED}]
			ending.last_die_holder = "hauler"
		Kind.BECOME_FATE:
			ending.saved_out = []
			ending.dice_left = 3
		Kind.FELL_IN:
			ending.left_behind = ["picket_holdout"]
	return ending
