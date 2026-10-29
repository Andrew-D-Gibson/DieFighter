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

## Reduce Flashing: the brightest a full-screen wash may get, a faint tint...
const _REDUCED_WASH_ALPHA: float = 0.08
## ...the quickest it may fade, so it never reads as a blink...
const _REDUCED_WASH_MIN_SECONDS: float = 0.35
## ...and how long after one before another may play, so a storm's bolts
## can't strobe the screen.
const _REDUCED_WASH_GAP_MSEC: int = 600
## The share of its strength a sprite or screen-edge flash keeps.
const _REDUCED_FLASH_SHARE: float = 0.4

## When the last softened wash started, in real ms. See screen_flash().
static var _last_reduced_wash_msec: int = -_REDUCED_WASH_GAP_MSEC


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


## Stops a bump partway and puts [param node] back at its resting scale, for
## code that is about to set the scale itself.
static func cancel_bump(node: Node2D) -> void:
	if not is_instance_valid(node) or not node.has_meta(_BUMP_TWEEN_META):
		return
	var tween: Tween = node.get_meta(_BUMP_TWEEN_META)
	if tween != null and tween.is_valid():
		tween.kill()
		node.scale = node.get_meta(_REST_SCALE_META)
	node.remove_meta(_BUMP_TWEEN_META)


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
## "look here" for something that just fired. [param draw_z_index] is relative
## to [param parent]; pass 0 to keep the ring on the parent's own layer.
static func ring(parent: Node, global_pos: Vector2, color: Color,
		end_radius: float = 16.0, duration: float = 0.35, start_radius: float = 2.0,
		draw_z_index: int = _FX_Z_INDEX) -> void:
	if not _usable(parent):
		return
	var shockwave: JuiceRing = JuiceRing.new()
	shockwave.color = color
	shockwave.start_radius = start_radius
	shockwave.end_radius = end_radius
	shockwave.duration = duration
	JuicePixelated.spawn(parent, shockwave, draw_z_index).global_position = global_pos


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


## The same label at an arbitrary point, for anchors that aren't where their
## node is (the player's is their health bar).
static func callout_at(parent: Node, global_pos: Vector2, text: String, color: Color, big: bool = false) -> void:
	if not _usable(parent):
		return
	DamageNumber.spawn_text_at(parent, global_pos, text, color, big)


## A jagged bolt from `from` to `to` that flickers for `msec` and is gone.
static func zap(parent: Node, from: Vector2, to: Vector2, color: Color, msec: int = 140) -> void:
	if not _usable(parent):
		return
	var bolt: JuiceBolt = JuiceBolt.new()
	bolt.from = from
	bolt.to = to
	bolt.color = color
	bolt.duration = msec / 1000.0
	bolt.z_index = _FX_Z_INDEX
	parent.add_child(bolt)
	bolt.global_position = Vector2.ZERO
	sparkle(parent, to, color, 6, 35.0)


## `count` motes that arc from `from` to `to`, staggered so they read as a
## flow rather than a volley. Returns the seconds until the last one lands.
static func stream(parent: Node, from: Vector2, to: Vector2, color: Color, count: int = 10) -> float:
	if not _usable(parent):
		return 0.0
	var flow: JuiceStream = JuiceStream.new()
	flow.from = from
	flow.to = to
	flow.color = color
	flow.count = count
	flow.z_index = _FX_Z_INDEX
	parent.add_child(flow)
	flow.global_position = Vector2.ZERO
	return flow.total_seconds()


## A laser or missile (see JuiceProjectile.Style) from `from` to `to`, on the
## game's pixel grid. With a `target`, the shot follows that node's anchor in
## flight instead of `to`. `seconds` is how long a laser holds or a missile
## flies; zero takes the style's default. Returns the seconds until impact.
static func projectile(parent: Node, from: Vector2, to: Vector2, color: Color,
		style: JuiceProjectile.Style, seconds: float = 0.0, target: Node2D = null) -> float:
	if not _usable(parent):
		return 0.0
	var shot: JuiceProjectile = JuiceProjectile.new()
	shot.style = style
	shot.from = from
	shot.to = to
	shot.target = target
	shot.color = color
	shot.duration = seconds
	JuicePixelated.spawn(parent, shot, _FX_Z_INDEX)
	return shot.impact_seconds()


