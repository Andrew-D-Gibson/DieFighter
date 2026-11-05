class_name TrailerView
extends RefCounted
## What trailer capture mode asks of the screen, read by the few things that
## must change for a clean take: the drawn cursor, the save indicator, the FPS
## counter. Statics, so nothing reaches for the TrailerDirector autoload,
## which only exists in dev builds. All of it rests at "the game as usual".
##
## See TrailerDirector (Source/Systems/Autoloads/trailer_director.gd).

## Debug and bookkeeping overlays (FPS, "Saving...", the dev console) are
## kept off screen.
static var clean_hud: bool = false

## The drawn cursor is hidden (the real mouse still works).
static var cursor_hidden: bool = false

## A scripted drag is steering the drawn cursor: it sits at
## [member puppet_position] (viewport coordinates) instead of the mouse.
static var puppet_active: bool = false
static var puppet_position: Vector2 = Vector2.ZERO
## The puppet has something in hand, so the cursor wears the grab fist.
static var puppet_grabbing: bool = false


## Back to the game as usual.
static func reset() -> void:
	clean_hud = false
	cursor_hidden = false
	puppet_active = false
	puppet_grabbing = false
