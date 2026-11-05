class_name LivingSky
extends Node2D
## Keeps a settled sky from reading as a still image. A jump in is all motion
## (the stars stream, the planet slides into place), then the stars hold
## still, so on its own the sky would snap to a picture. Once it has settled,
## the main menu's space dust drifts in over it; a jump fades the dust out
## again, since dust that ignores the streaming stars would look pinned to the
## glass.
##
## Cosmetic only: nothing here touches the board or draws from a gameplay RNG
## stream. Drawn in art pixels with its origin at the screen's top-left.

@export_group("Dust")
@export var dust: CPUParticles2D
## In place of the dust scene's own colour: the menu's grey vanishes against
## a battle sky, which is lighter than the menu's near-black.
@export var dust_color: Color = Color("#63605C")
## How visible the dust is once it has faded in. Kept low: it sits behind play.
@export_range(0.0, 1.0) var dust_opacity: float = 0.6
@export var dust_fade_in_seconds: float = 2.5
@export var dust_fade_out_seconds: float = 0.3

var _settled: bool = false
var _dust_tween: Tween


func _ready() -> void:
	dust.color = dust_color
	dust.modulate.a = 0.0


## Called by BackgroundManager whenever the sky starts or stops holding still.
func set_settled(settled: bool) -> void:
	if settled == _settled:
		return
	_settled = settled
	_fade_dust(dust_opacity if settled else 0.0,
		dust_fade_in_seconds if settled else dust_fade_out_seconds)


func is_settled() -> bool:
	return _settled


func _fade_dust(to_alpha: float, seconds: float) -> void:
	if _dust_tween:
		_dust_tween.kill()
	_dust_tween = create_tween()
	_dust_tween.tween_property(dust, "modulate:a", to_alpha, seconds)
