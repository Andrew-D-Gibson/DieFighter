extends ReckoningCutsceneSegment
## Become Fate (RECKONING_ENDINGS.md §6.5, from step 2): the hole recognises
## its own, and the game loops. The player has destroyed "You"; this is what
## follows, out of black, through the credits, back to black.
##
## 1. What's left of "You" comes apart in glitch slices, and the small Fate's
##    Die floats free of it, across to the ship, and settles into the canopy.
## 2. The purple spreads from the nose back, a pixel row at a time, and the
##    Horizon Drive's gold goes purple.
## 3. The shot pulls back onto the hole. The ship turns to face it, flies in,
##    and the camera follows it down through the centre without a cut: the
##    hole grows round the frame, the stars stream in and bend at the rim,
##    and the ship dwindles into the dark until the core is all there is.
## 4. The camera turns. Now we're looking out of the hole: the frame is ringed
##    by its swirling rim, the stars bend at the edge, debris falls toward us,
##    and far off a small ship claws away on the opening's cyan, two
##    Attackers behind it. One Attacker's drive gives out and the hole (us)
##    takes it. The small ship jumps; the other Attacker follows. The
##    opening's theme plays under it, slowed and lowered.
## 5. Hold. The die tumbles once in the dark foreground and lands on a face.
## 6. The credits fall (falling_credits.gd), and the screen goes to black.
##
## "From the hole's side" has to read without a word, so the reverse shot is
## the opening's own staging turned round: the same three ships, the same
## lost Attacker, the same cyan jump, the same theme, with the hole's rim
## where the frame's edge was.
##
## Built like the first ending (EndingCutscene): everything that is art lives
## in the PixelWorld SubViewport, 320x180 blown up 6x, with the starfield
## behind it at 1080p so it glides. The film is one Tween sequence (_film());
## the per-frame motion it drives (the shot, the stars, the dive) is here.
## Nothing inside the art grid is zoomed: the push-ins scale the finished
## picture, and the dive grows the hole by redrawing it bigger at one shader
## pixel per art pixel, and shrinks the ship through PixelArtShrinker.
##
## Plays mode BECOME_FATE only.

@export_category('Starfield')
@export var num_of_stars: int = 110
@export var num_of_twinkling_stars: int = 25
@export var star_pixel_scene: PackedScene
@export var star_twinkle_scene: PackedScene

## How far the shot is pushed in on the 320x180 frame; 1 shows all of it.
## Held on whole art-pixel scales, as in the opening.
var view_zoom: float = 2.0
## The point of the frame, in art pixels, the shot centres on.
var view_center: Vector2 = Vector2(196, 90)
## How fast the stars glide past, in art pixels per second, outside the dive.
var star_speed: float = 3.0
## How far into the hole the dive has gone: 0 the ship still outside, 1 the
## core filling the frame.
var dive: float = 0.0:
	set(value):
		dive = value
		_apply_dive()
## Rows of the hull the purple has taken, from the nose.
var washed_rows: float = 0.0:
	set(value):
		washed_rows = floorf(value)
		_hull_material.set_shader_parameter("washed_rows", washed_rows)
## The camera turning round into the hole's point of view: radians the
## reverse shot is still turned by.
var turn: float = 0.0:
	set(value):
		turn = value
		_mouth_sky.turn = value
		_far_ships.rotation = value
		_rim_material.set_shader_parameter("turn", value)

const _ART_SCALE: float = 6.0
const _CENTER: Vector2 = Vector2(160, 90)
const _PIXEL_TEXTURE: Texture2D = preload("res://Assets/Particles/hit_particle_pixel.png")
const _SNAP_SHADER: Shader = preload("res://Assets/Shaders/palette_snap.gdshader")
const _FLASH_SHADER: Shader = preload("res://Assets/Shaders/enemy_shader.gdshader")
const _ATTACKER_TEXTURE: Texture2D = preload("res://Assets/Textures/Enemies/Attacker/attacker.png")
const _GLITCH_SCENE: PackedScene = preload("res://Source/Systems/UI/Glitch/glitch_shader.tscn")
const GlitchRemains = preload("res://Source/Scenes/Cutscenes/Reckoning/BecomeFate/glitch_remains.gd")
const ThrownFateDie = preload("res://Source/Scenes/Cutscenes/Reckoning/BecomeFate/thrown_fate_die.gd")
const FallingCredits = preload("res://Source/Scenes/Cutscenes/Reckoning/BecomeFate/falling_credits.gd")

# Borrowed sounds. The ones this wants made are in the report that shipped
# it (and RECKONING_ENDINGS.md §10, Music).
const _FATE_PULSE_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/die_dread_thunk.tres")
const _DIE_HOME_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/tractor_lock.tres")
const _DIE_STILL_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/die_dead_click.tres")
const _DRIVE_TAKEN_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/upgrade_trigger.tres")
const _ENGINES_OUT_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/enemy_pre_death.tres")
const _CONSUMED_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/enemy_death_explosion.tres")
const _DIE_LANDS_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/tile_dropped.tres")

