class_name JumpFx
extends RefCounted
## A ship's jump drive, seen from outside: the charge (motes drawn in while
## the hull flickers brighter and brighter), the jump out (a white flare, a
## stretch along the line of flight, a streak to the edge of the screen, a
## ring and a burst of sparks), and the jump in that reverses it.
##
## The opening cutscene first showed it; ships that leave a fight under their
## own power (Enemy.jump_away()) use the same one, so a pirate fleeing mid-run
## looks like the one the player watched in the opening.
##
## Cosmetic only, like Juice: nothing here touches the board, and nothing
## draws from a gameplay RNG stream. Positions are global, in art pixels.
## Every tween is bound to the node it moves, so a ship freed mid-jump takes
## its own tweens with it.

## How the jump stretches a ship along its line of flight as it goes to light
## speed. Ships are drawn nose-up or nose-down, so that's their local y.
const STRETCH: Vector2 = Vector2(0.5, 3.0)
## How long the stretch takes. The ship is gone once it has.
const STRETCH_SECONDS: float = 0.1
## How long the stretched ship is held before the stretch is let go, for
## whoever hides it to do so first.
const STRETCH_HOLD_SECONDS: float = 0.15

## The Rearguard-blue drive the player's fleet jumps with.
const BLUE: Color = Color("#8df1f4")
## The Undertow's (pirates') drive. Ships fall back to it when their faction
## gives no colour of its own.
const RED: Color = Color("#d03656")

const _PIXEL_TEXTURE: Texture2D = preload("res://Assets/Particles/hit_particle_pixel.png")
## How far past the edge of the screen a streak runs, so a camera shake never
## shows its end.
const _EDGE_MARGIN: float = 8.0
## Matches Juice's: above whatever spawned it, below damage numbers.
const _FX_Z_INDEX: int = 20

## Where the effects draw (the streak, the ring, the sparks). Not the ship:
## a departing ship is freed while its streak is still pinching shut.
var _layer: Node
## Whether [member _layer] already draws on the art grid (the cutscene's
## 320x180 PixelWorld). If not, the streak and ring go through JuicePixelated,
## or on the 6x canvas they'd pinch shut in smooth sub-pixel steps instead of
## a game pixel at a time.
var _on_art_grid: bool


func _init(layer: Node, on_art_grid: bool = false) -> void:
	_layer = layer
	_on_art_grid = on_art_grid


## Spools the drive for [param seconds]: motes of the jump's [param color] are
## drawn in to [param ship] while its hull flickers brighter and brighter. The
## hull flicker drives the ship's flash shader, so [param ship] needs the
## flash material every ship sprite carries.
func charge(ship: Node2D, seconds: float, color: Color) -> void:
	var motes: CPUParticles2D = _charge_particles(color)
	ship.add_child(motes)
	motes.emitting = true
	# The motes' own tween, so a ship freed mid-charge takes the shutdown
	# with it rather than leaving a timer to reach for freed motes.
	motes.finished.connect(motes.queue_free)
	motes.create_tween().tween_callback(motes.set.bind(&"emitting", false)).set_delay(seconds)

	var material: ShaderMaterial = ship.material as ShaderMaterial
	if not material:
		return
	material.set_shader_parameter("flash_color", Globals.white)
	var tween: Tween = ship.create_tween()
	var pulses: int = 5
	for i: int in range(pulses):
		var peak: float = Juice.soften_flash(lerpf(0.15, 0.7, float(i) / (pulses - 1)))
		var beat: float = seconds / pulses
		tween.tween_property(material, "shader_parameter/flash_amount", peak, beat * 0.3)
		tween.tween_property(material, "shader_parameter/flash_amount", 0.0, beat * 0.7)


## The ship snaps to light speed heading [param direction]: it flares white,
## stretches along its line of flight and leaves a streak to the edge of the
## screen. The stretch is let go again after [constant STRETCH_SECONDS] +
## [constant STRETCH_HOLD_SECONDS]; hide the ship before then.
func jump_out(ship: Node2D, color: Color, direction: Vector2) -> void:
	flare(ship, Globals.white, 0.15)

	var rest: Vector2 = ship.scale
	var tween: Tween = ship.create_tween()
	tween.tween_property(ship, "scale", rest * STRETCH, STRETCH_SECONDS) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.tween_property(ship, "scale", rest, 0.0).set_delay(STRETCH_HOLD_SECONDS)

	var spot: Vector2 = ship.global_position
	streak(spot, _screen_exit(spot, direction), color)
	ring(spot, color, 3.0, 22.0, 0.35)
	Juice.sparkle(_layer, spot, color, 14, 70.0)


