class_name EnemyHealthBar
extends HealthBarController

## How far the drawn bar reaches to the left and right of its own origin: the
## health and shield rings. The formation spaces ships by this, so it has to
## track the art if the bar is redrawn.
const REACH_LEFT: float = 12.0
const REACH_RIGHT: float = 12.0
