class_name TileUpgradeLook
extends RefCounted
## How an upgraded tile looks: a shimmer round its edge (tile.gdshader) and a
## few sparks in its family's colour, so it reads as upgraded at a glance,
## and the burst it gives off at the moment it upgrades. Only the look: Tile
## decides when a tile merges and what it becomes.

const _SPARK_TEXTURE: Texture2D = preload("res://Assets/Particles/hit_particle_pixel.png")
const _UPGRADE_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/upgrade_trigger.tres")
## The sparks' node under the tile's sprite.
const SPARKS_NAME: StringName = &"UpgradeSparks"


## Dresses [param sprite], which draws [param resource], as upgraded or not.
## Safe to call again whenever the resource changes.
static func apply(sprite: AnimatedSprite2D, resource: TileResource) -> void:
	var upgraded: bool = resource.is_upgrade
	var mat: ShaderMaterial = sprite.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("upgraded", upgraded)
	var sparks: CPUParticles2D = sprite.get_node_or_null(NodePath(SPARKS_NAME))
	if upgraded and sparks == null:
		# Lightened, or the family's deeper colours vanish against the art.
		sprite.add_child(_make_sparks(ColorSymbolBadge.color_of_tile(resource).lerp(Globals.white, 0.5)))
	elif not upgraded and sparks:
		sparks.queue_free()


## The moment [param tile] becomes its upgrade: a bump, a white flash, a ring
## and sparks in its family's colour, and a callout.
static func burst(tile: Tile) -> void:
	var color: Color = ColorSymbolBadge.color_of_tile(tile.tile_resource)
	Juice.bump(tile.sprite_frames, 0.35, 0.35)
	tile.flash(Globals.white, 1.0, 0.4)
	Juice.sparkle(tile, tile.global_position, color, 16, 50.0, true)
	Juice.ring(tile, tile.global_position, Globals.white, 20.0, 0.35, 6.0)
	Juice.callout(tile, TranslationServer.translate(&"CALLOUT_UPGRADED"), color, true)
	Events.play_sound.emit(_UPGRADE_SFX)


static func _make_sparks(color: Color) -> CPUParticles2D:
	var sparks: CPUParticles2D = CPUParticles2D.new()
	sparks.name = SPARKS_NAME
	sparks.texture = _SPARK_TEXTURE
	sparks.amount = 5
	sparks.lifetime = 1.6
	sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	sparks.emission_rect_extents = Vector2(10, 11)
	sparks.direction = Vector2.UP
	sparks.spread = 20.0
	sparks.gravity = Vector2(0, -6)
	sparks.initial_velocity_min = 3.0
	sparks.initial_velocity_max = 7.0
	sparks.color = color
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	ramp.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	sparks.color_ramp = ramp
	sparks.z_index = 1
	return sparks