## The opening's run track, slowed and lowered: the same throw, heard from
## the other end.
const _OPENING_TRACK: StringName = &"trailer_1"
const _OPENING_PITCH: float = 0.72
## What the menu plays: the credits hand straight off to it.
const _MENU_TRACK: StringName = &"game_start_theme"

## Approved palette.
const _FATE_PURPLE: Color = Color("#c552f1")
const _DEEP_PURPLE: Color = Color("#80359d")
const _GOLD: Color = Color("#eed35d")
const _CYAN: Color = Color("#8df1f4")

## Where "You" came apart and the die floats out of, and the ship it floats
## to: the first shot.
const _REMAINS_AT: Vector2 = Vector2(246, 86)
const _SHIP_AT: Vector2 = Vector2(168, 94)
## Where the ship has flown to, nose to the hole, when the dive takes it.
const _DIVE_FROM: Vector2 = Vector2(134, 94)
## The canopy, in the hull's own nose-up pixels.
const _CANOPY: Vector2 = Vector2(0, -3)
## Fate's black hole as the opening framed it: its scale, and how many
## pixels its disk and core shaders draw across at scale 1.
const _HOLE_AT: Vector2 = Vector2(44, 90)
const _HOLE_SCALE: float = 1.4
const _DISK_PIXELS: float = 300.0
const _CORE_PIXELS: float = 100.0
## The core's radius at scale 1 (black_hole.tscn: a 100-unit rect, radius
## 0.265 of it).
const _CORE_RADIUS: float = 26.5
## How far the dive grows the hole: enough for its core to swallow the frame.
const _DIVE_GROWTH: float = 9.0
## The share of the dive by which the ship is gone into the centre.
const _SHIP_GONE_AT: float = 0.72
## Widths the ship steps down through as it falls away, in art pixels.
const _DIVE_WIDTHS: Array[int] = [26, 22, 18, 14, 11, 8, 6, 4, 3, 2, 1]

## The reverse shot: the mouth's radius, and where the far ships are, from
## its middle.
const _MOUTH_RADIUS: float = 80.0
const _RUNNER_FROM: Vector2 = Vector2(2, 26)
const _RUNNER_TO: Vector2 = Vector2(0, 2)
const _SURVIVOR_FROM: Vector2 = Vector2(-28, 40)
const _SURVIVOR_TO: Vector2 = Vector2(-12, 16)
const _DOOMED_FROM: Vector2 = Vector2(30, 44)
## Widths the small ships are drawn at: the runner far off, the Attackers
## nearer.
const _RUNNER_WIDTHS: Array[int] = [15, 13, 12, 11, 10, 9, 8]
const _ATTACKER_WIDTH: int = 11
const _DOOMED_WIDTHS: Array[int] = [11, 13, 16, 20, 25, 31]

var _hull: ShipResource
var _hull_material: ShaderMaterial
var _rim_material: ShaderMaterial
var _jump_fx: JumpFx
var _stars: Array[Node2D] = []
var _star_depths: PackedFloat32Array = PackedFloat32Array()
var _exhaust: Array[CPUParticles2D] = []
## The ship as it falls away into the hole: a still frame, shrunk.
var _falling_ship: Sprite2D
var _small_die: Sprite2D
var _disk_material: ShaderMaterial
var _core_material: ShaderMaterial
var _runner: Sprite2D
var _survivor: Sprite2D
var _doomed: Sprite2D
var _die: ThrownFateDie
var _die_sprite: Sprite2D
var _credits: FallingCredits
var _film_tween: Tween
var _age: float = 0.0
var _ending_film: bool = false
var _hidden_cursor_layer: CanvasLayer

@onready var _star_layer: CanvasLayer = $StarLayer
@onready var _pixel_layer: CanvasLayer = $PixelLayer
@onready var _pixel_screen: SubViewportContainer = $PixelLayer/PixelScreen
@onready var _curtain: ColorRect = %Curtain
@onready var _effects: Node2D = %Effects
@onready var _world: Node2D = %World
@onready var _fate: Node2D = %Fate
@onready var _black_hole: Node2D = %BlackHole
@onready var _storm: FateStorm = %FateStorm
@onready var _ship: AnimatedSprite2D = %PlayerShip
@onready var _mouth: Node2D = %Mouth
@onready var _mouth_sky: Node2D = %Sky
@onready var _far_ships: Node2D = %FarShips


func _ready() -> void:
	var skip: CutsceneSkipPrompt = CutsceneSkipPrompt.new(96)
	skip.confirmed.connect(_skip)
	add_child(skip)
	_hide_cursor(true)
	var glitch: CanvasLayer = CanvasLayer.new()
	glitch.layer = 94
	glitch.add_child(_GLITCH_SCENE.instantiate())
	add_child(glitch)

	_hull = ShipCatalog.find(ending.ship_id if ending else &"")
	_hull_material = _ship.material as ShaderMaterial
	_rim_material = (%Rim as ColorRect).material as ShaderMaterial
	_jump_fx = JumpFx.new(_effects, true)
	_own_hole_materials()
	_spawn_stars()
	_dress_player_ship()
	_add_exhaust()
	_build_small_die()
	_build_far_ships()
	_build_thrown_die()
	_frame_shot()
	# The fight's music goes under the black: the first shots are quiet.
	MusicDirector.stop(1.5)
	_film()


