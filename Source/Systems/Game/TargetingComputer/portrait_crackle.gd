class_name PortraitCrackle
extends Sprite2D
## Electric crackle over the targeting computer's portrait of a ship whose
## overload gauge is armed (EnemyResource.overload_portrait_crackle). The
## sheet's square frames play in a jittery order with uneven holds, so the
## arcs never settle into a loop the eye can follow. With reduce_flashing it
## holds its first frame still.

const _MIN_HOLD_SECONDS: float = 0.05
const _MAX_HOLD_SECONDS: float = 0.12

## Cosmetic only, so it keeps off the game's seeded RNG buckets.
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _hold_left: float = 0.0


func _ready() -> void:
	stop()


func is_playing() -> bool:
	return visible and texture != null


## Starts crackling with [param sheet], a horizontal strip of square frames
## drawn over the portrait.
func play(sheet: Texture2D) -> void:
	frame = 0
	texture = sheet
	hframes = maxi(sheet.get_width() / maxi(sheet.get_height(), 1), 1)
	_hold_left = _MAX_HOLD_SECONDS
	show()
	set_process(not Globals.reduce_flashing and hframes > 1)


func stop() -> void:
	hide()
	frame = 0
	hframes = 1
	texture = null
	set_process(false)


func _process(delta: float) -> void:
	_hold_left -= delta
	if _hold_left > 0.0:
		return
	_hold_left = _rng.randf_range(_MIN_HOLD_SECONDS, _MAX_HOLD_SECONDS)
	# Any frame but the one showing, so every hold is a visible jump.
	var next: int = _rng.randi_range(0, hframes - 2)
	if next >= frame:
		next += 1
	frame = next
