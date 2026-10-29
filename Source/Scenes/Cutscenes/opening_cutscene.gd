extends Node2D
## The opening: the player's ship claws away from Fate, loses one of its two
## pursuers to it and jumps, only for the other to follow it out of
## hyperspace. It cuts straight into the first fight (COMBAT_opening_ambush,
## one Attacker already holed) as the player turns to face it.
##
## Two resolutions on purpose. Everything that is art (ships, Fate, debris,
## effects) lives in the PixelWorld SubViewport: 320x180, blown up 6x, so it
## sits on the same pixel grid as the game and nothing rotates or scales into
## mixels. The starfield sits behind it in the full 1080p viewport, so stars
## glide and streak smoothly instead of stepping a whole art pixel at a time.
##
## The timeline is the AnimationPlayer's "cutscene_anim". Paths, fades, the
## shot and the starfield's speed are keyed there; its method track calls the
## one-shot effects below. This script owns the ships' scale and flash, so the
## keys never fight a jump's stretch.
##
## The shot (view_zoom, view_center) is framed from outside both worlds: it
## scales the finished 320x180 picture and the starfield together, rather
## than zooming a camera inside the SubViewport. Inside, a zoom that isn't a
## whole number would draw some art pixels twice as wide as others; outside,
## each art pixel is at worst one screen pixel off its neighbours, and every
## held zoom is keyed on a whole number of screen pixels per art pixel.

@export_category('Starfield')
@export var num_of_stars: int = 110
@export var num_of_twinkling_stars: int = 25
@export var star_pixel_scene: PackedScene
@export var star_twinkle_scene: PackedScene
## Keyed. How fast the stars stream past, in art pixels per second.
@export var star_speed: float = 30.0
## Keyed. How far each star smears into a streak, as a multiple of its width.
## 1 is a plain dot; the jump drives it up the way the game's jump does.
@export var star_stretch: float = 1.0

@export_category('Shot')
## Keyed. How far the shot is pushed in on the 320x180 frame; 1 shows all of
## it. Hold it on a multiple of 1/6 (a whole number of screen pixels per art
## pixel) so a held shot stays crisp.
@export var view_zoom: float = 1.0
## Keyed. The point of the frame, in art pixels, the shot centres on. Kept far
## enough in that the shot never runs off the edge of the frame.
@export var view_center: Vector2 = Vector2(160, 90)

@export_category('Debris')
## Pieces of wreckage being dragged into Fate.
@export var debris_scenes: Array[PackedScene] = []
## Fate's own shards, dragged in with the wreckage and drawn with
## fate_debris_shader, the way the Fate background draws them.
@export var fate_debris_scenes: Array[PackedScene] = []
@export var fate_debris_shader: Shader
@export var num_of_debris: int = 16
## Keyed. How fast the debris is dragged left toward Fate.
@export var debris_speed: float = 70.0
## Keyed. Speed lines whipping past, per second. 0 for none.
@export var speed_lines: float = 0.0
## Keyed. Whether Fate throws its own lightning about. Off until the shot
## pulls back far enough to show it, so its weather doesn't arrive first.
@export var fate_weather: bool = true
## How fast the rift's nebula slides past, in texture lengths per second.
## Negative, because the sheet is turned on its side.
@export var nebula_drift: float = -0.015

const _DIE_TEXTURE: Texture2D = preload("res://Assets/Textures/Dice/Cutscene/cutscene_dice.png")
const _PIXEL_TEXTURE: Texture2D = preload("res://Assets/Particles/hit_particle_pixel.png")
const _HYPERSPACE_STREAKS: Texture2D = preload("res://Assets/SpriteMancer/JumpTransition/jump_particles.png")

const _DICE_CANNON_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/dice_cannon.tres")
const _PLAYER_HIT_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/player_health_hit.tres")
const _ENEMY_HIT_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/enemy_health_hit.tres")
const _FATE_PULSE_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/die_dread_thunk.tres")
const _ENGINES_OUT_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/enemy_pre_death.tres")
const _CONSUMED_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/enemy_death_explosion.tres")
const _LOCK_ON_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/tractor_lock.tres")

## jump_particles.png is a 12x10 grid of horizontal streak frames.
const _STREAK_COLUMNS: int = 12
const _STREAK_ROWS: int = 10
const _STREAK_FPS: float = 24.0
## Each frame has a few clear texels round its edge. Stretched across the
## screen they left a thin streakless band down each side, so they are
## cropped off.
const _STREAK_FRAME_INSET: float = 4.0
## How far the screen-filling layers reach past the frame on every side, so a
## camera shake never shows their edges. Matches their rects in the scene.
const _OVERSCAN: float = 8.0

