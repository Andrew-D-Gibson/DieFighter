class_name VentPuff
extends CPUParticles2D
## A cockpit vent that breathes out a faint wisp every so often. Each puff is
## a one-shot burst on its own random timer, so the vents never sync up and
## no single one draws the eye.

@export var min_interval: float = 5.0
@export var max_interval: float = 14.0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _timer: float = 0.0


func _ready() -> void:
	_rng.randomize()
	one_shot = true
	emitting = false
	# Stagger the first puff too, or every vent would go off together a few
	# seconds after the cockpit loads.
	_timer = _rng.randf_range(0.5, max_interval)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = _rng.randf_range(min_interval, max_interval)
	restart()
