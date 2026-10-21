class_name CockpitDestruction
extends Node2D
## The player's death: the cockpit tears itself apart, then the game ends.
##
## The canopy's cracks, faded to ghosts by now, come back one at a time in the
## order they were taken, faster and faster, until the glass gives way.
##
## The fight has already stopped by the time this plays (player_destroyed
## shuts the scenario engine down), but nothing is frozen: the ships keep
## hovering, shots already in the air land, the background keeps scrolling.
## The breaks rupture one after another, the shell blows out into pieces and
## the panels tumble away, leaving the pilot's view of open space and the
## ships that did it. game_over follows once the wreckage has cleared.

const _EXPLOSION_SCENE: PackedScene = preload("res://Assets/Particles/enemy_death_explosion.tscn")
const _PIXEL: Texture2D = preload("res://Assets/Particles/hit_particle_pixel.png")
const _KLAXON_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/alarm_klaxon.tres")
const _RUPTURE_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/enemy_pre_death.tres")
const _EXPLOSION_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/enemy_death_explosion.tres")

## Above the ships and the hand: the cockpit is the nearest thing to the
## camera, and its pieces fly past everything on their way out.
const _DEBRIS_Z: int = 30
## Over the rest of the debris: the dice cross the middle of the screen just
## as the main viewer tumbles through it, and must not vanish behind it.
const _HANGING_DICE_Z: int = _DEBRIS_Z + 5

## How much debris grows over its flight (min, max), which sells it coming at
## the camera. A whole panel is already big; growing it as much as a shard
## would fill the screen with it.
const _FRAGMENT_GROW: Vector2 = Vector2(1.3, 2.2)
const _PANEL_GROW: Vector2 = Vector2(1.05, 1.3)

@export var rupture_time: float = 1.6
## How long the wreckage tumbles before the game-over panel comes up.
@export var aftermath_time: float = 2.4
## The shell is cut into cells this size; each with enough cockpit in it
## becomes a piece.
@export var fragment_size: Vector2i = Vector2i(16, 12)
## Where the blast comes from. Below centre, under the dash: the pieces fly
## up and out, toward and past the camera.
@export var blast_origin: Vector2 = Vector2(160, 130)

@export_group("Breakup Slow-Mo")
## The moment the shell blows apart plays in slow motion, so the pieces can
## be seen leaving rather than just gone.
@export var breakup_slow_mo_scale: float = 0.25
## Real (unscaled) milliseconds the slow-mo lasts.
@export var breakup_slow_mo_ms: int = 1600
## Where the hanging dice's hook is carried to. The dice don't scatter at
## random like the rest of the wreckage: every death, they tear off the
## top-right strut and drift through the middle of the screen during the
## slow-mo, then snap apart and fly off. The one fixed beat in the sequence.
@export var hanging_dice_crossing: Vector2 = Vector2(178, 70)
@export var hanging_dice_crossing_scale: float = 1.6
@export var hanging_dice_crossing_rotation: float = -0.5
## How fast the two dice fly off once their chains snap, in pixels/second.
@export var hanging_dice_split_speed: float = 260.0

## Everything flying apart, as {node, velocity, spin, grow, age, life,
## rest_scale, owned, fade}. Shell fragments slow and fade. The player's
## panels are thrown clear off screen instead: tiles draw through a shader
## that ignores modulate, so a panel fading out would leave its tiles hanging
## in space. Owned pieces were made here and are freed; borrowed ones hidden.
var _debris: Array[Dictionary] = []
var _playing: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

@onready var _damage: CockpitDamage = get_parent() as CockpitDamage


func _ready() -> void:
	_rng.randomize()
	z_as_relative = false
	z_index = _DEBRIS_Z
	Events.player_destroyed.connect(play)


func play() -> void:
	if _playing:
		return
	_playing = true
	# A hitstop from the killing blow would hold the whole sequence on one
	# frame. Swap it for a brief slow-mo, so the hit still lands heavy.
	TimeDirector.clear()
	TimeDirector.slow_mo(0.3, 450)
	Events.red_alert.emit(rupture_time + 1.0)
	Events.glitch_burst.emit(250)
	Events.play_sound.emit(_KLAXON_SFX)
	for site: CockpitDamageSite in _glass_sites():
		site.dim()

	await get_tree().create_timer(0.35).timeout
	await _rupture()
	_break_apart()
	await get_tree().create_timer(aftermath_time).timeout
	Events.game_over.emit()


