class_name EndingCutscene
extends Node
## The ending of the run that first learns the secret (LORE.md §4, §6): the
## player's ship pulls away from the Bastion's burning husk, its broken tithe
## vault spilling dice that don't drift back toward Fate but stream past the
## ship, forward, into a second black hole ahead: the opening's Fate, exactly
## mirrored. The screen glitches out into its purple, and Fate's Die turns in
## the light, blank, until its faces carve themselves one by one. "Fate only
## notices those who choose..." Then UNLOCKED, black, and the victory screen.
##
## It plays over the game scene rather than replacing it, so the run is still
## there to be won once it ends (the victory screen, the save, the run's
## numbers). Its own layers sit above everything but the pause menu.
##
## Built like the opening (opening_cutscene.gd): everything that is art lives
## in the PixelWorld SubViewport, 320x180 blown up 6x; the starfield sits
## behind it at 1080p so it glides. The flight is the AnimationPlayer's
## "ending_anim" (paths, the shot, fades and the one-shot effects on its
## method track); the vision of the die that follows is timed here, since
## its carvings follow the die as it turns.
##
## Camera direction rhymes with the opening in reverse: the opening starts
## close on the ship and pulls out; this starts close and pulls out, then
## pushes in on the ship and the hole where the opening's last push was.

## The flight is over and the run has been handed to the victory screen.
signal finished

const SCENE: String = "res://Source/Scenes/Cutscenes/ending_cutscene.tscn"

@export_category('Starfield')
@export var num_of_stars: int = 110
@export var num_of_twinkling_stars: int = 25
@export var star_pixel_scene: PackedScene
@export var star_twinkle_scene: PackedScene
## Keyed. How fast the stars stream past, in art pixels per second.
@export var star_speed: float = 30.0
## Keyed. How far each star smears into a streak, as a multiple of its width.
@export var star_stretch: float = 1.0

@export_category('Shot')
## Keyed. How far the shot is pushed in on the 320x180 frame; 1 shows all of
## it. Held on multiples of 1/6, as in the opening.
@export var view_zoom: float = 1.0
## Keyed. The point of the frame, in art pixels, the shot centres on.
@export var view_center: Vector2 = Vector2(160, 90)

@export_category('Husk')
## Scrap shed by the husk, drifting back behind the ship.
@export var debris_scenes: Array[PackedScene] = []
@export var num_of_debris: int = 7
## Keyed. How bright the husk's last running lights are, 0-1. Under 1 they
## stutter; at 0 they're dead.
@export var husk_power: float = 1.0
## Keyed. Tithe dice spilled from the broken vault per second.
@export var tithe_spill: float = 0.0

@export_category('Fate')
## Keyed. Whether Fate throws its lightning about, once it's in view.
@export var fate_weather: bool = false

@export_category('Vision')
## Seconds the die takes to come out of the purple.
@export var die_fade_in: float = 2.4
## Seconds after it's fully in before the first carving, then between them.
@export var first_carve_delay: float = 0.5
@export var carve_interval: float = 0.6
## Seconds after the last carving before the words start.
@export var words_delay: float = 1.2
@export var characters_per_second: float = 18.0
## Seconds held on each point of the closing ellipsis before the next.
@export var ellipsis_beats: PackedFloat32Array = PackedFloat32Array([0.95, 0.95, 1.25])
@export var unlocked_hold: float = 2.4
@export var fade_out_seconds: float = 1.1
## Seconds the victory screen takes to come up out of the black.
@export var victory_fade_in: float = 0.45

## The tithe: ordinary dice, every face of them, taken off ordinary ships.
const _TITHE_DICE: Array[Texture2D] = [
	preload("res://Assets/Textures/Dice/Regular/dice1.png"),
	preload("res://Assets/Textures/Dice/Regular/dice2.png"),
	preload("res://Assets/Textures/Dice/Regular/dice3.png"),
	preload("res://Assets/Textures/Dice/Regular/dice4.png"),
	preload("res://Assets/Textures/Dice/Regular/dice5.png"),
	preload("res://Assets/Textures/Dice/Regular/dice6.png"),
]
const _PIXEL_TEXTURE: Texture2D = preload("res://Assets/Particles/hit_particle_pixel.png")
const _SNAP_SHADER: Shader = preload("res://Assets/Shaders/palette_snap.gdshader")
const _GLITCH_SCENE: PackedScene = preload("res://Source/Systems/UI/Glitch/glitch_shader.tscn")

