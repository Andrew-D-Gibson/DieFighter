class_name TextFitSettle
extends RefCounted
## Refits text measured while something above it was mid-animation.
##
## A fit snaps the text to the canvas pixel grid at the scale it's drawn at
## (TextFit.canvas_pixels_per_unit). Text fitted while a parent is scaling in
## (a card unfolding from 6% size) is snapped for that passing scale, and
## nothing about the text itself changes when the parent comes to rest, so it
## would stay off its grid until something else refits it. This watches the
## scale the fit was measured at and asks for one refit once the parent stops
## moving at a different one: once, at rest, not every frame of the tween.
##
## The owner (a CanvasItem with set_notify_transform(true)) forwards its
## NOTIFICATION_TRANSFORM_CHANGED to moved(self), processes while that returns
## true, and once settled() refits if off_scale().

## The item whose scale the fit measured: the label's parent.
var _item: CanvasItem
## Its canvas pixels per unit at the last fit; negative before one.
var _fitted_scale: float = -1.0
var _moved_frame: int = -1
var _watching: bool = false


## After a fit of text drawn under [param item].
func fitted(item: CanvasItem) -> void:
	_item = item
	_fitted_scale = TextFit.canvas_pixels_per_unit(item)


## Something above the text moved: [param observer] heard it. True while
## it's worth watching for it to come to rest: its scale differs from the
## fitted one, or it's still moving.
func moved(observer: CanvasItem) -> bool:
	# Godot only notifies again once the observer's global transform has been
	# read since the last change: without this it hears the first frame of a
	# tween and nothing after.
	observer.get_global_transform()
	if _fitted_scale < 0.0 or not is_instance_valid(_item):
		return false
	_moved_frame = Engine.get_process_frames()
	if not _watching and not off_scale():
		# Moved without rescaling (laid out, slid along): the fit still holds.
		return false
	_watching = true
	return true


## Each frame while watching: true once a whole frame has passed without it
## moving, which ends the watch.
func settled() -> bool:
	if Engine.get_process_frames() <= _moved_frame + 1:
		return false
	_watching = false
	return true


## Whether the scale now differs from the one the last fit measured.
func off_scale() -> bool:
	return is_instance_valid(_item) and _fitted_scale >= 0.0 \
		and not is_equal_approx(TextFit.canvas_pixels_per_unit(_item), _fitted_scale)