## How the jump stretches a ship along its heading as it goes to light speed.
const _JUMP_STRETCH: Vector2 = Vector2(0.5, 3.0)
## Debris closer than this to Fate's centre starts to spaghettify; at the
## event horizon it is gone.
const _DEBRIS_STRETCH_RANGE: float = 70.0
const _EVENT_HORIZON: float = 14.0
## Fate's lightning starts out on its disk, so the arcs crawl over the disk's
## edge rather than out of the black core.
const _FATE_RIM: float = 40.0
## Fastest a piece tumbles, in radians per second, before Fate spins it up.
const _DEBRIS_MAX_SPIN: float = 1.5

const _BLUE_JUMP: Color = Color("#8df1f4")
const _RED_JUMP: Color = Color("#d03656")
const _FATE_PURPLE: Color = Color("#c552f1")

var main_game_scene: String = "uid://deisauteocrjl"

var _stars: Array[Node2D] = []
## Per star: how near it is. Near stars stream faster and streak longer.
var _star_depths: PackedFloat32Array = PackedFloat32Array()
## Each piece of debris sits in an unrotated holder: the piece tumbles, while
## the holder is what Fate stretches, so it stretches along the pull and not
## along whichever way the piece happens to face.
var _debris: Array[Node2D] = []
var _debris_depths: PackedFloat32Array = PackedFloat32Array()
var _debris_spins: PackedFloat32Array = PackedFloat32Array()
## Extra drag on the debris from Fate's last pulse, dying away.
var _debris_jolt: float = 0.0
var _speed_lines: SpeedLines = null
## Smoke trails, each following the ship it was lit on.
var _smoke_trails: Dictionary[Node2D, CPUParticles2D] = {}
var _reticle: LockOnReticle = null

@onready var _effects: Node2D = %Effects
@onready var _pixel_layer: CanvasLayer = $PixelLayer
@onready var _pixel_screen: SubViewportContainer = $PixelLayer/PixelScreen
@onready var _star_camera: Camera2D = $Camera2D
@onready var _fate: Node2D = %Fate
@onready var _storm: FateStorm = %FateStorm


func _ready() -> void:
	SceneLoader.request(main_game_scene)
	_spawn_stars()
	_spawn_debris()
	_speed_lines = SpeedLines.new()
	_speed_lines.z_index = 8
	%PixelWorld.add_child(_speed_lines)
	_build_hyperspace_streaks()
	_dress_player_ship(Globals.current_ship())
	_add_exhaust(%PlayerShip)
	%RiftNebula.speed = nebula_drift


func _process(delta: float) -> void:
	_frame_shot()
	_move_stars(delta)
	_move_debris(delta)
	# The storm is Fate's weather: it goes when Fate drops behind the jump.
	_storm.visible = _fate.visible
	_storm.autonomous = _fate.visible and fate_weather
	_speed_lines.rate = speed_lines
	for ship: Node2D in _smoke_trails:
		var smoke: CPUParticles2D = _smoke_trails[ship]
		# Behind the ship along its heading, so the trail leaves its tail.
		smoke.global_position = ship.global_position - _heading(ship) * 9.0
		# Off while the ship is between jumps, so no smoke hangs in empty space.
		smoke.emitting = ship.is_visible_in_tree()
	if _reticle:
		_reticle.global_position = _reticle.target.global_position


func _input(event: InputEvent) -> void:
	# Handle skipping the cutscene
	if event is InputEventMouseButton and \
	event.button_index == MOUSE_BUTTON_LEFT and \
	event.pressed:
		_switch_to_next_scene()


# --- Shot -------------------------------------------------------------------

## Pushes in on view_center by view_zoom: the pixel layer is scaled and moved
## on screen, and the starfield's camera matched to it, so stars and ships
## stay together.
func _frame_shot() -> void:
	var art_scale: float = float(_pixel_screen.stretch_shrink)
	var zoom: float = maxf(view_zoom, 1.0)
	var half_view: Vector2 = Globals.SCREEN_SIZE / (2.0 * zoom)
	var centre: Vector2 = view_center.clamp(half_view, Globals.SCREEN_SIZE - half_view)
	_star_camera.zoom = Vector2.ONE * art_scale * zoom
	_star_camera.position = centre
	_pixel_layer.scale = Vector2.ONE * zoom
	# Whole screen pixels, so the art grid never lands between them.
	_pixel_layer.offset = (get_viewport_rect().size / 2.0 - centre * art_scale * zoom).round()


# --- Starfield --------------------------------------------------------------