# Borrowed sounds: SOUND_EFFECTS_TODO.md lists the ones this wants made.
const _BLAST_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/enemy_death_explosion.tres")
const _VAULT_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/glass_crack.tres")
const _FATE_PULSE_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/die_dread_thunk.tres")
const _CARVE_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/upgrade_trigger.tres")
const _POINT_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/die_dead_click.tres")
const _UNLOCKED_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/die_dread_thunk.tres")

## Debris closer than this to Fate's centre stretches; at the horizon it's gone.
const _STRETCH_RANGE: float = 70.0
const _EVENT_HORIZON: float = 14.0
const _FATE_RIM: float = 40.0
const _FATE_PURPLE: Color = Color("#c552f1")
## The purple the vision settles into once the flood has passed: dark enough
## that Fate's purple words read on it.
const _VISION_DEEP: Color = Color("#251c6b")
const _FLIGHT_TRACK: StringName = &"game_start_theme"
const _ART_SCALE: float = 6.0
## Where the husk's three bays are, from its centre, once it's turned to face
## the way the ship flew (the hull art is drawn nose-down and turned a quarter).
const _BAYS: Array[Vector2] = [Vector2(2, 62), Vector2(-2, 0), Vector2(2, -62)]
## The tithe vault: the middle bay, where the Marshal's core sat.
const _VAULT: int = 1

var _stars: Array[Node2D] = []
var _star_depths: PackedFloat32Array = PackedFloat32Array()
## Scrap drifting back off the husk.
var _debris: Array[Node2D] = []
var _debris_speeds: PackedFloat32Array = PackedFloat32Array()
## The tithe dice: each sits in an unrotated holder, which is what Fate
## stretches, while the die inside tumbles.
var _dice: Array[Node2D] = []
var _dice_velocity: PackedVector2Array = PackedVector2Array()
var _dice_spin: PackedFloat32Array = PackedFloat32Array()
var _spill_owed: float = 0.0
var _husk_material: ShaderMaterial
var _fires: Array[CPUParticles2D] = []
var _jump_fx: JumpFx
var _die: FateDieSpin
var _die_sprite: Sprite2D
var _words: Label
var _unlocked: Label
var _vision: Tween
var _done: bool = false
var _hidden_cursor_layer: CanvasLayer

@onready var _star_layer: CanvasLayer = $StarLayer
@onready var _pixel_layer: CanvasLayer = $PixelLayer
@onready var _pixel_screen: SubViewportContainer = $PixelLayer/PixelScreen
@onready var _curtain: ColorRect = $CurtainLayer/Curtain
@onready var _effects: Node2D = %Effects
@onready var _fate: Node2D = %Fate
@onready var _storm: FateStorm = %FateStorm
@onready var _husk: Node2D = %Husk
@onready var _ship: AnimatedSprite2D = %PlayerShip
@onready var _vision_root: Node2D = %Vision
@onready var _timeline: AnimationPlayer = $AnimationPlayer


## Plays the ending over the running game scene and waits for it to hand the
## run to the victory screen.
static func play() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var ending: EndingCutscene = (load(SCENE) as PackedScene).instantiate()
	tree.current_scene.add_child(ending)
	await ending.finished


func _ready() -> void:
	var skip: CutsceneSkipPrompt = CutsceneSkipPrompt.new(96)
	skip.confirmed.connect(_skip)
	add_child(skip)
	_hide_cursor(true)
	_jump_fx = JumpFx.new(_effects, true)
	_spawn_stars()
	_spawn_debris()
	_dress_husk()
	_dress_player_ship(Globals.current_ship())
	_add_exhaust(_ship)
	_build_vision()
	var glitch: CanvasLayer = CanvasLayer.new()
	glitch.layer = 94
	glitch.add_child(_GLITCH_SCENE.instantiate())
	add_child(glitch)

	# The jump cuts to black over the game first; the flight comes up out of
	# the black behind the curtain.
	_pixel_layer.visible = false
	_star_layer.visible = false
	$BackdropLayer.visible = false
	_timeline.play(&"ending_anim")
	_timeline.advance(0.0)
	_timeline.pause()
	MusicDirector.stop(1.0)
	_curtain.color.a = 0.0
	var open: Tween = create_tween()
	open.tween_property(_curtain, "color:a", 1.0, 0.6)
	open.tween_callback(func() -> void:
		_pixel_layer.visible = true
		_star_layer.visible = true
		$BackdropLayer.visible = true
		_curtain.color.a = 0.0
		_timeline.play())


