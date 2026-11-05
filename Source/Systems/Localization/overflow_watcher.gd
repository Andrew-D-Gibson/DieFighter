class_name OverflowWatcher
extends Node
## Debug builds only: catches text that doesn't fit, in whatever language is
## showing, while the game is played normally.
##
## Every half second it looks over the visible Labels and RichTextLabels and
## flags any whose text runs past its box (taller than the box, or wider with
## no wrapping), any spilling out of the side of the button or panel it sits
## in, any on a button that a neighbouring button overlaps (tabs grown past
## the room they share), any cut off by the edge of the screen, any left with
## characters hidden (a typewriter stuck short of the end), and any whose font
## has no glyph for a character it shows. A
## flagged label gets a red outline on screen and one line in debug_log.txt
## with its node path and, where it can be found, the translation key, so a
## translation that only breaks three screens deep still gets noticed.
##
## The localization audit (Source/Debug/LocAudit) calls inspect() and scan()
## itself, on the screens it forces into view.

## The kinds of problem, as written in the log and the audit report.
const HEIGHT: String = "overflow_height"
const WIDTH: String = "overflow_width"
const HIDDEN_CHARACTERS: String = "characters_hidden"
const MISSING_GLYPHS: String = "missing_glyphs"
const OFF_SCREEN: String = "off_screen"
const OUTSIDE_PARENT: String = "outside_parent"
const OVERLAP: String = "overlap"
## Fitted text (TextFitter, TextFitBox) that overflows its box even at its
## policy's smallest scale: it needs a bigger box or a shorter translation.
const FIT_FAILED: String = "fit_failed"
## A fitted label wrapping onto more or fewer lines than its fit measured:
## TextFit and Godot's own line breaking disagree, and the fit is wrong.
const FIT_MISMATCH: String = "fit_mismatch"
## Smart wrapping split a word too long for its line.
const WORD_BROKEN: String = "word_broken"
## Wrapped lines whose glyphs draw into each other.
const LINES_COLLIDE: String = "lines_collide"

## Set on a label to leave it out (a deliberately clipped ticker, say).
const IGNORE_META: StringName = &"loc_watch_ignore"
## Set on a label to name the key its text came from, when the text was built
## in code and can't be traced back to one.
const KEY_META: StringName = &"loc_key"

const _OUTLINE_NAME: StringName = &"LocOverflowOutline"
const _OUTLINE_COLOR: Color = Color(1.0, 0.1, 0.15)
## On-screen thickness of the outline, whatever scale the label is drawn at.
const _OUTLINE_SCREEN_PIXELS: float = 3.0
const _SCAN_SECONDS: float = 0.5
## A typewriter mid-line hides characters on purpose. Only one that hasn't
## moved for this long is stuck.
const _STALLED_SECONDS: float = 2.0
## Half a pixel of slack: layouts round.
const _SLACK: float = 0.5
## A single line's box is often a pixel shorter than the font's line height,
## which clips only the empty space under the letters. More than this is
## letters being cut.
const _HEIGHT_SLACK: float = 1.5
## Below this much opacity (its own and its parents' together) a label can't
## be read, so whatever it does isn't a problem yet: a menu fading in.
const _MIN_VISIBLE_ALPHA: float = 0.05

## Whether the half-second scan runs. The audit turns it off and scans when it
## has posed each screen.
var live: bool = true

var _elapsed: float = 0.0
## Flags already logged, so a label that stays broken is reported once.
var _logged: Dictionary[String, bool] = {}
## Labels outlined right now, by instance id.
var _outlined: Dictionary[int, Control] = {}
## instance id -> [visible_characters, msec first seen at that count].
var _typing: Dictionary[int, Array] = {}
## instance id -> where the label's box was on screen at the last live scan.
## One that has moved since is sliding or popping in, and its place against
## the screen edge or its neighbours means nothing until it stops.
var _last_rects: Dictionary[int, Rect2] = {}
## Shown text -> key, for the current locale. Rebuilt when it changes.
var _reverse_keys: Dictionary[String, String] = {}
var _reverse_locale: String = ""


func _process(delta: float) -> void:
	if not live:
		return
	_elapsed += delta
	if _elapsed < _SCAN_SECONDS:
		return
	_elapsed = 0.0
	scan(get_tree().root, true)