func _spawn_stars() -> void:
	for i: int in range(num_of_stars + num_of_twinkling_stars):
		var scene: PackedScene = star_pixel_scene if i < num_of_stars else star_twinkle_scene
		var star: Node2D = scene.instantiate()
		%Stars.add_child(star)
		star.position = _random_point_on_screen()
		var depth: float = RNGManager.randf_range(RNGManager.Bucket.COSMETIC, 0.3, 1.0)
		# Far stars are dimmer as well as slower.
		star.modulate = Color(1, 1, 1, lerpf(0.25, 0.8, depth))
		_stars.append(star)
		_star_depths.append(depth)


func _move_stars(delta: float) -> void:
	for i: int in range(_stars.size()):
		var star: Node2D = _stars[i]
		var depth: float = _star_depths[i]
		star.position.x -= star_speed * depth * delta
		star.scale.x = lerpf(1.0, star_stretch, depth)
		if star.position.x < -star.scale.x:
			star.position.x = Globals.SCREEN_SIZE.x + star.scale.x
			star.position.y = RNGManager.randf_range(RNGManager.Bucket.COSMETIC, 0, Globals.SCREEN_SIZE.y)


# --- Debris -----------------------------------------------------------------

func _spawn_debris() -> void:
	var pool: Array[PackedScene] = debris_scenes.duplicate()
	pool.append_array(fate_debris_scenes)
	if pool.is_empty():
		return
	for i: int in range(num_of_debris):
		var holder: Node2D = Node2D.new()
		%Debris.add_child(holder)
		var scene: PackedScene = RNGManager.pick_random(RNGManager.Bucket.COSMETIC, pool)
		var piece: Node2D = scene.instantiate()
		if fate_debris_shader and fate_debris_scenes.has(scene):
			_corrupt(piece)
		holder.add_child(piece)
		piece.rotation = RNGManager.randf_range(RNGManager.Bucket.COSMETIC, 0.0, TAU)
		var depth: float = RNGManager.randf_range(RNGManager.Bucket.COSMETIC, 0.5, 1.2)
		# Further pieces sink into the dark rather than going see-through,
		# which would show stars through solid wreckage.
		var shade: float = remap(depth, 0.5, 1.2, 0.4, 0.85)
		holder.modulate = Color(shade, shade, shade)
		holder.z_index = int(depth * 4)
		holder.position = _random_point_on_screen()
		_debris.append(holder)
		_debris_depths.append(depth)
		_debris_spins.append(RNGManager.randf_range(RNGManager.Bucket.COSMETIC, -_DEBRIS_MAX_SPIN, _DEBRIS_MAX_SPIN))


## Gives a fate shard the corruption the Fate background draws it with. The
## holder's modulate already sinks far pieces into the dark, so the shader's
## own depth fade is left fully shown.
func _corrupt(piece: Node2D) -> void:
	var corruption: ShaderMaterial = ShaderMaterial.new()
	corruption.shader = fate_debris_shader
	corruption.set_shader_parameter("keep_texture_colors", true)
	corruption.set_shader_parameter("base_visibility", 1.0)
	corruption.set_shader_parameter("seed", RNGManager.randf_range(RNGManager.Bucket.COSMETIC, 0.0, 100.0))
	piece.material = corruption
	for child: Node in piece.get_children():
		if child is CanvasItem:
			(child as CanvasItem).use_parent_material = true


## Drags each piece left and in toward Fate's centre line, and stretches it
## thin along its path as it nears the hole, until it slips through and comes
## back around from the right.
func _move_debris(delta: float) -> void:
	if not %Debris.visible:
		return
	_debris_jolt = move_toward(_debris_jolt, 0.0, 240.0 * delta)
	var hole: Vector2 = _fate.global_position
	for i: int in range(_debris.size()):
		var holder: Node2D = _debris[i]
		var depth: float = _debris_depths[i]
		var distance: float = holder.position.x - hole.x
		var pull: float = clampf(1.0 - distance / 260.0, 0.0, 1.0)
		holder.position.x -= (debris_speed + _debris_jolt) * depth * (1.0 + pull) * delta
		holder.position.y = lerpf(holder.position.y, hole.y, pull * pull * 2.0 * delta)
		# Tumbles faster the deeper into the pull it gets.
		holder.get_child(0).rotation += _debris_spins[i] * (1.0 + pull * pull * 6.0) * delta

		var squeeze: float = clampf(distance / _DEBRIS_STRETCH_RANGE, 0.0, 1.0)
		holder.scale = Vector2(lerpf(2.5, 1.0, squeeze), lerpf(0.0, 1.0, squeeze))

		if distance < _EVENT_HORIZON:
			holder.position = Vector2(
				Globals.SCREEN_SIZE.x + RNGManager.randf_range(RNGManager.Bucket.COSMETIC, 20, 80),
				RNGManager.randf_range(RNGManager.Bucket.COSMETIC, 8, Globals.SCREEN_SIZE.y - 8)
			)


