class_name CockpitWalls
extends Sprite2D
## The cockpit shell. The game scene holds one, and the ship's Cockpit dresses
## it: a shell of its own, or this default one repainted in the ship's colours.
##
## The shell is a real texture, recoloured once rather than shaded, because the
## cockpit's destruction and glass shards cut themselves out of it and land on
## its opaque pixels: they pick up whatever the ship flies for free.

const GROUP: StringName = &"cockpit_walls"


func _enter_tree() -> void:
	add_to_group(GROUP)


## The shell in [param from]'s tree, or null outside the game scene.
static func find(from: Node) -> CockpitWalls:
	if not from or not from.is_inside_tree():
		return null
	return from.get_tree().get_first_node_in_group(GROUP) as CockpitWalls


## A copy of the texture with each colour in the palette's keys swapped for
## its value. Exact matches only: the art is drawn from a fixed palette.
static func recolor(source: Texture2D, palette: Dictionary[Color, Color]) -> Texture2D:
	var image: Image = source.get_image()
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	var swaps: Dictionary[int, Color] = {}
	for from: Color in palette:
		swaps[_key(from)] = palette[from]
	for y: int in image.get_height():
		for x: int in image.get_width():
			var pixel: Color = image.get_pixel(x, y)
			if pixel.a > 0.0 and swaps.has(_key(pixel)):
				var swapped: Color = swaps[_key(pixel)]
				image.set_pixel(x, y, Color(swapped, pixel.a))
	return ImageTexture.create_from_image(image)


## The colour as 0xRRGGBB, so float rounding can't split one palette colour
## into two dictionary keys.
static func _key(color: Color) -> int:
	return (color.r8 << 16) | (color.g8 << 8) | color.b8
