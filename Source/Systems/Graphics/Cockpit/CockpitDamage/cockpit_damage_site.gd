class_name CockpitDamageSite
extends Sprite2D
## One piece of hull damage on the cockpit: a crack in the canopy glass, or a
## seam in the frame split open. CockpitDamage decides when it opens or
## closes; this owns how that looks.
##
## A crack holds for a moment after it opens, then fades to a faint ghost, so
## the canopy stays clear to see through. The torn seams and their smoke are
## what keep showing the hull is low.
##
## The texture is a full-screen overlay (cockpit pixels, origin top-left), so
## emit_points are plain screen coordinates. Particles go on the parent, not on
## the sprite: they have to outlive the break they came out of.

const _PIXEL: Texture2D = preload("res://Assets/Particles/hit_particle_pixel.png")
const _FLASH_SHADER: Shader = preload("res://Assets/Shaders/flash.gdshader")
const _SMOKE_SCENE: PackedScene = preload("res://Source/Systems/Graphics/Cockpit/CockpitDamage/cockpit_smoke.tscn")
const _CRACK_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/glass_crack.tres")

## How much bigger the lingering puffs get at nearly no hull than at a healthy
## one: the trail out of a torn seam thickens as things get dire. The healthy
## size is whatever cockpit_smoke.tscn sets, so tune that there.
const _LINGER_DIRE_GROWTH: float = 1.6
## How much bigger a big hit's plume puffs are than the scene's: from a hit
## that just made the cut to a huge hit with the hull nearly gone.
const _BILLOW_GROWTH_MIN: float = 1.9
const _BILLOW_GROWTH_MAX: float = 3.8

enum Kind { GLASS, FRAME }

@export var kind: Kind = Kind.GLASS
## Where particles come out: a crack's point of impact and a few spots along
## it, or the middle of each split in a seam. The first is the main one.
@export var emit_points: PackedVector2Array

var is_open: bool = false

## A torn seam keeps leaking a thin trail of smoke for as long as it's open.
var _linger_smoke: CPUParticles2D = null
var _linger_intensity: float = 0.0
## The scene's own puff size (min, max), kept so the dire growth scales it
## rather than replacing it.
var _linger_base_scale: Vector2 = Vector2.ONE
var _tween: Tween = null

@onready var _damage: CockpitDamage = get_parent() as CockpitDamage


func _ready() -> void:
	centered = false
	visible = false
	material = ShaderMaterial.new()
	material.shader = _FLASH_SHADER


## Shows the damage. Animated, it pops in on a flash with debris flying out of
## the break; otherwise it's simply there (a loaded save, a new run), a crack
## already faded to its ghost.
func open(animate: bool) -> void:
	if is_open:
		return
	is_open = true
	_kill_tween()
	visible = true
	self_modulate = Color.WHITE
	if kind == Kind.FRAME:
		_start_linger_smoke()
	if not animate:
		_set_flash(Color.WHITE, 0.0)
		if kind == Kind.GLASS:
			self_modulate.a = _ghost_alpha()
		return

	_set_flash(Color.WHITE, 1.0)
	_tween = create_tween()
	_tween.tween_method(_set_flash_amount, 1.0, 0.0, 0.3)
	if kind == Kind.GLASS:
		_spill_glass()
		_queue_fade()
		return
	for point: Vector2 in emit_points:
		_burst(point, Globals.orange, 10, 60.0, 140.0)
		_burst(point, Globals.yellow, 4, 40.0, 140.0)
		_burst(point, Color(0.027, 0.012, 0.149), 4, 30.0, 220.0)


## A crack that has faded to its ghost cracks again, full and bright, for the
## cockpit's last moments.
func flare_back() -> void:
	if kind != Kind.GLASS:
		return
	is_open = true
	_kill_tween()
	visible = true
	self_modulate = Color.WHITE
	_set_flash(Color.WHITE, 1.0)
	_tween = create_tween()
	_tween.tween_method(_set_flash_amount, 1.0, 0.0, 0.25)
	_spill_glass()
	Events.play_sound.emit(_CRACK_SFX)


## Fades a crack straight to its ghost, clearing the canopy for flare_back.
func dim() -> void:
	if kind != Kind.GLASS or not is_open:
		return
	_kill_tween()
	_set_flash(Color.WHITE, 0.0)
	_tween = create_tween()
	_tween.tween_property(self, "self_modulate:a", _ghost_alpha(), 0.25)


## Repairs the damage: the break glows green and fades as green sparks pop out
## of it, so healing reads as the exact reverse of the hit that caused it.
func close(animate: bool) -> void:
	if not is_open:
		return
	is_open = false
	_kill_tween()
	_stop_linger_smoke()
	if not animate:
		visible = false
		return

	for point: Vector2 in emit_points:
		Juice.sparkle(get_parent(), point, Globals.green, 10, 45.0, true)
	_set_flash(Globals.green, 0.0)
	_tween = create_tween()
	_tween.tween_method(_set_flash_amount, 0.0, 1.0, 0.12)
	_tween.tween_property(self, "self_modulate:a", 0.0, 0.4)
	_tween.tween_callback(hide)


