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
## The shimmer's colour on an ordinary upgrade (tile.gdshader's default).
const SHIMMER_COLOR: Color = Color("#cef0f1")
## Meta on the sprite holding a colour the tile is dressed in whatever its
## resource says (see set_override()).
const _OVERRIDE_META: StringName = &"upgrade_look_override"


## Dresses [param sprite], which draws [param resource], as upgraded or not.
## Safe to call again whenever the resource changes.
static func apply(sprite: AnimatedSprite2D, resource: TileResource) -> void:
	var override: Color = sprite.get_meta(_OVERRIDE_META, Color.TRANSPARENT)
	var overridden: bool = override.a > 0.0
	var upgraded: bool = resource.is_upgrade or overridden
	var mat: ShaderMaterial = sprite.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("upgraded", upgraded)
		mat.set_shader_parameter("upgrade_color", override if overridden else SHIMMER_COLOR)
	var sparks: CPUParticles2D = sprite.get_node_or_null(NodePath(SPARKS_NAME))
	if not upgraded and sparks == null:
		return
	# Lightened, or the family's deeper colours vanish against the art.
	var spark_color: Color = override if overridden \
		else ColorSymbolBadge.color_of_tile(resource).lerp(Globals.white, 0.5)
	if sparks and (not upgraded or sparks.color != spark_color):
		# Freed now, not at frame end, so the new sparks can take the name.
		sprite.remove_child(sparks)
		sparks.queue_free()
		sparks = null
	if upgraded and sparks == null:
		sprite.add_child(_make_sparks(spark_color))


## Dresses [param tile] as upgraded, in [param color], whatever its resource
## says, until a transparent colour takes it off again. For a tile that has
## been made more than it is: the engine charger once the Horizon Drive is in
## it. It holds through resource changes.
static func set_override(tile: Tile, color: Color) -> void:
	if color.a > 0.0:
		tile.sprite_frames.set_meta(_OVERRIDE_META, color)
	else:
		tile.sprite_frames.remove_meta(_OVERRIDE_META)
	apply(tile.sprite_frames, tile.tile_resource)


## The moment [param tile] is made more than it is, in [param color]: the
## upgrade's burst without its callout, for whoever names it.
static func burst_in(tile: Tile, color: Color) -> void:
	Juice.bump(tile.sprite_frames, 0.35, 0.35)
	tile.flash(Globals.white, 1.0, 0.4)
	Juice.sparkle(tile, tile.global_position, color, 16, 50.0, true)
	Juice.ring(tile, tile.global_position, Globals.white, 20.0, 0.35, 6.0)
	Events.play_sound.emit(_UPGRADE_SFX)


## The moment [param tile] becomes its upgrade: a bump, a white flash, a ring
## and sparks in its family's colour, and a callout.
static func burst(tile: Tile) -> void:
	var color: Color = ColorSymbolBadge.color_of_tile(tile.tile_resource)
	burst_in(tile, color)
	Juice.callout(tile, TranslationServer.translate(&"CALLOUT_UPGRADED"), color, true)


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
