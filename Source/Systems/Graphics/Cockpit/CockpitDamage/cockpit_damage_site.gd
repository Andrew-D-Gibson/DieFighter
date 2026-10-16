class_name CockpitDamageSite
extends Sprite2D
## One piece of hull damage on the cockpit: a crack in the canopy glass, or a
## seam in the frame split open. CockpitDamage decides when it opens or
## closes; this owns how that looks.
##
## The texture is a full-screen overlay (cockpit pixels, origin top-left), so
## emit_points are plain screen coordinates. Particles go on the parent, not on
## the sprite: they have to outlive the break they came out of.

const _PIXEL: Texture2D = preload("res://Assets/Particles/hit_particle_pixel.png")
const _FLASH_SHADER: Shader = preload("res://Assets/Shaders/flash.gdshader")
const _SMOKE_SCENE: PackedScene = preload("res://Source/Systems/Graphics/Cockpit/CockpitDamage/cockpit_smoke.tscn")

enum Kind { GLASS, FRAME }

@export var kind: Kind = Kind.GLASS
## Where particles come out: a crack's point of impact and a few spots along
## it, or the middle of each split in a seam. The first is the main one.
@export var emit_points: PackedVector2Array

var is_open: bool = false

## A torn seam keeps leaking a thin trail of smoke for as long as it's open.
var _linger_smoke: CPUParticles2D = null
var _tween: Tween = null


func _ready() -> void:
	centered = false
	visible = false
	material = ShaderMaterial.new()
	material.shader = _FLASH_SHADER


## Shows the damage. Animated, it pops in on a flash with debris flying out of
## the break; otherwise it's simply there (a loaded save, a new run).
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
		return

	_set_flash(Color.WHITE, 1.0)
	_tween = create_tween()
	_tween.tween_method(_set_flash_amount, 1.0, 0.0, 0.3)
	for point: Vector2 in emit_points:
		if kind == Kind.GLASS:
			_burst(point, Globals.white, 8, 50.0, 90.0)
		else:
			_burst(point, Globals.orange, 10, 60.0, 140.0)
			_burst(point, Globals.yellow, 4, 40.0, 140.0)
			_burst(point, Color(0.027, 0.012, 0.149), 4, 30.0, 220.0)


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


## A big hit chokes the cabin: a heavy plume rolls out of the break.
func billow() -> void:
	if not is_open or emit_points.is_empty():
		return
	var smoke: CPUParticles2D = _SMOKE_SCENE.instantiate()
	smoke.one_shot = true
	smoke.amount = 48
	smoke.lifetime = 3.0
	smoke.explosiveness = 0.6
	smoke.spread = 70.0
	smoke.emission_sphere_radius = 3.0
	smoke.initial_velocity_min = 10.0
	smoke.initial_velocity_max = 30.0
	smoke.scale_amount_min = 3.0
	smoke.scale_amount_max = 6.0
	smoke.finished.connect(smoke.queue_free)
	get_parent().add_child(smoke)
	smoke.position = emit_points[0]
	smoke.emitting = true


## Stops the lingering smoke without cutting off what's already in the air.
func stop_smoke() -> void:
	_stop_linger_smoke()


func _start_linger_smoke() -> void:
	if _linger_smoke or emit_points.is_empty():
		return
	_linger_smoke = _SMOKE_SCENE.instantiate()
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