## The reverse of a jump: a streak from the edge of the screen behind it, and
## the ship, flying [param direction], decelerates out of it, overshooting
## into a squash before it settles.
func jump_in(ship: Node2D, color: Color, direction: Vector2) -> void:
	var rest: Vector2 = ship.scale
	ship.scale = rest * STRETCH
	flare(ship, Globals.white, 0.35)

	var tween: Tween = ship.create_tween()
	tween.tween_property(ship, "scale", rest * Vector2(1.2, 0.8), 0.12) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(ship, "scale", rest, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var spot: Vector2 = ship.global_position
	streak(_screen_exit(spot, -direction), spot, color)
	ring(spot, color, 3.0, 18.0, 0.3)
	Juice.sparkle(_layer, spot, color, 10, 50.0)


## A line of light from [param from] to [param to] that flashes from white to
## [param color] as it pinches shut: the wake a jump leaves.
func streak(from: Vector2, to: Vector2, color: Color) -> void:
	# The line turns about its own middle, so the holder sits there.
	var holder: Node2D = Node2D.new()
	var line: ColorRect = ColorRect.new()
	line.color = Globals.white
	line.size = Vector2(from.distance_to(to), 3.0)
	line.position = -line.size / 2.0
	line.pivot_offset = line.size / 2.0
	line.rotation = (to - from).angle()
	holder.add_child(line)
	_place(holder, (from + to) / 2.0)

	var tween: Tween = line.create_tween().set_parallel(true)
	tween.tween_property(line, "color", color, 0.12)
	tween.tween_property(line, "scale:y", 0.0, 0.35) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(holder.queue_free)


## A ring growing from [param from_radius] to [param to_radius] round
## [param spot] as it fades.
func ring(spot: Vector2, color: Color, from_radius: float, to_radius: float, seconds: float) -> void:
	if not _on_art_grid:
		Juice.ring(_layer, spot, color, to_radius, seconds, from_radius)
		return
	var shockwave: JuiceRing = JuiceRing.new()
	shockwave.color = color
	shockwave.start_radius = from_radius
	shockwave.end_radius = to_radius
	shockwave.duration = seconds
	_layer.add_child(shockwave)
	shockwave.global_position = spot


## Flashes [param ship]'s hull [param color], fading out over [param seconds].
## Drives the ship's flash shader directly; a ship that runs its own flashes
## (EnemyGraphicsManager) should cancel them first.
static func flare(ship: Node2D, color: Color, seconds: float) -> void:
	var material: ShaderMaterial = ship.material as ShaderMaterial
	if not material:
		return
	material.set_shader_parameter("flash_color", color)
	var tween: Tween = ship.create_tween()
	tween.tween_property(material, "shader_parameter/flash_amount", 0.0, seconds).from(Juice.soften_flash(1.0)) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _place(effect: Node2D, at: Vector2) -> void:
	if _on_art_grid:
		_layer.add_child(effect)
		effect.global_position = at
	else:
		JuicePixelated.spawn(_layer, effect, _FX_Z_INDEX).global_position = at


## Where a line from [param from] heading [param direction] leaves the
## screen, plus a margin.
static func _screen_exit(from: Vector2, direction: Vector2) -> Vector2:
	var bounds: Rect2 = Rect2(Vector2.ZERO, Globals.SCREEN_SIZE).grow(_EDGE_MARGIN)
	var heading: Vector2 = direction.normalized()
	var reach: float = INF
	if heading.x > 0.0:
		reach = minf(reach, (bounds.end.x - from.x) / heading.x)
	elif heading.x < 0.0:
		reach = minf(reach, (bounds.position.x - from.x) / heading.x)
	if heading.y > 0.0:
		reach = minf(reach, (bounds.end.y - from.y) / heading.y)
	elif heading.y < 0.0:
		reach = minf(reach, (bounds.position.y - from.y) / heading.y)
	if is_inf(reach):
		return from
	return from + heading * reach


static func _charge_particles(color: Color) -> CPUParticles2D:
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
	var fade_in: Gradient = Gradient.new()
	fade_in.colors = PackedColorArray([Color(1, 1, 1, 0), Color.WHITE])
	motes.color_ramp = fade_in
	return motes
