class_name EnemyHealthBar
extends HealthBarController

## How far the drawn bar reaches to the left and right of its own origin: the
## health and shield rings plus the soft light outline that lifts them off
## dark space. The formation spaces ships by this, so it has to track the art
## if the bar is redrawn.
const REACH_LEFT: float = 13.0
const REACH_RIGHT: float = 13.0
## A hull of 100 or more can't fit in the ring's dark centre, so its outer
## digits land on the red ring itself. The ring's own red would vanish there;
## light reads on both.
const _WIDE_HULL: int = 100


func _get_health_string() -> String:
	var hull: String = super()
	if health_component.health < _WIDE_HULL:
		return hull
	return "[color=#%s]%s[/color]" % [Globals.white.to_html(false), hull]
