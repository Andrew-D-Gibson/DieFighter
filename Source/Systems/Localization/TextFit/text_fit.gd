class_name TextFit
extends RefCounted
## Fits text into the box it's allowed to appear in, whatever the language:
## wrapping it, shrinking it on its pixel grid, and placing it by its ink.
##
## Translated text overflows in predictable ways. German runs long and
## builds compounds no line can break ("Bildschirmwackeln"); Chinese runs
## short but tall, its 12 px characters filling a line box English capitals
## use half of. So every piece of fitted text has:
## - a box: where it may appear, in its parent's coordinates (a button's face
##   inside its border and 3D lip, a menu's hint strip, a row's width);
## - a policy (TextFitPolicy): how many lines it may take, how far it may
##   shrink, which it tries first.
## solve() picks the largest scale at which the text fits its box under the
## policy, never breaking inside a word unless nothing else fits, and works
## out where the label goes so its glyphs sit centred in the box (or on its
## top or bottom edge) and inside it. apply() puts the label there.
##
## Scales step in whole canvas pixels per font pixel: through the 6x world
## camera a shrunk world label draws its font pixels 5 or 4 canvas pixels
## wide, and a BodyX6 one 5 or 4 too, so shrunk text stays crisp and even.
## Shrinking is Control.scale, never a font size override, so the font roles
## (FontRoles) keep owning every size.
##
## What's measured is the label's shown text in its own font, size and line
## spacing: a Label's translated text, a RichTextLabel's parsed text. Inline
## images and BBCode that changes fonts or sizes aren't measured, so text
## made of those wants its own box sized from its content.
##
## Most code doesn't call this directly:
## - TextFitter, a child of a label in a fixed frame (a button, a strip),
##   keeps it fitted as its text, language, font or frame change.
## - TextFitBox, a Container holding one label, fits it to the width a layout
##   gives it and asks for the height it then needs (an options row).
## - TextFitGroup makes several fitted texts share one scale (a row of tabs,
##   a pair of buttons), so one long title doesn't leave its row mismatched.
## - fit_line() serves code that draws its text with draw_string().

## A label's meta naming the TextFitter or TextFitBox fitting it; the
## overflow watcher reads its result.
const META: StringName = &"text_fit"
## Set on a label while a fit overrides its line spacing: the theme's own.
const _SPACING_META: StringName = &"text_fit_line_spacing"
## Added to the width a label wraps at (in its units): less than any word, so
## it can't pull one up a line, but past the rounding a label breaks with.
const _WRAP_HEADROOM: float = 0.5

## Characters measured against an ideograph rather than a capital when
## centring text by its ink. Ranges of [first, last] code points.
const _FULL_HEIGHT_RANGES: Array[Vector2i] = [
	Vector2i(0x2E80, 0x9FFF),	# CJK radicals, kana, symbols, unified ideographs
	Vector2i(0xAC00, 0xD7AF),	# Hangul syllables
	Vector2i(0xF900, 0xFAFF),	# CJK compatibility ideographs
	Vector2i(0xFF00, 0xFFEF),	# full-width forms
]
const _CAPITAL_REFERENCE: int = 0x48	# H
const _IDEOGRAPH_REFERENCE: int = 0x56FD	# 国

## Per glyph ("rid:size:index"), its ink above and below the baseline as
## Vector2(top, bottom) in pixels (y down), or Vector2.INF for none.
static var _glyph_ink: Dictionary[String, Vector2] = {}
## Per font and size and reference ("rid:size:H"), the reference glyph's ink.
static var _reference_ink: Dictionary[String, Vector2] = {}


