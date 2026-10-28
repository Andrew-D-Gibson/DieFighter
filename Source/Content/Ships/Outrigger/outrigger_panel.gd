class_name OutriggerPanel
extends Node2D
## Dresses the systems panel for the Outrigger at runtime: the twin-pod panel
## art in place of the default 5x3 one, the sail mast in the hull gap, and the
## pods' running lights. The shared scenes stay untouched.
##
## The Engine Charger has no place here: its tile is removed (the sail does
## its job, see OutriggerSail), and its gauge only shows on the map tab, where
## the default frame still frames it. The EngineCharger node itself keeps
## running, since it owns the drive's resets (cold at the start of a fight,
## full after a win or on a peaceful arrival).

const _PANEL: Texture2D = preload("res://Assets/Textures/Ships/Outrigger/outrigger_panel.png")
const _PANEL_REVEAL: Texture2D = preload("res://Assets/Textures/Ships/Outrigger/outrigger_panel_reveal.png")
## The map tab's frame, recoloured and widened to match the systems panel,
## with a sail emblem where the charger's tile sat.
const _MAP_FRAME: Texture2D = preload("res://Assets/Textures/Ships/Outrigger/outrigger_map_frame.png")
const _CHARGER_FILL: Texture2D = preload("res://Assets/Textures/Ships/Outrigger/charger_fill_sail.png")
const _CHARGER_CHARGED: Texture2D = preload("res://Assets/Textures/Ships/Outrigger/charger_charged_sail.png")
const _MAP_REVEAL: Texture2D = preload("res://Assets/Textures/Ships/Outrigger/outrigger_map_reveal.png")

## The panel is drawn centred on the main viewer's origin.
const _PANEL_CENTRE: Vector2 = Vector2.ZERO
## The mast's slot, top-left, relative to the main viewer.
const _MAST_TOP_LEFT: Vector2 = Vector2(-3, -31)
## The readout badge, relative to the main viewer.
const _BADGE_RECT: Rect2 = Rect2(-12, -45, 24, 13)
## Running lights, relative to the main viewer: port red, starboard green.
const _PORT_LIGHT: Vector2 = Vector2(-84, -33)
const _STARBOARD_LIGHT: Vector2 = Vector2(83, -33)
const _PORT_COLOR: Color = Color("#d03656")
const _STARBOARD_COLOR: Color = Color("#7abd33")

@onready var gauge: SailGauge = %SailGauge

var _viewer: MainViewer
var _systems_frames: SpriteFrames
var _map_frames: SpriteFrames
var _readout: RichTextLabel
var _time: float = 0.0


func _ready() -> void:
	var grid: TileGrid = get_parent().get_parent() as TileGrid
	_viewer = grid.get_parent() as MainViewer if grid else null
	if not _viewer:
		# Not in the game scene (a test building the grid by hand).
		return

	_systems_frames = SpriteFrames.new()
	_systems_frames.add_frame(&"default", _PANEL)
	_map_frames = SpriteFrames.new()
	_map_frames.add_frame(&"default", _MAP_FRAME)

	_retire_engine_charger()
	_restyle_reveal_overlay()
	_place_mast()

	Events.systems_shown.connect(_dress_systems)
	Events.map_shown.connect(_dress_map)
	# MainViewer lights the MAP label purple when the drive can jump. On this
	# hull the tab is orange, so the label goes sail-orange instead. Deferred:
	# MainViewer connects after us and recolours it in the same signal.
	for ready_signal: Signal in [Events.engine_charge_changed, Events.start_scenario,
			Events.combat_finished, Events.start_combat]:
		ready_signal.connect(func() -> void: _retint_map_label.call_deferred())
	if _viewer.screen_showing == MainViewer.ScreenShowing.SYSTEMS:
		_dress_systems()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


## The charger's tile goes: nothing should take a die there, and its socket
## is covered by the starboard pod. Its gauge waits for the map tab, filling
## sail-orange there.
func _retire_engine_charger() -> void:
	var charger: Node2D = _viewer.get_node_or_null("EngineCharger") as Node2D
	if not charger:
		return
	var tile: Node = charger.get_node_or_null("EngineChargerTile")
	if tile:
		tile.queue_free()
	charger.remove_from_group(&"engine_charger")
	gauge.charger = charger
	var bar: TextureProgressBar = charger.get("progress_bar")
	if bar:
		bar.texture_progress = _CHARGER_FILL
	var lit: Sprite2D = charger.get("charged_indicator")
	if lit:
		lit.texture = _CHARGER_CHARGED


## The startup wipes peel a dark cover off each tab's panel; they have to be
## this hull's width or its outer edges show through early.
func _restyle_reveal_overlay() -> void:
	for pair: Array in [["%SystemsRevealOverlay", _PANEL_REVEAL], ["%MapRevealOverlay", _MAP_REVEAL]]:
		var overlay: Sprite2D = _viewer.get_node_or_null(pair[0]) as Sprite2D
		if overlay:
			overlay.texture = pair[1]
			overlay.offset = _panel_offset()


func _place_mast() -> void:
	gauge.global_position = _viewer.global_position + _MAST_TOP_LEFT
	_readout = RichTextLabel.new()
	_readout.bbcode_enabled = true
	_readout.scroll_active = false
	_readout.autowrap_mode = TextServer.AUTOWRAP_OFF
	_readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_readout.size = _BADGE_RECT.size
	_readout.pivot_offset = _BADGE_RECT.size / 2.0
	add_child(_readout)
	_readout.global_position = _viewer.global_position + _BADGE_RECT.position
	gauge.readout = _readout
	gauge.update_readout()


func _dress_systems() -> void:
	_viewer.background.sprite_frames = _systems_frames
	_viewer.background.frame = 0
	_viewer.background.offset = _panel_offset()
	var charger: Node2D = gauge.charger
	if is_instance_valid(charger):
		charger.visible = false


func _dress_map() -> void:
	_viewer.background.sprite_frames = _map_frames
	_viewer.background.frame = 0
	_viewer.background.offset = _panel_offset()
	var charger: Node2D = gauge.charger
	if is_instance_valid(charger):
		charger.visible = true


## The background sits half a pixel left of the viewer's origin to centre the
## default panel's odd width. Ours is even, so it shifts back.
func _panel_offset() -> Vector2:
	return _PANEL_CENTRE - _viewer.background.position


func _draw() -> void:
	if not _viewer:
		return
	# Each light blinks on its own beat, port then starboard, like a hull at
	# anchor: alive, never in sync.
	_draw_light(_PORT_LIGHT, _PORT_COLOR, 0.0)
	_draw_light(_STARBOARD_LIGHT, _STARBOARD_COLOR, 0.9)


func _draw_light(viewer_pos: Vector2, color: Color, phase: float) -> void:
	var beat: float = fmod(_time * 0.6 + phase, 1.8)
	var lit: float = 1.0 if beat < 0.18 else 0.35
	var at: Vector2 = to_local(_viewer.global_position + viewer_pos)
	draw_rect(Rect2(at - Vector2.ONE, Vector2(3, 3)), Color(color, 0.25 * lit))
	draw_rect(Rect2(at, Vector2.ONE), Color(color, 0.5 + 0.5 * lit))


func _retint_map_label() -> void:
	var label: RichTextLabel = _viewer.map_button_label
	if is_instance_valid(label) and label.get_theme_color(&"default_color") == Globals.medium_purple:
		label.add_theme_color_override(&"default_color", Globals.orange)