## Checks every visible label under [param root], outlines the ones with a
## problem (and clears outlines that no longer apply), and returns a record
## per flagged label: {path, key, text, problems: [{kind, detail}]}.
## [param log_new] writes each new flag to the debug log.
func scan(root: Node, log_new: bool = false) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var still_flagged: Dictionary[int, bool] = {}
	var labels: Array[Control] = _visible_labels(root)
	var overlaps: Dictionary[int, String] = _overlapping_buttons(labels)
	# The audit poses still screens; only the live scan sees things move.
	var moving: Dictionary[int, bool] = {}
	if live:
		moving = _moving(labels)
	for control: Control in labels:
		var problems: Array[Dictionary] = inspect(control)
		var settled: bool = not moving.has(control.get_instance_id())
		if overlaps.has(control.get_instance_id()) and settled:
			problems.append({"kind": OVERLAP, "detail": overlaps[control.get_instance_id()]})
		if not control.has_meta(IGNORE_META) and settled:
			problems.append_array(_inspect_parent_box(control))
			problems.append_array(_inspect_screen_edge(control))
		problems = problems.filter(func(problem: Dictionary) -> bool:
			return problem["kind"] != HIDDEN_CHARACTERS or _stalled(control))
		if problems.is_empty():
			continue
		var record: Dictionary = {
			"path": str(control.get_path()),
			"key": key_of(control),
			"text": shown_text(control),
			"problems": problems,
		}
		found.append(record)
		still_flagged[control.get_instance_id()] = true
		_outline(control)
		if log_new:
			_log_once(record)
	for id: int in _outlined.keys():
		if not still_flagged.has(id):
			var control: Control = _outlined[id]
			if is_instance_valid(control):
				_remove_outline(control)
			_outlined.erase(id)
	return found


## The labels among [param labels] whose box has moved on screen since the
## last call, by instance id, and remembers where each is now.
func _moving(labels: Array[Control]) -> Dictionary[int, bool]:
	var moving: Dictionary[int, bool] = {}
	var now: Dictionary[int, Rect2] = {}
	for control: Control in labels:
		var id: int = control.get_instance_id()
		now[id] = control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)
		if not _last_rects.has(id) or not _last_rects[id].is_equal_approx(now[id]):
			moving[id] = true
	_last_rects = now
	return moving


## Removes every outline this watcher drew.
func clear_outlines() -> void:
	for control: Control in _outlined.values():
		if is_instance_valid(control):
			_remove_outline(control)
	_outlined.clear()


## What's wrong with [param control]'s text as laid out right now: a list of
## {kind, detail}, empty when it fits. Characters hidden by visible_characters
## are reported as found; scan() only counts them once they've stalled.
static func inspect(control: Control) -> Array[Dictionary]:
	var problems: Array[Dictionary] = []
	if control.has_meta(IGNORE_META):
		return problems
	var text: String = shown_text(control)
	if text.strip_edges().is_empty():
		return problems
	var fit: TextFit.Result = TextFit.result_of(control)
	if fit != null:
		# A fitted label is sized and placed by its fitter: the one question
		# is whether the fit worked.
		if not fit.fits:
			problems.append({"kind": FIT_FAILED, "detail": fit.describe()})
		var lines: int = int(control.call(&"get_line_count"))
		if fit.line_count > 0 and lines != fit.line_count:
			problems.append({"kind": FIT_MISMATCH, "detail": "%d lines drawn, %d measured" % [lines, fit.line_count]})
	else:
		if control is RichTextLabel:
			_inspect_rich(control as RichTextLabel, problems)
		elif control is Label:
			_inspect_label(control as Label, text, problems)
		if TextFit.breaks_words(control):
			problems.append({"kind": WORD_BROKEN, "detail": "a word wider than its %d px line" % floori(control.size.x)})
		if TextFit.lines_collide(control):
			problems.append({"kind": LINES_COLLIDE, "detail": "line spacing %d" % control.get_theme_constant(
				&"line_separation" if control is RichTextLabel else &"line_spacing")})
	var missing: String = missing_glyphs(text, _font_of(control))
	if not missing.is_empty():
		problems.append({"kind": MISSING_GLYPHS, "detail": missing})
	return problems


