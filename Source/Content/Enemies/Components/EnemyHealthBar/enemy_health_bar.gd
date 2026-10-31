class_name EnemyHealthBar
extends HealthBarController

## How far the drawn bar reaches to the left and right of its own origin: the
## health and shield rings plus the soft outline that lifts them off dark
## space. The formation spaces ships by this, so it has to track the art if
## the bar is redrawn.
const REACH_LEFT: float = 13.0
const REACH_RIGHT: float = 13.0
## A hull of 100 or more can't fit in the ring's dark centre, so its outer
## digits land on the red ring itself. The ring's own red would vanish there;
## light reads on both.
const _WIDE_HULL: int = 100

## The outline is a white mask tinted by how the ship feels about the player,
## so the whole formation reads friend from foe at a glance, not only the ship
## on the targeting computer. Kept translucent so it stays a soft edge rather
## than a hard ring competing with the bar's own red and blue.
const _OUTLINE_ALPHA: float = 0.8
## A ship changing sides mid-fight (a shop the player fired on) blinks its
## outline, the same beat as the targeting computer's bezel.
const _BLINKS: int = 3
const _BLINK_SECONDS: float = 0.08

## The attitude the outline shows, or -1 before the first one, so the first
## colouring of a fresh ship doesn't blink.
var _shown_attitude: int = -1
var _blink_tween: Tween


## Tints the outline for [param attitude]: green friendly, grey neutral, red
## hostile, the targeting computer's own colours (AttitudeDisplay).
func show_attitude(attitude: Enemy.Attitude) -> void:
	var changed: bool = _shown_attitude != -1 and _shown_attitude != attitude
	_shown_attitude = attitude
	var tint: Color = AttitudeDisplay.attitude_colour(attitude)
	tint.a = _OUTLINE_ALPHA
	%Outline.modulate = tint
	if changed and is_inside_tree():
		_blink()


func _blink() -> void:
	if _blink_tween:
		_blink_tween.kill()
	_blink_tween = create_tween()
	for i: int in range(_BLINKS):
		_blink_tween.tween_callback(_set_outline_lit.bind(false))
		_blink_tween.tween_interval(_BLINK_SECONDS)
		_blink_tween.tween_callback(_set_outline_lit.bind(true))
		_blink_tween.tween_interval(_BLINK_SECONDS)


func _set_outline_lit(lit: bool) -> void:
	%Outline.visible = lit


func _get_health_string() -> String:
	var hull: String = super()
	if health_component.health < _WIDE_HULL:
		return hull
	return "[color=#%s]%s[/color]" % [Globals.white.to_html(false), hull]
