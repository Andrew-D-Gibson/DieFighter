class_name ArrivalShip
extends Node2D
## One ship in the sky with no Fate in it (RECKONING_ENDINGS.md §6): a saved
## ship in its formation slot, or the player's own, burning the Vanguard
## Drive's gold. Flies nose right, the way the convoy goes.
##
## The hull is a child turned a quarter from how combat draws it, so JumpFx
## (which stretches a ship along its local y) and the flash shaders work on it
## exactly as they do in a fight. This node only ever moves; the hull bobs.

const _ENEMY_SHADER: Shader = preload("res://Assets/Shaders/enemy_shader.gdshader")
const _DRIVE_SHADER: Shader = preload("res://Assets/Shaders/drive_recolor.gdshader")
const _PIXEL_TEXTURE: Texture2D = preload("res://Assets/Particles/hit_particle_pixel.png")
const _DIALOGUE_SCENE: PackedScene = preload("res://Source/Systems/Game/EnemyDialogueManager/enemy_dialogue_manager.tscn")
## The die the last ship carries, a six: it catches the glint a six does.
const _DIE_TEXTURE: Texture2D = preload("res://Assets/Textures/Dice/Regular/dice6.png")

## The fleet's own drive colour, which every saved ship burns: only the
## player's runs on the Vanguard Drive.
const _FLEET_EXHAUST: Color = JumpFx.BLUE
## Above the ships and their flares, so a line is never hidden by a hull.
const _BUBBLE_Z: int = 30

## How hard the drive burns: 1 cruising, under 1 dimmed, over 1 pushing.
var engine_power: float = 1.0:
	set(value):
		engine_power = value
		_apply_engine_power()

var art: ArrivalShipArt.Art
## What the hull is drawn with; JumpFx flashes it.
var hull: Node2D

var _exhaust: Array[CPUParticles2D] = []
var _bubble: EnemyDialogueManager
var _die: Sprite2D
var _bob_phase: float = 0.0
var _age: float = 0.0
var _is_player: bool = false


## A ship drawn from [param ship_art]. [param is_player] burns gold.
static func create(ship_art: ArrivalShipArt.Art, is_player: bool) -> ArrivalShip:
	var ship: ArrivalShip = ArrivalShip.new()
	ship.art = ship_art
	ship._is_player = is_player
	return ship


func _ready() -> void:
	_bob_phase = RNGManager.randf_range(RNGManager.Bucket.COSMETIC, 0.0, TAU)
	hull = _build_hull()
	add_child(hull)
	for point: Vector2 in art.engines:
		var flame: CPUParticles2D = _exhaust_particles(point)
		hull.add_child(flame)
		_exhaust.append(flame)
	_apply_engine_power()


func _process(delta: float) -> void:
	_age += delta
	# A slow drift up and down, a pixel at most: a ship holding station, not
	# a still picture.
	hull.position.y = roundf(sin(_age * 0.9 + _bob_phase) * 0.7)
	if _die:
		_die.position = _die_spot()


## Comes out of a jump at this spot, flying right: JumpFx's jump in, in
## [param color], drawn on [param jump_fx]'s layer.
func arrive(jump_fx: JumpFx, color: Color) -> void:
	show()
	jump_fx.jump_in(hull, color, Vector2.RIGHT)


## Says [param line] in a speech bubble, over whatever else is being said:
## the convoy's chatter overlaps.
func say(line: String) -> void:
	if _bubble == null:
		_bubble = _DIALOGUE_SCENE.instantiate() as EnemyDialogueManager
		_bubble.z_index = _BUBBLE_Z
		add_child(_bubble)
		_bubble.anchor = Vector2(ceilf(art.size.y * 0.5) + 1.0, -2.0)
		# Ahead of the ship, into the sky the convoy is flying toward; it
		# flips behind only if the edge of the frame leaves it no room.
		_bubble.point(false)
	_bubble.show_dialogue(line, ScenarioManager.Faction.CIVILIAN, false)


## A small die beside the hull: the one the player gave it to carry.
func carry_die() -> void:
	if _die:
		return
	_die = Sprite2D.new()
	# At the ships' own scale, so it reads as the die from the fight.
	_die.texture = ArrivalShipArt.shrink_texture(_DIE_TEXTURE, roundi(_DIE_TEXTURE.get_width() * ArrivalShipArt.SCALE))
	_die.centered = false
	_die.z_index = 1
	add_child(_die)
	_die.position = _die_spot()


## Where the carried die's middle is, globally: what catches the light.
func die_glint_point() -> Vector2:
	var size: Vector2 = _die.texture.get_size() if _die else Vector2.ZERO
	return global_position + _die_spot() + (size / 2.0).floor()


## Under the ship's tail, so the die rides with it without covering the hull.
func _die_spot() -> Vector2:
	var half: Vector2 = Vector2(art.size.y, art.size.x) * 0.5
	return Vector2(-floorf(half.x) - 2.0, ceilf(half.y) - 1.0) + Vector2(0, hull.position.y if hull else 0.0)


func _build_hull() -> Node2D:
	var material: ShaderMaterial = ShaderMaterial.new()
	if _is_player:
		material.shader = _DRIVE_SHADER
	else:
		material.shader = _ENEMY_SHADER
		# The enemy shader draws nothing until told how opaque to be, which
		# in a fight is the graphics manager's job.
		material.set_shader_parameter("alpha", 1.0)
	material.set_shader_parameter("flash_color", Color.WHITE)
	material.set_shader_parameter("flash_amount", 0.0)

	var node: Node2D
	if art.frames:
		var animated: AnimatedSprite2D = AnimatedSprite2D.new()
		animated.sprite_frames = art.frames
		animated.centered = false
		animated.offset = -(Vector2(art.size) / 2.0).floor()
		animated.play(&"default")
		node = animated
	else:
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = art.texture
		sprite.centered = false
		# A whole-pixel offset, so the quarter turn lands every pixel on the
		# grid even for a sprite of odd size.
		sprite.offset = -(Vector2(art.size) / 2.0).floor()
		node = sprite
	node.material = material
	# A quarter turn so the nose leads to the right.
	node.rotation = PI / 2.0 if art.nose_up else -PI / 2.0
	return node


## A short flame from one engine, trailing behind as the ship flies: the
## player's in the drive's gold, every other ship's in the fleet's cyan.
func _exhaust_particles(point: Vector2) -> CPUParticles2D:
	var flame: CPUParticles2D = CPUParticles2D.new()
	flame.texture = _PIXEL_TEXTURE
	flame.amount = 8
	flame.lifetime = 0.3
	flame.local_coords = false
	# Out of the tail: local down on a nose-up sheet, local up on a nose-down one.
	flame.direction = Vector2.DOWN if art.nose_up else Vector2.UP
	flame.spread = 8.0
	flame.gravity = Vector2.ZERO
	flame.color = EngineCharger.DRIVE_COLOR if _is_player else _FLEET_EXHAUST
	var ramp: Gradient = Gradient.new()
	ramp.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	flame.color_ramp = ramp
	flame.position = point
	flame.show_behind_parent = true
	return flame


func _apply_engine_power() -> void:
	for flame: CPUParticles2D in _exhaust:
		var power: float = maxf(engine_power, 0.0)
		flame.emitting = power > 0.05
		flame.lifetime = lerpf(0.08, 0.3, minf(power, 1.0)) * (1.0 + maxf(power - 1.0, 0.0) * 0.8)
		flame.initial_velocity_min = 22.0 * power
		flame.initial_velocity_max = 34.0 * power
		flame.modulate.a = clampf(power, 0.25, 1.0)