func _process(delta: float) -> void:
	_frame_shot()
	_move_stars(delta)
	_move_debris(delta)
	_spill_tithe(delta)
	_move_dice(delta)
	_flicker_husk()
	_storm.visible = _fate.visible
	_storm.autonomous = _fate.visible and fate_weather


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


func _move_stars(delta: float) -> void:
	for i: int in range(_stars.size()):
		var star: Node2D = _stars[i]
		var depth: float = _star_depths[i]
		star.position.x -= star_speed * depth * delta
		star.scale.x = lerpf(1.0, star_stretch, depth)
		if star.position.x < -star.scale.x:
			star.position.x = Globals.SCREEN_SIZE.x + star.scale.x
			star.position.y = _randf(0, Globals.SCREEN_SIZE.y)


# --- The husk ---------------------------------------------------------------

## The Bastion as it was left: its three mounts gone, a scar in every bay,
## fire in them, and its lights on their last flicker.
func _dress_husk() -> void:
	var body: Sprite2D = %HuskBody
	_husk_material = body.material as ShaderMaterial
	for bay: int in _BAYS.size():
		var fire: CPUParticles2D = _fire_particles(bay == _VAULT)
		_husk.add_child(fire)
		fire.position = _BAYS[bay]
		_fires.append(fire)


## The husk's lights stutter while power is between dead and full.
func _flicker_husk() -> void:
	if not _husk_material:
		return
	var lit: float = husk_power
	if husk_power > 0.0 and husk_power < 1.0:
		lit = 1.0 if _randf(0.0, 1.0) < husk_power * 0.8 else 0.0
	_husk_material.set_shader_parameter("lights", lit)


func _spawn_debris() -> void:
	if debris_scenes.is_empty():
		return
	for i: int in range(num_of_debris):
		var holder: Node2D = Node2D.new()
		%Debris.add_child(holder)
		var piece: Node2D = (debris_scenes[i % debris_scenes.size()]).instantiate()
		holder.add_child(piece)
		piece.rotation = _randf(0.0, TAU)
		var depth: float = _randf(0.5, 1.1)
		var shade: float = remap(depth, 0.5, 1.1, 0.45, 0.85)
		holder.modulate = Color(shade, shade, shade)
		holder.position = _husk.position + Vector2(_randf(-10, 40), _randf(-80, 80))
		_debris.append(holder)
		_debris_speeds.append(_randf(4.0, 14.0) * depth)


## Scrap falls back behind the ship faster than the husk does: the husk is
## huge and far, the scrap close.
func _move_debris(delta: float) -> void:
	for i: int in range(_debris.size()):
		var holder: Node2D = _debris[i]
		holder.position.x -= (_debris_speeds[i] + star_speed * 0.4) * delta
		holder.get_child(0).rotation += 0.6 * delta * (1.0 if i % 2 == 0 else -1.0)


## A secondary blast somewhere on the husk. [param bay] -1 picks a spot on
## the hull at random.
func _husk_blast(bay: int, strength: float) -> void:
	var spot: Vector2 = _husk.global_position + (
		_BAYS[bay] if bay >= 0 else Vector2(_randf(-26, 26), _randf(-90, 90)))
	Events.play_sound.emit(_BLAST_SFX)
	if strength > 1.0:
		Events.camera_shake_large.emit()
	else:
		Events.camera_shake_small.emit()
	Juice.sparkle(_effects, spot, Globals.orange, int(10 * strength), 40.0 * strength)
	Juice.sparkle(_effects, spot, Globals.yellow, int(6 * strength), 28.0 * strength)
	_ring(spot, Globals.orange, 2.0, 10.0 + 8.0 * strength, 0.35)


