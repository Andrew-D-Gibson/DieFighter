class_name EnemyHealthBar
extends HealthBarController

## How far the drawn bar reaches to the left and right of its own origin: the
## health and shield rings plus the soft light outline that lifts them off
## dark space. The formation spaces ships by this, so it has to track the art
## if the bar is redrawn.
const REACH_LEFT: float = 13.0
const REACH_RIGHT: float = 13.0
