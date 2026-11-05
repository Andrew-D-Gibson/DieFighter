class_name FontRoles
extends RefCounted
## Font roles: every piece of text names a role, never a font file or a raw
## size, and each language decides how its roles look.
##
## Five roles cover the game's text:
## - small: most UI text. The theme's default font, so a Label, Button or
##   RichTextLabel with no font of its own is in this role. m3x6 in English.
## - body: titles, the info panel and world-space readouts. m5x7 in English.
## - popup: the words that float off ships (DamageNumber callouts).
## - digits, digits_small: the figures that float off ships (a hit's "5", a
##   heal's "+3", a capped "12→3" whose lead is digits_small). m5x7 and m3x6
##   in every language: digits read the same in all of them, so a popup looks
##   the same everywhere and the capped lead stays a size below the result.
##   Only figures land here (DamageNumber.is_figure), never words.
##
## A FontProfile per locale (res://Assets/Fonts/Profiles/<locale>.tres) gives
## each role a FontFace: a font, a unit size and fallbacks. Localization
## applies the language's profile when it switches language, so the fonts
## change everywhere at once, live.
##
## How text reaches its role:
## - Every role draws through one FontVariation wrapper
##   (res://Assets/Fonts/Roles/<role>.tres). Applying a profile sets each
##   wrapper's base font and fallbacks; everything holding the wrapper
##   re-shapes, because the wrapper emits `changed`.
## - Sizes are in units of the role: a slot is "body at x6", never "96". A
##   scene's Label or RichTextLabel names its slot through
##   theme_type_variation (one of SLOT_TYPES, e.g. &"BodyX6"); the project
##   theme defines each slot type's font and size, and applying a profile sets
##   those sizes to unit x scale. Plain text in the small role at x1 needs
##   nothing: the theme's default font and size are that slot.
## - Code that draws text itself (draw_string, measuring) asks for font(role)
##   and size(role, scale).
## So when a role doesn't fit in a language, changing that role's face in the
## language's profile resizes every slot of the role together, and English
## sizes are untouched. test_font_roles.gd fails on a raw font or size
## override on text a scene translates.
##
## Readable Font (the accessibility option, see FontSwap) layers a readable
## profile's face over the language's: the readable font leads and the
## language's fonts follow as its fallbacks, so scripts the readable font
## lacks still draw, in the language's own line box. Readable Font changes
## Latin text only. Since a fallback draws at the primary's size, the readable
## face of a role must have the language face's unit size, or the language's
## pixel font would draw off its grid: a profile names its own readable
## overlay (FontProfile.readable) when its units differ from the default
## readable profile's 16. Chinese and Japanese use readable_12 (Atkinson
## rescaled to draw at 12 as it does at 16, so Fusion Pixel stays at 12);
## de, fr, es, pt_BR and ru use readable_8 for small text, so Tiny5 (drawing
## the Cyrillic Atkinson lacks) stays at 8. Each rescaled copy also has its
## pixel font's own line and the same line spacing, because a Label's lines
## are as tall as the tallest font in the chain plus the leading one's spacing.
##
## Godot draws a fallback at the primary font's size (checked in 4.7.1), so a
## language whose script the role's font lacks swaps the role's primary font
## and unit size rather than only adding fallbacks.
##
## A face's line spacing (FontFace.spacing_top/bottom) makes its line box
## English's. Godot adds a FontVariation's spacing in whole pixels whatever the
## size it draws at (checked in 4.7.1), so the wrapper carries the x1 spacing,
## and a slot type at another scale draws through a FontVariation of its own
## over the wrapper with the spacing times its scale. (A variation over a
## variation takes the base's font and fallbacks but only its own spacing.)
##
## World text (the wrappers and the x1/x2 slots, drawn through the 6x
## cameras) rasterizes its bitmap fonts at ScreenFrame.ART_PIXEL_SCALE: Godot
## places a bitmap glyph on its own texel grid, so a font rasterized at x1
## snaps to whole art pixels (a [wave] or a slide steps 6 canvas pixels at a
## time) where one rasterized at x6 moves by canvas pixels, and still draws
## each font pixel as a crisp 6x6 block. Godot's automatic oversampling
## doesn't count a camera's zoom (checked in 4.7.1), and MSDF, which would,
## seams pixel fonts' glyphs, so it's set here on every non-MSDF font a
## profile names (_prepare_world()). The imports keep the value screen-space
## text needs: screen slots (x3 and up, already one canvas pixel per texel)
## draw through copies made before the change (_screen_font()), as x6 there
## would rasterize Chinese body text at 432 px a glyph.

