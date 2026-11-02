class_name PixelArtShrinker
extends RefCounted
## Shrinks pixel art to an exact pixel width the way an artist would, rather
## than the way a GPU would: every output pixel is the average of the art it
## covers, snapped back to a colour the art already uses. Nearest-neighbour
## scaling drops whole rows and columns instead, so a sprite that shrinks
## slowly flickers as different rows go missing.


## [param source] shrunk to [param width] pixels wide, keeping its aspect.
## [param flip_v] turns it upside down as well.
static func shrink(source: Image, width: int, flip_v: bool = false) -> Image:
	var src: Image = source.duplicate()
	if src.is_compressed():
		src.decompress()
	src.convert(Image.FORMAT_RGBA8)
	if flip_v:
		src.flip_y()

	var src_size: Vector2i = src.get_size()
	var factor: float = float(width) / src_size.x
	var out_size: Vector2i = Vector2i(width, maxi(1, roundi(src_size.y * factor)))
	if out_size.x >= src_size.x:
		return src

	# Every source pixel falls into exactly one output pixel. Each output
	# pixel sums the opaque colour that fell into it and counts how much did.
	var cells: int = out_size.x * out_size.y
	var sums: PackedVector3Array = PackedVector3Array()
	sums.resize(cells)
	var opaque: PackedInt32Array = PackedInt32Array()
	opaque.resize(cells)
	var total: PackedInt32Array = PackedInt32Array()
	total.resize(cells)
	var palette: Dictionary[Color, bool] = {}
	var bytes: PackedByteArray = src.get_data()
	for y: int in src_size.y:
		var row: int = mini(floori(y * factor), out_size.y - 1) * out_size.x
		for x: int in src_size.x:
			var cell: int = row + mini(floori(x * factor), out_size.x - 1)
			total[cell] += 1
			var i: int = (y * src_size.x + x) * 4
			if bytes[i + 3] < 128:
				continue
			var c: Color = Color8(bytes[i], bytes[i + 1], bytes[i + 2])
			palette[c] = true
			sums[cell] += Vector3(c.r, c.g, c.b)
			opaque[cell] += 1

	var colors: Array[Color] = []
	colors.assign(palette.keys())
	var out: Image = Image.create_empty(out_size.x, out_size.y, false, Image.FORMAT_RGBA8)
	for cell: int in cells:
		# Transparent unless art covers at least half of it.
		if opaque[cell] * 2 < total[cell] or opaque[cell] == 0:
			continue
		var average: Vector3 = sums[cell] / opaque[cell]
		out.set_pixel(cell % out_size.x, floori(float(cell) / out_size.x), _nearest(colors, average))
	return out


static func _nearest(colors: Array[Color], target: Vector3) -> Color:
	var best: Color = colors[0]
	var best_distance: float = INF
	for c: Color in colors:
		var d: float = Vector3(c.r, c.g, c.b).distance_squared_to(target)
		if d < best_distance:
			best_distance = d
			best = c
	return best
