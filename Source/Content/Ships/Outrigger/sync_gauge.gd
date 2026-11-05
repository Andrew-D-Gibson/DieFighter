class_name SyncGauge
extends Node2D
## The Outrigger's drive gauge, in the 16 px hull gap between its pods: two
## thin thrust columns, port on the left and starboard on the right, rising
## from the bottom of the gap as dice spent in each pod add thrust
## (OutriggerSync). The part both columns share (the lower pod's thrust, what
## ending the turn would charge) is lit in the charge colour; the lead one
## pod has over the other is dimmer. A pip of each column is lit in the level
## colour while the two are exactly level.
##
## During the player's turn in a fight a tag at the top of the gap reads
## "+N", what ending the turn now would add to the drive (to the gate). The
## badge above the gap (built by OutriggerPanel) always reads the charge,
## "x/10".
##
## It is the engine's anchor for juice while the systems tab is up: it takes
## the "engine_charger" group from the hidden EngineCharger, and hands back to
## that gauge's anchor while the map (where the charger still shows) is up.
##
## Drawing is all in local pixels from the gap's top-left; the constants
## below place and colour everything.

## The hull gap the gauge fills, in pixels.
const GAP_SIZE: Vector2i = Vector2i(16, 72)
## Each column's left edge and width.
const _PORT_COLUMN_X: int = 2
const _STARBOARD_COLUMN_X: int = 10
const _COLUMN_WIDTH: int = 4
## A pip of thrust is a segment this tall with a gap above it. The columns
## show at most _PIPS_SHOWN pips, from the bottom of the gap up; past that the
## top segment blinks.
const _PIP_HEIGHT: int = 4
const _PIP_GAP: int = 1
const _PIPS_SHOWN: int = 12
## The "+N" tag, top-left corner, and how long the pips take to catch up.
const _TAG_AT: Vector2i = Vector2i(1, 1)
const _EASE_RATE: float = 10.0
const _OVER_BLINK_HZ: float = 3.0
const _LEVEL_PULSE_HZ: float = 2.0

## Approved palette only.
const _OUTLINE: Color = Color("#040217")
const _TRACK: Color = Color("#130f38")
const _MATCHED: Color = Color("#c552f1")
const _MATCHED_EDGE: Color = Color("#cef0f1")
const _PORT_EXCESS: Color = Color("#80359d")
const _STARBOARD_EXCESS: Color = Color("#80359d")
const _LEVEL: Color = Color("#f29c5d")
const _FLASH: Color = Color("#cef0f1")
const _TAG_FILL: Color = Color("#a846ce")
const _TAG_TEXT: Color = Color("#cef0f1")
const _TAG_EMPTY_FILL: Color = Color("#63605c")
const _TAG_EMPTY_TEXT: Color = Color("#a5a29d")
const _REDLINE_TEXT: String = "#d03656"
const _FULL_TEXT: String = "#f29c5d"
## 3x5 pixel glyphs for the tag, rows top to bottom, bit 2 = left column.
const _GLYPHS: Dictionary[String, Array] = {
	"0": [7, 5, 5, 5, 7], "1": [2, 6, 2, 2, 7], "2": [7, 1, 7, 4, 7],
	"3": [7, 1, 7, 1, 7], "4": [5, 5, 7, 1, 1], "5": [7, 4, 7, 1, 7],
	"6": [7, 4, 7, 5, 7], "7": [7, 1, 1, 1, 1], "8": [7, 5, 7, 5, 7],
	"9": [7, 5, 7, 1, 7], "+": [0, 2, 7, 2, 0],
}

## The charger the gauge stands in for, whose anchor is used on the map tab.
var charger: Node2D = null
## The charge readout in the badge above the gap.
var readout: RichTextLabel = null
## The rules it shows; found in the scene when not set.
var sync: OutriggerSync = null

## Each column's pips as drawn, eased towards the real thrust.
var _shown: Array[float] = [0.0, 0.0]
var _projecting: bool = false
var _flash: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	add_to_group(&"engine_charger")
	Events.player_turn_start.connect(_start_projecting)
	Events.first_turn_start.connect(_start_projecting)
	Events.player_turn_over.connect(_stop_projecting)
	Events.combat_finished.connect(_stop_projecting)
	Events.engine_charge_changed.connect(update_readout)
	Events.start_scenario.connect(update_readout)
	update_readout()