## How a piece of text was fitted, and where its label goes.
class Result:
	extends RefCounted
	## The label's scale: 1 at full size.
	var scale: float = 1.0
	var line_count: int = 0
	## Whether the lines were broken inside words (the last resort).
	var broke_words: bool = false
	## The lines' boxes together, in the label's own (unscaled) units.
	var block_size: Vector2 = Vector2.ZERO
	## The glyphs' ink, relative to the block's top-left, unscaled.
	var ink: Rect2 = Rect2()
	## The label's place, in the box's (its parent's) coordinates: position
	## and unscaled size.
	var position: Vector2 = Vector2.ZERO
	var size: Vector2 = Vector2.ZERO
	## The ink as drawn, in the parent's coordinates.
	var ink_rect: Rect2 = Rect2()
	## False when the text overflows its box even at the policy's min_scale.
	var fits: bool = true
	## Roughly the scale it would have needed, when it doesn't fit.
	var needed_scale: float = 1.0
	## The box it was fitted to.
	var box: Rect2 = Rect2()
	## Set by solve(): how apply() wraps the label.
	var wrap_width: float = -1.0
	## The spacing between its lines, and the label's own (see Layout).
	var line_spacing: float = 0.0
	var own_line_spacing: float = 0.0
	## What it was measured from, for placing it again in a resized box.
	var source: Source
	var layout: Layout

	func describe() -> String:
		var parts: Array[String] = ["x%.2f" % scale, "%d line%s" % [line_count, "" if line_count == 1 else "s"]]
		if broke_words:
			parts.append("words broken")
		if not fits:
			parts.append("needs ~x%.2f" % needed_scale)
		return ", ".join(parts)


## Everything about a text that its fit depends on, measured once.
class Source:
	extends RefCounted
	var text: String = ""
	var font: Font
	var font_size: int = 16
	## Added between lines: a Label's line_spacing, a RichTextLabel's
	## line_separation.
	var line_spacing: float = 0.0
	var horizontal_alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT
	## Canvas pixels per unit of the label's parent.
	var pixels_per_unit: float = 1.0
	## One font pixel, in the label's units (0 when the font isn't a role's).
	var font_pixel: float = 0.0
	## Canvas pixels per font pixel at full size (0 when unknown).
	var grid: int = 0
	var paragraph: TextParagraph


## The text's lines at one width.
class Layout:
	extends RefCounted
	var line_count: int = 0
	var widest: float = 0.0
	var height: float = 0.0
	## Relative to the block's top: the ink's extent, and the optical band
	## (capitals' or ideographs' height, accents and descenders left out)
	## that centring goes by.
	var ink_top: float = 0.0
	var ink_bottom: float = 0.0
	var band_top: float = 0.0
	var band_bottom: float = 0.0
	## The first line's baseline, from the block's top.
	var first_ascent: float = 0.0
	## Between lines: the label's own spacing, or more if the lines' ink
	## would touch.
	var line_spacing: float = 0.0
	## The width the lines were broken at (-1: unbroken).
	var width: float = -1.0
	var broke_words: bool = false


## --- Solving ---

## Fits [param label]'s text into [param box] (in the label's parent's
## coordinates) under [param policy], at most at [param max_scale] (a
## TextFitGroup's shared scale). A box of infinite height constrains only the
## width and the line count.
static func solve(label: Control, box: Rect2, policy: TextFitPolicy, max_scale: float = 1.0) -> Result:
	return solve_source(source_of(label), box, policy, max_scale)


static func solve_source(source: Source, box: Rect2, policy: TextFitPolicy, max_scale: float = 1.0) -> Result:
	var result: Result = Result.new()
	result.box = box
	if source.text.strip_edges().is_empty() or source.font == null:
		result.position = box.position
		result.size = Vector2(box.size.x, 0.0 if not is_finite(box.size.y) else box.size.y)
		return result
	var scales: Array[float] = _scales(source, policy, max_scale)
	var passes: Array[int] = [policy.max_lines]
	if policy.prefer == TextFitPolicy.Prefer.SHRINK and policy.max_lines > 1:
		passes = [1, policy.max_lines]
	for line_limit: int in passes:
		for scale: float in scales:
			var layout: Layout = _fitting_layout(source, box, scale, line_limit)
			if layout != null:
				if layout.line_count > 1 and layout.width > 0.0 and policy.balance_lines:
					layout = _balanced(source, layout)
				_finish(result, source, layout, scale, policy, true)
				return result
	# Nothing fits: the smallest scale, breaking words if the policy allows.
	var smallest: float = scales[-1]
	var last: Layout
	if policy.max_lines > 1 and is_finite(box.size.x):
		last = _layout(source, box.size.x / smallest, policy.break_words_last_resort)
	else:
		last = _layout(source, -1.0, false)
	_finish(result, source, last, smallest, policy, false)
	result.needed_scale = _needed_scale(source, box, policy, smallest)
	return result


