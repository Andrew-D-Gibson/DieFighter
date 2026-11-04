class_name HazardThematicVFX
extends RefCounted
## Thematic visual effects for timed background hazards (Asteroid Impact,
## Ion Storm, Solar Flare, Fate Rift).
##
## Built with procedural pixel-art effects and approved palette colors:
##   - Asteroid Impact: an asteroid rock flying in from off-screen directly onto
##     the target tile with impact particles and shake right before locking it.
##   - Ion Storm: a crackling lightning/ion discharge striking across the player's
##     ship and grid in electric blue and cyan colors.
##   - Solar Flare: a radiant solar flare wash sweeping across the viewer and
##     grid in bright yellow and orange heat.
##   - Fate Rift: a reality-warp rift tear distortion with fate shards and sparks
##     where enemy dice 1s and 6s flip.

# Approved palette constants
# Ion / Electric
const _ION_CORE: Color = Color("#cef0f1")
const _ION_HOT: Color = Color("#8df1f4")
const _ION_GLOW: Color = Color("#43a6fc")
const _ION_SKY: Color = Color("#251c6b")

# Solar / Heat
const _SOLAR_WHITE: Color = Color("#cef0f1")
const _SOLAR_YELLOW: Color = Color("#eed35d")
const _SOLAR_ORANGE: Color = Color("#f29c5d")
const _SOLAR_DARK_ORANGE: Color = Color("#ee7f2f")
const _SOLAR_DEEP: Color = Color("#bd580f")

# Fate / Reality Distortion
const _FATE_CORE: Color = Color("#cef0f1")
const _FATE_HOT: Color = Color("#c552f1")
const _FATE_WARM: Color = Color("#80359d")
const _FATE_DARK: Color = Color("#463c91")

# Asteroid / Rock / Debris
const _ROCK_FIRE: Color = Color("#f29c5d")
const _ROCK_HOT: Color = Color("#eed35d")
const _ROCK_DEBRIS_1: Color = Color("#8e8b85")
const _ROCK_DEBRIS_2: Color = Color("#63605c")

const _ASTEROID_TEXTURE: Texture2D = preload(
	"res://Assets/Textures/Backgrounds/StaticObjects/asteroid_large.png"
)
const _DREAD_SFX: SoundEffectResource = preload(
	"res://Source/Resources/SoundEffectResources/SoundEffects/die_dread_thunk.tres"
)
const _FLARE_SFX: SoundEffectResource = preload(
	"res://Source/Resources/SoundEffectResources/SoundEffects/dice_cannon.tres"
)
const _ION_SFX: SoundEffectResource = preload(
	"res://Source/Resources/SoundEffectResources/SoundEffects/upgrade_trigger.tres"
)


## Plays the strike-moment thematic VFX for [param hazard].
static func play_hazard_strike(context: Node, hazard: BackgroundHazardResource) -> void:
	if not is_instance_valid(context) or not context.is_inside_tree():
		return
	if hazard == null:
		return

	var name_lower: String = hazard.hazard_name.to_lower()
	if name_lower.contains("ion"):
		await play_ion_storm_discharge(context)
	elif name_lower.contains("solar"):
		await play_solar_flare_sweep(context)
	elif name_lower.contains("fate"):
		await play_fate_rift_strike(context)
	elif not name_lower.contains("asteroid"):
		Juice.screen_flash(context, hazard.color, 0.45, 0.4)
		Events.camera_shake_large.emit(true)


# -----------------------------------------------------------------------------
# 1. Asteroid Impact: rock flying in from off-screen onto target tile
# -----------------------------------------------------------------------------