## The tithe vault gives: a flash in the middle bay, and the dice it held
## burst out toward the ship, and past it.
func _vault_breaks() -> void:
	var spot: Vector2 = _husk.global_position + _BAYS[_VAULT]
	Events.play_sound.emit(_VAULT_SFX)
	Events.play_sound.emit(_BLAST_SFX)
	Events.camera_shake_large.emit()
	TimeDirector.hitstop(90)
	_ring(spot, Globals.white, 3.0, 26.0, 0.4)
	_ring(spot, Globals.yellow, 4.0, 40.0, 0.6)
	Juice.sparkle(_effects, spot, Globals.yellow, 16, 60.0)
	for i: int in 14:
		_spill_die(spot, _randf(70.0, 150.0))


# --- The tithe --------------------------------------------------------------

func _spill_tithe(delta: float) -> void:
	_spill_owed += tithe_spill * delta
	while _spill_owed >= 1.0:
		_spill_owed -= 1.0
		_spill_die(_husk.global_position + _BAYS[_VAULT] + Vector2(4, _randf(-6, 6)), _randf(45.0, 95.0))


func _spill_die(from: Vector2, speed: float) -> void:
	var holder: Node2D = Node2D.new()
	var die: Sprite2D = Sprite2D.new()
	die.texture = _TITHE_DICE[int(_randf(0.0, _TITHE_DICE.size() - 0.001))]
	die.rotation = _randf(0.0, TAU)
	holder.add_child(die)
	# Some pass in front of the ship, some behind it.
	holder.z_index = 12 if _randf(0.0, 1.0) < 0.4 else 6
	%Tithe.add_child(holder)
	holder.global_position = from
	_dice.append(holder)
	# Out of the vault in a fan, but all of it forward: toward the hole ahead.
	var heading: float = _randf(-0.75, 0.75)
	_dice_velocity.append(Vector2.RIGHT.rotated(heading) * speed)
	_dice_spin.append(_randf(-5.0, 5.0))


## The dice flow forward past the ship. Once Fate is in front of them they
## fall toward it, faster the nearer, stretch thin along the pull and are gone
## at the horizon, the way the opening's wreckage falls into the Fate behind.
func _move_dice(delta: float) -> void:
	var hole: Vector2 = _fate.global_position
	for i: int in range(_dice.size() - 1, -1, -1):
		var holder: Node2D = _dice[i]
		var velocity: Vector2 = _dice_velocity[i]
		var to_hole: Vector2 = hole - holder.position
		var distance: float = to_hole.length()
		var pull: float = clampf(1.0 - distance / 300.0, 0.0, 1.0)
		# The fan closes up onto the stream, then the stream onto the hole.
		velocity.y = lerpf(velocity.y, 0.0, delta * 0.8)
		velocity += to_hole.normalized() * (14.0 + 220.0 * pull * pull) * delta
		_dice_velocity[i] = velocity
		holder.position += velocity * delta
		holder.get_child(0).rotation += _dice_spin[i] * (1.0 + pull * 4.0) * delta

		var squeeze: float = clampf(distance / _STRETCH_RANGE, 0.0, 1.0)
		holder.rotation = to_hole.angle()
		holder.scale = Vector2(lerpf(2.5, 1.0, squeeze), lerpf(0.0, 1.0, squeeze))
		var gone: bool = distance < _EVENT_HORIZON or holder.position.x > Globals.SCREEN_SIZE.x + 60.0
		if gone:
			if distance < _EVENT_HORIZON and i % 3 == 0:
				Juice.sparkle(_effects, hole, _FATE_PURPLE, 3, 18.0)
			holder.queue_free()
			_dice.remove_at(i)
			_dice_velocity.remove_at(i)
			_dice_spin.remove_at(i)


# --- Fate ahead -------------------------------------------------------------

## Fate breathing, as in the opening.
func _fate_pulse(strength: float) -> void:
	Events.play_sound.emit(_FATE_PULSE_SFX)
	var centre: Vector2 = _fate.global_position
	var storm_centre: Vector2 = _storm.to_local(centre)
	_ring(centre, _FATE_PURPLE, 70.0, 110.0 + 40.0 * strength, 0.9)
	if strength > 1.0:
		_ring(centre, Globals.white, 60.0, 180.0, 0.7)
		_flash_screen(_FATE_PURPLE, 0.4, 0.5)
		_storm.strike_from(storm_centre, 7, 110.0, _FATE_RIM)
		_storm.strike(FateStorm.Kind.TEAR)
		Events.camera_shake_large.emit()
	else:
		_storm.strike_from(storm_centre, 4, 35.0, _FATE_RIM, 0.8)
		Events.camera_shake_small.emit()


