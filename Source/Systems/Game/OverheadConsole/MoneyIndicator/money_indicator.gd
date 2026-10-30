class_name MoneyIndicator
extends Node2D
## The credit readout in the OverheadConsole's case. Changes collect for a
## moment, then count across into the balance. A run starts with no credits
## and the console up; the first credits bring it down (the first payout coin
## taking off is enough) and it stays down for the rest of the run, even if the
## balance is spent back to 0.

## What the readout asks the console for while it has something to show.
const _CONSOLE_REQUEST: StringName = &"credits"
## The knock a coin gives the console as it lands.
const _COIN_SWAY_DEGREES: float = 2.0

@export var money_label: RichTextLabel
@export var money_change_label: RichTextLabel

# Configuration
@export var grace_period: float = 1.0  # Time window to accumulate changes
@export var max_countdown_time: float = 2.0  # Maximum time a countdown is allowed to take
var countdown_tick_duration: float = 0.03 

## The change label floats over whatever is behind the cockpit, so it carries a
## dark 1px outline. Built from offset copies: the font's MSDF outline comes out
## soft and patchy at this size.
const _OUTLINE_COLOR: Color = Color(0.0156863, 0.00784314, 0.0901961, 1)
const _OUTLINE_OFFSETS: Array[Vector2] = [
	Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1),
	Vector2(-1, 0), Vector2(1, 0),
	Vector2(-1, 1), Vector2(0, 1), Vector2(1, 1),
]
## Hotter than the palette red, which sinks into the dark sky.
const _LOSS_COLOR: Color = Color(1.0, 0.301961, 0.427451, 1)
var _change_outline_labels: Array[RichTextLabel] = []

var total_change: int = 0
var grace_timer: Timer
var countdown_tween: Tween

## Set by the console that carries the readout. Null when it stands alone.
var console: OverheadConsole = null

## Credits have come in this run, so the readout stays on show for good.
var _earned: bool = false
## Payout coins still in the air before the first credits land, which the
## readout has to be down to catch.
var _coins_in_flight: int = 0

func _ready() -> void:
	Globals.money_indicator = self
	
	_update_money_display(0)
	_build_change_outline()
	
	# Initialize the grace period timer
	grace_timer = Timer.new()
	grace_timer.one_shot = true
	grace_timer.timeout.connect(_on_grace_period_expired)
	add_child(grace_timer)

	Events.set_money.connect(_on_money_changed)
	Events.load_game_save.connect(_on_load_game_save)


## Where coins should fly to (and lost ones start from): the readout's place
## once the console is down, even while it is still on its way.
func coin_target() -> Vector2:
	return console.rest_global_position(self) if console else global_position


## A payout or loss coin has taken off. Before the run's first credits the
## console comes down for it, so the coin has somewhere to land.
func track_coin(coin: Node) -> void:
	_coins_in_flight += 1
	coin.tree_exiting.connect(_on_coin_gone, CONNECT_ONE_SHOT)
	_refresh_request()


func _on_coin_gone() -> void:
	_coins_in_flight = maxi(0, _coins_in_flight - 1)
	_refresh_request()


## A save from partway through a run has had credits already, even if they're
## all spent, so the readout comes back down with it.
func _on_load_game_save(game_save: GameSaveResource) -> void:
	_update_money_display(game_save.money)
	_earned = game_save.money > 0 or int(game_save.run_stats.get("credits_earned", 0)) > 0
	_refresh_request()


func _is_counting() -> bool:
	return not grace_timer.is_stopped() \
		or (countdown_tween != null and countdown_tween.is_valid() and countdown_tween.is_running())


func _refresh_request() -> void:
	if console == null:
		return
	console.request_down(_CONSOLE_REQUEST, _earned or _coins_in_flight > 0)


func _on_money_changed(new_value: int) -> void:
	var previous_change: int = total_change if _is_counting() else 0
	total_change = new_value - int(money_label.text)

	# Any real balance change (reward, shop, dev tools) brings the readout
	# down for good, rather than relying on each source to announce itself.
	if total_change == 0:
		return
	_earned = true
	# Each coin landing knocks the console a little.
	if console and total_change > previous_change:
		console.sway(_COIN_SWAY_DEGREES)

	if countdown_tween:
		countdown_tween.kill()
		
	# Start grace period
	grace_timer.start(grace_period)
	_refresh_request()

	# Show the change label with the total change
	_show_change_label(total_change)


func _on_grace_period_expired() -> void:
	# Start the countdown animation
	_start_countdown_animation()


func _show_change_label(change: int) -> void:
	money_change_label.visible = true
	
	# Undo the previous countdown's fade-out.
	money_change_label.modulate.a = 1.0
	if change > 0:
		money_change_label.add_theme_color_override("default_color", Globals.green)
	elif change < 0:
		money_change_label.add_theme_color_override("default_color", _LOSS_COLOR)
	else:
		money_change_label.visible = false
	_update_change_display(change)


func _start_countdown_animation() -> void:
	if total_change == 0:
		money_change_label.visible = false
		return
	
	# Cancel any existing tween
	if countdown_tween:
		countdown_tween.kill()
	
	countdown_tween = create_tween()
	countdown_tween.set_parallel(true)
	
	var countdown_duration: float = clamp(
		abs(total_change) * countdown_tick_duration,
		0,
		max_countdown_time
	)
	
	# Animate the change label counting down to 0
	countdown_tween.tween_method(
		_update_change_display, 
		total_change, 
		0, 
		countdown_duration
	).set_trans(Tween.TRANS_LINEAR)
	
	# Animate the main money label counting up to final value
	countdown_tween.tween_method(
		_update_money_display, 
		int(money_label.text), 
		Globals.player.money, 
		countdown_duration
	).set_trans(Tween.TRANS_LINEAR)
	
	# Fade out the change label at the end
	countdown_tween.tween_property(
		money_change_label, 
		"modulate:a", 
		0.0, 
		countdown_duration * 0.5
	).set_delay(countdown_duration * 0.5)
	
	# Hide the change label when animation completes
	countdown_tween.tween_callback(
		func() -> void: money_change_label.visible = false
	).set_delay(countdown_duration)


func _update_change_display(value: int) -> void:
	var text: String = ""
	if value > 0:
		text = "+" + str(value)
	elif value < 0:
		text = str(value)
	money_change_label.text = text
	for outline_label: RichTextLabel in _change_outline_labels:
		outline_label.text = text


## Children of the change label, so they share its visibility and fade.
func _build_change_outline() -> void:
	# The outline pokes a pixel past the label's rect.
	money_change_label.clip_contents = false
	# Duplicate them all before attaching any, or each copy also clones the
	# outline labels already attached.
	for offset: Vector2 in _OUTLINE_OFFSETS:
		var outline_label: RichTextLabel = money_change_label.duplicate() as RichTextLabel
		outline_label.visible = true
		outline_label.show_behind_parent = true
		outline_label.position = offset
		outline_label.add_theme_color_override("default_color", _OUTLINE_COLOR)
		_change_outline_labels.append(outline_label)
	for outline_label: RichTextLabel in _change_outline_labels:
		money_change_label.add_child(outline_label)


func _update_money_display(value: int) -> void:
	money_label.text = str(value)