# --- Hyperspace -------------------------------------------------------------

## The game's jump streak sheet, rebuilt here as frames: it is drawn
## horizontally, which is the way this cutscene flies.
func _build_hyperspace_streaks() -> void:
	var frames: SpriteFrames = SpriteFrames.new()
	frames.set_animation_speed(&"default", _STREAK_FPS)
	var size: Vector2 = Vector2(
		_HYPERSPACE_STREAKS.get_width() / _STREAK_COLUMNS,
		_HYPERSPACE_STREAKS.get_height() / _STREAK_ROWS
	)
	var inset: Vector2 = Vector2.ONE * _STREAK_FRAME_INSET
	for row: int in range(_STREAK_ROWS):
		for column: int in range(_STREAK_COLUMNS):
			var frame: AtlasTexture = AtlasTexture.new()
			frame.atlas = _HYPERSPACE_STREAKS
			frame.region = Rect2(Vector2(column, row) * size + inset, size - inset * 2.0)
			frames.add_frame(&"default", frame)

	var streaks: AnimatedSprite2D = %HyperspaceStreaks
	streaks.sprite_frames = frames
	streaks.scale = (Globals.SCREEN_SIZE + Vector2.ONE * _OVERSCAN * 2.0) / (size - inset * 2.0)
	streaks.play(&"default")


# --- Timeline calls ---------------------------------------------------------

## Keyed on the cutscene's method track at 0 s, so the fade can be retimed in
## the AnimationPlayer. The trailer plays once, on into the run; when it ends
## the playlist brings the start theme back and holds it.
func _start_music() -> void:
	MusicDirector.play_track(&"trailer_1", 4.0)


## Fate breathing: a ring rolls out of the hole, lightning cracks off it and
## the screen shudders. Strength 1 is a pulse; higher is the surge that takes
## a ship. A pulse's bolts stay short of the Attackers, so it never reads as
## Fate striking them before the surge does.
func _fate_pulse(strength: float) -> void:
	Events.play_sound.emit(_FATE_PULSE_SFX)
	var centre: Vector2 = _fate.global_position
	var storm_centre: Vector2 = _storm.to_local(centre)
	_debris_jolt = 140.0 * strength
	_ring(centre, _FATE_PURPLE, 70.0, 110.0 + 40.0 * strength, 0.9)
	if strength > 1.0:
		_ring(centre, Globals.white, 60.0, 180.0, 0.7)
		_flash_screen(_FATE_PURPLE, 0.45, 0.5)
		_storm.strike_from(storm_centre, 7, 110.0, _FATE_RIM)
		_storm.strike(FateStorm.Kind.TEAR)
		Events.camera_shake_large.emit()
	else:
		_storm.strike_from(storm_centre, 4, 35.0, _FATE_RIM, 0.8)
		Events.camera_shake_small.emit()


## Lobs a die from [param shooter]'s guns at [param target]. A hit homes in
## on wherever the target has got to by the time it lands; a miss flies at
## where it was when fired, so a target that has moved since dodges it.
func _fire_die(shooter: StringName, target: StringName, flight_time: float, hits: bool) -> void:
	var from: Node2D = _ship(shooter)
	var to: Node2D = _ship(target)
	var muzzle: Vector2 = from.global_position + _heading(from) * 12.0
	Events.play_sound.emit(_DICE_CANNON_SFX)
	_recoil(from)
	Juice.sparkle(_effects, muzzle, Globals.yellow, 5, 30.0)
	_ring(muzzle, Globals.yellow, 1.0, 7.0, 0.15)

	var die: Sprite2D = Sprite2D.new()
	die.texture = _DIE_TEXTURE
	_effects.add_child(die)
	die.global_position = muzzle
	die.add_child(_trail_particles())

	var aim: Vector2 = to.global_position
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(die, "rotation", TAU * 2.0 * signf(_heading(from).x), flight_time)
	if hits:
		tween.tween_method(func(t: float) -> void:
			if is_instance_valid(to):
				die.global_position = muzzle.lerp(to.global_position, t),
			0.0, 1.0, flight_time)
		tween.chain().tween_callback(func() -> void:
			_ship_hit(target)
			die.queue_free())
	else:
		# Carries on past the target's old spot and off screen.
		var past: Vector2 = muzzle + (aim - muzzle) * 3.0
		tween.tween_property(die, "global_position", past, flight_time * 3.0)
		tween.chain().tween_callback(die.queue_free)


