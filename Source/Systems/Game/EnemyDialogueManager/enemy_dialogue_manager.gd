class_name EnemyDialogueManager
extends Node2D
## A ship's speech bubble: a box sized to its line, with a tail pointing back
## at the ship, kept on screen and clear of the other ships' bubbles.
##
## The box art is one picture per faction: a box, symmetric left to right,
## with its tail on the middle of its left edge. It's drawn in pieces (see
## _draw()) so the box can stretch to fit any line while the tail and the
## rounded corners keep their pixels.

## How close the box may come to the edge of the screen.
const _SCREEN_MARGIN: float = 4.0

## Where the pieces are in the box art. The box starts this far right of the
## tail's tip...
const _ART_BOX_LEFT: int = 8
## ...its rounded corners and three-pixel border take this many pixels in
## from each edge...
const _ART_CORNER: int = 4
## ...this column and row hold nothing but plain box, to stretch...
const _ART_FILL: Vector2i = Vector2i(40, 10)
## ...and the tail, laid over the box's left edge, is this.
const _ART_TAIL: Rect2i = Rect2i(0, 16, 11, 16)
## Where the tail's tip sits, relative to this node: the point the box speaks
## from, which [member anchor] puts beside the ship.
const _TAIL_TIP: Vector2 = Vector2(-2, 0)

## Room between the text and the box's edge, the border included.
const _TEXT_PADDING: Vector2 = Vector2(5, 6)
## The smallest box: tall enough for the tail to meet a straight edge.
const _MIN_BOX_SIZE: Vector2 = Vector2(32, 24)
## How far in from the box's top or bottom the tail must stay, so it joins a
## straight stretch of edge rather than a rounded corner.
const _TAIL_INSET: float = 8.0 + _ART_CORNER
## A line wraps onto at most this many lines before it shrinks.
const _MAX_LINES: int = 6

const _TEXT_BLIP_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/text_blip.tres")

## A line has started showing, fresh or replayed. The targeting computer's
## comms lamp listens for it.
signal line_shown()
## A line has run its course and starts to fade, fresh or replayed (not one
## cut off by the next line or a jump). The comms lamp's first-time pulse
## waits for it: that's when the player can first ask for the line again.
signal line_finished()
## The box has gone from beside the ship: folded into [member stow_point]
## ([param stowed]), or faded where it was. The comms badge comes back then.
signal put_away(stowed: bool)

@export var character_reveal_time: float = 0.08

var current_dialogue: String
var character_reveal_tween: Tween
var fade_tween: Tween
var fade_time: float = 1

## A line wider than this, in art pixels, wraps, and the box grows taller
## instead: a wide box would crowd the ships beside this one.
@export var max_text_width: float = 72.0

var red_dialogue_box: Texture2D = preload("uid://dt1r6m0xqqoe7")
var green_dialogue_box: Texture2D = preload("uid://csw1kfx56jn5i")
var yellow_dialogue_box: Texture2D = preload("uid://dttgyiiq0jp7y")

var faction_textures: Dictionary[ScenarioManager.Faction, Texture2D] = {
	ScenarioManager.Faction.CIVILIAN: green_dialogue_box,
	ScenarioManager.Faction.PIRATE: red_dialogue_box,
	ScenarioManager.Faction.BOSS: red_dialogue_box,
}

static var time_last_dialogue_was_shown: int
@export var time_between_dialogues: float = 3

var fadeout_timer: Timer
@export var dialogue_time_shown: float = 4

## Where the box sits relative to the ship, as authored: on the ship's right.
var anchor: Vector2 = Vector2.ZERO:
	set(value):
		anchor = value
		_apply_side()

## How much further out than [member anchor] the box sits, room permitting,
## to clear what else hangs off that side of the ship: the health bar on its
## left, the dice it's holding on its right.
@export var left_clearance: float = 16.0
@export var right_clearance: float = 14.0

## How far the box may tuck in toward the ship, past [member anchor], when it
## would otherwise run out of room: off the screen edge or into a neighbour's
## speech. Its tail then overlaps the hull a little, which reads better than
## a box jammed against the edge of the screen.
@export var max_tuck: float = 8.0