## For a report: the largest scale under [param below] at which the text
## would fit (searched down to a quarter), so a failed fit says how far off
## it is.
static func _needed_scale(source: Source, box: Rect2, policy: TextFitPolicy, below: float) -> float:
	var scale: float = below
	while scale > 0.25:
		scale -= 1.0 / maxf(source.grid, 12.0)
		if _fitting_layout(source, box, scale, policy.max_lines) != null:
			return scale
	return 0.25


## The largest scale [param label]'s text fits [param box] at under
## [param policy], for a TextFitGroup sharing out one scale.
static func best_scale(label: Control, box: Rect2, policy: TextFitPolicy) -> float:
	return solve(label, box, policy).scale


## For text drawn with draw_string(): fits one string in [param font] at
## [param font_size] into [param box] (in the drawing item's coordinates).
## Draw it with draw_set_transform(result.position, 0, Vector2.ONE * result.scale)
## and the string at (0, ascent) of the first line, or use draw_fitted_line().
static func fit_line(item: CanvasItem, text: String, font: Font, font_size: int, box: Rect2,
		policy: TextFitPolicy, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Result:
	var source: Source = _source(text, font, font_size, 0.0, alignment, item)
	return solve_source(source, box, policy)


## Draws [param text] on [param item] as fit_line() fitted it (one line).
static func draw_fitted_line(item: CanvasItem, result: Result, text: String, font: Font, font_size: int,
		color: Color) -> void:
	var ascent: float = result.layout.first_ascent if result.layout else font.get_ascent(font_size)
	item.draw_set_transform(result.position, 0.0, Vector2.ONE * result.scale)
	item.draw_string(font, Vector2(0.0, ascent), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	item.draw_set_transform(Vector2.ZERO)


## Puts [param label] where [param result] says, at its scale, wrapping as it
## was measured. The label is placed by its top-left with its text at the
## top, so nothing of Godot's own alignment moves it off the pixel grid.
static func apply(label: Control, result: Result) -> void:
	if label is RichTextLabel:
		var rich: RichTextLabel = label as RichTextLabel
		rich.fit_content = false
		rich.scroll_active = false
	# Ink can sit a pixel outside the line boxes (Chinese, accents), and a
	# [wave] moves it further: the box, not the label, bounds the text.
	label.clip_contents = false
	label.set(&"vertical_alignment", VERTICAL_ALIGNMENT_TOP)
	var wrap: TextServer.AutowrapMode = TextServer.AUTOWRAP_OFF
	if result.wrap_width >= 0.0:
		wrap = TextServer.AUTOWRAP_WORD_SMART if result.broke_words else TextServer.AUTOWRAP_WORD
	label.set(&"autowrap_mode", wrap)
	_apply_line_spacing(label, result)
	label.pivot_offset = Vector2.ZERO
	label.scale = Vector2.ONE * result.scale
	label.position = result.position
	label.size = result.size


## Spaces the label's lines as the fit measured them, overriding its theme's
## spacing only while its lines' ink needs more room, and only when the value
## changes (an override re-themes the label, which would refit it).
static func _apply_line_spacing(label: Control, result: Result) -> void:
	var item: StringName = _line_spacing_item(label)
	var wanted: int = roundi(result.line_spacing)
	if wanted != roundi(result.own_line_spacing):
		if not label.has_meta(_SPACING_META):
			label.set_meta(_SPACING_META, result.own_line_spacing)
		if not label.has_theme_constant_override(item) or label.get_theme_constant(item) != wanted:
			label.add_theme_constant_override(item, wanted)
	elif label.has_meta(_SPACING_META):
		label.remove_meta(_SPACING_META)
		label.remove_theme_constant_override(item)


## A label's spacing between lines as its theme sets it, ignoring the
## override a fit may have added.
static func _own_line_spacing(label: Control) -> float:
	if label.has_meta(_SPACING_META):
		return float(label.get_meta(_SPACING_META))
	return label.get_theme_constant(_line_spacing_item(label))


static func _line_spacing_item(label: Control) -> StringName:
	return &"line_separation" if label is RichTextLabel else &"line_spacing"


## The TextFitter or TextFitBox fitting [param label], or null.
static func fitter_of(label: Node) -> Object:
	if label.has_meta(META):
		var fitter: Object = label.get_meta(META)
		if is_instance_valid(fitter):
			return fitter
	return null


## The last fit of [param label]'s fitter, or null if it has none (or hasn't
## fitted yet).
static func result_of(label: Node) -> Result:
	var fitter: Object = fitter_of(label)
	return fitter.get(&"result") as Result if fitter != null else null


## --- Checking text nobody fitted (the overflow watcher) ---

## Where [param label]'s glyph ink draws as the label lays it out now, in the
## label's own coordinates (its own vertical and horizontal alignment
## counted).
static func laid_out_ink(label: Control) -> Rect2:
	var source: Source = source_of(label)
	var layout: Layout = _laid_out(label, source)
	var spare: Vector2 = label.size - Vector2(layout.widest, layout.height)
	var factors: Array[float] = [0.0, 0.5, 1.0, 0.0]	# left/top, centre, right/bottom, fill
	var x: float = spare.x * factors[clampi(int(label.get(&"horizontal_alignment")), 0, 3)]
	var y: float = spare.y * factors[clampi(int(label.get(&"vertical_alignment")), 0, 3)]
	return Rect2(x, y + layout.ink_top, layout.widest, layout.ink_bottom - layout.ink_top)


## Whether [param label]'s wrapping breaks inside a word: smart wrapping does
## when a word is wider than the line ("Bildschirmwack / eln").
static func breaks_words(label: Control) -> bool:
	var wrap: int = int(label.get(&"autowrap_mode"))
	if wrap != TextServer.AUTOWRAP_WORD_SMART and wrap != TextServer.AUTOWRAP_ARBITRARY:
		return false
	var source: Source = source_of(label)
	var layout: Layout = _layout(source, label.size.x, false)
	return layout.widest > label.size.x + 0.5


## Whether [param label]'s wrapped lines draw into each other: its line
## spacing leaves less room than its glyphs need (Chinese under English's
## tight RichTextLabel spacing).
static func lines_collide(label: Control) -> bool:
	var source: Source = source_of(label)
	var layout: Layout = _laid_out(label, source)
	return layout.line_count > 1 and layout.line_spacing > source.line_spacing + 0.5


## The source's layout as the label wraps it now.
static func _laid_out(label: Control, source: Source) -> Layout:
	var wrap: int = int(label.get(&"autowrap_mode"))
	var width: float = -1.0 if wrap == TextServer.AUTOWRAP_OFF else label.size.x
	return _layout(source, width, wrap == TextServer.AUTOWRAP_WORD_SMART or wrap == TextServer.AUTOWRAP_ARBITRARY)


## --- Measuring ---

## What [param label] shows and how, ready to fit.
static func source_of(label: Control) -> Source:
	var parent: CanvasItem = label.get_parent() as CanvasItem
	if label is RichTextLabel:
		var rich: RichTextLabel = label as RichTextLabel
		return _source(rich.get_parsed_text(), rich.get_theme_font(&"normal_font"),
			rich.get_theme_font_size(&"normal_font_size"), _own_line_spacing(rich),
			rich.horizontal_alignment, parent if parent else label)
	if label is Label:
		var plain: Label = label as Label
		var text: String = plain.atr(plain.text)
		return _source(text.to_upper() if plain.uppercase else text, plain.get_theme_font(&"font"),
			plain.get_theme_font_size(&"font_size"), _own_line_spacing(plain),
			plain.horizontal_alignment, parent if parent else label)
	push_error("TextFit: %s is neither a Label nor a RichTextLabel" % label.get_path())
	return Source.new()


## Canvas pixels per unit of [param item]: its own scale through the canvas
## it's drawn on, the world's 6x camera counted at its resting zoom (a zoom
## punch shouldn't refit text).
static func canvas_pixels_per_unit(item: CanvasItem) -> float:
	if item == null or not item.is_inside_tree():
		return ScreenFrame.ART_PIXEL_SCALE
	var scale: float = absf(item.get_global_transform().get_scale().x)
	var layer: CanvasLayer = item.get_canvas_layer_node()
	if layer == null or layer.follow_viewport_enabled:
		scale *= ScreenFrame.ART_PIXEL_SCALE
	else:
		scale *= absf(layer.transform.get_scale().x)
	return maxf(scale, 0.001)


static func _source(text: String, font: Font, font_size: int, line_spacing: float,
		alignment: HorizontalAlignment, item: CanvasItem) -> Source:
	var source: Source = Source.new()
	source.text = text
	source.font = font
	source.font_size = font_size
	source.line_spacing = line_spacing
	source.horizontal_alignment = alignment
	source.pixels_per_unit = canvas_pixels_per_unit(item)
	var unit: int = FontRoles.unit_of(font) if font else 0
	if unit > 0:
		source.font_pixel = float(font_size) / unit
		source.grid = roundi(source.pixels_per_unit * source.font_pixel)
	source.paragraph = TextParagraph.new()
	if font:
		source.paragraph.add_string(text, font, font_size)
	return source


## The scales to try, largest first: whole canvas pixels per font pixel from
## full size down to the policy's minimum, none above [param max_scale].
static func _scales(source: Source, policy: TextFitPolicy, max_scale: float) -> Array[float]:
	var scales: Array[float] = []
	var steps: Array[float] = []
	if source.grid >= 2:
		for pixels: int in range(source.grid, 0, -1):
			steps.append(float(pixels) / source.grid)
	else:
		for i: int in range(17):
			steps.append(1.0 - i / 16.0)
	for scale: float in steps:
		if scale > max_scale + 0.0001:
			continue
		if scale < policy.min_scale - 0.0001:
			break
		scales.append(scale)
	if scales.is_empty():
		# A group's shared scale can be below this text's own minimum: the
		# group's look wins, at the nearest step under it.
		for scale: float in steps:
			if scale <= max_scale + 0.0001:
				scales.append(scale)
				break
	if scales.is_empty():
		scales.append(steps[-1])
	return scales


## The text's layout at [param scale] if it fits [param box] on at most
## [param line_limit] lines without breaking a word, else null.
static func _fitting_layout(source: Source, box: Rect2, scale: float, line_limit: int) -> Layout:
	var width: float = box.size.x / scale
	# A canvas pixel of slack: layouts round, and a glyph a fraction of a
	# canvas pixel over its box draws exactly as one inside it.
	var slack: float = 1.0 / (source.pixels_per_unit * scale)
	var layout: Layout = _layout(source, -1.0 if line_limit == 1 or not is_finite(width) else width, false)
	if layout.line_count > line_limit or layout.widest > width + slack:
		return null
	if is_finite(box.size.y) and layout.ink_bottom - layout.ink_top > box.size.y / scale + slack:
		return null
	return layout


## The fewest-lines layout made as narrow as it can be without adding a line,
## so wrapped lines come out even.
static func _balanced(source: Source, layout: Layout) -> Layout:
	var low: float = 0.0
	var high: float = layout.width
	for i: int in range(10):
		var middle: float = (low + high) / 2.0
		var trial: Layout = _layout(source, middle, false)
		if trial.line_count <= layout.line_count and trial.widest <= middle + 0.01:
			high = middle
		else:
			low = middle
	var balanced: Layout = _layout(source, high, false)
	return balanced if balanced.line_count == layout.line_count else layout


## Breaks the source's text at [param width] (-1: only at newlines) and
## measures its lines and ink. Shaping happened once, in _source(); this only
## re-breaks it.
static func _layout(source: Source, width: float, break_words: bool) -> Layout:
	var paragraph: TextParagraph = source.paragraph
	var flags: int = TextServer.BREAK_MANDATORY | TextServer.BREAK_TRIM_START_EDGE_SPACES \
		| TextServer.BREAK_TRIM_END_EDGE_SPACES
	if width >= 0.0:
		flags |= TextServer.BREAK_WORD_BOUND
		if break_words:
			flags |= TextServer.BREAK_ADAPTIVE
	paragraph.break_flags = flags
	paragraph.width = width
	var text_server: TextServer = TextServerManager.get_primary_interface()
	var layout: Layout = Layout.new()
	layout.width = width
	layout.broke_words = break_words
	layout.line_count = paragraph.get_line_count()
	layout.ink_top = INF
	layout.ink_bottom = -INF
	layout.band_top = INF
	layout.band_bottom = -INF
	# Each line's ink and band relative to its own baseline, first: the
	# spacing between lines depends on them.
	var line_inks: Array[Rect2] = []
	var line_bands: Array[Vector2] = []
	# Per line, the ink of its ideographs (and kana, Hangul) and of
	# everything else, apart: see the spacing below.
	var full_inks: Array[Vector2] = []
	var other_inks: Array[Vector2] = []
	for i: int in range(layout.line_count):
		layout.widest = maxf(layout.widest, paragraph.get_line_width(i))
		var ink_span: Vector2 = Vector2(INF, -INF)
		var band_span: Vector2 = Vector2(INF, -INF)
		var full_span: Vector2 = Vector2(INF, -INF)
		var other_span: Vector2 = Vector2(INF, -INF)
		for glyph: Dictionary in text_server.shaped_text_get_glyphs(paragraph.get_line_rid(i)):
			if glyph["flags"] & TextServer.GRAPHEME_IS_SPACE:
				continue
			var code: int = source.text.unicode_at(glyph["start"]) if glyph["start"] < source.text.length() else 0
			if code == 0xFFFC:
				continue
			var rid: RID = glyph["font_rid"]
			var size: int = glyph["font_size"]
			var lift: float = (glyph["offset"] as Vector2).y
			var ink: Vector2 = _ink_of(rid, size, glyph["index"])
			if ink == Vector2.INF:
				continue
			var span: Vector2 = Vector2(lift + ink.x, lift + ink.y)
			ink_span = Vector2(minf(ink_span.x, span.x), maxf(ink_span.y, span.y))
			var full_height: bool = _is_full_height(code)
			if full_height:
				full_span = Vector2(minf(full_span.x, span.x), maxf(full_span.y, span.y))
			else:
				other_span = Vector2(minf(other_span.x, span.x), maxf(other_span.y, span.y))
			var band: Vector2 = _reference_band(rid, size, full_height, ink)
			band_span = Vector2(minf(band_span.x, lift + band.x), maxf(band_span.y, lift + band.y))
		line_inks.append(Rect2(0.0, ink_span.x, 0.0, ink_span.y - ink_span.x))
		line_bands.append(band_span)
		full_inks.append(full_span)
		other_inks.append(other_span)

	# Lines as far apart as the label's spacing puts them, or further where
	# one line's ink would run into the next's. English's tight
	# line_separation lets a descender touch the capital below it, and Latin
	# keeps that; an ideograph, which fills its line, gets a font pixel's gap,
	# or a wrapped Chinese label reads as one block.
	layout.line_spacing = source.line_spacing
	var gap: float = source.font_pixel if source.font_pixel > 0.0 else 1.0
	for i: int in range(layout.line_count - 1):
		var descent: float = paragraph.get_line_size(i).y - paragraph.get_line_ascent(i)
		var pitch: float = descent + paragraph.get_line_ascent(i + 1)
		for upper: Array in [[full_inks[i], true], [other_inks[i], false]]:
			for lower: Array in [[full_inks[i + 1], true], [other_inks[i + 1], false]]:
				var below: float = (upper[0] as Vector2).y
				var above: float = -(lower[0] as Vector2).x
				if not is_finite(below) or not is_finite(above):
					continue
				var needed: float = below + above + (gap if upper[1] or lower[1] else 0.0) - pitch
				# Whole pixels, ignoring float dust from the MSDF correction.
				layout.line_spacing = maxf(layout.line_spacing, ceilf(needed - 0.01))

	var top: float = 0.0
	for i: int in range(layout.line_count):
		var baseline: float = top + paragraph.get_line_ascent(i)
		if i == 0:
			layout.first_ascent = baseline
		if is_finite(line_inks[i].position.y):
			layout.ink_top = minf(layout.ink_top, baseline + line_inks[i].position.y)
			layout.ink_bottom = maxf(layout.ink_bottom, baseline + line_inks[i].end.y)
			layout.band_top = minf(layout.band_top, baseline + line_bands[i].x)
			layout.band_bottom = maxf(layout.band_bottom, baseline + line_bands[i].y)
		top += paragraph.get_line_size(i).y
		if i < layout.line_count - 1:
			top += layout.line_spacing
	layout.height = top
	if layout.ink_top == INF:
		# Nothing with ink (all images or blanks): the line boxes stand in.
		layout.ink_top = 0.0
		layout.ink_bottom = top
		layout.band_top = 0.0
		layout.band_bottom = top
	return layout


## Where the label goes for [param layout] at [param scale] in the result's
## box, filled into [param result].
static func _finish(result: Result, source: Source, layout: Layout, scale: float,
		policy: TextFitPolicy, fits: bool) -> void:
	result.scale = scale
	result.fits = fits
	result.line_count = layout.line_count
	result.broke_words = layout.broke_words
	result.block_size = Vector2(layout.widest, layout.height)
	result.ink = Rect2(0.0, layout.ink_top, layout.widest, layout.ink_bottom - layout.ink_top)
	# The width the lines were broken at, not the widest line: breaking also
	# counts the space a line ends on, so the widest line's width can push a
	# word down a line. Plus _WRAP_HEADROOM: a balanced width sits right on a
	# break, where a label's own rounding can tip a word over.
	result.wrap_width = -1.0 if layout.width < 0.0 else layout.width + _WRAP_HEADROOM
	result.line_spacing = layout.line_spacing
	result.own_line_spacing = source.line_spacing
	result.source = source
	result.layout = layout
	place(result, result.box, policy)


## Positions an already solved [param result] in [param box]: horizontally
## by the label's alignment, vertically by the policy's, by ink. Separate so
## a container can fit to its width first and place once it knows its
## height.
static func place(result: Result, box: Rect2, policy: TextFitPolicy) -> void:
	var source: Source = result.source
	var layout: Layout = result.layout
	if source == null or layout == null:
		result.position = box.position
		return
	result.box = box
	var scale: float = result.scale
	var room: Vector2 = Vector2(box.size.x / scale, (box.size.y if is_finite(box.size.y) else layout.height * scale) / scale)
	var width: float = layout.widest if layout.width < 0.0 else layout.width + _WRAP_HEADROOM
	var x: float = 0.0
	match source.horizontal_alignment:
		HORIZONTAL_ALIGNMENT_CENTER:
			x = (room.x - width) / 2.0
		HORIZONTAL_ALIGNMENT_RIGHT:
			x = room.x - width

	var ink_height: float = layout.ink_bottom - layout.ink_top
	var y: float = 0.0
	if not policy.align_by_ink:
		match policy.vertical_alignment:
			VERTICAL_ALIGNMENT_TOP:
				y = 0.0
			VERTICAL_ALIGNMENT_BOTTOM:
				y = room.y - layout.height
			_:
				y = (room.y - layout.height) / 2.0
	else:
		match policy.vertical_alignment:
			VERTICAL_ALIGNMENT_TOP:
				y = -layout.ink_top
			VERTICAL_ALIGNMENT_BOTTOM:
				y = room.y - layout.ink_bottom
			_:
				y = (room.y - (layout.band_bottom - layout.band_top)) / 2.0 - layout.band_top
	# Accents, descenders and tall scripts stay inside the box when they can:
	# the text moves rather than poke out of its frame.
	if ink_height <= room.y:
		y = clampf(y, -layout.ink_top, room.y - layout.ink_bottom)

	var position: Vector2 = box.position + Vector2(x, y) * scale
	result.position = _snap(position, source, scale)
	result.size = Vector2(width, layout.height)
	result.ink_rect = Rect2(result.position + Vector2(0.0, layout.ink_top) * scale,
		Vector2(width, ink_height) * scale)


## Full-size text lands on whole art pixels (6 canvas pixels: one world unit,
## or six of a screen layer's), so it lines up with the pixel art of the frame
## it's in; shrunk text, whose font pixels are narrower, on whole canvas
## pixels.
static func _snap(position: Vector2, source: Source, scale: float) -> Vector2:
	var step: float = 1.0 / source.pixels_per_unit
	if is_equal_approx(scale, 1.0) and source.font_pixel > 0.0:
		step = ScreenFrame.ART_PIXEL_SCALE / source.pixels_per_unit
	return (position / step).round() * step


static func _is_full_height(code: int) -> bool:
	for span: Vector2i in _FULL_HEIGHT_RANGES:
		if code >= span.x and code <= span.y:
			return true
	return false


## A glyph's ink as Vector2(top, bottom) relative to the baseline (y down),
## from its outline; Vector2.INF if it has none. A glyph with no outline that
## isn't blank (a bitmap font, a missing glyph's box) counts as its font's
## full height.
static func _ink_of(rid: RID, size: int, index: int) -> Vector2:
	var key: String = "%d:%d:%d" % [rid.get_id(), size, index]
	if _glyph_ink.has(key):
		return _glyph_ink[key]
	var text_server: TextServer = TextServerManager.get_primary_interface()
	var contours: Dictionary = text_server.font_get_glyph_contours(rid, size, index)
	var points: PackedVector3Array = contours.get("points", PackedVector3Array())
	var ink: Vector2 = Vector2.INF
	if not points.is_empty():
		var top: float = INF
		var bottom: float = -INF
		for point: Vector3 in points:
			top = minf(top, point.y)
			bottom = maxf(bottom, point.y)
		ink = Vector2(top, bottom) + Vector2.ONE * _msdf_shift(rid, size, index, top, bottom)
	elif index != 0 and text_server.font_get_glyph_advance(rid, size, index).x > 0.0 \
			and text_server.font_get_glyph_size(rid, Vector2i(size, 0), index).y > 0.0:
		ink = Vector2(-text_server.font_get_ascent(rid, size), text_server.font_get_descent(rid, size))
	_glyph_ink[key] = ink
	return ink


## How far an MSDF glyph draws below its outline (negative: above). 4.7.1
## places the glyph's distance-field quad at a fractional offset in the
## field's own texels while padding it evenly, so m3x6's capitals draw 0.4 of
## a font pixel above where their outline says, more at bigger sizes. Read
## off the quad Godot draws, so a fixed engine gives 0.
static func _msdf_shift(rid: RID, size: int, index: int, top: float, bottom: float) -> float:
	var text_server: TextServer = TextServerManager.get_primary_interface()
	if not text_server.font_is_multichannel_signed_distance_field(rid):
		return 0.0
	var field_size: int = text_server.font_get_msdf_size(rid)
	if field_size <= 0:
		return 0.0
	var to_field: float = float(field_size) / size
	var quad: Vector2 = text_server.font_get_glyph_size(rid, Vector2i(field_size, 0), index)
	var offset: Vector2 = text_server.font_get_glyph_offset(rid, Vector2i(field_size, 0), index)
	if quad.y <= 0.0:
		return 0.0
	var drawn_top: float = offset.y + (quad.y - (bottom - top) * to_field) / 2.0
	return drawn_top / to_field - top


## The band a glyph is centred by: its font's capital H (or, for an
## ideograph, 国), so a line of capitals, one with accents and one in
## lowercase all sit on the same baseline in the same box. A font without the
## reference uses the glyph's own ink.
static func _reference_band(rid: RID, size: int, full_height: bool, own: Vector2) -> Vector2:
	var key: String = "%d:%d:%s" % [rid.get_id(), size, "国" if full_height else "H"]
	if not _reference_ink.has(key):
		var text_server: TextServer = TextServerManager.get_primary_interface()
		var reference: int = _IDEOGRAPH_REFERENCE if full_height else _CAPITAL_REFERENCE
		var index: int = text_server.font_get_glyph_index(rid, size, reference, 0)
		_reference_ink[key] = _ink_of(rid, size, index) if index != 0 else Vector2.INF
	var band: Vector2 = _reference_ink[key]
	return own if band == Vector2.INF else band
