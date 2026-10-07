class_name Juice
extends RefCounted
## Small, reusable game-feel flourishes: squash-and-stretch bumps, sparkle
## bursts, shockwave rings and floating labels.
##
## Every helper is fire-and-forget and purely cosmetic. Nothing here is awaited
## by the effect pipeline, so making the game juicier never makes a turn
## longer, and none of it draws from a gameplay RNG stream (CPUParticles2D
## rolls its own), so a seeded run replays identically with or without it.

const _PIXEL_TEXTURE: Texture2D = preload("res://Assets/Particles/hit_particle_pixel.png")

const _REST_SCALE_META: StringName = &"_juice_rest_scale"
const _BUMP_TWEEN_META: StringName = &"_juice_bump_tween"
const _WIGGLE_TWEEN_META: StringName = &"_juice_wiggle_tween"

## Drawn above whatever spawned it, but relative, so a ring on a tile still
## sits under a ship that flies over the grid.
const _FX_Z_INDEX: int = 20


## Squash-and-stretch: snaps `node` wide and flat by `strength`, overshoots
## the other way, then springs back. A bump landing mid-bump restarts from the
## resting scale instead of compounding, so a chain of procs never balloons
## the node.
##
## Bump a sprite rather than a node whose scale something else already tweens
## (a die's root, a tile in flight), or the two fight over it.
static func bump(node: Node2D, strength: float = 0.25, duration: float = 0.3) -> void:
	if not _usable(node):
		return

	var rest: Vector2 = node.scale
	var previous: Tween = node.get_meta(_BUMP_TWEEN_META) if node.has_meta(_BUMP_TWEEN_META) else null
	if previous != null and previous.is_valid():
		previous.kill()
		rest = node.get_meta(_REST_SCALE_META)
	node.set_meta(_REST_SCALE_META, rest)

	node.scale = rest * Vector2(1.0 + strength, 1.0 - strength)
	var tween: Tween = node.create_tween()
	tween.tween_property(node, "scale", rest * Vector2(1.0 - strength * 0.4, 1.0 + strength * 0.4), duration * 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", rest, duration * 0.7) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	node.set_meta(_BUMP_TWEEN_META, tween)


## A quick side-to-side twist, read as "no". Rotation rather than position,
## because Shakeable owns a sprite's position while a shake is running.
static func wiggle(node: Node2D, degrees: float = 10.0, duration: float = 0.3) -> void:
	if not _usable(node):
		return

	var previous: Tween = node.get_meta(_WIGGLE_TWEEN_META) if node.has_meta(_WIGGLE_TWEEN_META) else null
	if previous != null and previous.is_valid():
		previous.kill()

	var step: float = duration / 4.0
	var tween: Tween = node.create_tween()
	tween.tween_property(node, "rotation_degrees", -degrees, step)
	tween.tween_property(node, "rotation_degrees", degrees * 0.7, step)
	tween.tween_property(node, "rotation_degrees", -degrees * 0.35, step)
	tween.tween_property(node, "rotation_degrees", 0.0, step) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	node.set_meta(_WIGGLE_TWEEN_META, tween)


## An expanding ring that fades as it grows: a shockwave for an impact, or a
## "look here" for something that just fired.
static func ring(parent: Node, global_pos: Vector2, color: Color,
		end_radius: float = 16.0, duration: float = 0.35, start_radius: float = 2.0) -> void:
	if not _usable(parent):
		return
	var shockwave: JuiceRing = JuiceRing.new()
	shockwave.color = color
	shockwave.start_radius = start_radius
	shockwave.end_radius = end_radius
	shockwave.duration = duration
	shockwave.z_index = _FX_Z_INDEX
	parent.add_child(shockwave)
	shockwave.global_position = global_pos


## A burst of single-pixel sparks flying out from `global_pos` and fading.
## `rise` drifts them upward, for gains (shields, heals, a status taking hold)
## rather than impacts.
static func sparkle(parent: Node, global_pos: Vector2, color: Color,
		count: int = 8, speed: float = 40.0, rise: bool = false) -> void:
	if not _usable(parent) or count <= 0:
		return

	var particles: CPUParticles2D = CPUParticles2D.new()
	particles.texture = _PIXEL_TEXTURE
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = count
	particles.lifetime = 0.5
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.gravity = Vector2(0.0, -60.0) if rise else Vector2.ZERO
	particles.initial_velocity_min = speed * 0.5
	particles.initial_velocity_max = speed
	particles.damping_min = speed
	particles.damping_max = speed * 1.5
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 2.0
	particles.color = color
	particles.color_ramp = _fade_out_ramp()
	particles.z_index = _FX_Z_INDEX
	particles.finished.connect(particles.queue_free)
	parent.add_child(particles)
	particles.global_position = global_pos
	particles.emitting = true


## Floats a short label off `anchor` (a status name, "x2", "+3").
static func callout(anchor: Node2D, text: String, color: Color, big: bool = false) -> void:
	DamageNumber.spawn_text(anchor, text, color, big)


## Alpha 1 to 0 over a particle's life, shared by every sparkle.
static func _fade_out_ramp() -> Gradient:
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	ramp.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	return ramp


static func _usable(node: Node) -> bool:
	return is_instance_valid(node) and node.is_inside_tree() and not node.is_queued_for_deletion()
