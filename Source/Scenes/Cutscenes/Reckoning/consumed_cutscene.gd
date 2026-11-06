class_name ConsumedCutscene
extends ReckoningCutsceneSegment
## The player's ship taken by Fate at the end of the Reckoning, in one of two
## opposite ways (RECKONING_ENDINGS.md §6.4 shot 1, §6.6):
##
## | Mode     | What it is                                                     |
## |----------|----------------------------------------------------------------|
## | LAST_DIE | Quiet acceptance. The last die is gone with the last ally. The |
## |          | hull is whole; its gold flames go out one by one, each with a  |
## |          | soft click, while Fate's purple creeps over it from the hole's |
## |          | side. It drifts back into the hole as the shot pulls out,      |
## |          | stretching a little at the rim, a point of light, gone. The    |
## |          | music has fallen away to one note, which ends with the light.  |
## |          | Purple, then black. The arrival (shot 2) follows.              |
## | FELL_IN  | Violent and short, since players will retry. The hull cracks,  |
## |          | its drive blows out, and the hole wrenches it round nose-down  |
## |          | and stretches it while the shot pushes in hard. The last       |
## |          | frames are exactly the Fallen (FateLedger._dress_as_fallen):   |
## |          | the ghost a later run will meet is born on screen. Then black  |
## |          | and the YOU FELL IN screen.                                    |
##
## Built like the first ending (EndingCutscene): everything that is art lives
## in the PixelWorld SubViewport, 320x180 blown up 6x, and the starfield sits
## behind it at 1080p so it glides. Each mode is an animation on the
## AnimationPlayer ("last_die", "fell_in"): paths, the shot, the hull's
## colour and the fades are keyed there, and its method track calls the
## one-shot effects below. The hull itself is a ConsumedHull.
##
## Camera direction is the two endings' difference: the Last Die only ever
## pulls out, slowly; Fell In only pushes in, fast.

@export_category('Starfield')
@export var num_of_stars: int = 110
@export var num_of_twinkling_stars: int = 25
@export var star_pixel_scene: PackedScene
@export var star_twinkle_scene: PackedScene
## Keyed. How the stars drift, in art pixels per second (nearest stars).
@export var star_drift: Vector2 = Vector2.ZERO
## Keyed. How far each star smears along its drift, as a multiple of its width.
@export var star_stretch: float = 1.0

@export_category('Shot')
## Keyed. How far the shot is pushed in on the 320x180 frame; 1 shows all of
## it. Held on multiples of 1/6, as in the opening.
@export var view_zoom: float = 1.0
## Keyed. The point of the frame, in art pixels, the shot centres on.
@export var view_center: Vector2 = Vector2(160, 90)

@export_category('Fate')
## Keyed. Whether Fate throws its lightning about on its own.
@export var fate_weather: bool = false

@export_category('Hull')
## Keyed. How far the hull has receded into the hole: 0 full size, 1 a single
## point of light. Shrunk the way PixelArtShrinker shrinks art.
@export var recede: float = 0.0
## Keyed. How bright that last point of light is, 0-1.
@export var light: float = 0.0

# Borrowed sounds, until this cutscene's own are made. The Last Die's
# sustained note is synthesised for now (SustainedNote).
const _CLICK_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/die_dead_click.tres")
const _CRACK_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/glass_crack.tres")
const _BLOWOUT_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/enemy_pre_death.tres")
const _HIT_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/player_health_hit.tres")
const _FATE_PULSE_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/die_dread_thunk.tres")
const _GLITCH_SCENE: PackedScene = preload("res://Source/Systems/UI/Glitch/glitch_shader.tscn")

const _FATE_PURPLE: Color = Color("#c552f1")
const _ART_SCALE: float = 6.0
## The dark heart of the hole, round Fate's centre, in art pixels.
const _FATE_RIM: float = 40.0
## Seconds the curtain takes to close on a skip.
const _SKIP_FADE: float = 0.25

var _stars: Array[Node2D] = []
var _star_depths: PackedFloat32Array = PackedFloat32Array()
var _note: SustainedNote
## Rings drawn straight onto the art grid (Juice.ring would draw through a
## viewport of its own that tracks the game's camera, not this shot).
var _jump_fx: JumpFx
var _engines_out: Tween
var _hidden_cursor_layer: CanvasLayer

@onready var _star_layer: CanvasLayer = $StarLayer
@onready var _pixel_layer: CanvasLayer = $PixelLayer
@onready var _pixel_screen: SubViewportContainer = $PixelLayer/PixelScreen
@onready var _curtain: ColorRect = $CurtainLayer/Curtain
@onready var _effects: Node2D = %Effects
@onready var _fate: Node2D = %Fate
@onready var _storm: FateStorm = %FateStorm
@onready var _hull: ConsumedHull = %Hull
@onready var _point: PointOfLight = %PointOfLight
@onready var _timeline: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	var skip: CutsceneSkipPrompt = CutsceneSkipPrompt.new(96)
	skip.confirmed.connect(_skip)
	add_child(skip)
	_hide_cursor(true)
	_jump_fx = JumpFx.new(_effects, true)
	_spawn_stars()
	_hull.dress(_ship())
	_hull.flame_out.connect(_on_flame_out)
	_note = SustainedNote.new()
	add_child(_note)
	var glitch: CanvasLayer = CanvasLayer.new()
	glitch.layer = 94
	glitch.add_child(_GLITCH_SCENE.instantiate())
	add_child(glitch)

	# Up out of black: the animation's first key holds the Fade over the shot.
	_timeline.play(&"fell_in" if mode == Mode.FELL_IN else &"last_die")
	_timeline.advance(0.0)