func _ship_hit(ship_name: StringName) -> void:
	var ship: Node2D = _ship(ship_name)
	var is_player: bool = ship_name == &"PlayerShip"
	Events.play_sound.emit(_PLAYER_HIT_SFX if is_player else _ENEMY_HIT_SFX)
	if is_player:
		Events.camera_shake_large.emit()
		TimeDirector.hitstop(50)
	else:
		Events.camera_shake_small.emit()
	_flash_ship(ship, Globals.red, 0.5)
	Juice.sparkle(_effects, ship.global_position, Globals.red, 10, 60.0)
	Juice.sparkle(_effects, ship.global_position, Globals.orange, 8, 40.0)
	_ring(ship.global_position, Globals.red, 3.0, 16.0, 0.3)


## A hit that leaves the ship trailing smoke for the rest of the cutscene.
## The ambush starts its Attacker on 65% hull; this is where it lost the rest.
func _ship_damaged(ship_name: StringName) -> void:
	_ship_hit(ship_name)
	TimeDirector.hitstop(70)
	var ship: Node2D = _ship(ship_name)
	var smoke: CPUParticles2D = _smoke_particles()
	_effects.add_child(smoke)
	smoke.global_position = ship.global_position
	_smoke_trails[ship] = smoke


## The doomed Attacker's drive gives out against the pull. From here the
## timeline drags it back into Fate.
func _engines_out(ship_name: StringName) -> void:
	var ship: Node2D = _ship(ship_name)
	Events.play_sound.emit(_ENGINES_OUT_SFX)
	for child: Node in ship.get_children():
		if child is CPUParticles2D:
			(child as CPUParticles2D).emitting = false
	Juice.sparkle(_effects, ship.global_position - _heading(ship) * 10.0, Globals.orange, 10, 30.0)
	_flash_ship(ship, Globals.white, 0.3)
	# It comes apart on the way in.
	var smoke: CPUParticles2D = _smoke_particles()
	_effects.add_child(smoke)
	_smoke_trails[ship] = smoke


## The ship crosses the event horizon: a last flare and it is gone.
func _consumed(ship_name: StringName) -> void:
	var ship: Node2D = _ship(ship_name)
	var spot: Vector2 = ship.global_position
	Events.play_sound.emit(_CONSUMED_SFX)
	Events.camera_shake_large.emit()
	TimeDirector.hitstop(120)
	Juice.sparkle(_effects, spot, _FATE_PURPLE, 18, 70.0)
	Juice.sparkle(_effects, spot, Globals.white, 10, 45.0)
	_ring(spot, Globals.white, 2.0, 28.0, 0.4)
	_ring(spot, _FATE_PURPLE, 4.0, 46.0, 0.6)
	_flash_screen(_FATE_PURPLE, 0.35, 0.4)
	# Fate tears the sky as it takes the ship.
	_storm.strike(FateStorm.Kind.TEAR)
	_storm.strike_from(_storm.to_local(_fate.global_position), 5, 30.0, _FATE_RIM)


## Spooling the jump drive: motes are drawn in to the ship while its hull
## flickers brighter and brighter. The motes take the colour of the jump they
## build up to.
func _charge_jump(ship_name: StringName, seconds: float, color: Color = _BLUE_JUMP) -> void:
	var ship: Node2D = _ship(ship_name)
	var motes: CPUParticles2D = _charge_particles(seconds, color)
	ship.add_child(motes)
	motes.emitting = true

	var material: ShaderMaterial = ship.material as ShaderMaterial
	material.set_shader_parameter("flash_color", Globals.white)
	var tween: Tween = create_tween()
	var pulses: int = 5
	for i: int in range(pulses):
		var peak: float = Juice.soften_flash(lerpf(0.15, 0.7, float(i) / (pulses - 1)))
		var beat: float = seconds / pulses
		tween.tween_property(material, "shader_parameter/flash_amount", peak, beat * 0.3)
		tween.tween_property(material, "shader_parameter/flash_amount", 0.0, beat * 0.7)


