class_name GhostDemo
extends Resource
## One gesture the tutorial's ghost cursor acts out: a drag from one named
## thing to another, or a click on one. A TutorialStep lists these, and the
## ghost plays them in order, on a loop, until the step is done.

enum Gesture {
	## Press on [member at], carry it to [member to], let go.
	DRAG,
	## Glide in to [member at] and click it.
	CLICK,
}

@export var gesture: Gesture = Gesture.DRAG
## Where the press lands.
@export var at: GhostTarget
## DRAG: where it lets go. Unused by CLICK.
@export var to: GhostTarget


## Whether this demo names everything its gesture needs.
func is_complete() -> bool:
	if at == null:
		return false
	return gesture == Gesture.CLICK or to != null