func _exit_tree() -> void:
	_hide_cursor(false)


func _process(delta: float) -> void:
	_frame_shot()
	_move_stars(delta)
	_storm.autonomous = fate_weather
	_aim_wash()
	_show_recede()


## The hull this run flew: the ending's ship, else the one selected.
func _ship() -> ShipResource:
	var ship: ShipResource = null
	if ending and not String(ending.ship_id).is_empty():
		ship = ShipCatalog.find(ending.ship_id)
	return ship if ship else Globals.current_ship()


# --- Shot -------------------------------------------------------------------

## As the first ending frames its shot: the finished 320x180 picture and the
## starfield are scaled together, so nothing inside the art grid zooms.
func _frame_shot() -> void:
	var art_scale: float = float(_pixel_screen.stretch_shrink)
	var zoom: float = maxf(view_zoom, 1.0)
	var half_view: Vector2 = Globals.SCREEN_SIZE / (2.0 * zoom)
	var centre: Vector2 = view_center.clamp(half_view, Globals.SCREEN_SIZE - half_view)
	var screen: Vector2 = Globals.SCREEN_SIZE * _ART_SCALE
	_star_layer.scale = Vector2.ONE * art_scale * zoom
	_star_layer.offset = screen / 2.0 - centre * art_scale * zoom
	_pixel_layer.scale = Vector2.ONE * zoom
	# Whole screen pixels, so the art grid never lands between them.
	_pixel_layer.offset = (screen / 2.0 - centre * art_scale * zoom).round()


# --- Starfield --------------------------------------------------------------

func _spawn_stars() -> void:
	for i: int in range(num_of_stars + num_of_twinkling_stars):
		var scene: PackedScene = star_pixel_scene if i < num_of_stars else star_twinkle_scene
		var star: Node2D = scene.instantiate()
		%Stars.add_child(star)
		star.position = Vector2(_randf(0, Globals.SCREEN_SIZE.x), _randf(0, Globals.SCREEN_SIZE.y))
		var depth: float = _randf(0.3, 1.0)
		star.modulate = Color(1, 1, 1, lerpf(0.25, 0.8, depth))
		_stars.append(star)
		_star_depths.append(depth)


## Stars drift with [member star_drift], smear along it, and wrap round the
## frame.
func _move_stars(delta: float) -> void:
	var bounds: Rect2 = Rect2(Vector2.ZERO, Globals.SCREEN_SIZE).grow(4.0)
	for i: int in range(_stars.size()):
		var star: Node2D = _stars[i]
		var depth: float = _star_depths[i]
		star.position += star_drift * depth * delta
		star.rotation = star_drift.angle() if star_drift.length_squared() > 0.01 else 0.0
		star.scale.x = lerpf(1.0, star_stretch, depth)
		if not bounds.has_point(star.position):
			star.position = Vector2(
				wrapf(star.position.x, bounds.position.x, bounds.end.x),
				wrapf(star.position.y, bounds.position.y, bounds.end.y))


# --- The hull ---------------------------------------------------------------

## Fate's cloak always comes from the hole's side of the hull, however the
## hull is turned.
func _aim_wash() -> void:
	var to_hole: Vector2 = (_fate.global_position - _hull.global_position).rotated(-_hull.global_rotation)
	if _hull.flip_h:
		to_hole.x = -to_hole.x
	if _hull.flip_v:
		to_hole.y = -to_hole.y
	if to_hole.length_squared() > 0.01:
		_hull.wash_from = to_hole.normalized()


## Receding into the hole the hull shrinks a pixel at a time, then is a point
## of light where it was.
func _show_recede() -> void:
	if recede <= 0.0:
		_hull.width = 0
	elif recede < 1.0:
		_hull.width = maxi(2, roundi(lerpf(float(_hull.frame_width()), 2.0, recede)))
	_hull.visible = recede < 1.0
	_point.global_position = _hull.global_position
	_point.brightness = light


## The flames go out one at a time across [param seconds].
func _engines_go_out(seconds: float) -> void:
	var order: Array[int] = _hull.snuff_order()
	if order.is_empty():
		return
	var gap: float = seconds / order.size()
	_engines_out = create_tween()
	for i: int in order.size():
		if i > 0:
			_engines_out.tween_interval(gap)
		_engines_out.tween_callback(_hull.snuff.bind(order[i], minf(gap * 0.9, 1.1)))