## The picture breaking up as it nears the hole: the glitch layer for a
## moment, and the ship blinking out of it.
func _glitch(milliseconds: int) -> void:
	Events.glitch_burst.emit(milliseconds)
	_ship.visible = false
	var back: Tween = create_tween()
	back.tween_interval(milliseconds / 2000.0)
	back.tween_callback(func() -> void: _ship.visible = true)


## Hot sparks off the drive, fighting the pull.
func _strain(straining: bool) -> void:
	var sparks: CPUParticles2D = _ship.get_node_or_null(^"StrainSparks")
	if not sparks:
		sparks = _strain_particles()
		_ship.add_child(sparks)
	sparks.emitting = straining


## The last frame of the flight: the music cuts and the purple takes the
## screen. Keyed just before the flood fades in.
func _cut_to_purple() -> void:
	MusicDirector.stop(0.05)
	Events.glitch_burst.emit(260)
	Events.camera_shake_large.emit()


# --- The vision -------------------------------------------------------------

func _build_vision() -> void:
	_die = FateDieSpin.new()
	_vision_root.add_child(_die)
	_die_sprite = Sprite2D.new()
	_die_sprite.texture = _die.get_texture()
	_die_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var snap: ShaderMaterial = ShaderMaterial.new()
	snap.shader = _SNAP_SHADER
	_die_sprite.material = snap
	_die_sprite.position = Vector2(160, 92)
	_die_sprite.modulate.a = 0.0
	_vision_root.add_child(_die_sprite)
	_die.carved.connect(_on_carved)
	var rim: FateRim = FateRim.new()
	rim.position = _die_sprite.position
	_vision_root.add_child(rim)
	_vision_root.move_child(rim, _die_sprite.get_index())

	_words = _vision_label(tr(&"ENDING_FATE_NOTICES"), Globals.purple, FontRoles.BODY, 20)
	_words.visible_characters = 0
	_unlocked = _vision_label(tr(&"ENDING_UNLOCKED"), Globals.orange, FontRoles.SMALL, 146, 2.0)
	_unlocked.modulate.a = 0.0
	_vision_root.visible = false


func _vision_label(text: String, color: Color, role: StringName, top: float, scale: float = 1.0) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.theme_type_variation = FontRoles.slot(role, scale)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", FateDieArt.OUTLINE)
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = Vector2(0, top)
	label.size = Vector2(Globals.SCREEN_SIZE.x, 0)
	_vision_root.add_child(label)
	return label


## Keyed at the end of the flight, once the purple has the screen.
func _begin_vision() -> void:
	_vision_root.visible = true
	%World.visible = false
	_star_layer.visible = false
	var flood: ColorRect = %Flood
	_vision = create_tween()
	_vision.tween_property(flood, "color", _VISION_DEEP, die_fade_in + 0.4).set_ease(Tween.EASE_IN_OUT)
	_vision.parallel().tween_property(_die_sprite, "modulate:a", 1.0, die_fade_in).set_ease(Tween.EASE_IN)
	_vision.tween_interval(first_carve_delay)
	var faces: Array[FateDie.Face] = FateDie.carvable_faces()
	for i: int in faces.size():
		if i > 0:
			_vision.tween_interval(carve_interval)
		_vision.tween_callback(_die.carve_facing.bind(faces[i]))
	_vision.tween_interval(words_delay)
	_type_words(_vision)
	_vision.tween_property(_unlocked, "modulate:a", 1.0, 0.35)
	_vision.parallel().tween_callback(_unlocked_lands)
	_vision.tween_interval(unlocked_hold)
	_vision.tween_property(%Fade, "modulate:a", 1.0, fade_out_seconds)
	_vision.tween_callback(_hand_over)