## The ship snaps to light speed: it stretches along its heading, flares
## white and leaves a streak to the edge of the screen. The timeline hides it
## on the next key.
func _jump_out(ship_name: StringName, color: Color) -> void:
	var ship: Node2D = _ship(ship_name)
	Events.camera_shake_large.emit()
	_flash_ship(ship, Globals.white, 0.15)
	if ship == %PlayerShip:
		# A breath of slow motion as the player's ship goes, so the stretch
		# and the streak it leaves can register.
		TimeDirector.slow_mo(0.3, 220)

	var tween: Tween = create_tween()
	tween.tween_property(ship, "scale", _JUMP_STRETCH, 0.1) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.tween_property(ship, "scale", Vector2.ONE, 0.0).set_delay(0.15)

	var spot: Vector2 = ship.global_position
	_streak(spot.x, Globals.SCREEN_SIZE.x + 8.0, spot.y, color)
	_ring(spot, color, 3.0, 22.0, 0.35)
	Juice.sparkle(_effects, spot, color, 14, 70.0)


## The reverse of a jump: a streak from behind, and the ship decelerates out
## of it, overshooting into a squash before it settles.
func _jump_in(ship_name: StringName, color: Color) -> void:
	var ship: Node2D = _ship(ship_name)
	Events.camera_shake_large.emit()
	ship.scale = _JUMP_STRETCH
	_flash_ship(ship, Globals.white, 0.35)

	var tween: Tween = create_tween()
	tween.tween_property(ship, "scale", Vector2(1.2, 0.8), 0.12) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(ship, "scale", Vector2.ONE, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var spot: Vector2 = ship.global_position
	_streak(-8.0, spot.x, spot.y, color)
	_ring(spot, color, 3.0, 18.0, 0.3)
	Juice.sparkle(_effects, spot, color, 10, 50.0)


## Hyperspace punches in over the starfield, as the game's jump does once it
## has built up speed.
func _hyperspace_punch() -> void:
	Events.camera_shake_large.emit()
	TimeDirector.hitstop(80)
	_flash_screen(Globals.white, 0.75, 0.5)


## Back out into normal space: hyperspace drops away under a white flash.
func _hyperspace_exit() -> void:
	Events.camera_shake_large.emit()
	_flash_screen(Globals.white, 1.0, 0.6)


## Hot sparks spitting from a drive run past its limit against Fate's pull.
func _strain(ship_name: StringName, straining: bool) -> void:
	var ship: Node2D = _ship(ship_name)
	var sparks: CPUParticles2D = ship.get_node_or_null(^"StrainSparks")
	if not sparks:
		sparks = _strain_particles(ship)
		ship.add_child(sparks)
	sparks.emitting = straining


## Manoeuvring thrusters firing on both flanks: the ship is about to turn.
func _rcs_burst(ship_name: StringName) -> void:
	var ship: Node2D = _ship(ship_name)
	var flank: Vector2 = _heading(ship).orthogonal() * 10.0
	Juice.sparkle(_effects, ship.global_position + flank, Globals.white, 5, 35.0)
	Juice.sparkle(_effects, ship.global_position - flank, Globals.white, 5, 35.0)


## Brackets close in on [param target]: [param shooter] has a firing solution.
func _lock_on(target: StringName) -> void:
	Events.play_sound.emit(_LOCK_ON_SFX)
	if _reticle:
		_reticle.queue_free()
	_reticle = LockOnReticle.new()
	_reticle.target = _ship(target)
	_reticle.color = Globals.red
	_effects.add_child(_reticle)
	_reticle.global_position = _reticle.target.global_position


func _switch_to_next_scene() -> void:
	SceneLoader.switch_to(get_tree(), main_game_scene)


# --- Helpers ----------------------------------------------------------------

func _ship(ship_name: StringName) -> Node2D:
	return get_node("%" + ship_name) as Node2D


## The way the ship's nose points. The player's sheet is drawn nose-up and
## the Attacker's nose-down, so their headings come off opposite axes.
func _heading(ship: Node2D) -> Vector2:
	var nose: Vector2 = Vector2.UP if ship == %PlayerShip else Vector2.DOWN
	return nose.rotated(ship.global_rotation)


func _random_point_on_screen() -> Vector2:
	return Vector2(
		RNGManager.randf_range(RNGManager.Bucket.COSMETIC, 0, Globals.SCREEN_SIZE.x),
		RNGManager.randf_range(RNGManager.Bucket.COSMETIC, 0, Globals.SCREEN_SIZE.y)
	)


func _flash_ship(ship: Node2D, color: Color, seconds: float) -> void:
	var material: ShaderMaterial = ship.material as ShaderMaterial
	if not material:
		return
	material.set_shader_parameter("flash_color", color)
	var tween: Tween = create_tween()
	tween.tween_property(material, "shader_parameter/flash_amount", 0.0, seconds).from(Juice.soften_flash(1.0)) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _flash_screen(color: Color, peak: float, seconds: float) -> void:
	var flash: ColorRect = %Flash
	flash.color = Color(color, Juice.screen_wash_alpha(peak))
	var tween: Tween = create_tween()
	tween.tween_property(flash, "color:a", 0.0, seconds).set_ease(Tween.EASE_OUT)


func _ring(spot: Vector2, color: Color, from_radius: float, to_radius: float, seconds: float) -> void:
	var ring: JuiceRing = JuiceRing.new()
	ring.color = color
	ring.start_radius = from_radius
	ring.end_radius = to_radius
	ring.duration = seconds
	_effects.add_child(ring)
	ring.global_position = spot


## A line of light along y from [param from_x] to [param to_x] that pinches
## shut: the wake a jump leaves.
func _streak(from_x: float, to_x: float, y: float, color: Color) -> void:
	var streak: ColorRect = ColorRect.new()
	streak.color = Globals.white
	streak.position = Vector2(minf(from_x, to_x), y - 1.5)
	streak.size = Vector2(absf(to_x - from_x), 3.0)
	streak.pivot_offset = streak.size / 2.0
	_effects.add_child(streak)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(streak, "color", color, 0.12)
	tween.tween_property(streak, "scale:y", 0.0, 0.35) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(streak.queue_free)


## Kicks the hull back against its heading for a frame or two. Offsets the
## sprite, not the node, because the timeline owns the node's position.
func _recoil(ship: Node2D) -> void:
	var sprite_offset: Vector2 = Vector2(0, 2) if ship == %PlayerShip else Vector2(0, -2)
	ship.set("offset", sprite_offset)
	var tween: Tween = create_tween()
	tween.tween_property(ship, "offset", Vector2.ZERO, 0.15).set_delay(0.05)


## The player's drive wash: a thin trail of cyan from both pods, on top of
## the flames drawn into the sheet.
## Swaps in the hull of the ship this run flies. Everything keyed on
## %PlayerShip (its path, its jumps) carries on with the new frames.
func _dress_player_ship(ship: ShipResource) -> void:
	if not ship or not ship.cutscene_frames:
		return
	%PlayerShip.sprite_frames = ship.cutscene_frames
	%PlayerShip.play(&"boost")


func _add_exhaust(ship: Node2D) -> void:
	var points: PackedVector2Array = PackedVector2Array([Vector2(-8.5, 9.0), Vector2(8.5, 9.0)])
	if ship == %PlayerShip and Globals.current_ship():
		points = Globals.current_ship().cutscene_exhaust_points
	for point: Vector2 in points:
		var exhaust: CPUParticles2D = CPUParticles2D.new()
		exhaust.texture = _PIXEL_TEXTURE
		exhaust.amount = 10
		exhaust.lifetime = 0.35
		exhaust.local_coords = false
		exhaust.direction = Vector2.DOWN
		exhaust.spread = 6.0
		exhaust.gravity = Vector2.ZERO
		exhaust.initial_velocity_min = 50.0
		exhaust.initial_velocity_max = 70.0
		exhaust.color = _BLUE_JUMP
		exhaust.color_ramp = _fade_ramp()
		exhaust.position = point
		exhaust.show_behind_parent = true
		ship.add_child(exhaust)


func _trail_particles() -> CPUParticles2D:
	var trail: CPUParticles2D = CPUParticles2D.new()
	trail.texture = _PIXEL_TEXTURE
	trail.amount = 14
	trail.lifetime = 0.25
	trail.local_coords = false
	trail.gravity = Vector2.ZERO
	trail.initial_velocity_max = 4.0
	trail.spread = 180.0
	trail.color = Globals.white
	trail.color_ramp = _fade_ramp()
	trail.show_behind_parent = true
	return trail


func _smoke_particles() -> CPUParticles2D:
	var smoke: CPUParticles2D = CPUParticles2D.new()
	smoke.texture = _PIXEL_TEXTURE
	smoke.amount = 40
	smoke.lifetime = 0.9
	smoke.local_coords = false
	# Drifts back off the ship's tail; the ship is flying right.
	smoke.direction = Vector2.LEFT
	smoke.spread = 20.0
	smoke.gravity = Vector2(0, -6)
	smoke.initial_velocity_min = 20.0
	smoke.initial_velocity_max = 35.0
	smoke.scale_amount_min = 1.0
	smoke.scale_amount_max = 3.0
	var ramp: Gradient = Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.12, 0.5, 1.0])
	ramp.colors = PackedColorArray([
		Globals.orange, Color("#a5a29d"), Color("#63605c"), Color(Color("#63605c"), 0.0)
	])
	smoke.color_ramp = ramp
	smoke.z_index = -1
	return smoke