## Whether the box is on the ship's left, mirrored so its tail still points
## back at the ship: the side [EnemyManager] asked for (see [method point]),
## unless only the other side has room for this line.
var points_left: bool = false

## The side [EnemyManager] asked for, and how far a box can reach to the
## ship's left (x) and right (y) before running into something. Infinite
## until it asks: the screen's edges stand in.
var _prefers_left: bool = false
var _room: Vector2 = Vector2(INF, INF)

## The box art for the current line's faction.
var _box_texture: Texture2D
## The box, sized to the current line (see [method _fit_text]).
var _box_size: Vector2 = _MIN_BOX_SIZE
## Where the label sits from the box's top-left, as the fit placed it.
var _text_offset: Vector2 = Vector2.ZERO
## How far the box has slid up or down past its tail, to stay on screen or
## clear of a neighbour's bubble while the tail still points at the ship.
var _box_dy: float = 0.0

## How far past [member anchor] the box currently sits; negative when it is
## tucked in. See [member left_clearance] and [member max_tuck].
var _shift: float = 0.0

## Set once the player jumps away from this ship; it never speaks again.
var _silenced: bool = false

## The last thing this ship said, untranslated, and the box it said it in, so
## the player can hail it for a line that faded before they read it. See
## replay_last_line().
var _last_line: String = ""
var _last_faction: ScenarioManager.Faction = ScenarioManager.Faction.PIRATE

## How many lines have run their course. See [signal line_finished].
var lines_finished: int = 0

## Where the box folds away to once its line runs out, and unfolds from when
## the player asks for the line again: the targeting computer's comms badge,
## for as long as this ship is the one targeted (TargetingComputer sets it).
## Unset, the box fades where it is, as a ship off to the side doesn't own
## the badge.
var stow_point: Callable = Callable()

## The fold mirrors RegionAlert's into the environment monitor, a little
## overshoot coming out. The box is far smaller than that card and has
## further to go, so it keeps its size and colour for most of the trip and
## only fades once it's almost in, or it would vanish halfway there.
const _FOLD_SECONDS: float = 0.55
const _FOLD_FADE_SHARE: float = 0.15
const _UNFOLD_SECONDS: float = 0.4
## How big the box is at the stow point, coming and going.
const _STOWED_SCALE: float = 0.08

## How far the box's middle has travelled toward the stow point (0 beside
## the ship, 1 there) and how far it has shrunk (0 full size, 1 stowed).
## Separate, so the shrink can overshoot while the travel doesn't.
var _travel: float = 0.0
var _shrink: float = 0.0
var _fold_tween: Tween
## The stow point as last asked, so a box already on its way keeps going if
## the player retargets mid-fold.
var _stowed_at: Vector2 = Vector2.ZERO
## Whether the box is out beside the ship (or on its way in or out).
var _out: bool = false
## Whether a line is waiting for another ship to finish before it shows.
var _waiting_turn: bool = false


func _ready() -> void:
	add_to_group(&"enemy_dialogue_boxes")
	fadeout_timer = Timer.new()
	fadeout_timer.one_shot = true
	fadeout_timer.timeout.connect(_on_line_ran_out)
	add_child(fadeout_timer)

	_box_texture = faction_textures[_last_faction]
	_apply_side()

	Events.jump.connect(_on_jump)


## Shows [param dialogue] in [param faction]'s box. Unless
## [param wait_turn] is off, a line arriving right after another ship spoke
## waits its turn, so two ships don't talk over each other.
func show_dialogue(
	dialogue: String,
	faction: ScenarioManager.Faction = ScenarioManager.Faction.PIRATE,
	wait_turn: bool = true
) -> void:
	_say(dialogue, faction, wait_turn, false)


