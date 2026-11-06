class_name ArrivalShipArt
extends RefCounted
## The arrival's ships at cutscene scale (RECKONING_ENDINGS.md §6, The
## formation): each one's combat sprite shrunk by PixelArtShrinker, so a
## chevron of up to twelve ships and the player's own fits the 320x180 frame
## with whole pixels and the art's own colours. Nothing here is new art.
##
## Sprites keep the way combat draws them (nose up or nose down); the ship
## node turns them to face the way the formation flies. Turned rather than
## redrawn, so JumpFx's stretch along a ship's local y still runs along its
## line of flight.

## Every ship is drawn at this share of its combat size. One scale for all,
## so ships keep their sizes relative to each other.
const SCALE: float = 0.5

## Where the flames leave a ship with no exhaust points of its own: the
## ShipResource default.
const _FALLBACK_ENGINES: PackedVector2Array = [Vector2(-8.5, 9.0), Vector2(8.5, 9.0)]

## Shrunk art by source and width, so a ship drawn twice costs one shrink.
static var _cache: Dictionary[String, ImageTexture] = {}


## One ship's art, ready for ArrivalShip.
class Art:
	## A still sprite (an ally) or the player's animated sheet.
	var texture: Texture2D = null
	var frames: SpriteFrames = null
	## Combat sprites are drawn nose down; the player's sheet nose up.
	var nose_up: bool = false
	## Where the drive flames leave the hull, in the shrunk sprite's pixels
	## from its centre, before it's turned.
	var engines: PackedVector2Array = PackedVector2Array()
	## The ship's faction colour (FactionIdentity.color): its jump, its flares.
	var color: Color = JumpFx.BLUE
	## The ship's faction (FactionIdentity.id): what it says when it's out.
	var faction_id: StringName = &""
	## The ship's name for the credits, translated.
	var display_name: String = ""
	## How big the shrunk sprite is, unturned.
	var size: Vector2i = Vector2i(16, 16)


## The art for saved ship [param enemy_id], or null if it isn't a registered
## enemy with a ship to draw.
static func for_enemy(enemy_id: String) -> Art:
	var path: String = ContentRegistry.get_enemy_path(enemy_id) if not enemy_id.is_empty() else ""
	var enemy: EnemyResource = load(path) as EnemyResource if not path.is_empty() else null
	if enemy == null or enemy.ship_graphics_scene == null:
		return null
	var graphics: Node2D = enemy.ship_graphics_scene.instantiate() as Node2D
	if graphics == null:
		return null
	var image: Image = _image_of(_hull_texture(graphics))
	var engines: PackedVector2Array = PackedVector2Array()
	for particles: Node in graphics.find_children("*", "CPUParticles2D", true, false):
		engines.append((particles as Node2D).position)
	graphics.free()
	if image == null:
		return null

	var art: Art = Art.new()
	art.texture = _shrunk(path, image)
	art.size = Vector2i(art.texture.get_size())
	# The engine flames are what say which end is the tail: a ship that flies
	# nose up in combat (an escort on the player's side) has them below.
	var tail_y: float = 0.0
	for engine: Vector2 in engines:
		tail_y += engine.y
	art.nose_up = tail_y > 0.0
	for engine: Vector2 in engines:
		art.engines.append((engine * SCALE).round())
	if enemy.faction:
		art.color = enemy.faction.color
		art.faction_id = enemy.faction.id
	art.display_name = enemy.display_name()
	return art


## The player's ship [param ship]: its cutscene sheet (the "boost" flames
## included), every frame shrunk.
static func for_player(ship: ShipResource) -> Art:
	var art: Art = Art.new()
	art.nose_up = true
	art.color = EngineCharger.DRIVE_COLOR
	var points: PackedVector2Array = ship.cutscene_exhaust_points if ship else _FALLBACK_ENGINES
	for point: Vector2 in points:
		art.engines.append((point * SCALE).round())
	if ship == null or ship.cutscene_frames == null or not ship.cutscene_frames.has_animation(&"boost"):
		return art
	art.display_name = ship.display_name
	var source: SpriteFrames = ship.cutscene_frames
	art.frames = SpriteFrames.new()
	art.frames.set_animation_speed(&"default", source.get_animation_speed(&"boost"))
	art.frames.set_animation_loop(&"default", source.get_animation_loop(&"boost"))
	for i: int in source.get_frame_count(&"boost"):
		var frame: Texture2D = source.get_frame_texture(&"boost", i)
		var image: Image = _image_of(frame)
		if image == null:
			continue
		var shrunk: ImageTexture = _shrunk("%s#%d" % [ship.id, i], image)
		art.frames.add_frame(&"default", shrunk, source.get_frame_duration(&"boost", i))
		art.size = Vector2i(shrunk.get_size())
	return art


## The hull's picture in a ship's graphics scene: its own sprite, or the
## first frame of an animated one.
static func _hull_texture(graphics: Node2D) -> Texture2D:
	var candidates: Array[Node] = [graphics]
	candidates.append_array(graphics.find_children("*", "", true, false))
	for node: Node in candidates:
		if node is Sprite2D and (node as Sprite2D).texture:
			return (node as Sprite2D).texture
		var animated: AnimatedSprite2D = node as AnimatedSprite2D
		if animated and animated.sprite_frames and animated.sprite_frames.get_frame_count(animated.animation) > 0:
			return animated.sprite_frames.get_frame_texture(animated.animation, 0)
	return null


## A small thing (the die the last ship carries) at [param width] pixels.
static func shrink_texture(texture: Texture2D, width: int) -> ImageTexture:
	var image: Image = _image_of(texture)
	var key: String = "%s@%d" % [texture.resource_path, width]
	if not _cache.has(key):
		_cache[key] = ImageTexture.create_from_image(PixelArtShrinker.shrink(image, width))
	return _cache[key]


static func _shrunk(key: String, image: Image) -> ImageTexture:
	var width: int = maxi(1, roundi(image.get_width() * SCALE))
	var cache_key: String = "%s@%d" % [key, width]
	if not _cache.has(cache_key):
		_cache[cache_key] = ImageTexture.create_from_image(PixelArtShrinker.shrink(image, width))
	return _cache[cache_key]


## The pixels of [param texture]; an atlas's region only, since several ships
## are cut from a shared sheet.
static func _image_of(texture: Texture2D) -> Image:
	if texture == null:
		return null
	var atlas: AtlasTexture = texture as AtlasTexture
	if atlas and atlas.atlas:
		var sheet: Image = atlas.atlas.get_image()
		if sheet == null:
			return null
		if sheet.is_compressed():
			sheet.decompress()
		return sheet.get_region(Rect2i(atlas.region))
	return texture.get_image()