func _strain_particles(ship: Node2D) -> CPUParticles2D:
	var sparks: CPUParticles2D = CPUParticles2D.new()
	sparks.name = "StrainSparks"
	sparks.texture = _PIXEL_TEXTURE
	sparks.amount = 18
	sparks.lifetime = 0.3
	sparks.local_coords = false
	# Out of the tail, which is local down for the player's nose-up sheet and
	# local up for the Attacker's nose-down one.
	var tail: Vector2 = Vector2.DOWN if ship == %PlayerShip else Vector2.UP
	sparks.position = tail * 12.0
	sparks.direction = tail
	sparks.spread = 25.0
	sparks.gravity = Vector2.ZERO
	sparks.initial_velocity_min = 45.0
	sparks.initial_velocity_max = 90.0
	var ramp: Gradient = Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	ramp.colors = PackedColorArray([Globals.yellow, Globals.orange, Color(Globals.red, 0.0)])
	sparks.color_ramp = ramp
	sparks.show_behind_parent = true
	sparks.emitting = false
	return sparks


func _charge_particles(seconds: float, color: Color) -> CPUParticles2D:
	var motes: CPUParticles2D = CPUParticles2D.new()
	motes.texture = _PIXEL_TEXTURE
	motes.amount = 24
	motes.lifetime = 0.4
	motes.local_coords = false
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
	motes.emission_sphere_radius = 26.0
	motes.gravity = Vector2.ZERO
	motes.radial_accel_min = -320.0
	motes.radial_accel_max = -260.0
	motes.color = color
	motes.color_ramp = _fade_in_ramp()
	get_tree().create_timer(seconds).timeout.connect(func() -> void:
		motes.emitting = false
		motes.finished.connect(motes.queue_free))
	return motes