## A flash that spreads across the tile grid one ring of cells at a time,
## starting from `origin` (or the middle of the grid when it's null). Each
## tile bumps as the wave reaches it.
static func grid_ripple(origin: Tile, color: Color, step_msec: int = 60) -> void:
	var grid: TileGrid = Globals.tile_grid
	if not _usable(grid):
		return
	var centre: Vector2i = Vector2i(floori(grid.grid_width / 2.0), floori(grid.grid_height / 2.0))
	if is_instance_valid(origin) and grid.is_grid_pos_valid(grid.find_tile_pos(origin)):
		centre = grid.find_tile_pos(origin)

	for pos: Vector2i in grid.tile_locations:
		var tile: Tile = grid.tile_locations[pos]
		var distance: int = absi(pos.x - centre.x) + absi(pos.y - centre.y)
		var timer: SceneTreeTimer = grid.get_tree().create_timer(distance * step_msec / 1000.0)
		timer.timeout.connect(func() -> void:
			if _usable(tile):
				tile.flash(color, 0.6, 0.3)
				bump(tile.sprite_frames, 0.18, 0.3)
		)


## A screen-space shockwave, centred on a world position, that bends
## everything on screen — UI included — as it passes. Counts as camera
## motion, so it scales with the screenshake setting.
static func screen_ripple(context_node: Node, world_pos: Vector2, strength: float = 1.0) -> void:
	var scaled: float = strength * Globals.screenshake_intensity
	if scaled <= 0.0 or not _usable(context_node):
		return
	JuiceScreenRipple.spawn(context_node, world_pos, scaled)


## Dims the world and rushes speed lines in on [param target] for
## [param hold_seconds] of effect time, then cuts them away. Meant to run inside
## a hitstop. Drawn at [param z_index] relative to [param target], so pass one
## just under whatever should stay lit. Skipped under Reduce Flashing: its
## speed lines flicker across most of the screen many times a second.
static func kill_focus(target: Node2D, z_index: int, hold_seconds: float, accent: Color) -> void:
	if Globals.reduce_flashing or hold_seconds <= 0.0 or not _usable(target):
		return
	var focus: JuiceKillFocus = JuiceKillFocus.new()
	focus.hold_seconds = hold_seconds
	focus.accent = accent
	JuicePixelated.spawn(target, focus, z_index)


## A full-screen wash of [param color] that fades over [param seconds] of real
## time: one bright frame to mark the instant something gives way. Kept faint,
## since the whole screen flashing at full strength is harsh. Under Reduce
## Flashing it's a faint tint that fades slowly, and one that lands too soon
## after the last is dropped.
static func screen_flash(context_node: Node, color: Color, alpha: float = 0.3, seconds: float = 0.12) -> void:
	if not _usable(context_node):
		return
	if Globals.reduce_flashing:
		var now: int = Time.get_ticks_msec()
		if now - _last_reduced_wash_msec < _REDUCED_WASH_GAP_MSEC:
			return
		_last_reduced_wash_msec = now
		alpha = screen_wash_alpha(alpha)
		seconds = maxf(seconds, _REDUCED_WASH_MIN_SECONDS)
	var layer: CanvasLayer = CanvasLayer.new()
	# Over the game and UI, alongside the screen ripple.
	layer.layer = 90
	var rect: ColorRect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = Color(color, alpha)
	layer.add_child(rect)
	context_node.get_tree().root.add_child(layer)

	var tween: Tween = TimeDirector.effect_tween(layer)
	tween.tween_property(rect, "color:a", 0.0, seconds) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.finished.connect(layer.queue_free)


