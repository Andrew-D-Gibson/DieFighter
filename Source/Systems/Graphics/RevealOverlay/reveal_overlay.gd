class_name RevealOverlay
extends RefCounted
## The "system coming online" wipe shared by the health bar, targeting
## computer, systems panel and map: tween an overlay's reveal shader from
## start_progress to end_progress, then hide it.
##
## Each overlay's shader has its own scale for progress (a wider panel needs a
## larger value to clear), so callers pass the range rather than a fraction.


static func play(
	overlay: CanvasItem,
	duration: float,
	end_progress: float,
	start_progress: float = 0.0
) -> void:
	var tween: Tween = overlay.get_tree().create_tween()
	tween.tween_property(
		overlay,
		"material:shader_parameter/progress",
		end_progress,
		duration
	).from(start_progress)

	await tween.finished
	if is_instance_valid(overlay):
		overlay.hide()