## [param unfold] brings the box out of [member stow_point] rather than
## fading it in beside the ship.
func _say(
	dialogue: String,
	faction: ScenarioManager.Faction,
	wait_turn: bool,
	unfold: bool
) -> void:
	if _silenced:
		return
	if dialogue != "":
		_last_line = dialogue
		_last_faction = faction
	# A line can be a translation key. Translated here rather than left to the
	# label, because the reveal below is timed off the text's length: a key
	# shorter than its line would cut the line off. Plain English passes
	# through unchanged.
	dialogue = tr(dialogue)

	# Check if we just showed a dialogue, and if so, just wait
	var current_time: int = Time.get_ticks_msec()
	if wait_turn and time_last_dialogue_was_shown and \
	current_time < time_last_dialogue_was_shown + (time_between_dialogues * 1000):
		var time_remaining: int = (time_last_dialogue_was_shown + (time_between_dialogues * 1000)) - current_time
		_waiting_turn = true
		await get_tree().create_timer(float(time_remaining) / 1000).timeout
		_waiting_turn = false
		# The player may have jumped away while this line waited its turn.
		if _silenced:
			return

	# Reset if we this was just called for another line of dialogue. The last
	# line's fade-out timer goes too, or it would cut this one off partway.
	fadeout_timer.stop()
	if character_reveal_tween:
		character_reveal_tween.kill()
	%RichTextLabel.visible_characters = 0
	%RichTextLabel.text = dialogue
	
	if dialogue == "":
		hide_dialogue()
		return

	_box_texture = faction_textures[faction]
	_fit_text()

	# Record the time this dialogue was shown
	time_last_dialogue_was_shown = Time.get_ticks_msec()

	if unfold and stow_point.is_valid():
		_unfold()
	else:
		_start_fade_in()
	line_shown.emit()
		
	character_reveal_tween = get_tree().create_tween()
	character_reveal_tween.tween_method(
		_show_characters, 
		0, 
		len(dialogue), 
		character_reveal_time * len(dialogue)
	).set_trans(Tween.TRANS_LINEAR)
	
	await character_reveal_tween.finished
	
	
	
	fadeout_timer.start(dialogue_time_shown)
	
	
## Whether the ship has said anything it could say again.
func has_line_to_replay() -> bool:
	return not _silenced and not _last_line.is_empty()


## Whether the box is out beside the ship, or on its way in or out.
func is_out() -> bool:
	return _out


## Whether this ship is talking, or has a line waiting its turn: what a
## cockpit moment (a carving of Fate's Die) waits out rather than talk over.
func is_speaking() -> bool:
	return not _silenced and (_waiting_turn or (_out and visible))


## Says the last line again, at once, out of the comms badge: the player
## asked for it.
func replay_last_line() -> void:
	if has_line_to_replay():
		_say(_last_line, _last_faction, false, true)


func _on_line_ran_out() -> void:
	lines_finished += 1
	line_finished.emit()
	if stow_point.is_valid():
		_stow()
	else:
		hide_dialogue()


func hide_dialogue() -> void:
	if fade_tween:
		fade_tween.kill()
	# A box cut off mid-fold fades from where it got to.
	if _fold_tween:
		_fold_tween.kill()

	fade_tween = get_tree().create_tween()
	fade_tween.tween_property(
		self,
		"modulate:a",
		0,
		fade_time
	).from_current()\
	.set_trans(Tween.TRANS_LINEAR)\
	.set_ease(Tween.EASE_IN_OUT)
	
	await fade_tween.finished
	hide()
	_set_fold(0.0, 0.0)
	_out = false
	put_away.emit(false)


## Shrinks into [member stow_point], fading out as it gets there.
func _stow() -> void:
	_stop_motion()
	_stowed_at = stow_point.call()
	_fold_tween = create_tween().set_parallel()
	_fold_tween.tween_method(_set_travel, 0.0, 1.0, _FOLD_SECONDS) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_fold_tween.tween_method(_set_shrink, 0.0, 1.0, _FOLD_SECONDS) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_fold_tween.tween_property(self, "modulate:a", 0.0, _FOLD_SECONDS * _FOLD_FADE_SHARE) \
		.set_delay(_FOLD_SECONDS * (1.0 - _FOLD_FADE_SHARE))
	_fold_tween.chain().tween_callback(func() -> void:
		hide()
		_set_fold(0.0, 0.0)
		_out = false
		put_away.emit(true)
	)