## A big hit chokes the cabin: a plume rolls out of the break and rises.
## [param intensity] runs from 0 (a hit that just made the cut) to 1 (a huge
## hit with the hull nearly gone), and everything about the plume grows with it.
func billow(intensity: float) -> void:
	if not is_open or emit_points.is_empty():
		return
	var t: float = clampf(intensity, 0.0, 1.0)
	var smoke: CPUParticles2D = _SMOKE_SCENE.instantiate()
	smoke.one_shot = true
	#smoke.amount = roundi(lerpf(24.0, 70.0, t))
	smoke.lifetime = lerpf(2.6, 4.2, t)
	smoke.explosiveness = 0.6
	smoke.spread = lerpf(55.0, 90.0, t)
	smoke.emission_sphere_radius = lerpf(3.0, 6.0, t)
	smoke.initial_velocity_min = lerpf(8.0, 14.0, t)
	smoke.initial_velocity_max = lerpf(22.0, 40.0, t)
	smoke.gravity = Vector2(3.0, lerpf(-10.0, -18.0, t))
	var growth: float = lerpf(_BILLOW_GROWTH_MIN, _BILLOW_GROWTH_MAX, t)
	smoke.scale_amount_min *= growth
	smoke.scale_amount_max *= growth
	smoke.finished.connect(smoke.queue_free)
	get_parent().add_child(smoke)
	smoke.position = emit_points[0]
	smoke.emitting = true


## How dire things are, 0 to 1: the lingering trail thickens with it.
func set_linger_intensity(intensity: float) -> void:
	_linger_intensity = clampf(intensity, 0.0, 1.0)
	if _linger_smoke:
		_apply_linger_intensity(_linger_smoke)


## Stops the lingering smoke without cutting off what's already in the air.
func stop_smoke() -> void:
	_stop_linger_smoke()


func _start_linger_smoke() -> void:
	if _linger_smoke or emit_points.is_empty():
		return
	_linger_smoke = _SMOKE_SCENE.instantiate()
	_linger_base_scale = Vector2(_linger_smoke.scale_amount_min, _linger_smoke.scale_amount_max)
	_apply_linger_intensity(_linger_smoke)
	get_parent().add_child(_linger_smoke)
	_linger_smoke.position = emit_points[0]
	_linger_smoke.emitting = true


func _stop_linger_smoke() -> void:
	if not _linger_smoke:
		return
	# Let the last wisps drift off rather than vanish.
	var smoke: CPUParticles2D = _linger_smoke
	_linger_smoke = null
	smoke.emitting = false
	get_tree().create_timer(smoke.lifetime).timeout.connect(smoke.queue_free)


func _apply_linger_intensity(smoke: CPUParticles2D) -> void:
	var size: Vector2 = _linger_base_scale * lerpf(1.0, _LINGER_DIRE_GROWTH, _linger_intensity)
	smoke.scale_amount_min = size.x
	smoke.scale_amount_max = size.y


## Glass knocked in through the crack: shards tumbling down into the cockpit,
## and a quick glint of fine bits at the point of impact.
func _spill_glass() -> void:
	if emit_points.is_empty():
		return
	var shards: CockpitGlassShards = _damage.glass_shards if _damage else null
	for i: int in emit_points.size():
		var point: Vector2 = emit_points[i]
		_burst(point, Globals.white, 3, 35.0, 90.0)
		if shards:
			# Most of the glass comes out where it was struck.
			shards.spill(to_global(point), 5 if i == 0 else 2)


## Holds the crack at full strength for a beat, then lets it fade to a ghost.
func _queue_fade() -> void:
	var hold: float = _damage.crack_hold_time if _damage else 2.0
	var fade: float = _damage.crack_fade_time if _damage else 6.0
	_tween.tween_interval(maxf(0.0, hold - 0.3))
	_tween.tween_property(self, "self_modulate:a", _ghost_alpha(), fade) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _ghost_alpha() -> float:
	return _damage.crack_ghost_alpha if _damage else 0.1


func _burst(point: Vector2, color: Color, count: int, speed: float, fall: float) -> void:
	var particles: CPUParticles2D = CPUParticles2D.new()
	particles.texture = _PIXEL
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = count
	particles.lifetime = 0.6
	particles.randomness = 0.4
	particles.spread = 180.0
	particles.gravity = Vector2(0.0, fall)
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
	get_parent().add_child(particles)
	particles.position = point
	particles.emitting = true


func _set_flash(color: Color, amount: float) -> void:
	(material as ShaderMaterial).set_shader_parameter("color", color)
	_set_flash_amount(amount)


func _set_flash_amount(amount: float) -> void:
	(material as ShaderMaterial).set_shader_parameter("flash_amount", amount)


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
