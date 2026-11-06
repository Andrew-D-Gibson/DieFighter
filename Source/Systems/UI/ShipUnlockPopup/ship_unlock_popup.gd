class_name ShipUnlockPopup
extends Node2D
## The card that says a ship has been earned for good (ShipUnlocks): the hull
## lands in a flash, light rays turn behind it and sparks stream off it, its
## name and pitch come up underneath, and a beat later the green Close button
## pops in. Shown by EscortKeeper once the escort that earned it has gone.
##
## In world space, like TileUnlockPopup, so the hull is drawn on the same
## pixel grid as everything else, and the rays are drawn into the game's
## 320x180 grid (JuicePixelated) rather than in smooth screen pixels.

signal closed()

## Green, hover text included: carry on, nothing to weigh up.
const _CLOSE_BUTTON: PackedScene = preload("res://Source/Systems/UI/Buttons/medium_green_button.tscn")
const _OPEN_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/upgrade_trigger.tres")
const _POP_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/shop_stock_pop.tres")

const _DIM_COLOR: Color = Color(0.027451, 0.0117647, 0.054902, 0.92)
## The flash the hull lands in: the palette's highlight white.
const _FLASH_COLOR: Color = Color("#cef0f1")
## Where the hull sits, and the rays and sparks come from.
const _SHIP_CENTER: Vector2 = Vector2(160, 54)
const _HEADER_Y: float = 14.0
## The card under the hull, holding its name, pitch and Close.
const _CARD_TOP: float = 84.0
const _CARD_WIDTH: int = 196
const _PANEL_PADDING: Vector2 = Vector2(8, 5)
const _GLITCH_MS: int = 220
## From the hull landing to Close popping in: long enough to take the moment
## in, short enough not to feel held.
const _CLOSE_DELAY: float = 1.1
## The hull idles on its engines, a pixel up and down.
const _BOB_SPEED: float = 2.6
## Spark colours, the palette's warm highlights.
const _SPARK_COLORS: Array[Color] = [Color("#cef0f1"), Color("#eed35d"), Color("#f29c5d"), Color("#ee7f2f")]

var _root: Control
var _dim: ColorRect
var _flash: ColorRect
var _rays: _Rays
var _burst: CPUParticles2D
var _stream: CPUParticles2D
var _header: Label
var _hull: TextureRect
var _hull_holder: Control
var _panel: TileUnlockPopup._Panel
var _column: VBoxContainer
## Placed by the column; the holder inside it takes the pop-in scale.
var _close_row: Control
var _close_holder: Control
var _close_button: Button
var _tween: Tween
var _bob_time: float = 0.0


func _ready() -> void:
	z_index = 40
	set_process(false)
	hide()


func _process(delta: float) -> void:
	_bob_time += delta
	_hull.position.y = roundf(sin(_bob_time * _BOB_SPEED))


## Shows [param ship], just earned.
func open(ship: ShipResource) -> void:
	_build(ship)
	_dim.modulate.a = 0.0
	_header.modulate.a = 0.0
	_panel.modulate.a = 0.0
	_column.modulate.a = 0.0
	_hull_holder.scale = Vector2.ZERO
	_close_holder.scale = Vector2.ZERO
	show()
	_play_in.call_deferred()