func _process(delta: float) -> void:
	_time += delta
	_flash = maxf(0.0, _flash - delta * 2.5)
	var rules: OutriggerSync = _rules()
	for pod: OutriggerSync.Pod in [OutriggerSync.Pod.PORT, OutriggerSync.Pod.STARBOARD]:
		var target: float = float(rules.thrust(pod)) if rules else 0.0
		_shown[pod] = move_toward(_shown[pod], target, maxf(1.0, absf(target - _shown[pod])) * delta * _EASE_RATE)
	queue_redraw()


## Where effects that move engine charge draw to and from: the charge
## readout above the gap, or the charger's gauge while the map is up.
func get_juice_anchor() -> Vector2:
	if not is_visible_in_tree() and is_instance_valid(charger) and charger.has_method("get_juice_anchor"):
		return charger.get_juice_anchor()
	if is_instance_valid(readout):
		return readout.get_global_rect().get_center()
	return to_global(Vector2(GAP_SIZE.x / 2.0, 0.0))


## The top of [param pod]'s lit column, where a sync's light leaves from.
func get_column_head(pod: OutriggerSync.Pod) -> Vector2:
	var x: int = _PORT_COLUMN_X if pod == OutriggerSync.Pod.PORT else _STARBOARD_COLUMN_X
	var pips: int = mini(roundi(_shown[pod]) if pod != OutriggerSync.Pod.NONE else 0, _PIPS_SHOWN)
	return to_global(Vector2(x + _COLUMN_WIDTH / 2.0, _pip_top(maxi(pips, 1)) + 1))


## The colour of charge on this gauge, for effects that move it.
func charge_color() -> Color:
	return _MATCHED


## A sync's light reached the drive (SyncChargeEvent): the readout flares
## and the gain is called out beside it; a level sync says so too.
func sync_landed(gain: int, level: bool) -> void:
	_flash = 1.0
	var at: Vector2 = get_juice_anchor()
	Juice.ring(self, at, _MATCHED, 14.0, 0.35, 2.0)
	Juice.sparkle(self, at, _MATCHED, 10, 40.0, true)
	Juice.callout_at(self, at + Vector2(18, 0), "+%d" % gain, _MATCHED, true)
	if level:
		Juice.callout_at(self, at + Vector2(-18, 0), tr("CALLOUT_PODS_LEVEL"), _LEVEL, true)
	_celebrate_if_full.call_deferred()


func _celebrate_if_full() -> void:
	# Deferred: the charge event this sync injected resolves just after it.
	await get_tree().create_timer(0.15).timeout
	if not is_inside_tree() or not is_instance_valid(Globals.player) \
	or not Globals.player.is_engine_charged():
		return
	var top: Vector2 = get_juice_anchor()
	Juice.ring(self, top, _FLASH, 22.0, 0.5, 3.0)
	Juice.sparkle(self, top, _LEVEL, 14, 45.0, true)
	if is_instance_valid(readout):
		var pop: Tween = readout.create_tween()
		readout.scale = Vector2(1.4, 1.4)
		pop.tween_property(readout, "scale", Vector2.ONE, 0.4) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Juice.callout_at(self, top + Vector2(0, -14), tr("CALLOUT_DRIVE_FULL"), Globals.yellow, true)
	Events.camera_shake_small.emit()


func _start_projecting() -> void:
	_projecting = true


func _stop_projecting() -> void:
	_projecting = false


## Rewrites the charge in the badge above the gap. Also called once the
## cockpit has built the badge (OutriggerPanel).
func update_readout() -> void:
	if not is_instance_valid(readout) or not is_instance_valid(Globals.player):
		return
	var player: Player = Globals.player
	if player.is_overcharged():
		readout.text = "[color=%s]%d+%d[/color]" % [_REDLINE_TEXT, player.max_engine_charge, player.overcharge_amount()]
	elif player.is_engine_charged():
		readout.text = "[color=%s]%d/%d[/color]" % [_FULL_TEXT, player.engine_charge, player.max_engine_charge]
	else:
		readout.text = "%d/%d" % [player.engine_charge, player.max_engine_charge]