## The text [param control] puts on screen: a Label's translated text, a
## RichTextLabel's text without its tags.
static func shown_text(control: Control) -> String:
	if control is RichTextLabel:
		return (control as RichTextLabel).get_parsed_text()
	if control is Label:
		var label: Label = control as Label
		var text: String = label.atr(label.text)
		return text.to_upper() if label.uppercase else text
	return ""


## The characters of [param text] that [param font] (fallbacks included) has
## no glyph for, each listed once, in order. Whitespace and control characters
## don't count, nor the placeholder a RichTextLabel shows for an inline image.
static func missing_glyphs(text: String, font: Font) -> String:
	if font == null:
		return ""
	var missing: String = ""
	for i: int in range(text.length()):
		var code: int = text.unicode_at(i)
		if code < 0x20 or code == 0xFFFC or char(code).strip_edges().is_empty():
			continue
		if not font.has_char(code) and not missing.contains(char(code)):
			missing += char(code)
	return missing


## The translation key [param control]'s text came from, or "" if it can't be
## told: the label's own key (auto-translated Labels hold it as their text),
## one named in its loc_key meta, or the key whose translation is exactly
## what it shows.
func key_of(control: Control) -> String:
	if control.has_meta(KEY_META):
		return str(control.get_meta(KEY_META))
	if control is Label:
		var raw: String = (control as Label).text
		if TranslationServer.get_translation_object("en") \
				and TranslationServer.get_translation_object("en").get_message(raw) != &"":
			return raw
	return _reverse_lookup(shown_text(control))


static func _inspect_label(label: Label, text: String, problems: Array[Dictionary]) -> void:
	var lines: int = label.get_line_count()
	var visible_lines: int = label.get_visible_line_count()
	if visible_lines < lines:
		problems.append({"kind": HEIGHT, "detail": "%d of %d lines shown" % [visible_lines, lines]})
	if label.autowrap_mode == TextServer.AUTOWRAP_OFF:
		var font: Font = _font_of(label)
		if font:
			var font_size: int = label.get_theme_font_size(&"font_size")
			var widest: float = 0.0
			for line: String in text.split("\n"):
				widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
			if widest > label.size.x + _SLACK:
				problems.append({"kind": WIDTH, "detail": "%d px in %d" % [ceili(widest), floori(label.size.x)]})
	var total: int = label.get_total_character_count()
	if label.visible_characters >= 0 and label.visible_characters < total:
		problems.append({"kind": HIDDEN_CHARACTERS, "detail": "%d of %d" % [label.visible_characters, total]})


static func _inspect_rich(label: RichTextLabel, problems: Array[Dictionary]) -> void:
	# fit_content grows the box to the text, so only a box held smaller by
	# its container or its own size can clip. A scrolling one that shows its
	# scrollbar is meant to.
	var height: float = label.get_content_height()
	var scrolls: bool = label.scroll_active and label.get_v_scroll_bar().visible
	if height > label.size.y + _HEIGHT_SLACK and not scrolls:
		problems.append({"kind": HEIGHT, "detail": "%d px in %d" % [ceili(height), floori(label.size.y)]})
	if label.autowrap_mode == TextServer.AUTOWRAP_OFF:
		var width: float = label.get_content_width()
		if width > label.size.x + _SLACK:
			problems.append({"kind": WIDTH, "detail": "%d px in %d" % [ceili(width), floori(label.size.x)]})
	var total: int = label.get_total_character_count()
	if label.visible_characters >= 0 and label.visible_characters < total:
		problems.append({"kind": HIDDEN_CHARACTERS, "detail": "%d of %d" % [label.visible_characters, total]})