## Out of [member stow_point] and up beside the ship: the fold played
## backwards, so the player sees where the line was kept.
func _unfold() -> void:
	_stop_motion()
	_out = true
	_stowed_at = stow_point.call()
	modulate.a = 0.0
	_set_fold(1.0, 1.0)
	show()
	_fold_tween = create_tween().set_parallel()
	_fold_tween.tween_method(_set_travel, 1.0, 0.0, _UNFOLD_SECONDS) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_fold_tween.tween_method(_set_shrink, 1.0, 0.0, _UNFOLD_SECONDS) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_fold_tween.tween_property(self, "modulate:a", 1.0, _UNFOLD_SECONDS * 0.4)


## Stops any fade or fold in flight and puts the box back beside the ship.
func _stop_motion() -> void:
	if fade_tween:
		fade_tween.kill()
	if _fold_tween:
		_fold_tween.kill()
	_set_fold(0.0, 0.0)


func _set_travel(amount: float) -> void:
	_set_fold(amount, _shrink)


func _set_shrink(amount: float) -> void:
	_set_fold(_travel, amount)


func _set_fold(travel: float, shrink: float) -> void:
	_travel = travel
	_shrink = shrink
	_place()


## Puts the box where it belongs: beside the ship, or partway to
## [member stow_point]. It's the box's middle that travels, so it shrinks
## toward its middle rather than toward the ship it hangs off.
func _place() -> void:
	queue_redraw()
	var rest: Vector2 = _separated_rest(Vector2((anchor.x + _shift) * (-1.0 if points_left else 1.0), anchor.y))
	if is_zero_approx(_travel) and is_zero_approx(_shrink):
		scale = Vector2.ONE
		position = rest
		return
	if stow_point.is_valid():
		_stowed_at = stow_point.call()
	var size: float = lerpf(1.0, _STOWED_SCALE, _shrink)
	var parent: Node2D = get_parent() as Node2D
	var target: Vector2 = parent.to_local(_stowed_at) if parent else _stowed_at
	var box: Vector2 = _box_rect().get_center()
	scale = Vector2.ONE * size
	position = (rest + box).lerp(target, _travel) - box * size


## A ship left behind in the jump has nothing more to say to the player. The
## box fades the usual way, but drops level with the hull first: the ships fall
## away behind the cockpit as the player jumps, and the box at its normal
## height would hang in front of the cockpit until the fade caught up.
func _on_jump() -> void:
	_silenced = true
	z_index = 0
	fadeout_timer.stop()
	if character_reveal_tween:
		character_reveal_tween.kill()
	if visible:
		hide_dialogue()


func _start_fade_in() -> void:
	_stop_motion()
	_out = true
	show()
	
	fade_tween = get_tree().create_tween()
	fade_tween.tween_property(
		self,
		"modulate:a",
		1,
		fade_time
	).from(0)\
	.set_trans(Tween.TRANS_LINEAR)\
	.set_ease(Tween.EASE_IN_OUT)
	
	
## Puts the box on the ship's left or right. [EnemyManager] picks the side from
## where the ship stands, so neighbouring ships talk away from each other
## rather than over each other. [param room] is how far from the ship the box
## can reach to its left (x) and right (y) before it runs into something.
func point(left: bool, room: Vector2 = Vector2(INF, INF)) -> void:
	_prefers_left = left
	_room = room
	_apply_side()


## Settles which side the box goes on and how far out it sits, for the line
## it holds now: a long line's box can outgrow the side it was given, and
## then goes on the other side if that has more room.
func _choose_side() -> void:
	var rooms: Vector2 = _rooms()
	var reach: float = _reach()
	var left: bool = _prefers_left
	var preferred: float = rooms.x if left else rooms.y
	var other: float = rooms.y if left else rooms.x
	if preferred < reach - max_tuck and other > preferred:
		left = not left
	points_left = left
	var room: float = rooms.x if left else rooms.y
	var clearance: float = left_clearance if left else right_clearance
	_shift = clampf(room - reach, -max_tuck, clearance)


## How far the box can reach to the ship's left (x) and right (y): what
## [EnemyManager] measured, or the screen's edges if it hasn't.
func _rooms() -> Vector2:
	var rooms: Vector2 = _room
	var parent: Node2D = get_parent() as Node2D
	if parent and parent.is_inside_tree():
		var x: float = parent.global_position.x
		if is_inf(rooms.x):
			rooms.x = x - _SCREEN_MARGIN
		if is_inf(rooms.y):
			rooms.y = Globals.SCREEN_SIZE.x - _SCREEN_MARGIN - x
	return rooms