## Sheds sparks behind [param node] as it moves, for [param seconds], then
## stops and cleans itself up once the last spark fades.
static func trail(node: Node2D, color: Color, seconds: float) -> void:
	if not _usable(node):
		return
	var particles: CPUParticles2D = CPUParticles2D.new()
	particles.texture = _PIXEL_TEXTURE
	# World space, so the sparks hang where they were shed instead of
	# following the node.
	particles.local_coords = false
	particles.amount = 40
	particles.lifetime = 0.4
	particles.spread = 180.0
	particles.initial_velocity_min = 4.0
	particles.initial_velocity_max = 14.0
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 3.0
	particles.color = color
	particles.color_ramp = _fade_out_ramp()
	particles.z_index = _FX_Z_INDEX
	node.add_child(particles)
	particles.emitting = true

	node.get_tree().create_timer(seconds).timeout.connect(func() -> void:
		if is_instance_valid(particles):
			particles.emitting = false
			particles.finished.connect(particles.queue_free)
	)


## The die spins, pops and throws a ring: its value was just changed or
## spent in a way worth noticing.
static func die_flare(die: Dice, color: Color) -> void:
	if not _usable(die):
		return
	die.play_pop(0.5)
	var sprite: Node2D = die.get_node("Sprite2D") as Node2D
	var spin: Tween = sprite.create_tween()
	spin.tween_property(sprite, "rotation", TAU, 0.3).from(0.0) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	ring(die, die.global_position, color, 14.0, 0.35, 4.0)
	sparkle(die, die.global_position, color, 8, 35.0)


## Where the player's engine charge is on screen, for effects that move it.
## Falls back to the player's usual anchor if the charger isn't around.
static func engine_anchor(fallback: Node2D) -> Vector2:
	var charger: Node2D = fallback.get_tree().get_first_node_in_group(&"engine_charger") as Node2D
	return anchor_of(charger) if charger else anchor_of(fallback)


## Where an effect on `node` should be drawn. Usually the node itself; the
## player has no sprite, so theirs is their health bar.
static func anchor_of(node: Node2D) -> Vector2:
	if node.has_method("get_juice_anchor"):
		return node.get_juice_anchor()
	return node.global_position


## Where a shot at `node`'s shields lands: the player's shield counter, or
## the usual anchor for anything without one of its own.
static func shield_anchor(node: Node2D) -> Vector2:
	if node.has_method("get_shield_anchor"):
		return node.get_shield_anchor()
	return anchor_of(node)


## The part of `node` worth squashing: a tile's sprite, a ship's hull, a
## die's face, the player's health bar. Never the root, whose scale and
## position belong to movement tweens.
static func body_of(node: Node2D) -> Node2D:
	if node is Tile:
		return (node as Tile).sprite_frames
	if node is Enemy:
		return (node as Enemy).graphics_manager.ship_graphics
	if node is Dice:
		return node.get_node("Sprite2D") as Node2D
	if node.has_method("get_juice_body"):
		return node.get_juice_body()
	return node


## How strong a sprite or screen-edge flash of [param strength] should play:
## as authored, or toned down under Reduce Flashing. For flashes small or
## soft enough to keep, just not at full brightness.
static func soften_flash(strength: float) -> float:
	return strength * _REDUCED_FLASH_SHARE if Globals.reduce_flashing else strength


## How opaque a full-screen wash of [param alpha] should be: as authored, or
## no more than a faint tint under Reduce Flashing. For washes drawn outside
## screen_flash().
static func screen_wash_alpha(alpha: float) -> float:
	return minf(alpha, _REDUCED_WASH_ALPHA) if Globals.reduce_flashing else alpha


## Alpha 1 to 0 over a particle's life, shared by every sparkle.
static func _fade_out_ramp() -> Gradient:
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	ramp.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	return ramp


static func _usable(node: Node) -> bool:
	return is_instance_valid(node) and node.is_inside_tree() and not node.is_queued_for_deletion()
