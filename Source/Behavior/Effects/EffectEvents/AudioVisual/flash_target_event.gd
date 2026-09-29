class_name FlashTargetEvent
extends EffectEvent

## Flashes every target a solid color. Enemies flash through their ship
## shader; the player has no sprite of their own, so they get the screen-edge
## vignette instead; anything else that can be drawn is over-brightened.

var color: Color = Color.WHITE

const _FLASH_SECONDS: float = 0.25


func resolve(_engine: ScenarioEngine) -> void:
	for target: Node in targets:
		if not is_instance_valid(target):
			continue

		if target is Enemy:
			(target as Enemy).graphics_manager.flash(color, _FLASH_SECONDS)
		elif target is Player:
			Events.vignette_pulse.emit(color)
		elif target is CanvasItem:
			_flash_canvas_item(target as CanvasItem)


## Snaps modulate up past white and lets it settle back. Snapped rather than
## eased in for the same reason as the enemy flash: it usually lands in a
## hitstop, where an ease-in would still be at zero when the freeze ends.
func _flash_canvas_item(item: CanvasItem) -> void:
	var resting: Color = item.modulate
	item.modulate = Color(color.r * 2.0, color.g * 2.0, color.b * 2.0, resting.a)
	var tween: Tween = item.create_tween()
	tween.tween_property(item, "modulate", resting, _FLASH_SECONDS) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
