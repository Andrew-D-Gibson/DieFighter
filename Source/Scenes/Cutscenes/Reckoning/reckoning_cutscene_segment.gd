class_name ReckoningCutsceneSegment
extends Node
## One piece of a Reckoning ending's film (RECKONING_ENDINGS.md §6-7): the
## arrival in the sky with no Fate in it, being consumed, Become Fate, the
## credits. ReckoningEndingPlayer plays them in turn over the game scene.
##
## The contract every segment keeps:
##   - ReckoningEndingPlayer sets [member ending] and [member mode] before
##     adding it to the tree, then awaits [signal finished].
##   - It comes up out of black and draws on canvas layers 89-96, as
##     EndingCutscene does. The player's own curtain (layer 88) is black
##     behind it the whole time, so the game never shows between segments.
##   - It ends on black and emits [signal finished] once, with whether the
##     player skipped (CutsceneSkipPrompt). A skip ends the whole ending: the
##     player goes straight to the end screen. The player frees the segment.
##   - It never emits Events.victory, game_over or fate_ending: the hand-over
##     is ReckoningEndingPlayer's.

## The segment has played out, or was skipped, and the screen is black.
signal finished(skipped: bool)

## Which version a segment that serves more than one ending plays. Each
## segment documents the modes it knows.
enum Mode { ALONE, CONVOY, LAST_DIE, BECOME_FATE, FELL_IN }

var ending: ReckoningEnding = null
var mode: Mode = Mode.ALONE

var _finished: bool = false


## Call once, on black, to hand back to ReckoningEndingPlayer.
func finish(skipped: bool = false) -> void:
	if _finished:
		return
	_finished = true
	finished.emit(skipped)


## The mode that matches an ending's kind.
static func mode_for(kind: ReckoningEnding.Kind) -> Mode:
	match kind:
		ReckoningEnding.Kind.CONVOY:
			return Mode.CONVOY
		ReckoningEnding.Kind.LAST_DIE:
			return Mode.LAST_DIE
		ReckoningEnding.Kind.BECOME_FATE:
			return Mode.BECOME_FATE
		ReckoningEnding.Kind.FELL_IN:
			return Mode.FELL_IN
		_:
			return Mode.ALONE