## How far from the ship the far edge of the box sits, unshifted.
func _reach() -> float:
	return anchor.x + _TAIL_TIP.x + _ART_BOX_LEFT + _box_size.x


func _apply_side() -> void:
	if not is_node_ready():
		return
	_choose_side()
	_place()


## The box (tail left out) in this node's coordinates, on whichever side of
## the tail it is.
func _box_rect() -> Rect2:
	var left: float = _TAIL_TIP.x + _ART_BOX_LEFT
	var top: float = roundf(_TAIL_TIP.y - _box_size.y * 0.5 + _box_dy)
	var rect: Rect2 = Rect2(left, top, _box_size.x, _box_size.y)
	if points_left:
		rect.position.x = -rect.end.x
	return rect


## Sizes the box to the label's text: the text wraps at
## [member max_text_width] into lines made as even as they can be, and the box
## hugs them. TextFit does the measuring and placing, as it does for every
## other fitted label, so the text sits by its ink and shrinks only if even
## [constant _MAX_LINES] lines can't hold it.
func _fit_text() -> void:
	var label: RichTextLabel = %RichTextLabel
	var policy: TextFitPolicy = TextFitPolicy.wrapping(_MAX_LINES)
	var natural: TextFit.Result = TextFit.solve(label, Rect2(0.0, 0.0, max_text_width, INF), policy)
	# Wrapped text is as wide as the width it was broken at, which can be a
	# little over its widest line: given only that line's width, the refit
	# below could break it onto one line more.
	var text_width: float = natural.block_size.x
	if natural.line_count > 1 and natural.wrap_width > 0.0:
		text_width = maxf(text_width, natural.wrap_width)
	var text_size: Vector2 = Vector2(text_width, natural.ink.size.y) * natural.scale
	var size: Vector2 = (text_size + _TEXT_PADDING * 2.0).ceil().max(_MIN_BOX_SIZE)
	# Even, so the box mirrors about its middle on whole pixels.
	_box_size = Vector2(ceilf(size.x * 0.5) * 2.0, ceilf(size.y * 0.5) * 2.0)
	var fit: TextFit.Result = TextFit.solve(label, Rect2(_TEXT_PADDING, _box_size - _TEXT_PADDING * 2.0), policy)
	TextFit.apply(label, fit)
	_text_offset = label.position
	_apply_side()


## The box art in pieces: the box from its right half, stretched, and that
## again mirrored for the left half; then the tail over the box's edge, all
## mirrored when the box is on the ship's left.
func _draw() -> void:
	if _box_texture == null:
		return
	var box: Rect2 = _box_rect()
	var middle: float = box.get_center().x
	_draw_half_box(Rect2(middle, box.position.y, box.size.x * 0.5, box.size.y), false)
	_draw_half_box(Rect2(box.position.x, box.position.y, box.size.x * 0.5, box.size.y), true)
	var mirror: float = -1.0 if points_left else 1.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(mirror, 1.0))
	var tail_top: float = _TAIL_TIP.y - _ART_TAIL.size.y * 0.5
	draw_texture_rect_region(_box_texture,
		Rect2(Vector2(_TAIL_TIP.x, tail_top), _ART_TAIL.size), Rect2(_ART_TAIL))
	draw_set_transform(Vector2.ZERO)