## The words come in a letter at a time; each point of the closing ellipsis
## lands on its own, with a click, after a beat.
func _type_words(sequence: Tween) -> void:
	var text: String = _words.text
	var points: int = 0
	while points < text.length() and text[text.length() - 1 - points] in [".", "…"]:
		points += 1
	var letters: int = text.length() - points
	sequence.tween_property(_words, "visible_characters", letters, letters / characters_per_second)
	for point: int in points:
		var beat: float = ellipsis_beats[mini(point, ellipsis_beats.size() - 1)]
		sequence.tween_interval(beat)
		sequence.tween_callback(func() -> void:
			_words.visible_characters = letters + point + 1
			Events.play_sound.emit(_POINT_SFX))
	sequence.tween_interval(ellipsis_beats[ellipsis_beats.size() - 1])


## A face cut into the die as it turns: it flares in the face's colour, and
## sparks fly off it.
func _on_carved(_side: int, face: FateDie.Face) -> void:
	var res: FateFaceResource = FateFaceCatalog.get_face(face)
	var color: Color = res.color if res else Globals.white
	Events.play_sound.emit(_CARVE_SFX)
	Events.camera_shake_small.emit()
	_flash_die(0.8, 0.35)
	Juice.sparkle(_vision_root, _die_sprite.position, color, 12, 45.0)
	Juice.sparkle(_vision_root, _die_sprite.position, Globals.white, 6, 30.0)
	Juice.ring(_vision_root, _die_sprite.position, color, 30.0, 0.4, 14.0)


func _unlocked_lands() -> void:
	Events.play_sound.emit(_UNLOCKED_SFX)
	Events.camera_shake_large.emit()
	_flash_die(1.0, 0.5)
	Juice.ring(_vision_root, _die_sprite.position, Globals.orange, 46.0, 0.6, 16.0)


func _flash_die(peak: float, seconds: float) -> void:
	var snap: ShaderMaterial = _die_sprite.material as ShaderMaterial
	snap.set_shader_parameter("flash", peak)
	var fade: Tween = create_tween()
	fade.tween_method(func(amount: float) -> void: snap.set_shader_parameter("flash", amount),
		peak, 0.0, seconds).set_ease(Tween.EASE_OUT)


# --- Hand-over --------------------------------------------------------------

## A second press of anything: straight to black and the victory screen.
func _skip() -> void:
	if _done:
		return
	_timeline.pause()
	if _vision:
		_vision.kill()
	var close: Tween = create_tween()
	close.tween_property(_curtain, "color:a", 1.0, 0.25)
	close.tween_callback(_hand_over)


## On black: the run is won. The victory screen comes up under the curtain,
## which then lifts off it.
func _hand_over() -> void:
	if _done:
		return
	_done = true
	_timeline.pause()
	_curtain.color.a = 1.0
	_pixel_layer.visible = false
	_star_layer.visible = false
	$BackdropLayer.visible = false
	_hide_cursor(false)
	Events.fate_ending.emit(&"unlocked")
	Events.victory.emit()
	MusicDirector.play_track(_FLIGHT_TRACK, 2.0, true)
	var lift: Tween = create_tween()
	lift.tween_property(_curtain, "color:a", 0.0, victory_fade_in)
	lift.tween_callback(func() -> void:
		finished.emit()
		queue_free())


## The game's pointer would float over the film; it comes back for the
## victory screen's buttons.
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


# --- Timeline calls ---------------------------------------------------------

## Keyed when the flight starts: the theme comes in under the husk's fires.
func _music_in() -> void:
	MusicDirector.play_track(_FLIGHT_TRACK, 3.0, true)


# --- Helpers ----------------------------------------------------------------

func _dress_player_ship(ship: ShipResource) -> void:
	if not ship or not ship.cutscene_frames:
		return
	_ship.sprite_frames = ship.cutscene_frames
	_ship.play(&"boost")


## The drive's wash, in the Horizon Drive's gold: the drive the Marshal
## handed over is what's running now.
func _add_exhaust(ship: Node2D) -> void:
	var points: PackedVector2Array = PackedVector2Array([Vector2(-8.5, 9.0), Vector2(8.5, 9.0)])
	if Globals.current_ship():
		points = Globals.current_ship().cutscene_exhaust_points
	for point: Vector2 in points:
		var exhaust: CPUParticles2D = CPUParticles2D.new()
		exhaust.texture = _PIXEL_TEXTURE
		exhaust.amount = 12
		exhaust.lifetime = 0.4
		exhaust.local_coords = false
		exhaust.direction = Vector2.DOWN
		exhaust.spread = 6.0
		exhaust.gravity = Vector2.ZERO
		exhaust.initial_velocity_min = 50.0
		exhaust.initial_velocity_max = 75.0
		exhaust.color = EngineCharger.DRIVE_COLOR
		exhaust.color_ramp = _fade_ramp()
		exhaust.position = point
		exhaust.show_behind_parent = true
		ship.add_child(exhaust)


