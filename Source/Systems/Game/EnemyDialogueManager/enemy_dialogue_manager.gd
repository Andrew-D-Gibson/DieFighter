class_name EnemyDialogueManager
extends Node2D

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
## back at the ship. See [method point].
var points_left: bool = false

## The box and text's authored x, which pointing left mirrors.
var _box_x: float
var _text_x: float

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


func _ready() -> void:
	fadeout_timer = Timer.new()
	fadeout_timer.one_shot = true
	fadeout_timer.timeout.connect(_on_line_ran_out)
	add_child(fadeout_timer)

	_box_x = %Sprite2D.position.x
	_text_x = %RichTextLabel.position.x
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
		await get_tree().create_timer(float(time_remaining) / 1000).timeout
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

	# Record the time this dialogue was shown
	time_last_dialogue_was_shown = Time.get_ticks_msec()

	if unfold and stow_point.is_valid():
		_unfold()
	else:
		_start_fade_in()
	%Sprite2D.texture = faction_textures[faction]
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
	var rest: Vector2 = Vector2((anchor.x + _shift) * (-1.0 if points_left else 1.0), anchor.y)
	if is_zero_approx(_travel) and is_zero_approx(_shrink):
		scale = Vector2.ONE
		position = rest
		return
	if stow_point.is_valid():
		_stowed_at = stow_point.call()
	var size: float = lerpf(1.0, _STOWED_SCALE, _shrink)
	var parent: Node2D = get_parent() as Node2D
	var target: Vector2 = parent.to_local(_stowed_at) if parent else _stowed_at
	var box: Vector2 = %Sprite2D.position
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
## can reach on that side before it runs into something.
func point(left: bool, room: float) -> void:
	points_left = left
	_shift = 0.0
	if is_node_ready():
		var clearance: float = left_clearance if left else right_clearance
		_shift = clampf(room - _reach(), -max_tuck, clearance)
	_apply_side()


## How far from the ship the far edge of the box sits, unshifted.
func _reach() -> float:
	return anchor.x + _box_x + %Sprite2D.texture.get_width() * 0.5


func _apply_side() -> void:
	if not is_node_ready():
		return

	var label: RichTextLabel = %RichTextLabel
	if points_left:
		%Sprite2D.position.x = -_box_x
		label.position.x = -_text_x - label.size.x
	else:
		%Sprite2D.position.x = _box_x
		label.position.x = _text_x
	%Sprite2D.flip_h = points_left
	_place()


func _show_characters(num: int) -> void:
	if %RichTextLabel.visible_characters != num and RNGManager.randi_range(RNGManager.Bucket.COSMETIC, 1, 5) == 1:
		Events.play_sound.emit(_TEXT_BLIP_SFX)
		
	%RichTextLabel.visible_characters = num


func _set_text(text: String) -> void:
	%RichTextLabel.text = \
		"[wave amp=2.0 freq=2.0 connected=0]" + \
		text + \
		"[/wave]"
