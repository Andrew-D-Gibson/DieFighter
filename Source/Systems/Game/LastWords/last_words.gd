class_name LastWords
extends Node2D
## A gate boss's last words (STORY_BOXES_PLAN.md). When the last hostile ship
## of a fight that has something to say goes down, it's held whole on screen
## (Enemy.hold_death()) while the rest of the wreck goes: on the Bastion, its
## hull breaks up around whichever part fell last. Once the fight is over it
## speaks in a StoryBox, and the last Close lets it die.
##
## What it says: at the run's last gate, the Bastion's confession
## (FateRevelation); at any other fight, its scenario's last_words beat, once
## in full and its repeat line after that (CollectionManager.
## has_read_story_beat()). Only in the player's own runs: the AutoPilot,
## trailer shots and tests never stop on a box.

## Seconds after the fight ends before the screen dims: long enough for the
## kill to land and a hull's breakup (ShipHull.break_up()) to play out.
const _DELAY: float = 1.6

var _held: Enemy = null
var _speaker_name: String = ""
var _lines: Array[String] = []
## The beat to mark read when its box opens; empty for the confession, which
## FateRevelation remembers its own way.
var _beat_id: String = ""
## Whether this scenario's fight has started. Its end can be announced
## (combat_finished) just before or just after the last ship's death,
## depending on what killed it, so that can't be what tells us.
var _fight_started: bool = false
## Whether the held ship's words are the last gate's confession, which ends
## by handing over the drive.
var _confession: bool = false


func _ready() -> void:
	Events.enemy_destroyed.connect(_on_enemy_destroyed)
	Events.start_combat.connect(func() -> void: _fight_started = true)
	# A fight left before it was won (a load, a scene change) lets its ship go.
	Events.load_scenario.connect(func(_scenario: ScenarioResource) -> void:
		_fight_started = false
		_let_go()
	)


## Decided as the ship dies, before its kill plays: only then can it be kept
## whole.
func _on_enemy_destroyed(ship: Enemy) -> void:
	if _held or not _fight_started or not CollectionManager.is_recording():
		return
	# A ship killed before it has flown in has nowhere on screen to speak.
	if ship.global_position.y < 0.0:
		return
	if _any_hostile_left() or not _began_the_fight(ship) or not _choose_words():
		return
	_held = ship
	ship.hold_death()
	_speak()


## Once the fight is over, the held ship says its piece, then dies.
func _speak() -> void:
	if _in_combat():
		await Events.combat_finished
	await get_tree().create_timer(_DELAY).timeout
	if not is_instance_valid(_held):
		_held = null
		return
	# Marked as it opens, so a Continue from here doesn't play it again.
	if not _beat_id.is_empty():
		CollectionManager.record_story_beat(_beat_id)
	var box: StoryBox = StoryBox.open_in(self, _speaker_name, _lines, _held)
	await box.finished
	if _confession:
		FateRevelation.hand_over_drive()
	_let_go()


## Picks this fight's words, if it has any. False when there's nothing to say.
func _choose_words() -> bool:
	_beat_id = ""
	_confession = FateRevelation.is_last_gate()
	if _confession:
		_speaker_name = FateRevelation.speaker()
		_lines = FateRevelation.lines()
		return true
	var scenario: ScenarioResource = _scenario()
	if not scenario or not scenario.last_words:
		return false
	var beat: StoryBeatResource = scenario.last_words
	_lines = beat.display_lines(CollectionManager.has_read_story_beat(beat.id()))
	_speaker_name = beat.display_speaker()
	_beat_id = beat.id()
	return not _lines.is_empty()


## The held ship's kill and wreck play now.
func _let_go() -> void:
	if is_instance_valid(_held):
		_held.release_death()
	_held = null


static func _scenario() -> ScenarioResource:
	var manager: ScenarioManager = Globals.scenario_manager
	return manager.current_scenario if manager else null


static func _in_combat() -> bool:
	return Globals.state_manager != null \
		and Globals.state_manager.state == GameStateManager.GameState.IN_COMBAT


static func _any_hostile_left() -> bool:
	if not Globals.enemy_manager:
		return false
	for ship: Enemy in Globals.enemy_manager.get_alive_enemies():
		if ship.is_hostile():
			return true
	return false


## Whether [param ship] is one the fight started with, not a fighter one of
## them launched: the boss speaks, not its escort.
static func _began_the_fight(ship: Enemy) -> bool:
	var scenario: ScenarioResource = _scenario()
	if not scenario:
		return false
	for spawn: EnemyStateRewardResource in scenario.starting_enemies:
		if spawn.enemy_resource == ship.enemy_resource:
			return true
	return false
