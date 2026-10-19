class_name AutoPilotCamera
extends RefCounted
## Screenshots of a replayed run (tools/autoplay.sh --replay), for seeing what
## a transcript describes: the board as each turn is about to be played, every
## error and broken invariant as it happens, and how the run ended.
##
## A capture waits for the frame to finish drawing but never holds up the
## caller, so taking pictures can't change when the bot acts and a replay
## still plays the run it's replaying. Files are numbered in the order they
## were asked for, then named for what they show:
##   007_turn_012.png, 008_error_turn_012.png, 031_end_defeat.png

## Errors and violations each get a picture up to this many; one bug can
## repeat every frame.
const _MAX_FLAGGED_SHOTS: int = 12

## Halved: a full 1920×1080 frame of pixel art loses nothing at half size.
const _SCALE: float = 0.5

var _dir: String
var _taken: int = 0
var _flagged: int = 0


func _init(dir: String) -> void:
	_dir = dir
	DirAccess.make_dir_recursive_absolute(_dir)


## Whether there's anything to photograph: a headless run draws nothing.
static func can_capture() -> bool:
	return DisplayServer.get_name() != "headless"


## Captures the next frame of [param viewport] as [param label]. Await it to
## be sure the file is written (before quitting, say); otherwise fire and
## forget.
func capture(viewport: Viewport, label: String) -> void:
	_taken += 1
	var path: String = _dir.path_join("%03d_%s.png" % [_taken, label.validate_filename()])
	await RenderingServer.frame_post_draw
	if not is_instance_valid(viewport):
		return
	var image: Image = viewport.get_texture().get_image()
	if image == null or image.is_empty():
		return
	image.resize(roundi(image.get_width() * _SCALE), roundi(image.get_height() * _SCALE),
		Image.INTERPOLATE_NEAREST)
	image.save_png(path)


## Like capture(), for an error or violation, until there have been enough.
func capture_flagged(viewport: Viewport, label: String) -> void:
	if _flagged >= _MAX_FLAGGED_SHOTS:
		return
	_flagged += 1
	capture(viewport, label)