## Draws the right half of the box art stretched over [param area], mirrored
## left to right with [param mirrored].
func _draw_half_box(area: Rect2, mirrored: bool) -> void:
	var art: Vector2 = _box_texture.get_size()
	var corner: float = _ART_CORNER
	if mirrored:
		draw_set_transform(Vector2(area.end.x + area.position.x, 0.0), 0.0, Vector2(-1.0, 1.0))
	# The art's columns: plain box, then the right edge. Its rows: the top
	# edge, plain box, the bottom edge.
	var columns: Array[Vector2] = [Vector2(_ART_FILL.x, 1.0), Vector2(art.x - corner, corner)]
	var rows: Array[Vector2] = [Vector2(0.0, corner), Vector2(_ART_FILL.y, 1.0), Vector2(art.y - corner, corner)]
	var xs: Array[Vector2] = [Vector2(area.position.x, area.size.x - corner), Vector2(area.end.x - corner, corner)]
	var ys: Array[Vector2] = [Vector2(area.position.y, corner),
		Vector2(area.position.y + corner, area.size.y - corner * 2.0), Vector2(area.end.y - corner, corner)]
	for column: int in range(2):
		for row: int in range(3):
			if xs[column].y <= 0.0 or ys[row].y <= 0.0:
				continue
			draw_texture_rect_region(_box_texture,
				Rect2(xs[column].x, ys[row].x, xs[column].y, ys[row].y),
				Rect2(columns[column].x, rows[row].x, columns[column].y, rows[row].y))
	draw_set_transform(Vector2.ZERO)


func _show_characters(num: int) -> void:
	if %RichTextLabel.visible_characters != num and RNGManager.randi_range(RNGManager.Bucket.COSMETIC, 1, 5) == 1:
		Events.play_sound.emit(_TEXT_BLIP_SFX)
		
	%RichTextLabel.visible_characters = num


func _set_text(text: String) -> void:
	%RichTextLabel.text = \
		"[wave amp=2.0 freq=2.0 connected=0]" + \
		text + \
		"[/wave]"


func _process(_delta: float) -> void:
	if _out:
		_place()


## Earlier ships keep their place; later ships choose the nearest free row.
## Considering every occupied edge at once avoids bubbles pushing each other
## back and forth as a formation slides or a new line unfolds.
##
## The box keeps on screen too. Moving up or down, it slides past its tail as
## far as the tail can still meet a straight edge, so the tail keeps pointing
## at the ship; only past that does the whole bubble move. Sets
## [member _box_dy] and returns where this node goes.
func _separated_rest(rest: Vector2) -> Vector2:
	_box_dy = 0.0
	var parent: Node2D = get_parent() as Node2D
	if parent == null or not is_inside_tree():
		_place_label()
		return rest
	var box_rect: Rect2 = _box_rect()
	var half: Vector2 = box_rect.size * 0.5
	var start: Vector2 = parent.to_global(rest + box_rect.get_center())
	var low: Vector2 = half + Vector2.ONE * _SCREEN_MARGIN
	var high: Vector2 = Globals.SCREEN_SIZE - low
	var center: Vector2 = start.clamp(low, high)
	var occupied: Array[Rect2] = []
	var rows: Array[float] = [center.y]
	for node: Node in get_tree().get_nodes_in_group(&"enemy_dialogue_boxes"):
		var other: EnemyDialogueManager = node as EnemyDialogueManager
		if other == self or not other._out or not other.visible \
			or other.get_instance_id() > get_instance_id() or other._travel > 0.1:
			continue
		var rect: Rect2 = other._global_box_rect().grow(2.0)
		if center.x + half.x <= rect.position.x or center.x - half.x >= rect.end.x:
			continue
		occupied.append(rect)
		rows.append(clampf(rect.position.y - half.y - 1.0, low.y, high.y))
		rows.append(clampf(rect.end.y + half.y + 1.0, low.y, high.y))
	var best_y: float = center.y
	var best_score: float = INF
	for row: float in rows:
		var candidate: Rect2 = Rect2(Vector2(center.x, row) - half, half * 2.0)
		var score: float = absf(row - center.y)
		for rect: Rect2 in occupied:
			if candidate.intersects(rect):
				score += 1000.0
		if score < best_score:
			best_y = row
			best_score = score
	center.y = best_y

	var slide: float = maxf(half.y - _TAIL_INSET, 0.0)
	_box_dy = roundf(clampf(center.y - start.y, -slide, slide))
	_place_label()
	return parent.to_local(center) - _box_rect().get_center()


## The box on screen, for the bubbles that come after it to keep clear of.
func _global_box_rect() -> Rect2:
	var rect: Rect2 = _box_rect()
	return Rect2(to_global(rect.position), rect.size * global_scale.abs())


## Keeps the text in the box wherever the box has gone.
func _place_label() -> void:
	%RichTextLabel.position = _box_rect().position + _text_offset
