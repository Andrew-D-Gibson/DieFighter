@tool
class_name TileUseLights
extends RefCounted
## The use lights on a limited tile's art, and how they change: a light that
## goes out pops in a burst of white sparks, and lights coming back (a new
## turn's refill) switch on one at a time, each drawing sparks in as it does.
## Only the look: Tile keeps the count, which always changes at once, so a die
## dropped mid-refill is judged on the real uses, not on the lights.
##
## The frames come from tools/add_use_lights.lua: frame k has k lights lit.

## Where the bottom light sits on the 24x24 art, from its centre, and how far
## up each next one is. add_use_lights.lua carves 2x2 slots at x 20-21, from
## y 20 upward, 3 px apart.
const _BOTTOM_LIGHT: Vector2 = Vector2(9.0, 9.0)
const _LIGHT_STEP: float = 3.0

## How long a light's sparks take to fall in, and how far behind it the next
## light starts, so a refill reads as one light after another rather than all
## at once.
const _GATHER_SECONDS: float = 0.2
const _NEXT_LIGHT_SECONDS: float = 0.14

var _tile: Tile
## How many lights the sprite shows right now, which trails Tile.uses_remaining
## while a refill plays.
var _shown: int = 0
var _refill: Tween


func _init(tile: Tile) -> void:
	_tile = tile


## Shows [param lit] lights, popping the ones that go out and switching the
## ones that come back on one by one. [param animate] false just sets them,
## for a tile being set up or one that isn't in play.
func show_lit(lit: int, animate: bool = true) -> void:
	if _refill and _refill.is_valid():
		_refill.kill()
	if not animate or Engine.is_editor_hint() or not _tile.is_visible_in_tree():
		_set_frame(lit)
		return

	if lit < _shown:
		for light: int in range(lit + 1, _shown + 1):
			Juice.sparkle(_tile, _light_position(light), Globals.white, 7, 30.0)
		_set_frame(lit)
	elif lit > _shown:
		_refill = _tile.create_tween().set_parallel(true)
		for step: int in lit - _shown:
			var light: int = _shown + step + 1
			var starts: float = step * _NEXT_LIGHT_SECONDS
			_refill.tween_callback(_gather_into.bind(light)).set_delay(starts)
			_refill.tween_callback(_set_frame.bind(light)).set_delay(starts + _GATHER_SECONDS)


func _gather_into(light: int) -> void:
	Juice.gather(_tile, _light_position(light), Globals.white, 5, 7.0, _GATHER_SECONDS)


func _set_frame(lit: int) -> void:
	_shown = lit
	_tile.sprite_frames.frame = lit


## Light [param light] (1 = the bottom one) in global space.
func _light_position(light: int) -> Vector2:
	var local: Vector2 = _BOTTOM_LIGHT + Vector2(0.0, -_LIGHT_STEP * (light - 1))
	return _tile.sprite_frames.to_global(local)
