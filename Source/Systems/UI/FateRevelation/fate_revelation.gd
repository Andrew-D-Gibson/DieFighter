class_name FateRevelation
extends Node
## The forbidden knowledge (LORE.md §4), confessed by the Bastion, the
## Rearguard's leader, as it dies at the run's last gate: there's a black hole
## ahead too, the fleet is being herded, and the tithe was the Bastion's price
## for its own life. Its death breaks that deal, so Fate comes to collect.
##
## The confession is the last gate's last words: LastWords holds the dying
## ship and plays them in a StoryBox. This owns what they are, and what
## hearing them does.
##
## Hearing it is Gate 1 of the secret fight: it outlives the run
## (CollectionManager.learn_fate_knowledge()), so the way back toward Fate can
## open on a later run. A player who has heard it before gets the short form.

const _LINES: Array[String] = [
	"FATE_REVEAL_1", "FATE_REVEAL_2", "FATE_REVEAL_3", "FATE_REVEAL_4",
	"FATE_REVEAL_5", "FATE_REVEAL_6", "FATE_REVEAL_7", "FATE_REVEAL_8",
]
const _LINES_AGAIN: Array[String] = ["FATE_REVEAL_AGAIN_1", "FATE_REVEAL_AGAIN_2"]
## Said only when the way back toward Fate is open, right after the drive is
## offered: what the map's two arrows now do. There's no menu for it any more,
## so the Bastion is the only place the player is told.
const _LINES_ROUTE: Array[String] = ["FATE_REVEAL_ROUTE_1", "FATE_REVEAL_ROUTE_2"]
## The full confession's line the drive is offered on (FATE_REVEAL_7): the
## route lines follow it.
const _DRIVE_LINE_INDEX: int = 6

## Whether the player knew the secret as this fight began. Hearing it is
## recorded as the fight ends, which can land before or after the last ship's
## death, so what to say is decided from this rather than the live record.
static var _knew_at_start: bool = false


func _ready() -> void:
	Events.start_combat.connect(func() -> void: _knew_at_start = CollectionManager.has_fate_knowledge())
	Events.combat_finished.connect(_on_combat_finished)


func _on_combat_finished() -> void:
	if not is_last_gate():
		return
	CollectionManager.learn_fate_knowledge()
	# A run nobody records hears no confession (LastWords stays quiet), but
	# the drive is still theirs.
	if not CollectionManager.is_recording():
		hand_over_drive()


## The Bastion's last act (FATE_REVEAL_7): the drive goes into the engine
## charger. LastWords calls this as the confession's box closes, so the
## player sees it land.
static func hand_over_drive() -> void:
	if Globals.fate_ledger:
		Globals.fate_ledger.take_drive()


## Whether the fight under way, or just won, is the run's last gate.
static func is_last_gate() -> bool:
	var manager: ScenarioManager = Globals.scenario_manager
	var state: GameStateManager = Globals.state_manager
	if not manager or not state or not manager.current_scenario:
		return false
	return manager.current_scenario.sector_gate_scenario \
		and state.current_game_save.sector_index + 1 >= state.demo_sector_count


static func speaker() -> String:
	return TranslationServer.translate("FATE_REVEAL_SPEAKER")


## The confession, translated: in full, or the short form for a player who
## had heard it before this fight. A player whose way back toward Fate is open
## also hears what the drive does with each arrow.
static func lines() -> Array[String]:
	var keys: Array[String] = []
	keys.assign(_LINES_AGAIN if _knew_at_start else _LINES)
	if Globals.fate_ledger and Globals.fate_ledger.fate_route_open():
		# After the drive is offered in the full form; at the end of the short one.
		var at: int = keys.size() if _knew_at_start else _DRIVE_LINE_INDEX + 1
		for i: int in _LINES_ROUTE.size():
			keys.insert(at + i, _LINES_ROUTE[i])
	var translated: Array[String] = []
	for key: String in keys:
		translated.append(TranslationServer.translate(key))
	return translated
