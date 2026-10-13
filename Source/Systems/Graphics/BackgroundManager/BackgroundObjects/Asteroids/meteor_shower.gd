extends HazardTelegraph
## Stray rocks streaking across an asteroid field's sky. Rare while the next
## impact is far off, constant once it is imminent; when it lands, one big rock
## comes down at the cockpit.
##
## Has no art of its own — place it at the origin, and it draws its streaks in
## screen space.

const _ROCK_TEXTURES: Array[Texture2D] = [
	preload("res://Assets/Textures/Backgrounds/StaticObjects/asteroid_small.png"),
	preload("res://Assets/Textures/Backgrounds/StaticObjects/asteroid_medium.png"),
]
const _IMPACT_TEXTURE: Texture2D = preload(
	"res://Assets/Textures/Backgrounds/StaticObjects/asteroid_large.png"
)

## The colour a rock's trail starts in: it is burning up, not just moving.
const _TRAIL_COLOR: Color = Color(0.949, 0.612, 0.365, 0.8)

const _SCREEN: Vector2 = Vector2(320, 180)

## Seconds between streaks at rest, and while an impact is imminent.
@export var calm_interval: Vector2 = Vector2(4.0, 9.0)
@export var urgent_interval: Vector2 = Vector2(0.6, 1.6)

var _until_next_streak: float = 0.0


func _ready() -> void:
	super()
	_schedule_next_streak()


func _process(delta: float) -> void:
	_until_next_streak -= delta
	if _until_next_streak <= 0.0:
		_streak_across_sky()
		_schedule_next_streak()


func _urgency_changed() -> void:
	_schedule_next_streak()


## The impact itself: a big rock falling from high up at the player's panel.
func _fired() -> void:
	var from: Vector2 = Vector2(_rand(60.0, 260.0), -24.0)
	var to: Vector2 = Vector2(_rand(110.0, 210.0), 150.0)
	_streak(_IMPACT_TEXTURE, from, to, 0.45, 28.0)


func _schedule_next_streak() -> void:
	var interval: Vector2 = urgent_interval if urgent else calm_interval
	_until_next_streak = _rand(interval.x, interval.y)


## A small rock crossing the upper sky on a shallow diagonal, either way.
func _streak_across_sky() -> void:
	var leftward: bool = _rand(0.0, 1.0) < 0.5
	var start_x: float = _SCREEN.x + 12.0 if leftward else -12.0
	var end_x: float = -12.0 if leftward else _SCREEN.x + 12.0
	var from: Vector2 = Vector2(start_x, _rand(-10.0, 30.0))
	var to: Vector2 = Vector2(end_x, from.y + _rand(30.0, 70.0))
	var texture: Texture2D = RNGManager.pick_random(RNGManager.Bucket.COSMETIC, _ROCK_TEXTURES)
	_streak(texture, from, to, _rand(1.4, 2.2), 14.0)


func _streak(texture: Texture2D, from: Vector2, to: Vector2, seconds: float, trail_length: float) -> void:
	var rock: Sprite2D = Sprite2D.new()
	rock.texture = texture
	add_child(rock)
	rock.global_position = from

	# A one-pixel tail pointing back along the path, fading to nothing.
	var trail: Line2D = Line2D.new()
	trail.width = 1.0
	trail.antialiased = false
	trail.points = PackedVector2Array([Vector2.ZERO, -(to - from).normalized() * trail_length])
	var fade: Gradient = Gradient.new()
	fade.set_color(0, _TRAIL_COLOR)
	fade.set_color(1, Color(_TRAIL_COLOR, 0.0))
	trail.gradient = fade
	trail.show_behind_parent = true
	rock.add_child(trail)

	var tween: Tween = rock.create_tween()
	tween.tween_property(rock, "global_position", to, seconds)
	tween.finished.connect(rock.queue_free)


func _rand(low: float, high: float) -> float:
	return RNGManager.randf_range(RNGManager.Bucket.COSMETIC, low, high)