## A label whose text reaches out of the button or panel it's written on, as
## a tab title longer than its tab does, or a Chinese one taller than it.
## Only those frames: a label under a bare Control or a container is placed,
## not framed. A fitted label's fitter answers for it (FIT_FAILED).
static func _inspect_parent_box(control: Control) -> Array[Dictionary]:
	var problems: Array[Dictionary] = []
	var frame: Control = control.get_parent() as Control
	if frame == null or frame.size.x <= 0.0 or frame.size.y <= 0.0 or TextFit.fitter_of(control) != null:
		return problems
	if not (frame is BaseButton or frame is Panel or frame is PanelContainer or frame is NinePatchRect):
		return problems
	var rect: Rect2 = control.get_transform() * _text_rect(control)
	if rect.position.x < -_SLACK or rect.end.x > frame.size.x + _SLACK:
		problems.append({"kind": OUTSIDE_PARENT, "detail": "%s in %s %s" % [
			Rect2i(rect), frame.get_class(), Vector2i(frame.size)]})
		return problems
	# Up and down by the glyphs' ink, not the line box: a line box is
	# routinely a pixel or two taller than the button's art, which clips
	# nothing, but ink over the edge draws on the frame.
	var ink: Rect2 = control.get_transform() * TextFit.laid_out_ink(control)
	if ink.position.y < -_HEIGHT_SLACK or ink.end.y > frame.size.y + _HEIGHT_SLACK:
		problems.append({"kind": OUTSIDE_PARENT, "detail": "ink %s in %s %s" % [
			Rect2i(ink), frame.get_class(), Vector2i(frame.size)]})
	return problems


## Labels on buttons that overlap a sibling button, by instance id, with the
## other button's text.
static func _overlapping_buttons(labels: Array[Control]) -> Dictionary[int, String]:
	var overlaps: Dictionary[int, String] = {}
	var by_row: Dictionary[int, Array] = {}
	for label: Control in labels:
		var button: BaseButton = label.get_parent() as BaseButton
		if button and button.get_parent():
			var row: int = button.get_parent().get_instance_id()
			if not by_row.has(row):
				by_row[row] = []
			by_row[row].append(label)
	for row: Array in by_row.values():
		for i: int in range(row.size()):
			for j: int in range(i + 1, row.size()):
				var a: Control = row[i]
				var b: Control = row[j]
				var shared: Rect2 = (a.get_parent() as Control).get_rect() \
					.intersection((b.get_parent() as Control).get_rect())
				if shared.size.x > 1.0 and shared.size.y > 1.0:
					overlaps[a.get_instance_id()] = "overlaps \"%s\"" % shown_text(b)
					overlaps[b.get_instance_id()] = "overlaps \"%s\"" % shown_text(a)
	return overlaps


## A label whose text reaches past the edge of the screen it's on. One wholly
## off it is parked there on purpose, waiting to slide in.
static func _inspect_screen_edge(control: Control) -> Array[Dictionary]:
	var problems: Array[Dictionary] = []
	var viewport: Viewport = control.get_viewport()
	if viewport == null:
		return problems
	var screen: Rect2 = viewport.get_visible_rect()
	var rect: Rect2 = control.get_global_transform_with_canvas() * _text_rect(control)
	# Scrolled out of its ScrollContainer, it's hidden, not cut off.
	var scroll: Control = _scroll_container_of(control)
	if scroll != null:
		var shown: Rect2 = scroll.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, scroll.size)
		if not rect.intersects(shown):
			return problems
		rect = rect.intersection(shown)
	if rect.intersects(screen) and not screen.grow(_SLACK).encloses(rect):
		problems.append({"kind": OFF_SCREEN, "detail": "%s on a %s screen" % [Rect2i(rect), Vector2i(screen.size)]})
	return problems


static func _scroll_container_of(control: Control) -> Control:
	var node: Node = control.get_parent()
	while node is Control:
		if node is ScrollContainer:
			return node as Control
		node = node.get_parent()
	return null


## Where in its box [param control]'s text actually draws: a box wider or
## taller than its text only matters where the text is.
static func _text_rect(control: Control) -> Rect2:
	var text_size: Vector2 = control.size
	if control is RichTextLabel:
		var rich: RichTextLabel = control as RichTextLabel
		text_size = Vector2(rich.get_content_width(), rich.get_content_height())
	elif control is Label:
		var label: Label = control as Label
		var font: Font = _font_of(label)
		if font:
			var font_size: int = label.get_theme_font_size(&"font_size")
			var widest: float = 0.0
			for line: String in shown_text(label).split("\n"):
				widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
			text_size = Vector2(widest, label.get_line_count() * label.get_line_height())
	text_size = text_size.min(control.size)
	var spare: Vector2 = control.size - text_size
	var horizontal: int = control.get("horizontal_alignment")
	var vertical: int = control.get("vertical_alignment")
	var offset: Vector2 = Vector2(
		spare.x / 2.0 if horizontal == HORIZONTAL_ALIGNMENT_CENTER else (spare.x if horizontal == HORIZONTAL_ALIGNMENT_RIGHT else 0.0),
		spare.y / 2.0 if vertical == VERTICAL_ALIGNMENT_CENTER else (spare.y if vertical == VERTICAL_ALIGNMENT_BOTTOM else 0.0))
	return Rect2(offset, text_size)