## Spawns an asteroid rock flying in from off-screen directly onto the target
## tile with fiery trail, impact particles and shake right before it locks.
static func play_asteroid_impact(tile: Tile) -> void:
	if not is_instance_valid(tile) or not tile.is_inside_tree():
		return

	var parent: Node = tile.get_parent()
	var target_pos: Vector2 = tile.global_position
	var speed_mult: float = maxf(0.1, Globals.animation_speed)

	# Start off-screen above the tile on a slight random diagonal.
	var x_jitter: float = RNGManager.randf_range(RNGManager.Bucket.COSMETIC, -24.0, 24.0)
	var start_pos: Vector2 = Vector2(target_pos.x + x_jitter, -28.0)

	var rock: Sprite2D = Sprite2D.new()
	rock.texture = _ASTEROID_TEXTURE
	rock.z_index = 25
	parent.add_child(rock)
	rock.global_position = start_pos
	rock.rotation = RNGManager.randf_range(RNGManager.Bucket.COSMETIC, 0.0, TAU)

	# Glowing fiery trail behind the rock
	var trail: Line2D = Line2D.new()
	trail.width = 2.0
	trail.antialiased = false
	var heading: Vector2 = (target_pos - start_pos).normalized()
	trail.points = PackedVector2Array([Vector2.ZERO, -heading * 24.0])
	var fade: Gradient = Gradient.new()
	fade.set_color(0, _ROCK_HOT)
	fade.set_color(1, Color(_ROCK_FIRE, 0.0))
	trail.gradient = fade
	trail.show_behind_parent = true
	rock.add_child(trail)

	var flight_duration: float = 0.35 / speed_mult
	Juice.trail(rock, _ROCK_FIRE, flight_duration)

	var tween: Tween = rock.create_tween().set_parallel(true)
	tween.tween_property(rock, "global_position", target_pos, flight_duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(rock, "rotation", rock.rotation + PI * 1.5, flight_duration)

	await tween.finished
	rock.queue_free()

	# Impact flourishes on tile landing
	Juice.sparkle(parent, target_pos, _ROCK_FIRE, 16, 75.0)
	Juice.sparkle(parent, target_pos, _ROCK_HOT, 8, 50.0)
	Juice.sparkle(parent, target_pos, _ROCK_DEBRIS_1, 10, 40.0)
	Juice.sparkle(parent, target_pos, _ROCK_DEBRIS_2, 6, 30.0)
	Juice.ring(parent, target_pos, _ROCK_FIRE, 26.0, 0.35, 4.0)

	tile.flash(_ROCK_FIRE, 0.85, 0.25)
	Juice.bump(tile.sprite_frames, 0.4, 0.3)

	Events.camera_shake_large.emit(true)
	Juice.screen_flash(tile, _ROCK_FIRE, 0.16, 0.15)
	Events.play_sound.emit(_DREAD_SFX)

	# Brief beat so the impact lands visually before the lock snaps into place
	await tile.get_tree().create_timer(0.06 / speed_mult).timeout


# -----------------------------------------------------------------------------
# 2. Ion Storm: crackling lightning discharge striking across ship/grid
# -----------------------------------------------------------------------------

## Crackling lightning/ion discharge striking across the player's ship/grid
## in cyan and electric blue palette colors.
static func play_ion_storm_discharge(context: Node) -> void:
	if not is_instance_valid(context) or not context.is_inside_tree():
		return

	var speed_mult: float = maxf(0.1, Globals.animation_speed)
	var root: Viewport = _world_viewport(context)

	var discharge: IonDischargeEffect = IonDischargeEffect.new()
	discharge.speed_mult = speed_mult
	root.add_child(discharge)

	Events.camera_shake_large.emit(true)
	Juice.screen_flash(context, _ION_HOT, 0.26, 0.22)
	Events.play_sound.emit(_ION_SFX)

	await discharge.finished


# -----------------------------------------------------------------------------
# 3. Solar Flare: radiant heat wash sweeping across viewer/grid
# -----------------------------------------------------------------------------

## A radiant solar flare wash/sweep across the viewer/grid in bright
## yellow/orange heat.
static func play_solar_flare_sweep(context: Node) -> void:
	if not is_instance_valid(context) or not context.is_inside_tree():
		return

	var speed_mult: float = maxf(0.1, Globals.animation_speed)
	var root: Viewport = _world_viewport(context)

	var sweep: SolarFlareSweepEffect = SolarFlareSweepEffect.new()
	sweep.speed_mult = speed_mult
	root.add_child(sweep)

	Events.camera_shake_large.emit(true)
	Juice.screen_flash(context, _SOLAR_YELLOW, 0.35, 0.4)
	Events.play_sound.emit(_FLARE_SFX)

	await sweep.finished


# -----------------------------------------------------------------------------
# 4. Fate Rift: purple/violet reality-warp rift tear distortion
# -----------------------------------------------------------------------------

## Reality-warp rift tear distortion at an enemy die that is flipping 1s and 6s.
static func play_fate_rift_die_flip(die: Dice) -> void:
	if not is_instance_valid(die) or not die.is_inside_tree():
		return

	var parent: Node = die.get_parent()
	var pos: Vector2 = die.global_position

	# Spawns a miniature reality-warp rift tear behind/over the die
	var mini_tear: FateRiftMiniTear = FateRiftMiniTear.new()
	parent.add_child(mini_tear)
	mini_tear.global_position = pos

	Juice.sparkle(parent, pos, _FATE_HOT, 10, 48.0)
	Juice.sparkle(parent, pos, _FATE_CORE, 6, 32.0)
	Juice.ring(parent, pos, _FATE_WARM, 16.0, 0.35, 3.0)
	Juice.screen_ripple(die, pos, 0.65)


## Broad reality-warp distortion pulse when the Fate Rift hazard strikes.
static func play_fate_rift_strike(context: Node) -> void:
	if not is_instance_valid(context) or not context.is_inside_tree():
		return

	var speed_mult: float = maxf(0.1, Globals.animation_speed)
	Juice.screen_ripple(context, Vector2(160, 90), 1.3)
	Juice.screen_flash(context, _FATE_HOT, 0.3, 0.35)
	Events.camera_shake_large.emit(true)

	var field: Viewport = _world_viewport(context)
	# Scatter fate shard motes across the field
	for i: int in range(16):
		var rx: float = RNGManager.randf_range(RNGManager.Bucket.COSMETIC, 40.0, 280.0)
		var ry: float = RNGManager.randf_range(RNGManager.Bucket.COSMETIC, 20.0, 140.0)
		Juice.sparkle(field, Vector2(rx, ry), _FATE_HOT, 2, 25.0)

	await context.get_tree().create_timer(0.3 / speed_mult).timeout


# =============================================================================
# Helper effect nodes
# =============================================================================

class IonDischargeEffect:
	extends Node2D

	signal finished()

	var speed_mult: float = 1.0
	var _bolts: Array[LightningBolt] = []
	var _age: float = 0.0
	var _duration: float = 0.38
	var _alpha: float = 1.0

	func _ready() -> void:
		z_index = 35
		_duration = 0.38 / speed_mult
		_generate_bolts()
		_strike_grid()

	func _generate_bolts() -> void:
		var grid: TileGrid = Globals.tile_grid
		var targets: Array[Vector2] = []
		if is_instance_valid(grid) and not grid.tile_locations.is_empty():
			var tiles: Array = grid.tile_locations.values()
			for i: int in range(mini(3, tiles.size())):
				var tile: Tile = tiles[RNGManager.randi_range(RNGManager.Bucket.COSMETIC, 0, tiles.size() - 1)] as Tile
				if is_instance_valid(tile):
					targets.append(tile.global_position)
		if targets.is_empty():
			targets.append(Vector2(110.0, 150.0))
			targets.append(Vector2(210.0, 150.0))

		# Strike from above cockpit down into grid cells
		for target_pos: Vector2 in targets:
			var start_x: float = target_pos.x + RNGManager.randf_range(RNGManager.Bucket.COSMETIC, -30.0, 30.0)
			var start_pos: Vector2 = Vector2(start_x, 10.0)
			var length: float = start_pos.distance_to(target_pos)
			var angle: float = start_pos.angle_to_point(target_pos)
			_bolts.append(LightningBolt.grow(start_pos, angle, length, 2))

		# Cross-bolt arcing across the grid columns
		if targets.size() >= 2:
			var from_p: Vector2 = targets[0]
			var to_p: Vector2 = targets[1]
			_bolts.append(LightningBolt.grow(from_p, from_p.angle_to_point(to_p), from_p.distance_to(to_p), 1))

	func _strike_grid() -> void:
		var grid: TileGrid = Globals.tile_grid
		if not is_instance_valid(grid):
			return
		for tile: Tile in grid.tile_locations.values():
			if not is_instance_valid(tile):
				continue
			tile.flash(_ION_HOT, 0.7, 0.25)
			Juice.bump(tile.sprite_frames, 0.2, 0.25)
			var p: Vector2 = tile.global_position
			Juice.sparkle(grid, p, _ION_HOT, 6, 40.0)
			Juice.sparkle(grid, p, _ION_CORE, 4, 25.0)

	func _process(delta: float) -> void:
		_age += delta
		if _age >= _duration:
			finished.emit()
			queue_free()
			return

		# Lightning crackle stutters: flash, dark blink, secondary strike, fade
		var t: float = _age / _duration
		if t < 0.2:
			_alpha = 1.0
		elif t < 0.35:
			_alpha = 0.2
		elif t < 0.65:
			_alpha = 0.95
		else:
			_alpha = lerpf(0.95, 0.0, (t - 0.65) / 0.35)

		queue_redraw()

	func _draw() -> void:
		if _alpha <= 0.02:
			return
		for bolt: LightningBolt in _bolts:
			bolt.draw_on(
				self,
				Color(_ION_CORE, _alpha),
				Color(_ION_GLOW, _alpha * 0.8)
			)


class SolarFlareSweepEffect:
	extends Node2D

	signal finished()

	var speed_mult: float = 1.0
	var _progress: float = 0.0
	var _duration: float = 0.55
	var _flashed_tiles: Dictionary = {}
	var _embers: Array[Dictionary] = []

	func _ready() -> void:
		z_index = 35
		_duration = 0.55 / speed_mult
		for i: int in range(24):
			_embers.append({
				"pos": Vector2(
					RNGManager.randf_range(RNGManager.Bucket.COSMETIC, -20.0, 340.0),
					RNGManager.randf_range(RNGManager.Bucket.COSMETIC, -20.0, 200.0)
				),
				"vel": Vector2(
					RNGManager.randf_range(RNGManager.Bucket.COSMETIC, 25.0, 65.0),
					RNGManager.randf_range(RNGManager.Bucket.COSMETIC, 15.0, 45.0)
				),
				"color": _SOLAR_YELLOW if i % 2 == 0 else _SOLAR_ORANGE,
				"age": 0.0,
				"life": RNGManager.randf_range(RNGManager.Bucket.COSMETIC, 0.3, 0.55),
			})

	func _process(delta: float) -> void:
		_progress += delta / _duration
		if _progress >= 1.0:
			finished.emit()
			queue_free()
			return

		# Diagonal wavefront (x + y) moves from top-left to bottom-right
		var front_diag: float = lerpf(-40.0, 520.0, _progress)

		# Check grid tiles passing the wave
		var grid: TileGrid = Globals.tile_grid
		if is_instance_valid(grid):
			for pos: Vector2i in grid.tile_locations:
				if _flashed_tiles.has(pos):
					continue
				var tile: Tile = grid.tile_locations[pos]
				if not is_instance_valid(tile):
					continue
				var tile_diag: float = tile.global_position.x + tile.global_position.y
				if front_diag >= tile_diag:
					_flashed_tiles[pos] = true
					tile.flash(_SOLAR_YELLOW, 0.8, 0.3)
					Juice.bump(tile.sprite_frames, 0.25, 0.3)
					Juice.sparkle(grid, tile.global_position, _SOLAR_ORANGE, 8, 45.0)

		# Move embers
		for ember: Dictionary in _embers:
			ember["age"] += delta
			ember["pos"] += ember["vel"] * delta

		queue_redraw()

	func _draw() -> void:
		var front_diag: float = lerpf(-40.0, 520.0, _progress)
		var fade: float = sin(_progress * PI)
		if fade <= 0.01:
			return

		# Draw radiant heat wash bands along the diagonal wavefront
		# Front radiant band (bright yellow/white)
		var front_alpha: float = 0.55 * fade
		_draw_diag_band(front_diag - 12.0, front_diag, Color(_SOLAR_YELLOW, front_alpha))
		_draw_diag_band(front_diag - 4.0, front_diag, Color(_SOLAR_WHITE, front_alpha * 0.75))

		# Trailing warm orange heat wash
		var wash_alpha: float = 0.38 * fade
		_draw_diag_band(front_diag - 45.0, front_diag - 12.0, Color(_SOLAR_ORANGE, wash_alpha))
		_draw_diag_band(front_diag - 80.0, front_diag - 45.0, Color(_SOLAR_DARK_ORANGE, wash_alpha * 0.5))

		# Floating solar embers
		for ember: Dictionary in _embers:
			var life_share: float = float(ember["age"]) / float(ember["life"])
			if life_share >= 1.0:
				continue
			var col: Color = Color(ember["color"], (1.0 - life_share) * fade)
			draw_rect(Rect2((ember["pos"] as Vector2).floor(), Vector2(2, 2)), col)

	func _draw_diag_band(d_min: float, d_max: float, color: Color) -> void:
		# Draws an angled band covering x + y in [d_min, d_max] on 320x180 viewport
		var step: float = 4.0
		var y: float = 0.0
		while y <= 180.0:
			var x_start: float = clampf(d_min - y, 0.0, 320.0)
			var x_end: float = clampf(d_max - y, 0.0, 320.0)
			if x_end > x_start:
				draw_rect(Rect2(x_start, y, x_end - x_start, step), color)
			y += step


class FateRiftMiniTear:
	extends Node2D

	var _age: float = 0.0
	var _duration: float = 0.45
	var _open_amount: float = 0.0

	func _ready() -> void:
		z_index = 30

	func _process(delta: float) -> void:
		_age += delta
		if _age >= _duration:
			queue_free()
			return

		var t: float = _age / _duration
		# Opens wide quickly, tremors with energy, knits back together
		if t < 0.25:
			_open_amount = lerpf(0.0, 1.0, t / 0.25)
		elif t < 0.7:
			var tremor: float = 0.08 * sin(_age * 30.0)
			_open_amount = 1.0 + tremor
		else:
			_open_amount = lerpf(1.0, 0.0, (t - 0.7) / 0.3)

		queue_redraw()

	func _draw() -> void:
		if _open_amount <= 0.02:
			return

		var half_h: float = 12.0
		var max_w: float = 5.0 * _open_amount
		var y_step: float = 1.0
		var y: float = -half_h

		while y <= half_h:
			var v: float = y / half_h
			var curve: float = maxf(0.0, 1.0 - v * v)
			var w: float = max_w * curve
			var s_offset: float = 2.0 * sin(y * 0.4)

			# Outer dark halo
			draw_rect(Rect2(s_offset - w - 1.0, y, (w * 2.0) + 2.0, y_step), Color(_FATE_DARK, 0.6))
			# Colored rift lips
			draw_rect(Rect2(s_offset - w, y, w * 2.0, y_step), Color(_FATE_HOT, 0.85))
			# Bright center seam
			if w > 1.5:
				draw_rect(Rect2(s_offset - 1.0, y, 2.0, y_step), _FATE_CORE)
			y += y_step


## Effects draw in the same 320x180 viewport as the grid, rather than in
## the 1920x1080 UI viewport that owns the scenario engine.
static func _world_viewport(context: Node) -> Viewport:
	if is_instance_valid(Globals.tile_grid) and Globals.tile_grid.is_inside_tree():
		return Globals.tile_grid.get_viewport()
	return context.get_viewport()