func _fire_particles(big: bool) -> CPUParticles2D:
	var fire: CPUParticles2D = CPUParticles2D.new()
	fire.texture = _PIXEL_TEXTURE
	fire.amount = 26 if big else 16
	fire.lifetime = 0.8
	fire.local_coords = false
	fire.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	fire.emission_rect_extents = Vector2(8, 14)
	# The ship is flying away to the right, so what burns off trails left.
	fire.direction = Vector2.LEFT
	fire.spread = 35.0
	fire.gravity = Vector2(-10, 0)
	fire.initial_velocity_min = 6.0
	fire.initial_velocity_max = 18.0
	fire.scale_amount_min = 1.0
	fire.scale_amount_max = 2.0
	var ramp: Gradient = Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 0.6, 1.0])
	ramp.colors = PackedColorArray([Globals.yellow, Globals.orange, Globals.red, Color(Globals.dark_gray, 0.0)])
	fire.color_ramp = ramp
	fire.z_index = 1
	return fire


func _strain_particles() -> CPUParticles2D:
	var sparks: CPUParticles2D = CPUParticles2D.new()
	sparks.name = "StrainSparks"
	sparks.texture = _PIXEL_TEXTURE
	sparks.amount = 18
	sparks.lifetime = 0.3
	sparks.local_coords = false
	# Out of the tail, local down on the player's nose-up sheet.
	sparks.position = Vector2.DOWN * 12.0
	sparks.direction = Vector2.DOWN
	sparks.spread = 25.0
	sparks.gravity = Vector2.ZERO
	sparks.initial_velocity_min = 45.0
	sparks.initial_velocity_max = 90.0
	var ramp: Gradient = Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	ramp.colors = PackedColorArray([Globals.white, EngineCharger.DRIVE_COLOR, Color(Globals.orange, 0.0)])
	sparks.color_ramp = ramp
	sparks.show_behind_parent = true
	sparks.emitting = false
	return sparks


func _fade_ramp() -> Gradient:
	var ramp: Gradient = Gradient.new()
	ramp.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	return ramp


func _flash_screen(color: Color, peak: float, seconds: float) -> void:
	var flash: ColorRect = %Flash
	flash.color = Color(color, Juice.screen_wash_alpha(peak))
	var tween: Tween = create_tween()
	tween.tween_property(flash, "color:a", 0.0, seconds).set_ease(Tween.EASE_OUT)


func _ring(spot: Vector2, color: Color, from_radius: float, to_radius: float, seconds: float) -> void:
	_jump_fx.ring(spot, color, from_radius, to_radius, seconds)


func _random_point_on_screen() -> Vector2:
	return Vector2(_randf(0, Globals.SCREEN_SIZE.x), _randf(0, Globals.SCREEN_SIZE.y))


func _randf(from: float, to: float) -> float:
	return RNGManager.randf_range(RNGManager.Bucket.COSMETIC, from, to)


## A faint ring behind the die, breathing: Fate's rim, seen from the inside.
## Drawn a pixel at a time so it stays on the art grid.
class FateRim extends Node2D:
	const _RADIUS: float = 52.0
	const _COLOR: Color = Color("#463c91")
	var _age: float = 0.0

	func _process(delta: float) -> void:
		_age += delta
		queue_redraw()

	func _draw() -> void:
		var radius: float = _RADIUS + roundf(sin(_age * 1.3) * 2.0)
		var steps: int = int(TAU * radius)
		var drawn: Dictionary[Vector2i, bool] = {}
		for i: int in steps:
			var at: Vector2 = Vector2.from_angle(TAU * i / steps) * radius
			var pixel: Vector2i = Vector2i(roundi(at.x), roundi(at.y))
			if drawn.has(pixel):
				continue
			drawn[pixel] = true
			draw_rect(Rect2(pixel, Vector2.ONE), _COLOR)