static func _font_of(control: Control) -> Font:
	if control is RichTextLabel:
		return control.get_theme_font(&"normal_font")
	return control.get_theme_font(&"font")


static func _visible_labels(root: Node) -> Array[Control]:
	var labels: Array[Control] = []
	var candidates: Array[Node] = [root]
	for type: String in ["Label", "RichTextLabel"]:
		candidates.append_array(root.find_children("*", type, true, false))
	for node: Node in candidates:
		if node is Label or node is RichTextLabel:
			var control: Control = node as Control
			if control.is_visible_in_tree() and control.size.x > 0.0 \
					and _opacity(control) >= _MIN_VISIBLE_ALPHA:
				labels.append(control)
	return labels


## How opaque [param control] draws: its own modulates times its parents',
## up to the canvas layer it's on.
static func _opacity(control: Control) -> float:
	var alpha: float = control.self_modulate.a
	var item: Node = control
	while item is CanvasItem:
		alpha *= (item as CanvasItem).modulate.a
		if (item as CanvasItem).top_level:
			break
		item = item.get_parent()
	return alpha


## True once [param control]'s visible_characters has sat at the same count
## for _STALLED_SECONDS.
func _stalled(control: Control) -> bool:
	var id: int = control.get_instance_id()
	var count: int = control.get("visible_characters")
	var now: int = Time.get_ticks_msec()
	var seen: Array = _typing.get(id, [])
	if seen.is_empty() or int(seen[0]) != count:
		_typing[id] = [count, now]
		return not live	# the audit poses finished screens: no waiting
	return now - int(seen[1]) >= int(_STALLED_SECONDS * 1000.0)


func _outline(control: Control) -> void:
	_outlined[control.get_instance_id()] = control
	var outline: ReferenceRect = control.get_node_or_null(NodePath(_OUTLINE_NAME)) as ReferenceRect
	if outline == null:
		outline = ReferenceRect.new()
		outline.name = _OUTLINE_NAME
		outline.editor_only = false
		outline.border_color = _OUTLINE_COLOR
		outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		outline.set_anchors_preset(Control.PRESET_FULL_RECT)
		# Internal, so code walking the label's children never meets it.
		control.add_child(outline, false, Node.INTERNAL_MODE_BACK)
	var scale: float = absf(control.get_global_transform_with_canvas().get_scale().x)
	outline.border_width = _OUTLINE_SCREEN_PIXELS / maxf(scale, 0.01)


static func _remove_outline(control: Control) -> void:
	var outline: Node = control.get_node_or_null(NodePath(_OUTLINE_NAME))
	if outline:
		outline.queue_free()


func _log_once(record: Dictionary) -> void:
	var kinds: Array[String] = []
	for problem: Dictionary in record["problems"]:
		kinds.append("%s (%s)" % [problem["kind"], problem["detail"]])
	var signature: String = "%s|%s|%s" % [record["path"], ",".join(kinds), str(record["text"]).hash()]
	if _logged.has(signature):
		return
	_logged[signature] = true
	var line: String = "Loc [%s] %s: %s key=%s \"%s\"" % [
		TranslationServer.get_locale(), ", ".join(kinds), record["path"],
		record["key"] if record["key"] != "" else "?",
		str(record["text"]).replace("\n", " ").left(60),
	]
	DebugLogger.note(line)


func _reverse_lookup(shown: String) -> String:
	var locale: String = TranslationServer.get_locale()
	if locale != _reverse_locale:
		_reverse_locale = locale
		_reverse_keys.clear()
		for translation_locale: String in ["en", locale]:
			var translation: Translation = TranslationServer.get_translation_object(translation_locale)
			if translation == null:
				continue
			for key: StringName in translation.get_message_list():
				_reverse_keys[str(TranslationServer.translate(key))] = str(key)
	return _reverse_keys.get(shown, "")