func _rules() -> OutriggerSync:
	if not is_instance_valid(sync) and is_inside_tree():
		sync = OutriggerSync.active(get_tree())
	return sync


## The y of the top row of pip [param pip] (1 = the bottom one).
func _pip_top(pip: int) -> int:
	return GAP_SIZE.y - pip * (_PIP_HEIGHT + _PIP_GAP) + _PIP_GAP


func _draw() -> void:
	var rules: OutriggerSync = _rules()
	if rules == null:
		return
	var port: int = roundi(_shown[OutriggerSync.Pod.PORT])
	var starboard: int = roundi(_shown[OutriggerSync.Pod.STARBOARD])
	var matched: int = mini(port, starboard)
	var level: bool = OutriggerSync.is_level(rules.thrust(OutriggerSync.Pod.PORT),
		rules.thrust(OutriggerSync.Pod.STARBOARD))
	_draw_column(_PORT_COLUMN_X, port, matched, _PORT_EXCESS, level)
	_draw_column(_STARBOARD_COLUMN_X, starboard, matched, _STARBOARD_EXCESS, level)
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, GAP_SIZE), Color(_FLASH, 0.18 * _flash))
	if _projecting and OutriggerSync.is_in_play():
		_draw_tag(rules.projected_gain())


## One pod's column: empty pip slots up the gap, the first [param matched]
## pips lit as charge, the rest of [param pips] in [param excess].
func _draw_column(x: int, pips: int, matched: int, excess: Color, level: bool) -> void:
	var over: bool = pips > _PIPS_SHOWN
	var blink_off: bool = over and fmod(_time * _OVER_BLINK_HZ, 1.0) < 0.5
	var pulse: float = 0.5 + 0.5 * sin(_time * TAU * _LEVEL_PULSE_HZ)
	for pip: int in range(1, _PIPS_SHOWN + 1):
		var rect: Rect2 = Rect2(x, _pip_top(pip), _COLUMN_WIDTH, _PIP_HEIGHT)
		draw_rect(rect.grow(1), _OUTLINE)
		var color: Color = _TRACK
		if pip <= matched:
			color = _MATCHED
		elif pip <= pips:
			color = excess
		if pip == _PIPS_SHOWN and blink_off:
			color = _TRACK
		draw_rect(rect, color)
		# The head of the shared part: a bright edge, gold while level.
		if pip == mini(matched, _PIPS_SHOWN) and matched > 0:
			var edge: Color = _MATCHED_EDGE.lerp(_LEVEL, pulse) if level else _MATCHED_EDGE
			draw_rect(Rect2(x, _pip_top(pip), _COLUMN_WIDTH, 1), edge)
		if color != _TRACK:
			draw_rect(rect, Color(_FLASH, 0.5 * _flash))


## The "+N" tag: what ending the turn now would add to the drive. Grey when
## it would add nothing.
func _draw_tag(gain: int) -> void:
	var text: String = "+%d" % gain
	var width: int = text.length() * 4 + 1
	var at: Vector2 = Vector2(roundi((GAP_SIZE.x - width) / 2.0), _TAG_AT.y)
	var fill: Color = _TAG_FILL if gain > 0 else _TAG_EMPTY_FILL
	var ink: Color = _TAG_TEXT if gain > 0 else _TAG_EMPTY_TEXT
	draw_rect(Rect2(at - Vector2.ONE, Vector2(width + 2, 9)), _OUTLINE)
	draw_rect(Rect2(at, Vector2(width, 7)), fill)
	for i: int in text.length():
		_draw_glyph(text[i], at + Vector2(1 + i * 4, 1), ink)


func _draw_glyph(glyph: String, at: Vector2, color: Color) -> void:
	var rows: Array = _GLYPHS.get(glyph, [])
	for row: int in rows.size():
		for column: int in 3:
			if int(rows[row]) & (4 >> column):
				draw_rect(Rect2(at + Vector2(column, row), Vector2.ONE), color)