const SMALL: StringName = &"small"
const BODY: StringName = &"body"
const POPUP: StringName = &"popup"
const DIGITS: StringName = &"digits"
const DIGITS_SMALL: StringName = &"digits_small"
const ROLES: Array[StringName] = [SMALL, BODY, POPUP, DIGITS, DIGITS_SMALL]
## The roles only figures are drawn in: their faces need digits, signs and
## % (FIGURE_CHARACTERS), not a language's whole script.
const FIGURE_ROLES: Array[StringName] = [DIGITS, DIGITS_SMALL]
const FIGURE_CHARACTERS: String = "0123456789+-%x"

const _WRAPPERS: Dictionary[StringName, FontVariation] = {
	SMALL: preload("res://Assets/Fonts/Roles/small.tres"),
	BODY: preload("res://Assets/Fonts/Roles/body.tres"),
	POPUP: preload("res://Assets/Fonts/Roles/popup.tres"),
	DIGITS: preload("res://Assets/Fonts/Roles/digits.tres"),
	DIGITS_SMALL: preload("res://Assets/Fonts/Roles/digits_small.tres"),
}

## The slot types a Control names in theme_type_variation: [role, scale].
## Each is a type variation in the project theme (based on Control, so one
## type serves Labels, RichTextLabels and Buttons alike) holding the role's
## wrapper as its font and unit x scale as its size. A whole scale keeps the
## text on the font's pixel grid at that many canvas pixels per font pixel.
## Screen-space UI (the 1920x1080 layers) sits at x6 to match the 6x world.
const SLOT_TYPES: Dictionary[StringName, Array] = {
	&"SmallX2": [SMALL, 2.0],
	&"SmallX6": [SMALL, 6.0],
	&"BodyX1": [BODY, 1.0],
	## The game-over run summary.
	&"BodyX3": [BODY, 3.0],
	## Off the 6x world grid but on the font's own: the info panel's asides.
	&"BodyX4": [BODY, 4.0],
	&"BodyX5": [BODY, 5.0],
	&"BodyX6": [BODY, 6.0],
	&"BodyX11": [BODY, 11.0],
	&"BodyX12": [BODY, 12.0],
	&"BodyX16": [BODY, 16.0],
	&"PopupX1": [POPUP, 1.0],
	&"DigitsX1": [DIGITS, 1.0],
	&"DigitsSmallX1": [DIGITS_SMALL, 1.0],
}

## The theme items a slot type sets: Label and Button read font/font_size,
## RichTextLabel normal_font/normal_font_size.
const _FONT_ITEMS: Array[StringName] = [&"font", &"normal_font"]
const _SIZE_ITEMS: Array[StringName] = [&"font_size", &"normal_font_size"]

## Theme items outside the slot types that are small text at x1.
const _SMALL_THEME_SIZES: Dictionary[StringName, StringName] = {
	&"PopupMenu": &"font_size",
}

## Slot types from this scale up are screen-space text (see SLOT_TYPES):
## they draw through screen copies of their fonts, never the wrappers' world
## oversampling.
const SCREEN_SLOT_MIN_SCALE: float = 3.0

const PROFILE_DIR: String = "res://Assets/Fonts/Profiles/"
const DEFAULT_LOCALE: String = "en"
const _READABLE_PROFILE: String = PROFILE_DIR + "readable.tres"

