class_name MoneyIndicator
extends Node2D

@export var money_label: RichTextLabel
@export var money_change_label: RichTextLabel

# Configuration
@export var grace_period: float = 1.0  # Time window to accumulate changes
@export var max_countdown_time: float = 2.0  # Maximum time a countdown is allowed to take

var countdown_tick_duration: float = 0.03 

var total_change: int = 0
var grace_timer: Timer
var countdown_tween: Tween

func _ready() -> void:
	Globals.money_indicator = self
	
	_update_money_display(0)
	
	# Initialize the grace period timer
	grace_timer = Timer.new()
	grace_timer.one_shot = true
	grace_timer.timeout.connect(_on_grace_period_expired)
	add_child(grace_timer)
	
	Events.set_money.connect(_on_money_changed)
	Events.spawn_reward.connect(
		func(_pos: Vector2, reward_resource: RewardResource) -> void:
			if reward_resource.max_money > 0:
				_fade_in()
	)
	
	hide()
	

func _on_money_changed(new_value: int) -> void:
	total_change = new_value - int(money_label.text)
	
	if countdown_tween:
		countdown_tween.kill()
		
	# Start grace period
	grace_timer.start(grace_period)
		
	# Show the change label with the total change
	_show_change_label(total_change)


func _on_grace_period_expired() -> void:
	# Start the countdown animation
	_start_countdown_animation()


func _show_change_label(change: int) -> void:
	money_change_label.visible = true
	
	if change > 0:
		money_change_label.text = "+" + str(change)
		money_change_label.modulate = Globals.green
	elif change < 0:
		money_change_label.text = str(change)
		money_change_label.modulate = Globals.red
	else:
		money_change_label.visible = false


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
		func(): money_change_label.visible = false
	).set_delay(countdown_duration)


func _update_change_display(value: int) -> void:
	if value > 0:
		money_change_label.text = "+" + str(value)
	elif value < 0:
		money_change_label.text = str(value)
	else:
		money_change_label.text = ""


func _update_money_display(value: int) -> void:
	money_label.text = str(value)
	

func _fade_in() -> void:
	# This should only ever be called once,
	# so disconnect the triggering signal
	if Events.combat_finished.is_connected(_fade_in):
		Events.combat_finished.disconnect(_fade_in)
		
	self_modulate.a = 0
	show()
	
	var fade_time: float = 2
	
	var tween: Tween = get_tree().create_tween()
	tween.tween_property(
		self,
		"modulate:a",
		1,
		fade_time
	).from(0)\
	.set_trans(Tween.TRANS_LINEAR)\
	.set_ease(Tween.EASE_IN_OUT)
