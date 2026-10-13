extends HazardTelegraph
## A charged cloud in an ion storm region. Lightning forks out of its belly now
## and then; as the storm's discharge gets close, it strikes constantly.

## Seconds between strikes at rest, and while the discharge is imminent.
@export var calm_interval: Vector2 = Vector2(2.5, 6.0)
@export var urgent_interval: Vector2 = Vector2(0.3, 1.1)

## How long one strike's bolt stays on screen.
@export var strike_seconds: float = 0.09

## The arcs sheet's blank frame, shown between strikes.
const _NO_BOLT: int = 2
const _BOLT_FRAMES: Array[int] = [0, 1]

@onready var _cloud: Sprite2D = $Cloud
@onready var _arcs: Sprite2D = $Arcs

var _until_next_strike: float = 0.0


func _ready() -> void:
	super()
	_arcs.frame = _NO_BOLT
	_schedule_next_strike()


func _process(delta: float) -> void:
	_until_next_strike -= delta
	if _until_next_strike <= 0.0:
		_strike()
		_schedule_next_strike()


func _urgency_changed() -> void:
	# Don't make an imminent storm sit out the rest of a long calm wait.
	_schedule_next_strike()


func _fired() -> void:
	for i: int in range(6):
		_strike()
		await get_tree().create_timer(strike_seconds * 1.6).timeout
		if not is_inside_tree():
			return


func _schedule_next_strike() -> void:
	var interval: Vector2 = urgent_interval if urgent else calm_interval
	_until_next_strike = RNGManager.randf_range(RNGManager.Bucket.COSMETIC, interval.x, interval.y)


## Shows one bolt, lights the cloud from inside for a beat, then goes dark.
func _strike() -> void:
	_arcs.frame = RNGManager.pick_random(RNGManager.Bucket.COSMETIC, _BOLT_FRAMES)
	_cloud.self_modulate = Color(1.6, 1.6, 1.6)
	var tween: Tween = create_tween()
	tween.tween_interval(strike_seconds)
	tween.tween_callback(func() -> void: _arcs.frame = _NO_BOLT)
	tween.parallel().tween_property(_cloud, "self_modulate", Color.WHITE, 0.25)
