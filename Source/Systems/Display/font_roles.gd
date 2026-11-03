class_name FontRoles
extends RefCounted
## Font roles: every piece of text names a role, never a font file or a raw
## size, and each language decides how its roles look.
##
## Three roles cover the game's text:
## - small: most UI text. The theme's default font, so a Label, Button or
##   RichTextLabel with no font of its own is in this role. m3x6 in English.
## - body: titles, the info panel and world-space readouts. m5x7 in English.
## - popup: the numbers and words that float off ships (DamageNumber).
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
## Readable Font (the accessibility option, see FontSwap) layers the readable
## profile's face over the language's: the readable font leads and the
## language's fonts follow as its fallbacks, so scripts the readable font
## lacks still draw.
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

const SMALL: StringName = &"small"
const BODY: StringName = &"body"
const POPUP: StringName = &"popup"
const ROLES: Array[StringName] = [SMALL, BODY, POPUP]

const _WRAPPERS: Dictionary[StringName, FontVariation] = {
	SMALL: preload("res://Assets/Fonts/Roles/small.tres"),
	BODY: preload("res://Assets/Fonts/Roles/body.tres"),
	POPUP: preload("res://Assets/Fonts/Roles/popup.tres"),
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
	## Off the 6x world grid but on the font's own: the info panel's asides.
	&"BodyX4": [BODY, 4.0],
	&"BodyX5": [BODY, 5.0],
	&"BodyX6": [BODY, 6.0],
	&"BodyX11": [BODY, 11.0],
	&"BodyX12": [BODY, 12.0],
	&"BodyX16": [BODY, 16.0],
	## Off-grid (m5x7 at 52): the game-over run summary, sized to fit its box
	## before roles existed. Snapping it to x3 is a look change for the user.
	&"BodyX3_25": [BODY, 3.25],
	&"PopupX1": [POPUP, 1.0],
}

## The theme items a slot type sets: Label and Button read font/font_size,
## RichTextLabel normal_font/normal_font_size.
const _FONT_ITEMS: Array[StringName] = [&"font", &"normal_font"]
const _SIZE_ITEMS: Array[StringName] = [&"font_size", &"normal_font_size"]

## Theme items outside the slot types that are small text at x1.
const _SMALL_THEME_SIZES: Dictionary[StringName, StringName] = {
	&"PopupMenu": &"font_size",
}

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


## The profile for [param locale]: its own file, else its language's (pt for
## pt_PT), else English's.
static func profile_for(locale: String) -> FontProfile:
	for candidate: String in [locale, locale.get_slice("_", 0), DEFAULT_LOCALE]:
		var path: String = PROFILE_DIR + candidate + ".tres"
		if ResourceLoader.exists(path):
			return _load_profile(path)
	return null


## The Readable Font option's faces (see face()).
static func readable_profile() -> FontProfile:
	return _load_profile(_READABLE_PROFILE)


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
	merged.fallbacks.append_array(language.chain())
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


## The font a slot type of [param scale] draws [param role_face] through: the
## role's wrapper, or over it a variation with the face's line spacing scaled
## to the slot. A face with no spacing (every English one) uses the wrapper,
## exactly as the theme file says.
static func _slot_font(type: StringName, role_face: FontFace, scale: float) -> Font:
	var role: StringName = SLOT_TYPES[type][0]
	var top: int = roundi(role_face.spacing_top * scale)
	var bottom: int = roundi(role_face.spacing_bottom * scale)
	if is_equal_approx(scale, 1.0) or (top == 0 and bottom == 0):
		return _WRAPPERS[role]
	if not _slot_fonts.has(type):
		var variation: FontVariation = FontVariation.new()
		variation.base_font = _WRAPPERS[role]
		_slot_fonts[type] = variation
	var slot_font: FontVariation = _slot_fonts[type]
	if slot_font.spacing_top != top:
		slot_font.spacing_top = top
	if slot_font.spacing_bottom != bottom:
		slot_font.spacing_bottom = bottom
	# The variation's own, not the wrapper's: only the base font carries over.
	if not is_equal_approx(slot_font.baseline_offset, role_face.baseline_offset):
		slot_font.baseline_offset = role_face.baseline_offset
	return slot_font


static func _set_size(theme: Theme, item: StringName, type: StringName, value: int) -> void:
	if theme.get_font_size(item, type) != value:
		theme.set_font_size(item, type, value)
