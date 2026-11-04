extends Node2D
## The padlock a Lockout hangs on its tile.
##
## The lock is a blow, so it slams on rather than appearing: it drops in big,
## lands with a squash, a burst of sparks, a ring and a clank, and knocks the
## tile. Its face then counts one pip, two, three: the faces that open it.
## It rattles each time it turns a die away, and pops off when it's opened.

const _LOCK_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/tractor_lock.tres")

## Approved-palette orange ramp, the lock's own colours.
const _LIGHT: Color = Color("#F29C5D")
const _MID: Color = Color("#EE7F2F")
const _DARK: Color = Color("#BD580F")

const _FACE_SECONDS: float = 0.6
const _SLAM_SECONDS: float = 0.2
const _DROP_PIXELS: float = 10.0
const _SLAM_SCALE: float = 2.4

@onready var _sprite: Sprite2D = $Sprite2D

var _host: Node2D
var _face_age: float = 0.0
var _released: bool = false
var _settled: bool = false
var _age: float = 0.0
var _keyword: RichTextLabel
var _tooltip: PanelContainer


func configure(host: Node2D) -> void:
	_host = host


func _ready() -> void:
	_build_keyword()
	_slam_in()


func _process(delta: float) -> void:
	if _released:
		return
	_age += delta
	if _settled:
		# Whole art pixels: a sub-pixel float would smear on the 6x viewport.
		_sprite.position.y = roundf(sin(_age * 2.4) * 1.2)
	queue_redraw()
	if is_instance_valid(_tooltip) and _tooltip.visible:
		var viewport_size: Vector2 = get_viewport_rect().size
		_tooltip.position = (get_viewport().get_mouse_position() + Vector2(24, 24)).clamp(
			Vector2(12, 12), viewport_size - _tooltip.size - Vector2(12, 12))
	_face_age += delta
	if _face_age >= _FACE_SECONDS:
		_face_age -= _FACE_SECONDS
		_sprite.frame = (_sprite.frame + 1) % _sprite.hframes


## The lock turned a die away: it rattles and spits a few sparks.
func on_modifier_triggered() -> void:
	if _released:
		return
	Juice.wiggle(_sprite, 16.0, 0.3)
	_flash(Color(2.0, 1.6, 1.3))
	Juice.sparkle(get_parent(), global_position, _MID, 6, 35.0)


## The lock was opened. Pops up and off, then frees itself. Takes the place
## of the plain free LockoutModifier.on_unregistered would otherwise do.
func release() -> void:
	if _released:
		return
	_released = true
	_keyword.hide()
	_tooltip.hide()
	queue_redraw()
	_sprite.rotation = 0.0
	Juice.sparkle(get_parent(), global_position, Globals.yellow, 12, 55.0, true)
	Juice.ring(get_parent(), global_position, Globals.yellow, 4.0, 0.3, 16.0)
	if is_instance_valid(_host):
		Juice.callout(_host, tr("CALLOUT_UNLOCKED"), Globals.yellow)
	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(_sprite, ^"position:y", -_DROP_PIXELS, 0.3) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_sprite, ^"scale", Vector2(1.4, 1.4), 0.3)
	tween.tween_property(_sprite, ^"modulate:a", 0.0, 0.3)
	tween.chain().tween_callback(queue_free)


func _slam_in() -> void:
	_sprite.scale = Vector2(_SLAM_SCALE, _SLAM_SCALE)
	_sprite.position = Vector2(0.0, -_DROP_PIXELS)
	_sprite.modulate.a = 0.0
	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(_sprite, ^"scale", Vector2.ONE, _SLAM_SECONDS) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_sprite, ^"position", Vector2.ZERO, _SLAM_SECONDS) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_sprite, ^"modulate:a", 1.0, _SLAM_SECONDS * 0.5)
	tween.chain().tween_callback(_land)


func _land() -> void:
	if _released:
		return
	var parent: Node = get_parent()
	Juice.sparkle(parent, global_position, _LIGHT, 14, 75.0)
	Juice.sparkle(parent, global_position, _DARK, 8, 45.0)
	Juice.ring(parent, global_position, _MID, 6.0, 0.35, 22.0)
	Events.play_sound.emit(_LOCK_SFX)
	Events.camera_shake_small.emit()
	if is_instance_valid(_host):
		Juice.bump(Juice.body_of(_host), 0.35, 0.3)
		Juice.callout(_host, tr("CALLOUT_LOCKED"), _LIGHT)
	_flash(Color(2.2, 1.8, 1.5))
	# Squash on impact, then settle.
	_sprite.scale = Vector2(1.35, 0.7)
	var tween: Tween = create_tween()
	tween.tween_property(_sprite, ^"scale", Vector2.ONE, 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void: _settled = true)


## Brightens the lock past white for a moment, then back.
func _flash(peak: Color) -> void:
	var tween: Tween = create_tween()
	_sprite.self_modulate = peak
	tween.tween_property(_sprite, ^"self_modulate", Color.WHITE, 0.18)


func _build_keyword() -> void:
	_keyword = RichTextLabel.new()
	_keyword.name = "LockedKeyword"
	_keyword.position = Vector2(-12, 11)
	_keyword.size = Vector2(24, 7)
	_keyword.bbcode_enabled = true
	_keyword.fit_content = true
	_keyword.scroll_active = false
	_keyword.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_keyword.text = Utils.format_text("[color=orange]%s[/color]" % Keywords.title("locked").to_upper())
	_keyword.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_keyword)
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	_tooltip = PanelContainer.new()
	_tooltip.name = "LockedTooltip"
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("0f0c2e")
	style.set_content_margin_all(18)
	_tooltip.add_theme_stylebox_override("panel", style)
	layer.add_child(_tooltip)
	var rule: RichTextLabel = RichTextLabel.new()
	rule.theme_type_variation = FontRoles.slot(FontRoles.SMALL, 6.0)
	rule.custom_minimum_size.x = 480
	rule.bbcode_enabled = true
	rule.fit_content = true
	rule.scroll_active = false
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.text = Utils.format_text("[color=orange]%s[/color]: %s" % [
		Keywords.title("locked"), Keywords.definition("locked")])
	_tooltip.add_child(rule)
	_tooltip.hide()
	_keyword.mouse_entered.connect(_tooltip.show)
	_keyword.mouse_exited.connect(_tooltip.hide)


## Low, slow wisps make a persistent lock readable without hiding its die faces.
func _draw() -> void:
	if _released or not _settled:
		return
	for i: int in 6:
		var phase: float = fposmod(_age * 0.35 + float(i) / 6.0, 1.0)
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var point: Vector2 = Vector2(side * (10.0 + sin(phase * TAU) * 1.5), 8.0 - phase * 20.0)
		var color: Color = _MID
		color.a = sin(phase * PI) * 0.55
		# One art pixel on the game's grid, not an antialiased sub-pixel dot.
		draw_rect(Rect2(point.floor(), Vector2.ONE), color)