## The breaks blow out one after another, faster and faster, as the frame
## gives way, and the cracks come back across the canopy.
func _rupture() -> void:
	var points: Array[Vector2] = _all_emit_points()
	if points.is_empty():
		points.append(blast_origin)
	for site: CockpitDamageSite in _sites():
		site.billow(1.0)

	var cracks: Array[CockpitDamageSite] = _glass_sites()
	var cracks_back: int = 0
	var elapsed: float = 0.0
	var blasts: int = 0
	while elapsed < rupture_time:
		var progress: float = elapsed / rupture_time
		while cracks_back < cracks.size() \
				and progress >= crack_return_at(cracks_back, cracks.size()):
			cracks[cracks_back].flare_back()
			cracks_back += 1
		var point: Vector2 = points[_rng.randi() % points.size()] \
				+ Vector2(_rng.randf_range(-4, 4), _rng.randf_range(-4, 4))
		_explosion(point)
		_sparks(point, Globals.orange, 10, 70.0)
		Events.camera_shake_small.emit()
		if blasts % 3 == 0:
			Events.play_sound.emit(_RUPTURE_SFX)
		blasts += 1

		var gap: float = lerpf(0.24, 0.07, progress)
		await get_tree().create_timer(gap).timeout
		elapsed += gap
	for i: int in range(cracks_back, cracks.size()):
		cracks[i].flare_back()


## When crack [param index] of [param count] comes back, as a fraction of the
## rupture. The gaps shrink gently as it goes, and the last lands a beat
## before the glass blows out, long enough to register.
static func crack_return_at(index: int, count: int) -> float:
	if count <= 1:
		return 0.08
	return 0.08 + 0.82 * pow(float(index) / (count - 1), 0.75)


## The shell blows apart. Every visible piece of cockpit becomes debris.
func _break_apart() -> void:
	TimeDirector.slow_mo(breakup_slow_mo_scale, breakup_slow_mo_ms)
	Events.play_sound.emit(_EXPLOSION_SFX)
	Events.camera_shake_large.emit(true)
	Events.camera_zoom_punch.emit(1.08, blast_origin, true)
	_flash()
	for i: int in 5:
		_explosion(blast_origin + Vector2(_rng.randf_range(-110, 110), _rng.randf_range(-30, 45)))

	_shatter_glass()
	_fragment_walls()
	_fling_ambience()
	_fling_player_panels()


func _shatter_glass() -> void:
	var glass_points: Array[Vector2] = []
	for site: CockpitDamageSite in _glass_sites():
		for point: Vector2 in site.emit_points:
			glass_points.append(site.to_global(point))
	if _damage:
		_damage.glass_shards.blow_away(blast_origin, glass_points, 3)
	for site: CockpitDamageSite in _sites():
		site.stop_smoke()
		site.hide()
		if site.kind != CockpitDamageSite.Kind.GLASS:
			continue
		for point: Vector2 in site.emit_points:
			_sparks(point, Globals.white, 14, 120.0)
	# The rest of the canopy goes too, not just the cracked panes.
	for i: int in 12:
		var point: Vector2 = Vector2(_rng.randf_range(10, 310), _rng.randf_range(5, 70))
		_sparks(point, Globals.white, 6, 90.0)


## Cuts the cockpit shell into cells and throws each one off on its own.
func _fragment_walls() -> void:
	var walls: Sprite2D = _walls()
	if not walls or not walls.texture:
		return
	var image: Image = walls.texture.get_image()
	var top_left: Vector2 = walls.global_position - walls.texture.get_size() / 2.0 \
			if walls.centered else walls.global_position
	walls.hide()

	for cy: int in range(0, image.get_height(), fragment_size.y):
		for cx: int in range(0, image.get_width(), fragment_size.x):
			var region: Rect2i = Rect2i(cx, cy, fragment_size.x, fragment_size.y) \
					.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
			if _opaque_pixels(image, region) < 6:
				continue
			var atlas: AtlasTexture = AtlasTexture.new()
			atlas.atlas = walls.texture
			atlas.region = Rect2(region)
			var piece: Sprite2D = Sprite2D.new()
			piece.texture = atlas
			add_child(piece)
			piece.global_position = top_left + Vector2(region.get_center())
			_add_debris(piece, true, _FRAGMENT_GROW)


func _fling_ambience() -> void:
	var ambience: Node = _damage.get_parent() if _damage else null
	if not ambience:
		return
	for child: Node in ambience.get_children():
		if child == _damage or not child is CanvasItem:
			continue
		if child is HangingDice:
			_send_hanging_dice_across(child)
		else:
			(child as CanvasItem).hide()