static var _profile: FontProfile = null
static var _readable: bool = false
## Every profile loaded this session, by path. Holding them keeps their fonts
## alive after a switch: text shaped before it still points at the old
## font's TextServer data, and if that font were freed, the next re-layout of
## such text (before it re-shapes in the new font) would read freed data and
## log 'Parameter "fd" is null' from the TextServer.
static var _loaded: Dictionary[String, FontProfile] = {}
## Per slot type at a scale other than x1, the variation that scales the
## face's line spacing with it. Made when a face first has spacing; while the
## spacing is zero the slot draws through the wrapper itself.
static var _slot_fonts: Dictionary[StringName, FontVariation] = {}
## Fallback fonts wearing a face's spacing (see _spaced), by font and spacing.
## Kept for the session for the same reason as _loaded.
static var _spaced_fonts: Dictionary[String, FontVariation] = {}
## Per world-oversampled font file (by instance id), its copy at the imported
## oversampling, for screen slots. Kept for the session like _loaded.
static var _screen_fonts: Dictionary[int, FontFile] = {}
## Per variation over world-oversampled fonts (by instance id), its rebuild
## over their screen copies.
static var _screen_variations: Dictionary[int, FontVariation] = {}


## The profile for [param locale]: its own file, else its language's (pt for
## pt_PT), else English's.
static func profile_for(locale: String) -> FontProfile:
	for candidate: String in [locale, locale.get_slice("_", 0), DEFAULT_LOCALE]:
		var path: String = PROFILE_DIR + candidate + ".tres"
		if ResourceLoader.exists(path):
			return _load_profile(path)
	return null


## The Readable Font option's faces for the current language (see face()).
static func readable_profile() -> FontProfile:
	var overlay: FontProfile = current_profile().readable
	return overlay if overlay != null else _load_profile(_READABLE_PROFILE)


static func _load_profile(path: String) -> FontProfile:
	if not _loaded.has(path):
		_loaded[path] = load(path) as FontProfile
	return _loaded[path]


## Switches every role to [param locale]'s faces.
static func use_locale(locale: String) -> void:
	use_profile(profile_for(locale))


static func use_profile(profile: FontProfile) -> void:
	_profile = profile
	_apply()


## The profile in use (English's until a language is set).
static func current_profile() -> FontProfile:
	if _profile == null:
		_profile = profile_for(DEFAULT_LOCALE)
	return _profile


static func is_readable() -> bool:
	return _readable


static func set_readable(readable: bool) -> void:
	_readable = readable
	_apply()


## The wrapper [param role]'s text draws through. Hold this, not a font file:
## it follows the language and Readable Font.
static func font(role: StringName) -> Font:
	return _WRAPPERS[role]


## The size [param role] is drawn at for a slot of [param scale]: whole scales
## keep a pixel font on its grid.
static func size(role: StringName, scale: float = 1.0) -> int:
	return roundi(face(role).size * scale)


## The theme type for [param role] at [param scale], for code that builds a
## Label: `label.theme_type_variation = FontRoles.slot(FontRoles.BODY)`. Small
## text at x1 is the theme's default, so it has none (an empty name).
static func slot(role: StringName, scale: float = 1.0) -> StringName:
	if role == SMALL and is_equal_approx(scale, 1.0):
		return &""
	for type: StringName in SLOT_TYPES:
		if SLOT_TYPES[type][0] == role and is_equal_approx(SLOT_TYPES[type][1], scale):
			return type
	push_error("FontRoles: no slot type for %s at x%s; add one to SLOT_TYPES and the theme" % [role, scale])
	return &""


## The unit size (see FontFace.size) of the role [param font] draws, for a
## role's wrapper or a slot type's font; 0 for any other font. Text fitting
## (TextFit) reads it to keep shrunk text on its font's pixel grid.
static func unit_of(font: Font) -> int:
	for role: StringName in ROLES:
		if _WRAPPERS[role] == font:
			return face(role).size
	for type: StringName in _slot_fonts:
		if _slot_fonts[type] == font:
			return face(SLOT_TYPES[type][0]).size
	return 0


## The face [param role] is drawn in now: the language's, under the readable
## one when Readable Font is on.
static func face(role: StringName) -> FontFace:
	var language: FontFace = current_profile().face(role)
	if not _readable:
		return language
	var readable: FontFace = readable_profile().face(role)
	var merged: FontFace = FontFace.new()
	merged.font = readable.font
	merged.size = readable.size
	merged.baseline_offset = readable.baseline_offset
	merged.spacing_top = readable.spacing_top
	merged.spacing_bottom = readable.spacing_bottom
	merged.fallbacks = readable.fallbacks.duplicate()
	# The language's font keeps its own spacing as a fallback, so a line of
	# Chinese under Readable Font is still English's line box.
	merged.fallbacks.append(_spaced(language.font, language.spacing_top, language.spacing_bottom,
		language.baseline_offset))
	merged.fallbacks.append_array(language.fallbacks)
	return merged