## A soft click as each flame goes, and a last ember off the nozzle.
func _on_flame_out(_index: int, at: Vector2) -> void:
	Events.play_sound.emit(_CLICK_SFX)
	if mode == Mode.LAST_DIE:
		Juice.sparkle(_effects, _hull.to_global(at), EngineCharger.DRIVE_COLOR, 2, 8.0)


# --- The Last Die -----------------------------------------------------------

## The fight's music falls away to the one note.
func _music_falls_away(seconds: float) -> void:
	MusicDirector.stop(seconds)


func _note_swells(seconds: float) -> void:
	_note.swell(seconds)


## The point of light crosses the horizon: the note ends with it, and the
## hole breathes once.
func _light_gone() -> void:
	_note.release(0.5)
	Juice.sparkle(_effects, _point.global_position, _FATE_PURPLE, 3, 10.0)
	_storm.strike(FateStorm.Kind.SHEET, 0.6)


# --- Fell In ----------------------------------------------------------------

## The music cuts: the cockpit's death has already played.
func _music_cut() -> void:
	MusicDirector.stop(0.15)


## The hull gives: a crack opens, lit from inside.
func _crack_hit(strength: float) -> void:
	var spot: Vector2 = _hull.global_position
	Events.play_sound.emit(_CRACK_SFX)
	Events.play_sound.emit(_HIT_SFX)
	Events.camera_shake_large.emit()
	TimeDirector.hitstop(int(60 * strength))
	Events.glitch_burst.emit(int(110 * strength))
	_hull.flash(Globals.white, 0.8, 0.25)
	Juice.sparkle(_effects, spot, Globals.white, int(6 * strength), 40.0 * strength)
	Juice.sparkle(_effects, spot, _FATE_PURPLE, int(10 * strength), 55.0 * strength)
	_jump_fx.ring(spot, _FATE_PURPLE, 3.0, 18.0 + 10.0 * strength, 0.35)
	_storm.strike_from(_storm.to_local(_fate.global_position), 2 + int(strength * 2), 90.0, _FATE_RIM, 0.8)


## The drive blows out all at once against the pull.
func _drive_blows() -> void:
	Events.play_sound.emit(_BLOWOUT_SFX)
	Events.camera_shake_large.emit()
	_hull.strain(false)
	for i: int in _hull.flame_count():
		var at: Vector2 = _hull.to_global(_hull.flame_nozzle(i))
		Juice.sparkle(_effects, at, EngineCharger.DRIVE_COLOR, 6, 45.0)
		Juice.sparkle(_effects, at, Globals.orange, 4, 30.0)
	_hull.set_all_flames(0.0)


## Fate pulls: the hole flares and throws lightning at the hull.
func _fate_pull() -> void:
	Events.play_sound.emit(_FATE_PULSE_SFX)
	Events.camera_shake_small.emit()
	_storm.strike(FateStorm.Kind.TEAR)
	_storm.strike_from(_storm.to_local(_fate.global_position), 4, 70.0, _FATE_RIM)


## The purple has it: the Fallen's flames light again, in its own colours,
## washed through with Fate, and the hull holds still as the ghost will.
func _fallen_born() -> void:
	Events.play_sound.emit(_FATE_PULSE_SFX)
	Events.glitch_burst.emit(90)
	_hull.hold_first_frame()
	_hull.plumes = false
	_hull.set_all_flames(1.0)
	_hull.flash(_FATE_PURPLE, 0.7, 0.4)
	_jump_fx.ring(_hull.global_position, _FATE_PURPLE, 6.0, 26.0, 0.45)


func _strain(straining: bool) -> void:
	_hull.strain(straining)


# --- Hand-over --------------------------------------------------------------

## Keyed on black at the end of each mode.
func _end() -> void:
	_timeline.pause()
	_stop_sound()
	finish(false)


## A second press of anything: straight to black, and the whole ending is
## skipped.
func _skip() -> void:
	if _finished:
		return
	_timeline.pause()
	if _engines_out:
		_engines_out.kill()
	_stop_sound()
	var close: Tween = create_tween()
	close.tween_property(_curtain, "color:a", 1.0, _SKIP_FADE)
	close.tween_callback(finish.bind(true))


func _stop_sound() -> void:
	_note.release(0.2)
	MusicDirector.stop(0.2)


## The game's pointer would float over the film; it comes back once this
## segment is gone.
func _hide_cursor(hide_it: bool) -> void:
	var scene: Node = get_tree().current_scene if is_inside_tree() else null
	if hide_it:
		_hidden_cursor_layer = scene.get_node_or_null(^"CursorLayer") as CanvasLayer if scene else null
		if _hidden_cursor_layer and _hidden_cursor_layer.visible:
			_hidden_cursor_layer.visible = false
		else:
			_hidden_cursor_layer = null
	elif is_instance_valid(_hidden_cursor_layer):
		_hidden_cursor_layer.visible = true
		_hidden_cursor_layer = null


func _randf(from: float, to: float) -> float:
	return RNGManager.randf_range(RNGManager.Bucket.COSMETIC, from, to)