func _build(ship: ShipResource) -> void:
	_root = Control.new()
	_root.size = Globals.SCREEN_SIZE
	add_child(_root)

	_dim = ColorRect.new()
	_dim.color = _DIM_COLOR
	_dim.size = Globals.SCREEN_SIZE
	# Swallows clicks so nothing under the card is touched while it's up.
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_dim)

	# Behind the hull, on the game's pixel grid.
	_rays = _Rays.new()
	# Lifted toward the palette's yellow: the ship's own colour alone goes
	# muddy at the rays' low alpha over the dim.
	_rays.color = ship.theme_color.lerp(Globals.yellow, 0.4)
	var pixelated: JuicePixelated = JuicePixelated.spawn(self, _rays, 0)
	pixelated.position = _SHIP_CENTER

	_stream = _sparks(false)
	_burst = _sparks(true)

	_header = _label(tr("SHIP_UNLOCK_HEADER"), 1.0, Globals.yellow)
	_header.position = Vector2(0, _HEADER_Y)
	_header.size.x = Globals.SCREEN_SIZE.x
	add_child(_header)

	# The holder takes the pop-in scale; the hull inside it bobs.
	var texture: Texture2D = ship.get_preview_texture()
	var hull_size: Vector2 = texture.get_size() if texture else Vector2(32, 32)
	_hull_holder = Control.new()
	_hull_holder.size = hull_size
	_hull_holder.pivot_offset = hull_size / 2.0
	_hull_holder.position = (_SHIP_CENTER - hull_size / 2.0).round()
	_hull_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hull_holder)
	_hull = TextureRect.new()
	_hull.texture = texture
	_hull.size = hull_size
	_hull.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hull_holder.add_child(_hull)

	_panel = TileUnlockPopup._Panel.new()
	_panel.outline = ship.theme_color
	add_child(_panel)

	_column = VBoxContainer.new()
	_column.custom_minimum_size.x = _CARD_WIDTH
	_column.add_theme_constant_override("separation", 3)
	add_child(_column)
	_column.add_child(_label(ship.display_name.to_upper(), 2.0, ship.theme_color))
	_column.add_child(_rich_text(Utils.format_text(ship.description), Globals.white))
	_column.add_child(_rich_text(tr("SHIP_UNLOCK_HINT"), Globals.purple))

	# The column resets its children's scale whenever it lays them out, so
	# the button pops inside a holder within the row the column places.
	_close_button = _CLOSE_BUTTON.instantiate()
	_close_row = Control.new()
	_close_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_close_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_column.add_child(_close_row)
	_close_holder = Control.new()
	_close_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_close_row.add_child(_close_holder)
	_close_holder.add_child(_close_button)
	_close_button.set_button_text("SHIP_UNLOCK_CLOSE")
	_close_button.pressed_within_window.connect(_close)
	_close_button.disabled = true

	_flash = ColorRect.new()
	_flash.color = _FLASH_COLOR
	_flash.size = Globals.SCREEN_SIZE
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.modulate.a = 0.0
	add_child(_flash)


## Small text at [param font_scale] (see FontRoles), centred.
func _label(text: String, font_scale: float, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.theme_type_variation = FontRoles.slot(FontRoles.SMALL, font_scale)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _rich_text(text: String, color: Color) -> RichTextLabel:
	var label: RichTextLabel = RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size.x = _CARD_WIDTH
	label.add_theme_color_override("default_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text
	return label


## Art-pixel sparks off the hull: a [param burst] as it lands, otherwise a
## steady stream rising off it for as long as the card is up.
func _sparks(burst: bool) -> CPUParticles2D:
	var sparks: CPUParticles2D = CPUParticles2D.new()
	sparks.position = _SHIP_CENTER
	sparks.texture = _pixel_texture()
	sparks.emitting = false
	sparks.local_coords = false
	sparks.direction = Vector2.UP
	sparks.spread = 180.0
	var colors: Gradient = Gradient.new()
	colors.offsets = PackedFloat32Array()
	colors.colors = PackedColorArray()
	for i: int in _SPARK_COLORS.size():
		colors.add_point(float(i) / (_SPARK_COLORS.size() - 1), _SPARK_COLORS[i])
	sparks.color_initial_ramp = colors
	var fade: Gradient = Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.6, Color.WHITE)
	sparks.color_ramp = fade
	if burst:
		sparks.one_shot = true
		sparks.explosiveness = 1.0
		sparks.amount = 48
		sparks.lifetime = 1.1
		sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		sparks.emission_sphere_radius = 6.0
		sparks.initial_velocity_min = 40.0
		sparks.initial_velocity_max = 95.0
		sparks.damping_min = 50.0
		sparks.damping_max = 80.0
		sparks.gravity = Vector2(0, 14)
	else:
		sparks.amount = 36
		sparks.lifetime = 1.8
		sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
		sparks.emission_sphere_radius = 22.0
		sparks.initial_velocity_min = 6.0
		sparks.initial_velocity_max = 16.0
		sparks.radial_accel_min = 8.0
		sparks.radial_accel_max = 18.0
		sparks.gravity = Vector2(0, -10)
	add_child(sparks)
	return sparks


## One art pixel, white, for the sparks to tint.
static func _pixel_texture() -> Texture2D:
	var image: Image = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)