## How many pixels a digit of [param role] stands above the baseline at x1,
## read off the glyph outline, so art drawn beside numbers (DamageNumber's cap
## arrow) can centre on them in any language's font.
static func digit_height(role: StringName) -> int:
	var role_face: FontFace = face(role)
	var text_server: TextServer = TextServerManager.get_primary_interface()
	var font_rid: RID = role_face.font.get_rids()[0]
	var glyph: int = text_server.font_get_glyph_index(font_rid, role_face.size, "0".unicode_at(0), 0)
	var contours: Dictionary = text_server.font_get_glyph_contours(font_rid, role_face.size, glyph)
	var top: float = 0.0
	for point: Vector3 in contours.get("points", PackedVector3Array()):
		top = minf(top, point.y)
	return roundi(-top)


## Points every wrapper and slot type at the current faces. Setting only what
## changed keeps a no-op switch from re-laying out every label.
static func _apply() -> void:
	for role: StringName in ROLES:
		var role_face: FontFace = face(role)
		_prepare_world(role_face.font)
		for fallback: Font in role_face.fallbacks:
			_prepare_world(fallback)
		var wrapper: FontVariation = _WRAPPERS[role]
		if wrapper.base_font != role_face.font:
			wrapper.base_font = role_face.font
		if wrapper.fallbacks != role_face.fallbacks:
			wrapper.fallbacks = role_face.fallbacks
		if not is_equal_approx(wrapper.baseline_offset, role_face.baseline_offset):
			wrapper.baseline_offset = role_face.baseline_offset
		if wrapper.spacing_top != role_face.spacing_top:
			wrapper.spacing_top = role_face.spacing_top
		if wrapper.spacing_bottom != role_face.spacing_bottom:
			wrapper.spacing_bottom = role_face.spacing_bottom

	var theme: Theme = ThemeDB.get_project_theme()
	if theme == null:
		return
	var small_size: int = size(SMALL)
	if theme.default_font_size != small_size:
		theme.default_font_size = small_size
	for type: StringName in _SMALL_THEME_SIZES:
		_set_size(theme, _SMALL_THEME_SIZES[type], type, small_size)
	for type: StringName in SLOT_TYPES:
		var role: StringName = SLOT_TYPES[type][0]
		var scale: float = SLOT_TYPES[type][1]
		var slot_size: int = size(role, scale)
		for item: StringName in _SIZE_ITEMS:
			_set_size(theme, item, type, slot_size)
		var slot_font: Font = _slot_font(type, face(role), scale)
		for item: StringName in _FONT_ITEMS:
			if theme.get_font(item, type) != slot_font:
				theme.set_font(item, type, slot_font)


## The font a slot type of [param scale] draws [param role_face] through. A
## world slot uses the role's wrapper, or over it a variation with the face's
## line spacing scaled to the slot; a face with no spacing (every English one)
## uses the wrapper, exactly as the theme file says. A screen slot always has
## its own variation, over screen copies of the face's fonts (see
## _screen_font()).
static func _slot_font(type: StringName, role_face: FontFace, scale: float) -> Font:
	var role: StringName = SLOT_TYPES[type][0]
	var top: int = roundi(role_face.spacing_top * scale)
	var bottom: int = roundi(role_face.spacing_bottom * scale)
	var spaced_fallbacks: bool = role_face.fallbacks.any(_has_spacing)
	var screen: bool = scale >= SCREEN_SLOT_MIN_SCALE
	if not screen and (is_equal_approx(scale, 1.0) or (top == 0 and bottom == 0 and not spaced_fallbacks)):
		return _WRAPPERS[role]
	if not _slot_fonts.has(type):
		_slot_fonts[type] = FontVariation.new()
	var slot_font: FontVariation = _slot_fonts[type]
	var base: Font = _screen_font(role_face.font) if screen else _WRAPPERS[role]
	if slot_font.base_font != base:
		slot_font.base_font = base
	if slot_font.spacing_top != top:
		slot_font.spacing_top = top
	if slot_font.spacing_bottom != bottom:
		slot_font.spacing_bottom = bottom
	# The variation's own, not the wrapper's: only the base font carries over.
	if not is_equal_approx(slot_font.baseline_offset, role_face.baseline_offset):
		slot_font.baseline_offset = role_face.baseline_offset
	# Over the wrapper, an empty list takes the wrapper's fallbacks; a spaced
	# one needs its spacing scaled too, so the slot then lists its own. Over a
	# screen copy there is no wrapper to take them from.
	var fallbacks: Array[Font] = []
	if screen or spaced_fallbacks:
		for fallback: Font in role_face.fallbacks:
			var scaled: Font = _scaled_fallback(fallback, scale)
			fallbacks.append(_screen_font(scaled) if screen else scaled)
	if slot_font.fallbacks != fallbacks:
		slot_font.fallbacks = fallbacks
	return slot_font