func _fade_ramp() -> Gradient:
	var ramp: Gradient = Gradient.new()
	ramp.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	return ramp


func _fade_in_ramp() -> Gradient:
	var ramp: Gradient = Gradient.new()
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color.WHITE])
	return ramp


## Four corner brackets that close in on a target and then blink: a firing
## solution, drawn in single pixels to sit on the art grid.
class LockOnReticle extends Node2D:
	const _START_HALF_SIZE: float = 30.0
	const _END_HALF_SIZE: float = 15.0
	const _ARM: float = 4.0

	var target: Node2D
	var color: Color = Color.RED
	var _half_size: float = _START_HALF_SIZE:
		set(value):
			_half_size = value
			queue_redraw()

	func _ready() -> void:
		z_index = 5
		var tween: Tween = create_tween()
		tween.tween_property(self, "_half_size", _END_HALF_SIZE, 0.35) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		var blink: Tween = create_tween().set_loops()
		blink.tween_property(self, "visible", false, 0.0).set_delay(0.18)
		blink.tween_property(self, "visible", true, 0.0).set_delay(0.12)

	func _draw() -> void:
		var h: float = roundf(_half_size)
		for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			var tip: Vector2 = corner * h
			draw_line(tip, tip - Vector2(corner.x * _ARM, 0), color, 1.0)
			draw_line(tip, tip - Vector2(0, corner.y * _ARM), color, 1.0)


## Thin dashes of light whipping past, closer than the stars: the sense of
## speed the starfield is too far away to give. One art pixel tall.
class SpeedLines extends Node2D:
	## Lines spawned per second.
	var rate: float = 0.0
	var _owed: float = 0.0
	## Per line: x, y, length, speed.
	var _lines: Array[Vector4] = []

	func _process(delta: float) -> void:
		_owed += rate * delta
		while _owed >= 1.0:
			_owed -= 1.0
			_lines.append(Vector4(
				Globals.SCREEN_SIZE.x + RNGManager.randf_range(RNGManager.Bucket.COSMETIC, 0, 40),
				roundf(RNGManager.randf_range(RNGManager.Bucket.COSMETIC, 0, Globals.SCREEN_SIZE.y)),
				RNGManager.randf_range(RNGManager.Bucket.COSMETIC, 10, 48),
				RNGManager.randf_range(RNGManager.Bucket.COSMETIC, 380, 640)
			))
		for i: int in range(_lines.size() - 1, -1, -1):
			_lines[i].x -= _lines[i].w * delta
			if _lines[i].x + _lines[i].z < 0:
				_lines.remove_at(i)
		queue_redraw()

	func _draw() -> void:
		for line: Vector4 in _lines:
			# The faster the line, the brighter: nearer things whip past.
			var alpha: float = remap(line.w, 380, 640, 0.2, 0.55)
			draw_rect(Rect2(roundf(line.x), line.y, roundf(line.z), 1), Color(Globals.white, alpha))