## Once laid out: the dim comes up, the hull lands in a flash with a burst of
## sparks and a ring, the rays fan out, the text follows, and a beat later
## Close pops in.
func _play_in() -> void:
	_fit_card()
	set_process(true)

	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_dim, "modulate:a", 1.0, 0.25)
	_tween.tween_callback(_land)
	_tween.tween_property(_flash, "modulate:a", 0.75, 0.05)
	_tween.tween_property(_flash, "modulate:a", 0.0, 0.3)
	_tween.parallel().tween_property(_hull_holder, "scale", Vector2.ONE, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_rays, "spread", 1.0, 0.6) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_header, "modulate:a", 1.0, 0.2).set_delay(0.1)
	_tween.tween_property(_panel, "modulate:a", 1.0, 0.15)
	_tween.parallel().tween_property(_column, "modulate:a", 1.0, 0.2)
	_tween.tween_interval(_CLOSE_DELAY - 0.5)
	_tween.tween_callback(Events.play_sound.emit.bind(_POP_SFX))
	_tween.tween_property(_close_holder, "scale", Vector2.ONE, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(func() -> void: _close_button.disabled = false)


## The moment the hull arrives.
func _land() -> void:
	Events.play_sound.emit(_OPEN_SFX)
	Events.glitch_burst.emit(_GLITCH_MS)
	Events.camera_shake_small.emit()
	_rays.ring()
	_burst.restart()
	_stream.emitting = true


func _close() -> void:
	if _tween:
		_tween.kill()
	_close_button.disabled = true
	_stream.emitting = false
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, 0.25)
	_tween.tween_callback(func() -> void:
		hide()
		set_process(false)
		closed.emit()
	)


## Lays the card out under the hull, with room in it for the button.
func _fit_card() -> void:
	_close_row.custom_minimum_size = _close_button.size
	_close_holder.size = _close_button.size
	_close_holder.pivot_offset = _close_button.size / 2.0
	_column.reset_size()
	_column.position = Vector2(roundf((Globals.SCREEN_SIZE.x - _column.size.x) / 2.0), _CARD_TOP)
	var around: Rect2 = Rect2(_column.position, _column.size)
	_panel.box = around.grow_individual(_PANEL_PADDING.x, _PANEL_PADDING.y, _PANEL_PADDING.x, _PANEL_PADDING.y)


## Light rays fanning out from the hull and slowly turning, with a ring that
## rolls out as it lands. Drawn about its own origin, in art pixels.
class _Rays:
	extends Node2D

	const RAY_COUNT: int = 12
	const LENGTH: float = 120.0
	## How much of each ray's slice of the circle it fills.
	const WIDTH_SHARE: float = 0.42
	const TURN_SPEED: float = 0.25
	const RING_SECONDS: float = 0.7
	const RING_RADIUS: float = 90.0

	var color: Color = Color.WHITE
	## 0 folded into the hull, 1 fanned out.
	var spread: float = 0.0
	var _angle: float = 0.0
	var _ring_age: float = -1.0

	func ring() -> void:
		_ring_age = 0.0

	func _process(delta: float) -> void:
		_angle += delta * TURN_SPEED
		if _ring_age >= 0.0:
			_ring_age += delta
			if _ring_age > RING_SECONDS:
				_ring_age = -1.0
		queue_redraw()

	func _draw() -> void:
		var length: float = LENGTH * spread
		if length > 1.0:
			var slice: float = TAU / RAY_COUNT
			var bright: Color = Color(color, 0.6)
			var faint: Color = Color(color, 0.0)
			for i: int in RAY_COUNT:
				var mid: float = _angle + i * slice
				# Every other ray a little shorter and dimmer, so they don't
				# read as a wheel.
				var reach: float = length * (1.0 if i % 2 == 0 else 0.7)
				var half: float = slice * WIDTH_SHARE * 0.5
				var points: PackedVector2Array = PackedVector2Array([
					Vector2.ZERO,
					Vector2.from_angle(mid - half) * reach,
					Vector2.from_angle(mid + half) * reach,
				])
				var tip: Color = faint
				var root: Color = bright if i % 2 == 0 else Color(color, 0.38)
				draw_polygon(points, PackedColorArray([root, tip, tip]))
			# A glow at the hull, so the rays seem to come from inside it.
			for r: int in [26, 18, 11]:
				draw_circle(Vector2.ZERO, r * spread, Color(color, 0.16))
		if _ring_age >= 0.0:
			var t: float = _ring_age / RING_SECONDS
			var radius: float = lerpf(6.0, RING_RADIUS, 1.0 - pow(1.0 - t, 3.0))
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(Color("#cef0f1"), 1.0 - t), 1.0)