## Carries the hanging dice into the middle of the screen over exactly the
## length of the breakup slow-mo, then splits them.
func _send_hanging_dice_across(dice: HangingDice) -> void:
	# The dice draw around their hook, but the node's origin is the screen's
	# corner. A pivot at the hook lets them tilt and grow about themselves
	# instead of swinging across the whole screen.
	var hook: Node2D = Node2D.new()
	hook.z_as_relative = false
	hook.z_index = _HANGING_DICE_Z
	add_child(hook)
	hook.global_position = dice.anchor
	dice.reparent(hook, true)

	# The slow-mo's span in game time, which is what a tween runs on, so the
	# dice reach the middle as the slow-mo lets go. Easing out, they rush off
	# the strut and then hang in the middle while time is slowest.
	var duration: float = breakup_slow_mo_scale * breakup_slow_mo_ms / 1000.0
	var tween: Tween = hook.create_tween().set_parallel()
	tween.tween_property(hook, "global_position", hanging_dice_crossing, duration) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(hook, "rotation", hanging_dice_crossing_rotation, duration) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(hook, "scale", Vector2.ONE * hanging_dice_crossing_scale, duration) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(_split_hanging_dice.bind(dice, hook))


## The chains snap and the two dice fly apart, on along the way they were
## already heading and away from each other, clear off the screen.
func _split_hanging_dice(dice: HangingDice, hook: Node2D) -> void:
	var heading: Vector2 = (hanging_dice_crossing - dice.anchor).normalized()
	_sparks(hook.global_position, Globals.yellow, 8, 60.0)
	var pieces: Array[Sprite2D] = dice.cut_loose(self)
	hook.queue_free()
	if pieces.is_empty():
		return

	var centre: Vector2 = Vector2.ZERO
	for piece: Sprite2D in pieces:
		centre += piece.global_position
	centre /= pieces.size()
	for piece: Sprite2D in pieces:
		var apart: Vector2 = piece.global_position - centre
		if apart.length() < 0.5:
			apart = heading.orthogonal()
		var direction: Vector2 = (heading + apart.normalized() * 1.2).normalized()
		_sparks(piece.global_position, Globals.yellow, 4, 40.0)
		_track_debris(piece, direction * hanging_dice_split_speed, true, false,
				Vector2(1.2, 1.5), _rng.randf_range(6.0, 10.0) * signf(apart.x + 0.01))
		piece.z_index = _HANGING_DICE_Z


## The player's panels and the dice in hand tumble away whole.
func _fling_player_panels() -> void:
	var player: Player = Globals.player
	if not player:
		return
	for child: Node in player.get_children():
		if not child is Node2D or not (child as Node2D).visible:
			continue
		_pin_draggables(child)
		_add_debris(child, false, _PANEL_GROW)


## Tiles and dice steer themselves home every frame through their Draggable,
## which would hold them in place while the panel under them flies off.
## Handing them to code lets them go with it.
func _pin_draggables(node: Node) -> void:
	for found: Node in node.find_children("*", "Area2D", true, false):
		var draggable: Draggable = found as Draggable
		if not draggable:
			continue
		draggable.dragging_allowed = false
		draggable.state = Draggable.DragState.MOVING_WITH_CODE


## Throws [param node] out from the blast.
func _add_debris(node: Node2D, owned: bool, grow: Vector2) -> void:
	var away: Vector2 = node.global_position - blast_origin
	if away.length() < 1.0:
		away = Vector2.UP
	var speed: Vector2 = Vector2(60.0, 170.0) if owned else Vector2(160.0, 240.0)
	var velocity: Vector2 = away.normalized().rotated(_rng.randf_range(-0.35, 0.35)) \
			* _rng.randf_range(speed.x, speed.y) + Vector2(0, -25)
	_track_debris(node, velocity, owned, owned, grow, _rng.randf_range(-5.0, 5.0))


## Flies [param node] at [param velocity] until its life runs out. A fading
## piece slows and fades; one that doesn't keeps its speed to clear the
## screen. Owned pieces are freed at the end, borrowed ones hidden.
func _track_debris(node: Node2D, velocity: Vector2, owned: bool, fade: bool,
		grow: Vector2, spin: float) -> void:
	node.z_as_relative = false
	node.z_index = _DEBRIS_Z
	_debris.append({
		"node": node,
		"velocity": velocity,
		"spin": spin,
		"grow": _rng.randf_range(grow.x, grow.y),
		"age": 0.0,
		"life": _rng.randf_range(1.2, 2.0),
		"rest_scale": node.scale,
		"owned": owned,
		"fade": fade,
	})