## [param font] with a face's line spacing and baseline offset, for use as a
## fallback: a fallback's own font draws with none of the primary's, so a
## language font behind the readable one carries its spacing itself. A font
## with nothing to add is returned as it is.
static func _spaced(font: Font, top: int, bottom: int, offset: float) -> Font:
	if top == 0 and bottom == 0 and is_zero_approx(offset):
		return font
	var key: String = "%d:%d:%d:%s" % [font.get_instance_id(), top, bottom, offset]
	if not _spaced_fonts.has(key):
		var variation: FontVariation = FontVariation.new()
		variation.base_font = font
		variation.spacing_top = top
		variation.spacing_bottom = bottom
		variation.baseline_offset = offset
		_spaced_fonts[key] = variation
	return _spaced_fonts[key]


static func _has_spacing(fallback: Font) -> bool:
	var variation: FontVariation = fallback as FontVariation
	return variation != null and (variation.spacing_top != 0 or variation.spacing_bottom != 0)


## Rasterizes [param font] (and what it's built on) at the world's art pixel
## scale, once, keeping a copy at its imported oversampling for screen slots
## first. MSDF fonts draw at any position and size already and are left be.
static func _prepare_world(font: Font) -> void:
	var variation: FontVariation = font as FontVariation
	if variation != null:
		if variation.base_font != null:
			_prepare_world(variation.base_font)
		for fallback: Font in variation.fallbacks:
			_prepare_world(fallback)
		return
	var file: FontFile = font as FontFile
	if file == null or file.multichannel_signed_distance_field or _screen_fonts.has(file.get_instance_id()):
		return
	_screen_fonts[file.get_instance_id()] = file.duplicate() as FontFile
	file.oversampling = ScreenFrame.ART_PIXEL_SCALE
	for fallback: Font in file.fallbacks:
		_prepare_world(fallback)


## [param font] as screen-space text draws it: its copy at the imported
## oversampling if it was prepared for the world, a variation rebuilt over
## such copies, else the font itself.
static func _screen_font(font: Font) -> Font:
	if font == null:
		return null
	if _screen_fonts.has(font.get_instance_id()):
		return _screen_fonts[font.get_instance_id()]
	var variation: FontVariation = font as FontVariation
	if variation == null:
		return font
	if _screen_variations.has(variation.get_instance_id()):
		return _screen_variations[variation.get_instance_id()]
	var base: Font = _screen_font(variation.base_font)
	var fallbacks: Array[Font] = []
	for fallback: Font in variation.fallbacks:
		fallbacks.append(_screen_font(fallback))
	if base == variation.base_font and fallbacks == variation.fallbacks:
		return font
	var copy: FontVariation = variation.duplicate() as FontVariation
	copy.base_font = base
	copy.fallbacks = fallbacks
	_screen_variations[variation.get_instance_id()] = copy
	return copy


## A spaced fallback (see _spaced) with its spacing times [param scale].
static func _scaled_fallback(fallback: Font, scale: float) -> Font:
	if not _has_spacing(fallback):
		return fallback
	var variation: FontVariation = fallback as FontVariation
	return _spaced(variation.base_font, roundi(variation.spacing_top * scale),
		roundi(variation.spacing_bottom * scale), variation.baseline_offset)


static func _set_size(theme: Theme, item: StringName, type: StringName, value: int) -> void:
	if theme.get_font_size(item, type) != value:
		theme.set_font_size(item, type, value)
