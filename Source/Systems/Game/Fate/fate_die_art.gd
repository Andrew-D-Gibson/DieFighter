class_name FateDieArt
extends RefCounted
## How Fate's Die looks: a bone-white die (the parked "knucklebones" idea of
## LORE.md §11: dice carved from something that fell into the hole) with each
## face's glyph carved into it. Composed at run time from the faces' 7x7
## glyphs, so a new face needs only its glyph, and cached per face and scale.

## Approved palette.
const OUTLINE: Color = Color("#040217")
const BONE: Color = Color("#c4c1bc")
const BONE_SHADE: Color = Color("#a5a29d")
const BONE_DEEP: Color = Color("#8e8b85")

## The die's size in pixels at scale 1: a 7x7 glyph with a pixel of bone and
## one of outline all round.
const SIZE: int = 11

static var _cache: Dictionary[Vector2i, ImageTexture] = {}


## The die showing [param face], [param scale] times its pixel size.
static func face_texture(face: FateDie.Face, scale: int = 1) -> ImageTexture:
	var key: Vector2i = Vector2i(int(face), scale)
	if _cache.has(key):
		return _cache[key]
	var image: Image = face_image(face)
	if scale > 1:
		image.resize(SIZE * scale, SIZE * scale, Image.INTERPOLATE_NEAREST)
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture


## The die showing [param face] at its pixel size, as an image to build on.
static func face_image(face: FateDie.Face) -> Image:
	var image: Image = Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y: int in SIZE:
		for x: int in SIZE:
			var corner: bool = (x == 0 or x == SIZE - 1) and (y == 0 or y == SIZE - 1)
			if corner:
				continue
			var edge: bool = x == 0 or y == 0 or x == SIZE - 1 or y == SIZE - 1
			if edge:
				image.set_pixel(x, y, OUTLINE)
			elif x == SIZE - 2 or y == SIZE - 2:
				image.set_pixel(x, y, BONE_SHADE)
			else:
				image.set_pixel(x, y, BONE)
	var res: FateFaceResource = FateFaceCatalog.get_face(face)
	if res and res.glyph:
		var glyph: Image = res.glyph.get_image()
		glyph.decompress()
		glyph.convert(Image.FORMAT_RGBA8)
		image.blend_rect(glyph, Rect2i(Vector2i.ZERO, glyph.get_size()), Vector2i(2, 2))
	elif face == FateDie.Face.BLANK:
		# A blank face still shows it's a face: a faint chisel mark.
		image.set_pixel(5, 5, BONE_DEEP)
	return image


## All six faces side by side as a strip of dice, for the info panel and the
## run's end: what the player carved, slot by slot.
static func strip_texture(die: FateDie, gap: int = 1) -> ImageTexture:
	var width: int = FateDie.FACE_COUNT * SIZE + (FateDie.FACE_COUNT - 1) * gap
	var image: Image = Image.create_empty(width, SIZE, false, Image.FORMAT_RGBA8)
	for slot: int in FateDie.FACE_COUNT:
		var face_img: Image = face_image(die.face_at(slot))
		image.blend_rect(face_img, Rect2i(0, 0, SIZE, SIZE), Vector2i(slot * (SIZE + gap), 0))
	return ImageTexture.create_from_image(image)


## The six faces in two rows of three on one bone slab, 24x24: the info
## panel's picture of the whole die.
static func net_texture(die: FateDie) -> ImageTexture:
	var image: Image = Image.create_empty(24, 24, false, Image.FORMAT_RGBA8)
	var slab: Rect2i = Rect2i(0, 3, 24, 18)
	for y: int in range(slab.position.y, slab.end.y):
		for x: int in range(slab.position.x, slab.end.x):
			var corner: bool = (x == slab.position.x or x == slab.end.x - 1) and (y == slab.position.y or y == slab.end.y - 1)
			if corner:
				continue
			var edge: bool = x == slab.position.x or x == slab.end.x - 1 or y == slab.position.y or y == slab.end.y - 1
			image.set_pixel(x, y, OUTLINE if edge else (BONE_SHADE if y == slab.end.y - 2 else BONE))
	for slot: int in FateDie.FACE_COUNT:
		var res: FateFaceResource = FateFaceCatalog.get_face(die.face_at(slot))
		var at: Vector2i = Vector2i([1, 8, 16][slot % 3], 5 + (slot / 3) * 7)
		if res and res.glyph:
			var glyph: Image = res.glyph.get_image()
			glyph.decompress()
			glyph.convert(Image.FORMAT_RGBA8)
			image.blend_rect(glyph, Rect2i(Vector2i.ZERO, glyph.get_size()), at)
		else:
			image.set_pixel(at.x + 3, at.y + 3, BONE_DEEP)
	return ImageTexture.create_from_image(image)