func _process(delta: float) -> void:
	for i: int in range(_debris.size() - 1, -1, -1):
		var d: Dictionary = _debris[i]
		var node: Node2D = d["node"]
		if not is_instance_valid(node):
			_debris.remove_at(i)
			continue
		d["age"] += delta
		var t: float = clampf(d["age"] / d["life"], 0.0, 1.0)
		var velocity: Vector2 = d["velocity"]
		node.global_position += velocity * delta
		node.rotation += d["spin"] * delta
		node.scale = d["rest_scale"] * lerpf(1.0, d["grow"], t)
		if d["fade"]:
			d["velocity"] = velocity * (1.0 - 0.6 * delta)
			node.modulate.a = 1.0 - smoothstep(0.55, 1.0, t)
		if t >= 1.0:
			_debris.remove_at(i)
			if d["owned"]:
				node.queue_free()
			else:
				node.hide()


func _flash() -> void:
	var flash: ColorRect = ColorRect.new()
	flash.color = Globals.white
	flash.size = Vector2(320, 180)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	flash.z_index = 1
	var tween: Tween = flash.create_tween()
	tween.tween_property(flash, "color:a", 0.0, 0.5).set_ease(Tween.EASE_OUT)
	tween.tween_callback(flash.queue_free)


## The same blast an enemy dies in, kept on the game's 320x180 pixel grid like
## the rest of the art: native size, whole-pixel placement, and only quarter
## turns and a mirror for variety. Any other scale or angle resamples the
## sprite, so its pixels come out smaller than, or skewed across, everything
## around it.
func _explosion(point: Vector2) -> void:
	var explosion: AnimatedSprite2D = _EXPLOSION_SCENE.instantiate()
	var quarter_turns: int = _rng.randi_range(0, 3)
	explosion.rotation = quarter_turns * PI / 2.0
	explosion.flip_h = _rng.randf() < 0.5
	add_child(explosion)
	var frame_size: Vector2 = explosion.sprite_frames \
			.get_frame_texture(explosion.animation, 0).get_size()
	if quarter_turns % 2 == 1:
		frame_size = Vector2(frame_size.y, frame_size.x)
	explosion.global_position = pixel_aligned_centre(point, frame_size)


## Where to put a centred sprite of [param size] near [param point] so its
## pixels land on whole world pixels. An odd-sized sprite's centre is the
## middle of a pixel, so it sits on a half; an even one on a whole.
static func pixel_aligned_centre(point: Vector2, size: Vector2) -> Vector2:
	return Vector2(_aligned_axis(point.x, int(size.x)), _aligned_axis(point.y, int(size.y)))


static func _aligned_axis(value: float, size: int) -> float:
	if size % 2 == 1:
		return floorf(value) + 0.5
	return roundf(value)


func _sparks(point: Vector2, color: Color, count: int, speed: float) -> void:
	var particles: CPUParticles2D = CPUParticles2D.new()
	particles.texture = _PIXEL
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = count
	particles.lifetime = 0.8
	particles.randomness = 0.5
	particles.spread = 180.0
	particles.gravity = Vector2(0.0, 120.0)
	particles.initial_velocity_min = speed * 0.4
	particles.initial_velocity_max = speed
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 2.0
	particles.color = color
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, Color.WHITE)
	ramp.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	particles.color_ramp = ramp
	particles.finished.connect(particles.queue_free)
	add_child(particles)
	particles.global_position = point
	particles.emitting = true


func _sites() -> Array[CockpitDamageSite]:
	return _damage.get_sites() if _damage else ([] as Array[CockpitDamageSite])


## The canopy cracks, in the order they open.
func _glass_sites() -> Array[CockpitDamageSite]:
	var glass: Array[CockpitDamageSite] = []
	for site: CockpitDamageSite in _sites():
		if site.kind == CockpitDamageSite.Kind.GLASS:
			glass.append(site)
	return glass


func _all_emit_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	for site: CockpitDamageSite in _sites():
		for point: Vector2 in site.emit_points:
			points.append(site.to_global(point))
	return points


func _walls() -> Sprite2D:
	return _damage.get_walls() if _damage else null


static func _opaque_pixels(image: Image, region: Rect2i) -> int:
	var count: int = 0
	for y: int in range(region.position.y, region.end.y):
		for x: int in range(region.position.x, region.end.x):
			if image.get_pixel(x, y).a > 0.0:
				count += 1
	return count