func _process(delta: float) -> void:
	_age += delta
	_frame_shot()
	_move_stars(delta)
	_rim_material.set_shader_parameter("time", _age)
	_storm.visible = _world.visible


# --- The film ---------------------------------------------------------------

## The whole cutscene, shot by shot, as one sequence. A skip kills it.
func _film() -> void:
	_film_tween = create_tween()
	var t: Tween = _film_tween
	# Up out of black on what's left of "You".
	t.tween_property(_curtain, "color:a", 0.0, 1.2).set_ease(Tween.EASE_OUT)
	t.parallel().tween_callback(_you_comes_apart).set_delay(0.2)
	t.tween_interval(0.5)
	_die_comes_home(t)
	_purple_takes_the_hull(t)
	_into_the_hole(t)
	_out_of_the_hole(t)
	_the_throw(t)
	t.tween_callback(_roll_credits)


## Shot 1. "You" is glitch slices pulling apart; the die above it has
## stopped turning. It floats free, across to the ship, and settles where
## the canopy die hung.
func _die_comes_home(t: Tween) -> void:
	t.tween_callback(func() -> void: Events.play_sound.emit(_DIE_STILL_SFX))
	t.tween_interval(0.8)
	var canopy: Vector2 = _SHIP_AT + _CANOPY.rotated(_ship.rotation)
	var from: Vector2 = _small_die.position
	# A slow, slightly sagging arc: drifting, not flying.
	t.tween_method(func(p: float) -> void:
		var at: Vector2 = from.lerp(canopy, p)
		at.y += sin(p * PI) * 9.0
		_small_die.position = at.round(),
		0.0, 1.0, 3.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(self, "view_center", Vector2(184, 92), 3.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_callback(_die_settles)
	t.tween_interval(0.5)


## Shot 2. Close on the ship: the purple spreads back from the nose a pixel
## row at a time, then the gold engines stutter and go purple.
func _purple_takes_the_hull(t: Tween) -> void:
	t.tween_property(self, "view_zoom", 3.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(self, "view_center", _SHIP_AT, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_callback(func() -> void: Events.play_sound.emit(_FATE_PULSE_SFX))
	var rows: float = _hull_rows()
	t.tween_property(self, "washed_rows", rows, rows * 0.15)
	t.tween_interval(0.35)
	for flicker: int in 5:
		t.tween_callback(_hull_material.set_shader_parameter.bind("drive_purple", float(flicker % 2 == 0)))
		t.tween_interval(0.09 if flicker < 4 else 0.0)
	t.tween_callback(_drive_taken)
	t.tween_interval(1.2)


## Shot 3. Pull back onto the hole; the ship turns to face it, goes in, and
## the camera follows it down through the centre into black.
func _into_the_hole(t: Tween) -> void:
	t.tween_property(self, "view_zoom", 1.0, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(self, "view_center", _CENTER, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_callback(_fate_pulse.bind(1.0)).set_delay(0.9)
	t.tween_interval(0.3)
	t.tween_callback(_rcs_burst)
	# A half turn, slow and deliberate: it stops running.
	t.tween_property(_ship, "rotation", _ship.rotation + PI, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_callback(_rcs_burst)
	t.tween_interval(0.4)
	t.tween_property(_ship, "position", _DIVE_FROM, 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(_begin_dive)
	t.tween_property(self, "dive", 1.0, 6.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.parallel().tween_callback(_fate_pulse.bind(1.0)).set_delay(1.0)
	t.parallel().tween_callback(_fate_pulse.bind(1.6)).set_delay(3.4)
	# Through the centre: black.
	t.tween_property(%Fade, "color:a", 1.0, 0.25)
	t.tween_interval(0.6)


## Shot 4. The camera turns: out of the hole, at the opening, from Fate's
## side.
func _out_of_the_hole(t: Tween) -> void:
	t.tween_callback(_begin_reverse_shot)
	t.tween_interval(0.6)
	t.tween_property(%Fade, "color:a", 0.0, 1.8).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "turn", 0.0, 3.4).from(-1.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_method(func(p: float) -> void: _mouth_sky.fall = p, 0.0, 1.0, 3.0)
	t.tween_interval(1.4)
	t.tween_callback(_engines_out)
	t.tween_interval(0.5)
	t.tween_method(_drag_doomed_in, 0.0, 1.0, 2.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(_doomed_consumed)
	t.tween_interval(1.2)
	t.tween_callback(_charge_far.bind(_runner, _CYAN, 1.2))
	t.tween_interval(1.2)
	t.tween_callback(_jump_far.bind(_runner, _CYAN))
	t.tween_interval(0.5)
	t.tween_callback(_charge_far.bind(_survivor, JumpFx.RED, 0.9))
	t.tween_interval(0.9)
	t.tween_callback(_jump_far.bind(_survivor, JumpFx.RED))
	# Hold on the empty mouth.
	t.tween_interval(2.4)


## Shot 5. In the dark foreground, the die tumbles once and lands on a face.
func _the_throw(t: Tween) -> void:
	t.tween_property(%Dim, "color:a", 0.5, 1.2)
	t.tween_callback(_throw_die)
	t.tween_property(_die_sprite, "position:y", 100.0, 1.0).from(-40.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(_die, "throw_progress", 1.0, 1.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_callback(_die_lands)
	t.tween_property(_die_sprite, "position:y", 96.0, 0.12).set_ease(Tween.EASE_OUT)
	t.tween_property(_die_sprite, "position:y", 100.0, 0.18).set_ease(Tween.EASE_IN)
	t.tween_interval(0.9)
	t.tween_callback(_die_glints)
	t.tween_interval(1.8)


# --- Shot 1: the die ------------------------------------------------------------

func _you_comes_apart() -> void:
	var remains: GlitchRemains = GlitchRemains.new()
	%Remains.add_child(remains)
	remains.position = _REMAINS_AT
	Events.glitch_burst.emit(240)
	Events.camera_shake_small.emit()


## The small die, as it hangs from the canopy all run: bone white, carved,
## at its own pixel size.
func _build_small_die() -> void:
	_small_die = Sprite2D.new()
	_small_die.texture = FateDieArt.face_texture(_die_faces()[0])
	_small_die.z_index = 12
	_world.add_child(_small_die)
	_small_die.position = _REMAINS_AT + Vector2(0, -4)


## The die reaches the canopy: a glint, and it's aboard.
func _die_settles() -> void:
	Events.play_sound.emit(_DIE_HOME_SFX)
	Juice.glint(_effects, _small_die.global_position, Globals.white, 6.0, 0.5)
	_jump_fx.ring(_small_die.global_position, _FATE_PURPLE, 1.0, 9.0, 0.45)
	_small_die.visible = false
	JumpFx.flare(_ship, _FATE_PURPLE, 0.4)


# --- Shot 2: the hull ----------------------------------------------------------

## The engines go purple: the drive is Fate's now.
func _drive_taken() -> void:
	Events.play_sound.emit(_DRIVE_TAKEN_SFX)
	Events.camera_shake_small.emit()
	_hull_material.set_shader_parameter("drive_purple", 1.0)
	# The hot row has nowhere left to go.
	washed_rows = _hull_rows() + 2.0
	JumpFx.flare(_ship, _FATE_PURPLE, 0.6)
	for exhaust: CPUParticles2D in _exhaust:
		exhaust.color = _FATE_PURPLE
		Juice.sparkle(_effects, exhaust.global_position, _FATE_PURPLE, 6, 24.0)


func _hull_rows() -> float:
	var frame: Texture2D = _ship.sprite_frames.get_frame_texture(_ship.animation, 0) if _ship.sprite_frames else null
	return float(frame.get_height()) if frame else 28.0


# --- Shot 3: into the hole ------------------------------------------------------

## Fate breathing, as in the opening: a ring off the hole, lightning off its
## rim, a shudder.
func _fate_pulse(strength: float) -> void:
	Events.play_sound.emit(_FATE_PULSE_SFX)
	var centre: Vector2 = _fate.global_position
	var reach: float = _hole_radius()
	_jump_fx.ring(centre, _FATE_PURPLE, reach * 0.8, reach * (1.2 + 0.3 * strength), 0.9)
	_storm.strike_from(_storm.to_local(centre), int(3 + 2 * strength), reach * 0.9, reach * 0.55, 0.8)
	if strength > 1.0:
		_flash_screen(_FATE_PURPLE, 0.3, 0.5)
		Events.camera_shake_large.emit()
	else:
		Events.camera_shake_small.emit()


## Manoeuvring thrusters on both flanks.
func _rcs_burst() -> void:
	var flank: Vector2 = Vector2.RIGHT.rotated(_ship.rotation) * 10.0
	Juice.sparkle(_effects, _ship.global_position + flank, Globals.white, 5, 30.0)
	Juice.sparkle(_effects, _ship.global_position - flank, Globals.white, 5, 30.0)


## From here the ship is a still frame that shrinks as it falls away, so
## no zoom ever scales its art.
func _begin_dive() -> void:
	_falling_ship = Sprite2D.new()
	_falling_ship.material = _hull_material
	_falling_ship.rotation = _ship.rotation
	_ship.get_parent().add_child(_falling_ship)
	for exhaust: CPUParticles2D in _exhaust:
		exhaust.reparent(_falling_ship)
	_ship.visible = false
	_apply_dive()


## Lays out the dive at [member dive]: the hole slides to the middle of the
## frame and grows round it, redrawn at one shader pixel per art pixel, and
## the ship falls away into its centre.
func _apply_dive() -> void:
	if not is_node_ready() or _falling_ship == null:
		return
	var growth: float = pow(_DIVE_GROWTH, dive)
	var centre: Vector2 = _HOLE_AT.lerp(_CENTER, smoothstep(0.0, 0.55, dive))
	_fate.position = centre.round()
	_black_hole.scale = Vector2.ONE * _HOLE_SCALE * growth
	_disk_material.set_shader_parameter("pixels", _DISK_PIXELS * growth)
	_core_material.set_shader_parameter("pixels", _CORE_PIXELS * growth)

	# The ship stays ahead of the camera, falling away down the middle.
	var gone: float = clampf(dive / _SHIP_GONE_AT, 0.0, 1.0)
	var offset: Vector2 = (_DIVE_FROM - _HOLE_AT) * (1.0 - smoothstep(0.0, 1.0, gone))
	_falling_ship.position = (centre + offset).round()
	var step: int = mini(int(gone * _DIVE_WIDTHS.size()), _DIVE_WIDTHS.size() - 1)
	var width: int = _DIVE_WIDTHS[step]
	_falling_ship.visible = gone < 1.0
	if _falling_ship.get_meta(&"width", -1) != width:
		_falling_ship.set_meta(&"width", width)
		_falling_ship.texture = _shrunk_hull(width)
		_hull_material.set_shader_parameter("hull_rows", float(_falling_ship.texture.get_height()))
		var shrink: float = float(width) / 26.0
		for exhaust: CPUParticles2D in _exhaust:
			exhaust.position = exhaust.get_meta(&"point") * shrink
			exhaust.initial_velocity_min = 30.0 * shrink
			exhaust.initial_velocity_max = 45.0 * shrink


## The hole's core radius as drawn now, in art pixels.
func _hole_radius() -> float:
	return _CORE_RADIUS * _black_hole.scale.x


## The hole's materials are shared by every black hole in the game (the one
## behind the fight included): the dive's are its own.
func _own_hole_materials() -> void:
	var disk: ColorRect = _black_hole.get_node(^"Disk")
	var core: ColorRect = _black_hole.get_node(^"BlackHole")
	_disk_material = disk.material.duplicate() as ShaderMaterial
	_core_material = core.material.duplicate() as ShaderMaterial
	disk.material = _disk_material
	core.material = _core_material


# --- Shot 4: out of the hole ----------------------------------------------------

## The cut, on black: the flight's world goes, the hole's point of view
## comes, and the opening's theme starts again, slowed and lowered.
func _begin_reverse_shot() -> void:
	_world.visible = false
	_star_layer.visible = false
	_mouth.visible = true
	turn = -1.3
	_mouth_sky.fall = 0.0
	_place_far_ships(0.0)
	# They claw away the whole shot: the runner pulls ahead and dwindles.
	var away: Tween = create_tween()
	away.tween_method(_place_far_ships, 0.0, 1.0, 13.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	MusicDirector.play_track(_OPENING_TRACK, 0.0, true)
	var deck: MusicDeck = MusicDirector.active_deck()
	if deck:
		deck.pitch_scale = _OPENING_PITCH


## The opening's three ships, seen from behind and far off, as the hole sees
## them: all three nose away from us, toward the middle of the mouth.
func _build_far_ships() -> void:
	_runner = _far_ship(_hull_image(), _RUNNER_WIDTHS[0], false)
	_survivor = _far_ship(_ATTACKER_TEXTURE.get_image(), _ATTACKER_WIDTH, true)
	_doomed = _far_ship(_ATTACKER_TEXTURE.get_image(), _ATTACKER_WIDTH, true)
	_add_far_exhaust(_runner, _hull.cutscene_exhaust_points if _hull else PackedVector2Array(), 26.0, _CYAN)
	var attacker_engines: PackedVector2Array = PackedVector2Array([Vector2(-3, 13), Vector2(3, 13)])
	_add_far_exhaust(_survivor, attacker_engines, 32.0, Globals.orange)
	_add_far_exhaust(_doomed, attacker_engines, 32.0, Globals.orange)


func _far_ship(image: Image, width: int, flip: bool) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.set_meta(&"image", image)
	sprite.set_meta(&"flip", flip)
	sprite.texture = ImageTexture.create_from_image(PixelArtShrinker.shrink(image, width, flip))
	sprite.set_meta(&"width", width)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = _FLASH_SHADER
	material.set_shader_parameter("alpha", 1.0)
	material.set_shader_parameter("flash_amount", 0.0)
	sprite.material = material
	_far_ships.add_child(sprite)
	return sprite


func _resize_far_ship(sprite: Sprite2D, width: int) -> void:
	if sprite.get_meta(&"width") == width:
		return
	sprite.set_meta(&"width", width)
	sprite.texture = ImageTexture.create_from_image(
		PixelArtShrinker.shrink(sprite.get_meta(&"image"), width, sprite.get_meta(&"flip")))
	_place_far_exhaust(sprite)


## Exhaust coming back toward us out of the ship's tail, at
## [param points] on a hull [param art_width] pixels wide.
func _add_far_exhaust(ship: Sprite2D, points: PackedVector2Array, art_width: float, color: Color) -> void:
	ship.set_meta(&"art_width", art_width)
	for point: Vector2 in points:
		var exhaust: CPUParticles2D = CPUParticles2D.new()
		exhaust.texture = _PIXEL_TEXTURE
		exhaust.amount = 8
		exhaust.lifetime = 0.45
		exhaust.local_coords = false
		exhaust.direction = Vector2.DOWN
		exhaust.spread = 14.0
		exhaust.gravity = Vector2.ZERO
		exhaust.initial_velocity_min = 10.0
		exhaust.initial_velocity_max = 16.0
		exhaust.color = color
		exhaust.color_ramp = _fade_ramp()
		exhaust.set_meta(&"point", point)
		exhaust.show_behind_parent = true
		ship.add_child(exhaust)
	_place_far_exhaust(ship)


## Keeps the exhaust on the engines as a far ship is redrawn smaller.
func _place_far_exhaust(ship: Sprite2D) -> void:
	if not ship.has_meta(&"art_width"):
		return
	var shrink: float = float(ship.get_meta(&"width")) / float(ship.get_meta(&"art_width"))
	for child: Node in ship.get_children():
		if child is CPUParticles2D and child.has_meta(&"point"):
			(child as CPUParticles2D).position = (child.get_meta(&"point") * shrink).round()


## Where the far ships are, [param p] of the way through the reverse shot:
## clawing away, the runner pulling ahead and dwindling.
func _place_far_ships(p: float) -> void:
	_runner.position = _RUNNER_FROM.lerp(_RUNNER_TO, p).round()
	var step: int = mini(int(p * _RUNNER_WIDTHS.size()), _RUNNER_WIDTHS.size() - 1)
	_resize_far_ship(_runner, _RUNNER_WIDTHS[step])
	_survivor.position = _SURVIVOR_FROM.lerp(_SURVIVOR_TO, p).round()
	if not _doomed.has_meta(&"lost"):
		_doomed.position = _DOOMED_FROM.lerp(_SURVIVOR_TO * Vector2(-1, 1), p * 0.4).round()


## The Attacker on the right loses its drive against the pull.
func _engines_out() -> void:
	_doomed.set_meta(&"lost", true)
	_doomed.set_meta(&"lost_at", _doomed.position)
	Events.play_sound.emit(_ENGINES_OUT_SFX)
	for child: Node in _doomed.get_children():
		if child is CPUParticles2D:
			(child as CPUParticles2D).emitting = false
	Juice.sparkle(_effects, _doomed.global_position + Vector2(0, 4), Globals.orange, 8, 20.0)
	JumpFx.flare(_doomed, Globals.white, 0.3)


## It falls back toward us, growing and tumbling, swung round by the rim.
func _drag_doomed_in(p: float) -> void:
	var from: Vector2 = _doomed.get_meta(&"lost_at")
	var out: Vector2 = from.normalized()
	# Swings clockwise round with the hole as it nears the rim.
	var angle: float = out.angle() + p * p * 0.9
	var reach: float = lerpf(from.length(), _MOUTH_RADIUS + 10.0, p)
	_doomed.position = (Vector2.from_angle(angle) * reach).round()
	_doomed.rotation = p * p * 2.6
	var step: int = mini(int(p * _DOOMED_WIDTHS.size()), _DOOMED_WIDTHS.size() - 1)
	_resize_far_ship(_doomed, _DOOMED_WIDTHS[step])


## Over the rim and gone: the hole takes it, the way the opening's Fate took
## it, from the other side.
func _doomed_consumed() -> void:
	var spot: Vector2 = _far_ships.to_global(_doomed.position.limit_length(_MOUTH_RADIUS))
	_doomed.visible = false
	Events.play_sound.emit(_CONSUMED_SFX)
	Events.camera_shake_large.emit()
	Juice.sparkle(_effects, spot, _FATE_PURPLE, 18, 70.0)
	Juice.sparkle(_effects, spot, Globals.white, 10, 45.0)
	_jump_fx.ring(spot, Globals.white, 2.0, 24.0, 0.4)
	_jump_fx.ring(spot, _FATE_PURPLE, 4.0, 40.0, 0.6)
	_flash_screen(_FATE_PURPLE, 0.35, 0.45)


## Spooling a far ship's drive: motes drawn in, the hull flickering
## brighter, as JumpFx charges a ship but at this distance's size.
func _charge_far(ship: Sprite2D, color: Color, seconds: float) -> void:
	var pulses: int = 4
	var material: ShaderMaterial = ship.material as ShaderMaterial
	material.set_shader_parameter("flash_color", Globals.white)
	var tween: Tween = ship.create_tween()
	for i: int in pulses:
		tween.tween_callback(func() -> void:
			Juice.gather(_effects, ship.global_position, color, 6, 8.0, seconds / pulses))
		tween.tween_property(material, "shader_parameter/flash_amount", Juice.soften_flash(lerpf(0.2, 0.7, float(i) / (pulses - 1))), seconds / pulses * 0.3)
		tween.tween_property(material, "shader_parameter/flash_amount", 0.0, seconds / pulses * 0.7)


## The jump, seen from behind: a white flare, a streak away into the
## distance, the jump's colour ringing out where it was.
func _jump_far(ship: Sprite2D, color: Color) -> void:
	var spot: Vector2 = ship.global_position
	JumpFx.flare(ship, Globals.white, 0.1)
	_far_streak(spot, color)
	_jump_fx.ring(spot, color, 1.0, 12.0, 0.35)
	Juice.sparkle(_effects, spot, color, 10, 40.0)
	_flash_screen(color, 0.12, 0.3)
	Events.camera_shake_small.emit()
	ship.create_tween().tween_callback(ship.hide).set_delay(0.06)


## A jump's wake, seen end on: one pixel wide, from the ship away into the
## distance, flashing white to the jump's colour as it pinches shut.
func _far_streak(spot: Vector2, color: Color) -> void:
	var line: ColorRect = ColorRect.new()
	line.color = Globals.white
	line.size = Vector2(1.0, 18.0)
	line.pivot_offset = Vector2(0.5, 18.0)
	_effects.add_child(line)
	line.global_position = (spot - Vector2(0.0, 18.0)).floor()
	var tween: Tween = line.create_tween().set_parallel(true)
	tween.tween_property(line, "color", color, 0.12)
	tween.tween_property(line, "scale:y", 0.0, 0.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(line.queue_free)


# --- Shot 5: the throw --------------------------------------------------------

func _build_thrown_die() -> void:
	_die = ThrownFateDie.new()
	%Foreground.add_child(_die)
	_die_sprite = Sprite2D.new()
	_die_sprite.texture = _die.get_texture()
	_die_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var snap: ShaderMaterial = ShaderMaterial.new()
	snap.shader = _SNAP_SHADER
	_die_sprite.material = snap
	_die_sprite.position = Vector2(160, -40)
	_die_sprite.visible = false
	%Foreground.add_child(_die_sprite)


## Thrown: it comes in from above, tumbling, to land on a face. Which face is
## the throw's: cosmetic, as a throw should be.
func _throw_die() -> void:
	var faces: Array[FateDie.Face] = _die_faces()
	_die.show_faces(faces)
	var side: int = int(RNGManager.randf_range(RNGManager.Bucket.COSMETIC, 0.0, faces.size() - 0.001))
	_die.throw_onto(side)
	_die.set_meta(&"face", faces[side])
	_die_sprite.visible = true


func _die_lands() -> void:
	Events.play_sound.emit(_DIE_LANDS_SFX)
	Events.camera_shake_small.emit()


## The face it landed on catches the light in its own colour.
func _die_glints() -> void:
	var res: FateFaceResource = FateFaceCatalog.get_face(_die.get_meta(&"face"))
	var color: Color = res.color if res else Globals.white
	Events.play_sound.emit(_DIE_STILL_SFX)
	Juice.glint(_effects, _die_sprite.position + Vector2(-14, -16), Globals.white, 7.0, 0.6)
	_jump_fx.ring(_die_sprite.position, color, 20.0, 34.0, 0.6)


## The faces on the die the cutscene shows. ReckoningEnding doesn't carry
## the run's die, so this is the die every face carved once, as the first
## ending's vision carved it.
## The player's own carved die where the ending carries it, so the throw that
## loops the game is theirs; the six carvable faces otherwise.
func _die_faces() -> Array[FateDie.Face]:
	var faces: Array[FateDie.Face] = []
	if ending:
		for face: int in ending.die_faces:
			if face != FateDie.Face.BLANK:
				faces.append(face as FateDie.Face)
	if faces.size() < 6:
		return FateDie.carvable_faces()
	return faces


# --- Credits and hand-over ---------------------------------------------------

## The credits fall over the dimmed mouth, then the screen goes to black.
func _roll_credits() -> void:
	_credits = FallingCredits.new()
	$CreditsLayer.add_child(_credits)
	_credits.rolled.connect(_end_film)
	# The mouth dims under the words, and the die goes back into the dark.
	var dim: Tween = create_tween().set_parallel(true)
	dim.tween_property(%Dim, "color:a", 0.65, 2.5)
	dim.tween_property(_die_sprite, "modulate:a", 0.0, 3.0).set_ease(Tween.EASE_IN)
	_credits.roll()


func _end_film() -> void:
	if _ending_film:
		return
	_ending_film = true
	MusicDirector.stop(2.2)
	var close: Tween = create_tween()
	close.tween_property(_curtain, "color:a", 1.0, 2.0).set_ease(Tween.EASE_IN)
	close.tween_callback(_hand_over.bind(false))


## A second press of anything: straight to black.
func _skip() -> void:
	if _ending_film:
		return
	_ending_film = true
	if _film_tween:
		_film_tween.kill()
	var close: Tween = create_tween()
	close.tween_property(_curtain, "color:a", 1.0, 0.25)
	close.tween_callback(_hand_over.bind(true))


## On black. The credits hand straight off toward the menu, so the menu's
## theme comes in under whatever comes up next.
func _hand_over(skipped: bool) -> void:
	_curtain.color.a = 1.0
	_pixel_layer.visible = false
	_star_layer.visible = false
	$BackdropLayer.visible = false
	$CreditsLayer.visible = false
	_hide_cursor(false)
	MusicDirector.play_track(_MENU_TRACK, 2.0, true)
	finish(skipped)


## The game's pointer would float over the film; it comes back for whatever
## comes next.
func _hide_cursor(hide_it: bool) -> void:
	var scene: Node = get_tree().current_scene
	if hide_it:
		_hidden_cursor_layer = scene.get_node_or_null(^"CursorLayer") as CanvasLayer if scene else null
		if _hidden_cursor_layer and _hidden_cursor_layer.visible:
			_hidden_cursor_layer.visible = false
		else:
			_hidden_cursor_layer = null
	elif is_instance_valid(_hidden_cursor_layer):
		_hidden_cursor_layer.visible = true


# --- Shot -------------------------------------------------------------------

## As the opening frames its shot: the finished 320x180 picture and the
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
		star.position = _random_point_on_screen()
		var depth: float = _randf(0.3, 1.0)
		star.modulate = Color(1, 1, 1, lerpf(0.25, 0.8, depth))
		_stars.append(star)
		_star_depths.append(depth)


## Outside the dive the stars barely drift: the fight is over and nothing is
## running. In it they pour in toward the hole, faster and longer the nearer
## the camera gets, and near the rim they're dragged round it and bent into
## arcs along it.
func _move_stars(delta: float) -> void:
	var diving: bool = _falling_ship != null
	var centre: Vector2 = _fate.position
	var core: float = _hole_radius() * 0.9
	for i: int in range(_stars.size()):
		var star: Node2D = _stars[i]
		var depth: float = _star_depths[i]
		if not diving:
			star.position.x -= star_speed * depth * delta
			if star.position.x < -1.0:
				star.position = Vector2(Globals.SCREEN_SIZE.x + 1.0, _randf(0, Globals.SCREEN_SIZE.y))
			continue
		var out: Vector2 = star.position - centre
		var r: float = maxf(out.length(), 0.01)
		var radial: Vector2 = out / r
		var rim: float = clampf(1.0 - (r - core) / 60.0, 0.0, 1.0)
		var inward: float = (8.0 + 160.0 * dive) * depth * (1.0 + rim)
		var round_rim: float = (0.4 + 2.2 * dive) * rim * rim
		var motion: Vector2 = -radial * inward + radial.orthogonal() * -round_rim * r
		star.position += motion * delta
		star.rotation = motion.angle()
		star.scale.x = 1.0 + (3.0 + 30.0 * dive) * depth * (0.3 + rim)
		if r < core or not Rect2(Vector2.ZERO, Globals.SCREEN_SIZE).grow(24.0).has_point(star.position):
			star.position = _edge_point()
			star.scale.x = 1.0


func _random_point_on_screen() -> Vector2:
	return Vector2(_randf(0, Globals.SCREEN_SIZE.x), _randf(0, Globals.SCREEN_SIZE.y))


## Somewhere just inside the frame's edge, for a star to pour in from.
func _edge_point() -> Vector2:
	var side: int = int(_randf(0.0, 3.999))
	var along: float = _randf(0.0, 1.0)
	match side:
		0:
			return Vector2(along * Globals.SCREEN_SIZE.x, 0.0)
		1:
			return Vector2(Globals.SCREEN_SIZE.x, along * Globals.SCREEN_SIZE.y)
		2:
			return Vector2(along * Globals.SCREEN_SIZE.x, Globals.SCREEN_SIZE.y)
		_:
			return Vector2(0.0, along * Globals.SCREEN_SIZE.y)


# --- The hull -----------------------------------------------------------------

## The hull this run flew, in its gold drive (the wash shader burns it gold
## until the purple takes it).
func _dress_player_ship() -> void:
	if _hull and _hull.cutscene_frames:
		_ship.sprite_frames = _hull.cutscene_frames
		_ship.play(&"boost")
	_ship.position = _SHIP_AT
	_hull_material.set_shader_parameter("hull_rows", _hull_rows())


## The drive's wash from the hull's pods, gold until Fate takes it. Idling:
## the fight is over.
func _add_exhaust() -> void:
	var points: PackedVector2Array = _hull.cutscene_exhaust_points if _hull else PackedVector2Array([Vector2(-8.5, 9.0), Vector2(8.5, 9.0)])
	for point: Vector2 in points:
		var exhaust: CPUParticles2D = CPUParticles2D.new()
		exhaust.texture = _PIXEL_TEXTURE
		exhaust.amount = 10
		exhaust.lifetime = 0.35
		exhaust.local_coords = false
		exhaust.direction = Vector2.DOWN
		exhaust.spread = 6.0
		exhaust.gravity = Vector2.ZERO
		exhaust.initial_velocity_min = 30.0
		exhaust.initial_velocity_max = 45.0
		exhaust.color = _GOLD
		exhaust.color_ramp = _fade_ramp()
		exhaust.position = point
		exhaust.set_meta(&"point", point)
		exhaust.show_behind_parent = true
		_ship.add_child(exhaust)
		_exhaust.append(exhaust)


func _hull_image() -> Image:
	var frames: SpriteFrames = _ship.sprite_frames
	return frames.get_frame_texture(&"boost", 0).get_image()


func _shrunk_hull(width: int) -> ImageTexture:
	return ImageTexture.create_from_image(PixelArtShrinker.shrink(_hull_image(), width))


# --- Helpers ----------------------------------------------------------------

func _fade_ramp() -> Gradient:
	var ramp: Gradient = Gradient.new()
	ramp.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	return ramp


func _flash_screen(color: Color, peak: float, seconds: float) -> void:
	var flash: ColorRect = %Flash
	flash.color = Color(color, Juice.screen_wash_alpha(peak))
	var tween: Tween = create_tween()
	tween.tween_property(flash, "color:a", 0.0, seconds).set_ease(Tween.EASE_OUT)


func _randf(from: float, to: float) -> float:
	return RNGManager.randf_range(RNGManager.Bucket.COSMETIC, from, to)
