class_name TileHeldDice
extends RefCounted
## Which of the dice on a tile it's holding, and for how long.
##
## Every die on a tile sits in its dice_queue, and that alone doesn't say why.
## A die there is one of:
##   - dropped: waiting for its activation to resolve, then it goes home;
##   - held for a pair (KEEP_DIE_WITH_TILE: Welder, the twin-dice tiles),
##     waiting for a second die. It goes home when the turn ends;
##   - held over (HOLD_DIE_FOR_TURNS: Holding Bay), kept past the end of the
##     turn until HeldDieDelay hands it back. It never outlasts the fight.
## So this keeps its own lists. Two dice dropped in quick succession would
## otherwise read as a held pair.
##
## A die leaving the queue (paid out, given away, picked back up) is no longer
## held by either list, even if it's dropped here again later. The tile calls
## forget_departed() on every die_removed.

var _tile: Tile
## Dice held for a pair (hold()).
var _for_pair: Array[Dice] = []
## Dice kept past the end of the turn (hold_over()).
var _over_turns: Array[Dice] = []


func _init(tile: Tile) -> void:
	_tile = tile


## Keeps [param die] on the tile for a later activation, until the tile uses
## it or the turn ends.
func hold(die: Dice) -> void:
	_tile.dice_queue.add(die, true, false)
	if die not in _for_pair:
		_for_pair.append(die)


## The first die held for a pair other than [param except], or null.
## [param except] is a Node so the AutoPilot can ask about a stand-in die.
func held_die(except: Node = null) -> Dice:
	# Variant, not Dice: a freed die can't be typed.
	for entry: Variant in _for_pair:
		if is_instance_valid(entry) and entry != except and entry in _tile.dice_queue.queue:
			return entry
	return null


## Keeps [param die], already in the tile's queue, past the end of the turn.
## Whatever hands it back (HeldDieDelay, the fight ending, a jump) takes it out
## of the queue, which lets it go.
func hold_over(die: Dice) -> void:
	if die in _tile.dice_queue.queue and die not in _over_turns:
		_over_turns.append(die)


func is_holding_over(die: Dice) -> bool:
	return die in _over_turns


## The turn is over: every die on the tile goes home except those held over.
func release_for_turn_end() -> void:
	for die: Dice in _tile.dice_queue.queue.duplicate():
		if die in _over_turns:
			continue
		_send_home(die)


## The fight is over: every die on the tile goes home.
func release_all() -> void:
	_over_turns.clear()
	for die: Dice in _tile.dice_queue.queue.duplicate():
		_send_home(die)


func forget_departed() -> void:
	_for_pair = _still_on_tile(_for_pair)
	_over_turns = _still_on_tile(_over_turns)


func _still_on_tile(dice: Array[Dice]) -> Array[Dice]:
	var kept: Array[Dice] = []
	for entry: Variant in dice:
		if is_instance_valid(entry) and entry in _tile.dice_queue.queue:
			kept.append(entry)
	return kept


func _send_home(die: Dice) -> void:
	if is_instance_valid(die) and is_instance_valid(Globals.player):
		Globals.player.dice_manager.add(die, true, false)
	else:
		_tile.dice_queue.remove(die)
